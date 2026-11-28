using System.Collections;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace ElevenEleven.Opening
{
    public sealed class OpeningReviewHost : MonoBehaviour
    {
        [SerializeField] private GameObject coverPanel;
        [SerializeField] private GameObject filmPanel;
        [SerializeField] private OpeningCinematicPresenter cinematic;
        [SerializeField] private Text dialogue;
        [SerializeField] private Button nextShot;
        [SerializeField] private Button skip;
        [SerializeField] private CanvasGroup skipGroup;
        [SerializeField] private Texture playGlyph;
        [SerializeField] private Texture pauseGlyph;
        [SerializeField] private Texture soundGlyph;
        [SerializeField] private Texture muteGlyph;
        [SerializeField] private Button pause;
        [SerializeField] private Button experimentQuestion;
        [SerializeField] private Button safetyQuestion;
        [SerializeField] private Button ready;
        [SerializeField] private Button back;
        [SerializeField] private Button motion;
        [SerializeField] private Button sound;

        [SerializeField] private bool useChapterPreferences;

        private bool reducedMotion;
        private bool muted;
        private GameObject wakePanel;
        private Text wakeTitle;
        private Text wakeMessage;
        private Coroutine skipResponse;

        private void Update()
        {
            if (cinematic.Beat == OpeningBeat.SystemWake)
                nextShot.interactable = cinematic.CanAdvance && !cinematic.Paused;

            if (skipResponse != null) return;
            var visible = cinematic.CanSkip ? 1f : 0f;
            skipGroup.alpha = reducedMotion ? visible :
                Mathf.MoveTowards(skipGroup.alpha, visible, 6f * Time.unscaledDeltaTime);
        }

        public void Skip()
        {
            if (!cinematic.CanSkip || skipResponse != null) return;
            if (reducedMotion) cinematic.SkipShot();
            else skipResponse = StartCoroutine(ConfirmSkip());
        }

        private IEnumerator ConfirmSkip()
        {
            var rect = skip.transform;
            var beat = cinematic.Beat;
            skip.interactable = false;
            rect.localScale = Vector3.one * 0.94f;
            yield return new WaitForSecondsRealtime(0.10f);
            rect.localScale = Vector3.one;
            skipGroup.alpha = 0f;
            skipResponse = null;
            if (cinematic.Beat == beat) cinematic.SkipShot();
        }

        private void OnEnable() => cinematic.StateChanged += Refresh;

        private void Start()
        {
            if (!useChapterPreferences) return;
            if (ChapterSceneLink.ReducedMotion != reducedMotion) ToggleMotion();
            if (ChapterSceneLink.Muted != muted) ToggleSound();
            cinematic.GetComponent<ChapterSceneLink>()?.PrepareDestination();
        }

        private void OnDestroy()
        {
            if (useChapterPreferences && cinematic != null)
                cinematic.GetComponent<ChapterSceneLink>()?.ReleasePreparation();
        }
        private void OnDisable() => cinematic.StateChanged -= Refresh;

        public void EnterFilm()
        {
            coverPanel.SetActive(false);
            filmPanel.SetActive(true);
            cinematic.Begin();
        }

        public void ToggleMotion()
        {
            reducedMotion = !reducedMotion;
            if (useChapterPreferences) ChapterSceneLink.ReducedMotion = reducedMotion;
            cinematic.SetReducedMotion(reducedMotion);
            motion.GetComponentInChildren<Text>(true).text = reducedMotion ? EntryCopy.MotionOff : EntryCopy.MotionOn;
            motion.GetComponentInChildren<RawImage>(true).texture = reducedMotion ? playGlyph : pauseGlyph;
        }

        public void ToggleSound()
        {
            muted = !muted;
            if (useChapterPreferences) ChapterSceneLink.Muted = muted;
            cinematic.SetMuted(muted);
            sound.GetComponentInChildren<Text>(true).text = muted ? EntryCopy.SoundOff : EntryCopy.SoundOn;
            sound.GetComponentInChildren<RawImage>(true).texture = muted ? muteGlyph : soundGlyph;
        }

        private void ShowWakePanel()
        {
            if (wakePanel == null)
            {
                var rect = WakeElement("System Wake panel", filmPanel.transform, new Vector2(0.22f, 0.35f), new Vector2(0.78f, 0.72f));
                wakePanel = rect.gameObject;
                var plate = wakePanel.AddComponent<Image>();
                plate.color = new Color(0.027f, 0.073f, 0.134f, 0.96f);
                plate.raycastTarget = false;
                var edge = wakePanel.AddComponent<Outline>();
                edge.effectColor = new Color(0.37f, 0.75f, 0.91f, 0.82f);
                edge.effectDistance = new Vector2(1f, 1f);
                edge.useGraphicAlpha = false;
                wakeTitle = WakeLabel(rect, "System clock", 28, 0.61f, 0.90f, new Color(0.55f, 0.87f, 1f));
                wakeMessage = WakeLabel(rect, "Experiment result", 32, 0.13f, 0.62f, new Color(0.9f, 0.95f, 1f));
            }
            wakeTitle.text = EntryCopy.WakeTitle;
            wakeMessage.text = EntryCopy.WakeMessage;
            wakePanel.SetActive(true);
        }

        private Text WakeLabel(Transform parent, string name, int size, float bottom, float top, Color tint)
        {
            var rect = WakeElement(name, parent, new Vector2(0.08f, bottom), new Vector2(0.92f, top));
            var label = rect.gameObject.AddComponent<Text>();
            label.font = dialogue.font;
            label.alignment = TextAnchor.MiddleCenter;
            label.color = tint;
            label.fontSize = size;
            label.resizeTextForBestFit = true;
            label.resizeTextMinSize = 16;
            label.resizeTextMaxSize = size;
            label.raycastTarget = false;
            return label;
        }

        private static RectTransform WakeElement(string name, Transform parent, Vector2 min, Vector2 max)
        {
            var rect = (RectTransform)new GameObject(name, typeof(RectTransform)).transform;
            rect.SetParent(parent, false);
            rect.anchorMin = min;
            rect.anchorMax = max;
            rect.offsetMin = Vector2.zero;
            rect.offsetMax = Vector2.zero;
            return rect;
        }

        private void Refresh()
        {
            var beat = cinematic.Beat;
            var questions = beat == OpeningBeat.Questions;
            var reply = beat == OpeningBeat.ExperimentReply || beat == OpeningBeat.SafetyReply;
            var finished = beat == OpeningBeat.Complete;
            var waking = beat == OpeningBeat.SystemWake;
            if (waking && cinematic.WakeRevealed) ShowWakePanel();
            else if (wakePanel != null) wakePanel.SetActive(false);
            experimentQuestion.gameObject.SetActive(questions);
            safetyQuestion.gameObject.SetActive(questions);
            ready.gameObject.SetActive(questions);
            back.gameObject.SetActive(reply);
            dialogue.transform.parent.gameObject.SetActive(questions || reply);
            nextShot.gameObject.SetActive((waking && cinematic.WakeRevealed) || cinematic.CanAdvance);
            pause.gameObject.SetActive(cinematic.IsFilmBeat || waking);
            skip.interactable = cinematic.CanSkip && skipResponse == null;
            skipGroup.blocksRaycasts = skip.interactable;
            skipGroup.interactable = skip.interactable;

            nextShot.interactable = cinematic.CanAdvance && !cinematic.Paused;
            foreach (var button in new[] { experimentQuestion, safetyQuestion, ready, back })
                button.interactable = !cinematic.Paused;

            nextShot.GetComponentInChildren<Text>(true).text = waking ? EntryCopy.Awaken : EntryCopy.Continue;
            skip.GetComponentInChildren<Text>(true).text = EntryCopy.Skip;
            pause.GetComponentInChildren<Text>(true).text = cinematic.Paused ? EntryCopy.Resume : EntryCopy.Pause;
            pause.GetComponentInChildren<RawImage>(true).texture = cinematic.Paused ? playGlyph : pauseGlyph;
            motion.GetComponentInChildren<Text>(true).text = reducedMotion ? EntryCopy.MotionOff : EntryCopy.MotionOn;
            sound.GetComponentInChildren<Text>(true).text = muted ? EntryCopy.SoundOff : EntryCopy.SoundOn;
            experimentQuestion.GetComponentInChildren<Text>(true).text = EntryCopy.Experiment;
            safetyQuestion.GetComponentInChildren<Text>(true).text = EntryCopy.Safety;
            ready.GetComponentInChildren<Text>(true).text = EntryCopy.Ready;
            back.GetComponentInChildren<Text>(true).text = EntryCopy.Questions;
            dialogue.text = beat switch
            {
                OpeningBeat.Questions => EntryCopy.EchoQuestion,
                OpeningBeat.ExperimentReply => EntryCopy.FatherExperiment,
                OpeningBeat.SafetyReply => EntryCopy.FatherSafety,
                OpeningBeat.Complete when !useChapterPreferences => "Opening complete. Room 01 is awaiting integration.",
                _ => "",
            };

            var events = EventSystem.current;
            if (!finished && events != null &&
                (events.currentSelectedGameObject == null || !events.currentSelectedGameObject.activeInHierarchy))
                events.SetSelectedGameObject((questions ? experimentQuestion : reply ? back :
                    nextShot.gameObject.activeSelf ? nextShot : pause).gameObject);
        }
    }
}
