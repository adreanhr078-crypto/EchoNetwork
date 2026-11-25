using System.Collections;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;
using UnityEngine.Video;

namespace ElevenEleven.Opening
{
    internal enum WardBeat { Bedside, Awake, MarkRevealed }

    public sealed class StationHospitalWard : MonoBehaviour
    {
        [SerializeField] private GameObject ward;
        [SerializeField] private Transform bedside;
        [SerializeField] private Transform vanity;
        [SerializeField] private Transform mirror;
        [SerializeField] private Transform bedsideShot;
        [SerializeField] private Transform mirrorShot;
        [SerializeField] private Transform closeShot;
        [SerializeField] private AudioSource mirrorCue;
        [SerializeField] private Light markLight;
        [SerializeField] private StationReflection reflection;
        [SerializeField] private GameObject panel;
        [SerializeField] private RawImage media;
        [SerializeField] private Texture2D poster;
        [SerializeField] private VideoPlayer film;
        [SerializeField] private Text speaker;
        [SerializeField] private Text line;
        [SerializeField] private Button advance;

        private Room01Player actor;
        private Coroutine playback;
        private bool playing;
        private bool entered;
        private bool mirageSeen;
        private bool cuePlayed;
        private bool fromCheckpoint;

        internal WardBeat Beat { get; private set; }
        internal bool IsReading => panel.activeSelf;
        internal bool OwnsShot => IsReading || (reflection.MirageSequenceActive && !ChapterSceneLink.ReducedMotion &&
            actor != null && InMirrorReach(actor.transform.position));
        private bool OnCloseShot => reflection.MirageActive && !ChapterSceneLink.ReducedMotion;
        internal Transform Shot => Beat == WardBeat.Bedside ? bedsideShot : OnCloseShot ? closeShot : mirrorShot;
        internal float ShotFov => OnCloseShot ? 36f : 50f;
        internal Vector3 ReturnPoint => Beat == WardBeat.MarkRevealed ? vanity.position : bedside.position;

        private static string Copy(string english, string arabic) => EntryCopy.Arabic ? arabic : english;

        internal string Objective => Beat switch
        {
            WardBeat.Bedside => Copy("Open your eyes.", ".ﻚﻴﻨﻴﻋ ﺢﺘﻓﺍ"),
            WardBeat.Awake => Copy("Find the mirror and inspect the mark.", ".ﺮﺛﻷﺍ ﺺﺤﻓﺍﻭ ﺓﺁﺮﻤﻟﺍ ﻰﻟﺇ ﻪﺠﺗﺍ"),
            _ => Copy("Chapter 1 complete.", ".ﻝﻭﻷﺍ ﻞﺼﻔﻟﺍ ﻰﻬﺘﻧﺍ"),
        };

        internal void Restore(bool transferred, WardBeat beat)
        {
            Beat = beat;
            fromCheckpoint = transferred;
            ward.SetActive(transferred);
            markLight.enabled = false;
        }

        internal void Tick(Room01Player player)
        {
            Enter(player);
            if (Time.timeScale > 0f) reflection.AdvanceMirage(Time.unscaledDeltaTime);
            if (Beat == WardBeat.Awake)
            {
                if (InMirrorReach(player.transform.position)) Reveal(player);
                else if (reflection.MirageSequenceActive)
                {
                    reflection.LookAway();
                    mirageSeen = false;
                }
            }
            markLight.enabled = reflection.MirageActive;
            if (reflection.MirageActive && !cuePlayed)
            {
                cuePlayed = true;
                if (!ChapterSceneLink.Muted) mirrorCue.Play();
            }
        }

        private void Reveal(Room01Player player)
        {
            if (mirageSeen) return;
            mirageSeen = true;
            player.FaceRouteFocus(mirror.position);
            cuePlayed = false;
            reflection.RevealMirage();
        }

        private void Enter(Room01Player player)
        {
            if (entered) return;
            entered = true;
            actor = player;
            ward.SetActive(true);
            actor.ApplyPactAppearance(false);
            if (!fromCheckpoint) actor.ReturnToSafePoint(ReturnPoint, "");
            if (Beat != WardBeat.Bedside) return;
            actor.FaceRouteFocus(mirror.position);
            Open();
            if (!fromCheckpoint && !ChapterSceneLink.ReducedMotion && film.clip != null)
                playback = StartCoroutine(PlayFilm());
        }

