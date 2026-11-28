using System;
using System.Collections;
using UnityEngine;
using UnityEngine.Events;
using UnityEngine.UI;
using UnityEngine.Video;

namespace ElevenEleven.Opening
{
    public sealed class OpeningCinematicPresenter : MonoBehaviour
    {
        private const float WakeDuration = 2.8f;
        private const float WakeSoundLead = 0.38f;

        [Serializable]
        private struct Shot
        {
            public VideoClip clip;
            public Texture2D poster;
            public AudioClip ambience;
        }

        [SerializeField] private Shot school;
        [SerializeField] private Shot laboratory;
        [SerializeField] private Shot experiment;
        [SerializeField] private Shot memory;
        [SerializeField] private RawImage surface;
        [SerializeField] private VideoPlayer player;
        [SerializeField] private AudioSource ambience;
        [SerializeField] private AudioClip wakeAmbience;
        [SerializeField] private AudioClip wakeFoley;
        [SerializeField] private UnityEvent completed = new UnityEvent();

        private readonly OpeningSequence sequence = new OpeningSequence();
        private Coroutine prepareShot;
        private bool started;
        private bool reducedMotion;
        private bool completedRaised;
        private bool mediaPlaying;
        private bool showingVideo;
        private float ambienceVolume;
        private float watchedSeconds;
        private float skipWindow;
        private bool offeredSkip;
        private ChapterSceneLink destination;
        private OpeningWakeAudio wakeAudio;

        public OpeningBeat Beat => sequence.Beat;
        public OpeningQuestion Asked => sequence.Asked;
        public bool Paused => sequence.Paused;
        public bool ShowingVideo => showingVideo;
        public bool WakeRevealed { get; private set; }
        public bool IsFilmBeat => Beat == OpeningBeat.School || Beat == OpeningBeat.Laboratory ||
            Beat == OpeningBeat.Experiment || (Beat == OpeningBeat.Memory && memory.clip != null);
        public bool CanSkip => ShowingVideo && !Paused && skipWindow > 0f;
        public bool CanAdvance => Beat == OpeningBeat.SystemWake
            ? WakeRevealed && (destination == null || destination.Ready || destination.PreparationFailed)
            : IsFilmBeat && !showingVideo && prepareShot == null;
        public UnityEvent Completed => completed;
        public event Action StateChanged;

        private void Awake()
        {
            destination = GetComponent<ChapterSceneLink>();
            player.playOnAwake = false;
            player.isLooping = false;
            player.renderMode = VideoRenderMode.APIOnly;
            player.audioOutputMode = VideoAudioOutputMode.None;
            player.loopPointReached += VideoFinished;
            player.errorReceived += VideoFailed;
            ambienceVolume = ambience.volume;
            ambience.playOnAwake = false;
            ambience.loop = true;
        }

        private void OnEnable()
        {
            if (started && !completedRaised) PresentBeat();
        }

        private void OnDisable()
        {
            StopMedia();
            StopWakeAudio();
        }

        private void OnDestroy()
        {
            if (player == null) return;
            player.loopPointReached -= VideoFinished;
            player.errorReceived -= VideoFailed;
        }

        public void Begin()
        {
            if (started) return;

            started = true;
            PresentBeat();
        }

        public bool Restore(OpeningBeat beat, OpeningQuestion asked)
        {
            if (started || !sequence.TryRestore(beat, asked)) return false;

            Begin();
            return true;
        }

        public void ContinueShot()
        {
            if (CanAdvance) Apply(sequence.AdvanceShot);
        }

        public void SkipShot()
        {
            if (CanSkip) Apply(sequence.AdvanceShot);
        }

        private void Update()
        {
            if (!showingVideo || Paused) return;
            if (mediaPlaying && player.frame >= 0 && player.frameCount > 1 &&
                (ulong)player.frame + 1 >= player.frameCount)
            {
                VideoFinished(player);
                return;
            }
            if (!player.isPlaying) return;
            var delta = Time.unscaledDeltaTime;
            watchedSeconds += delta;
            if (!offeredSkip && watchedSeconds >= 10f)
            {
                offeredSkip = true;
                skipWindow = 4f;
                StateChanged?.Invoke();
            }
            else if (skipWindow > 0f)
            {
                skipWindow -= delta;
                if (skipWindow <= 0f) StateChanged?.Invoke();
            }
        }
        public void AskAboutExperiment() => Apply(() => sequence.Ask(OpeningQuestion.Experiment));
        public void AskAboutSafety() => Apply(() => sequence.Ask(OpeningQuestion.Safety));
        public void ReturnToQuestions() => Apply(sequence.ReturnToQuestions);
        public void BeginExperiment() => Apply(sequence.BeginExperiment);

        public void SetReducedMotion(bool value)
        {
            if (reducedMotion == value) return;

            reducedMotion = value;
            if (started && !completedRaised) PresentBeat();
        }

        public void SetMuted(bool value)
        {
            ambience.mute = value;
            if (wakeAudio != null) wakeAudio.SetMuted(value);
        }

        public void TogglePause()
        {
            if (!started || completedRaised) return;

            sequence.SetPaused(!sequence.Paused);
            if (wakeAudio != null) wakeAudio.SetPaused(sequence.Paused);
            if (mediaPlaying)
            {
                if (sequence.Paused)
                {
                    player.Pause();
                    ambience.Pause();
                }
                else
                {
                    player.Play();
                    ambience.UnPause();
                }
            }
            StateChanged?.Invoke();
        }

