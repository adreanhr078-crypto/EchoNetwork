using System.Collections;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.EventSystems;
using UnityEngine.UI;
using UnityEngine.Video;

namespace ElevenEleven.Opening
{
    public sealed class ChapterTitle : MonoBehaviour
    {
        [SerializeField] private VideoPlayer video;
        [SerializeField] private RawImage image;
        [SerializeField] private Texture poster;
        [SerializeField] private AudioSource water;
        [SerializeField] private Text motionLabel;
        [SerializeField] private Text soundLabel;
        [SerializeField] private ChapterSceneLink newGameLink;
        [SerializeField] private ChapterSceneLink continueLink;
        [SerializeField] private Button entryButton;
        [SerializeField] private ChapterLoadingView bootView;

        private Room01Checkpoint resumeState;
        private ChapterSceneLink entryLink;
        private Text entryLabel;
        [SerializeField] private Text languageLabel;
        [SerializeField] private RawImage motionIcon;
        [SerializeField] private RawImage soundIcon;
        [SerializeField] private Texture playGlyph;
        [SerializeField] private Texture pauseGlyph;
        [SerializeField] private Texture soundGlyph;
        [SerializeField] private Texture muteGlyph;

        private Coroutine preparation;
        private bool starting;

        public bool ShowingVideo => video.isPlaying && video.texture != null && image.texture == video.texture;
        public long VideoFrame => video.frame;
        public int CompletedLoops { get; private set; }

        private void OnEnable()
        {
            video.errorReceived += OnVideoError;
            video.loopPointReached += CountLoop;
            ApplyCopy();
            ApplyMotion();
            ApplySound();
        }

        private void Start()
        {
            entryLabel = entryButton.GetComponentInChildren<Text>(true);
            PrepareEntry();
        }

        private void PrepareEntry()
        {
            entryButton.gameObject.SetActive(false);
            resumeState = ChapterSaveSession.Read();
            entryLink = resumeState != null ? continueLink : newGameLink;
            if (resumeState != null) entryLink.PrepareDestination();
            else entryLink.PrepareOpening();
            ApplyCopy();
            StartCoroutine(ShowEntryWhenReady());
        }

        private IEnumerator ShowEntryWhenReady()
        {
            if (!entryLink.Ready && !entryLink.PreparationFailed) bootView.ShowStartup();
            while (!entryLink.Ready && !entryLink.PreparationFailed) yield return null;
            bootView.gameObject.SetActive(false);
            if (!entryLink.Ready)
            {
                bootView.Show(ChapterLoadingView.Phase.Error, retryLoad: RetryPreparation);
                yield break;
            }

            entryButton.gameObject.SetActive(true);
            if (EventSystem.current != null && EventSystem.current.currentSelectedGameObject == null)
                EventSystem.current.SetSelectedGameObject(entryButton.gameObject);
        }

        private void RetryPreparation()
        {
            entryLink.ReleasePreparation();
            PrepareEntry();
        }

        private void OnDisable()
        {
            video.errorReceived -= OnVideoError;
            video.loopPointReached -= CountLoop;
            StopVideo();
            water.Stop();
        }

        public void EnterChapter()
        {
            if (starting || entryLink == null || !entryLink.Ready) return;
            ChapterSaveSession.SetRestore(resumeState);
            if (entryLink.EnterPrepared()) StopTitleMedia();
        }

        private void StopTitleMedia()
        {
            starting = true;
            StopVideo();
            water.Stop();
        }

        public void ToggleMotion()
        {
            ChapterSceneLink.ReducedMotion = !ChapterSceneLink.ReducedMotion;
            ApplyMotion();
            ApplySound();
        }

        public void ToggleSound()
        {
            ChapterSceneLink.Muted = !ChapterSceneLink.Muted;
            ApplySound();
        }

        public void ToggleLanguage()
        {
            EntryCopy.Arabic = !EntryCopy.Arabic;
            ApplyCopy();
        }

        private void ApplyCopy()
        {
            if (languageLabel != null) languageLabel.text = EntryCopy.Language;
            if (entryLabel != null)
                entryLabel.text = resumeState != null ? EntryCopy.Continue : EntryCopy.Start;
            motionLabel.text = ChapterSceneLink.ReducedMotion ? EntryCopy.MotionOff : EntryCopy.MotionOn;
            soundLabel.text = ChapterSceneLink.Muted ? EntryCopy.SoundOff : EntryCopy.SoundOn;
        }

        private void CountLoop(VideoPlayer player) => CompletedLoops++;

        private void ApplyMotion()
        {
            motionLabel.text = ChapterSceneLink.ReducedMotion ? EntryCopy.MotionOff : EntryCopy.MotionOn;
            if (motionIcon != null) motionIcon.texture = ChapterSceneLink.ReducedMotion ? playGlyph : pauseGlyph;
            StopVideo();
            if (!starting && !ChapterSceneLink.ReducedMotion && SystemInfo.graphicsDeviceType != GraphicsDeviceType.Null)
                preparation = StartCoroutine(PlayWhenReady());
        }

        private void ApplySound()
        {
            soundLabel.text = ChapterSceneLink.Muted ? EntryCopy.SoundOff : EntryCopy.SoundOn;
            if (soundIcon != null) soundIcon.texture = ChapterSceneLink.Muted ? muteGlyph : soundGlyph;
            if (starting || ChapterSceneLink.Muted || ChapterSceneLink.ReducedMotion)
                water.Stop();
            else if (!water.isPlaying)
                water.Play();
        }

        private IEnumerator PlayWhenReady()
        {
            video.Prepare();
            var deadline = Time.unscaledTime + 5f;
            do { yield return null; }
            while (!video.isPrepared && Time.unscaledTime < deadline);
            if (!video.isPrepared)
            {
                preparation = null;
                video.Stop();
                yield break;
            }

            video.Play();
            deadline = Time.unscaledTime + 2f;
            while ((video.texture == null || video.frame < 0) && Time.unscaledTime < deadline)
                yield return null;
            if (video.texture != null && video.frame >= 0) image.texture = video.texture;
            else video.Stop();
            preparation = null;
        }

        private void OnVideoError(VideoPlayer player, string message) => StopVideo();

        private void StopVideo()
        {
            if (preparation != null) StopCoroutine(preparation);
            preparation = null;
            video.Stop();
            image.texture = poster;
        }
    }
}