        private IEnumerator PlayFilm()
        {
            playing = true;
            media.gameObject.SetActive(true);
            media.texture = poster;
            line.text = "";
            AdvanceLabel(Copy("Skip scene", "ﺪﻬﺸﻤﻟﺍ ﻂﺨﺗ"));
            film.Prepare();
            var deadline = Time.realtimeSinceStartupAsDouble + 6;
            while (!film.isPrepared && Time.realtimeSinceStartupAsDouble < deadline) yield return null;
            if (film.isPrepared)
            {
                film.Play();
                deadline = Time.realtimeSinceStartupAsDouble + film.length + 3;
                while (Time.realtimeSinceStartupAsDouble < deadline)
                {
                    if (film.texture != null && film.frame >= 0)
                    {
                        media.texture = film.texture;
                        if (film.frame + 1 >= (long)film.frameCount) break;
                    }
                    yield return null;
                }
            }
            playback = null;
            FinishFilm();
        }

        private void FinishFilm()
        {
            if (playback != null) StopCoroutine(playback);
            playback = null;
            playing = false;
            film.Stop();
            Present();
        }

        internal string Action(Vector3 position)
        {
            return Beat == WardBeat.Awake && InMirrorReach(position)
                ? Copy("Inspect the mirror [E]", "ﺓﺁﺮﻤﻟﺍ ﺺﺤﻓﺍ") : "";
        }

        private bool InMirrorReach(Vector3 position)
        {
            var offset = vanity.position - position;
            return Mathf.Abs(offset.y) < 0.6f && new Vector2(offset.x, offset.z).sqrMagnitude <= 1.1f * 1.1f;
        }

        internal void Interact(Vector3 position)
        {
            if (Action(position).Length == 0) return;
            if (!actor.TrySaveWardBeat(Beat, WardBeat.MarkRevealed))
            {
                actor.ShowRouteNote(Copy("Could not save the mark. Try again.", ".ﺍﺩﺪﺠﻣ ﻝﻭﺎﺣ .ﺮﺛﻷﺍ ﻆﻔﺣ ﺭﺬﻌﺗ"));
                return;
            }
            Reveal(actor);
            Beat = WardBeat.MarkRevealed;
            actor.ReturnToSafePoint(vanity.position, "");
            actor.FaceRouteFocus(mirror.position);
            Open();
        }

        private void Open()
        {
            panel.SetActive(true);
            actor.HoldForExamination(true);
            Present();
            if (EventSystem.current != null) EventSystem.current.SetSelectedGameObject(advance.gameObject);
        }

        private void Present()
        {
            media.gameObject.SetActive(Beat == WardBeat.Bedside);
            if (Beat == WardBeat.Bedside) media.texture = poster;
            speaker.text = Beat == WardBeat.Bedside ? Copy("Hospital", "ﻰﻔﺸﺘﺴﻤﻟﺍ") : "EX-011";
            line.text = Beat == WardBeat.Bedside
                ? Copy("Do not move. Rest is important.", ".ﺔﻤﻬﻣ ﺔﺣﺍﺮﻟﺍ .ﻙﺮﺤﺘﺗ ﻻ")
                : Copy("The experiment’s trace remains.\nChapter 1 complete.", ".ﺔﺑﺮﺠﺘﻟﺍ ﺮﺛﺃ ﻝﺍﺯ ﺎﻣ\n.ﻝﻭﻷﺍ ﻞﺼﻔﻟﺍ ﻰﻬﺘﻧﺍ");
            AdvanceLabel(Beat == WardBeat.Bedside ? Copy("Open your eyes", "ﻚﻴﻨﻴﻋ ﺢﺘﻓﺍ") :
                Copy("Look away", "ﻙﺮﻈﻧ ﺪﻌﺑﺃ"));
        }

        private void AdvanceLabel(string label) => advance.GetComponentInChildren<Text>().text = label;

        public void Advance()
        {
            if (!IsReading || Time.timeScale <= 0f) return;
            if (playing)
            {
                FinishFilm();
                return;
            }
            if (Beat == WardBeat.Bedside)
            {
                if (!actor.TrySaveWardBeat(Beat, WardBeat.Awake))
                {
                    line.text = Copy("Could not save. Try again.", ".ﺍﺩﺪﺠﻣ ﻝﻭﺎﺣ .ﻆﻔﺤﻟﺍ ﺭﺬﻌﺗ");
                    return;
                }
                Beat = WardBeat.Awake;
            }
            reflection.LookAway();
            mirrorCue.Stop();
            panel.SetActive(false);
            actor.HoldForExamination(false);
            if (EventSystem.current != null) EventSystem.current.SetSelectedGameObject(null);
        }

        internal void Dismiss()
        {
            if (playing) FinishFilm();
            else if (Beat == WardBeat.MarkRevealed) Advance();
        }

        private void OnDisable()
        {
            if (film != null) film.Stop();
        }
    }
}