        private void Apply(Func<bool> update)
        {
            if (started && isActiveAndEnabled && update()) PresentBeat();
        }

        private void PresentBeat()
        {
            StopMedia();
            offeredSkip = false;
            skipWindow = 0f;
            if (Beat == OpeningBeat.Complete)
            {
                if (completedRaised) return;

                if (destination != null)
                {
                    destination.SetWakeAudio(wakeAudio);
                    wakeAudio = null;
                }
                else StopWakeAudio();
                completedRaised = true;
                StateChanged?.Invoke();
                completed.Invoke();
                return;
            }

            if (Beat == OpeningBeat.SystemWake)
            {
                if (wakeAudio == null && wakeAmbience != null)
                    wakeAudio = OpeningWakeAudio.Begin(gameObject.scene, wakeAmbience, wakeFoley, ambience.mute, sequence.Paused);

                var fullMotion = !reducedMotion &&
                    SystemInfo.graphicsDeviceType != UnityEngine.Rendering.GraphicsDeviceType.Null;
                if (WakeRevealed || !fullMotion || wakeAudio == null) RevealWake();
                else
                {
                    surface.texture = null;
                    surface.color = new Color(0.005f, 0.010f, 0.018f);
                }
                if (fullMotion) prepareShot = StartCoroutine(ShowWake());
            }
            else
            {
                var shot = CurrentShot();
                surface.texture = shot.poster;
                surface.color = Color.white;
                if (isActiveAndEnabled && IsFilmBeat && !reducedMotion && shot.clip != null)
                    prepareShot = StartCoroutine(Prepare(shot));
            }
            StateChanged?.Invoke();
        }

        private IEnumerator ShowWake()
        {
            var remaining = WakeDuration;
            while (remaining > 0f)
            {
                yield return null;
                if (!sequence.Paused) remaining -= Time.unscaledDeltaTime;
                if (!WakeRevealed && remaining <= WakeDuration - WakeSoundLead)
                {
                    RevealWake();
                    StateChanged?.Invoke();
                }
            }
            while (!CanAdvance || sequence.Paused) yield return null;
            prepareShot = null;
            ContinueShot();
        }

        private void RevealWake()
        {
            WakeRevealed = true;
            surface.texture = memory.poster;
            surface.color = memory.poster != null ? new Color(0.60f, 0.78f, 0.88f) :
                new Color(0.016f, 0.035f, 0.066f);
        }

        private void StopWakeAudio()
        {
            if (wakeAudio != null) wakeAudio.Stop();
            wakeAudio = null;
        }

        private IEnumerator Prepare(Shot shot)
        {
            player.clip = shot.clip;
            var embeddedMix = shot.clip.audioTrackCount > 0;
            ambience.volume = embeddedMix ? 1f : ambienceVolume;
            player.audioOutputMode = embeddedMix ? VideoAudioOutputMode.AudioSource : VideoAudioOutputMode.None;
            player.controlledAudioTrackCount = (ushort)(embeddedMix ? 1 : 0);
            if (embeddedMix)
            {
                player.EnableAudioTrack(0, true);
                player.SetTargetAudioSource(0, ambience);
            }
            player.Prepare();
            var timeout = Time.realtimeSinceStartupAsDouble + 10.0;
            while (!player.isPrepared && Time.realtimeSinceStartupAsDouble < timeout)
                yield return null;

            if (player.isPrepared)
            {
                while (sequence.Paused) yield return null;
                ambience.clip = embeddedMix ? null : shot.ambience;
                if (ambience.clip != null) ambience.Play();
                mediaPlaying = true;
                player.Play();
                var frameBudget = 5f;
                while ((player.texture == null || player.frame < 0) && frameBudget > 0f)
                {
                    yield return null;
                    if (!sequence.Paused) frameBudget -= Time.unscaledDeltaTime;
                }
                if (player.texture != null && player.frame >= 0)
                {
                    surface.texture = player.texture;
                    showingVideo = true;
                }
                else
                {
                    mediaPlaying = false;
                    player.Stop();
                    ambience.Stop();
                }
            }
            else
            {
                player.Stop();
            }
            prepareShot = null;
            StateChanged?.Invoke();
        }

        private void StopMedia()
        {
            if (prepareShot != null) StopCoroutine(prepareShot);
            prepareShot = null;
            mediaPlaying = false;
            showingVideo = false;
            player.Stop();
            ambience.Stop();
        }

        private void VideoFinished(VideoPlayer source)
        {
            if (mediaPlaying && source.clip == CurrentShot().clip) Apply(sequence.AdvanceShot);
        }

        private void VideoFailed(VideoPlayer source, string message)
        {
            if (!started || !IsFilmBeat || source.clip != CurrentShot().clip) return;

            StopMedia();
            surface.texture = CurrentShot().poster;
            Debug.LogWarning($"Opening video unavailable for {Beat}: {message}", this);
            StateChanged?.Invoke();
        }

        private Shot CurrentShot()
        {
            if (Beat == OpeningBeat.School) return school;
            if (Beat == OpeningBeat.Experiment) return experiment;
            if (Beat == OpeningBeat.Memory) return memory;
            return laboratory;
        }
    }
}
