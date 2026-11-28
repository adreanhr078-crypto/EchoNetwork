using System;
using System.Collections;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.SceneManagement;
using UnityEngine.UI;

namespace ElevenEleven.Opening
{
    public sealed class ChapterSceneLink : MonoBehaviour
    {
        private const string Title = "ChapterTitle";
        [SerializeField] private string destination;
        [SerializeField] private Text status;
        [SerializeField] private Button retry;
        [SerializeField] private ChapterLoadingView loadingView;
        [SerializeField] private bool stageBeforeEntry;

        public static bool ReducedMotion { get; set; }
        public static bool Muted { get; set; } = true;
        public bool IsLoading { get; private set; }
        private PreparedChapterRoom prepared;
        private Coroutine transition;
        private AsyncOperation opening;
        private OpeningWakeAudio wakeAudio;
        internal bool Ready => prepared?.Ready == true || opening?.progress >= 0.9f;
        internal bool PreparationFailed => prepared?.Failed == true || (prepared == null && opening == null);

        internal void PrepareOpening()
        {
            if (opening != null || !Application.CanStreamedLevelBeLoaded(destination)) return;
            opening = SceneManager.LoadSceneAsync(destination, LoadSceneMode.Single);
            if (opening != null) opening.allowSceneActivation = false;
        }

        internal bool EnterPrepared()
        {
            if (IsLoading || !Ready) return false;
            IsLoading = true;
            if (opening != null)
            {
                opening.allowSceneActivation = true;
                return true;
            }

            if (prepared != null && prepared.Activate()) return true;
            IsLoading = false;
            return false;
        }

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
        private static void ResetPreferences()
        {
            ReducedMotion = false;
            Muted = true;
            EntryCopy.Arabic = true;
        }

        internal void PrepareDestination()
        {
            if (prepared == null && !IsLoading)
                prepared = PreparedChapterRoom.Begin(gameObject.scene, destination);
        }

        internal void ReleasePreparation()
        {
            prepared?.Cancel();
            prepared = null;
        }

        internal void SetWakeAudio(OpeningWakeAudio source) => wakeAudio = source;

        private void OnDestroy()
        {
            StopWakeAudio();
            ReleasePreparation();
            if (opening != null && !opening.isDone) opening.allowSceneActivation = true;
        }

        public void Begin()
        {
            if (IsLoading) return;
            if (!Application.CanStreamedLevelBeLoaded(destination))
            {
                ReleasePreparation();
                ShowFailure();
                return;
            }

            if (stageBeforeEntry) PrepareDestination();
            IsLoading = true;
            if (prepared != null)
            {
                if (prepared.Ready && ActivateRoom(prepared)) return;
                transition = StartCoroutine(ActivatePrepared(prepared));
            }
            else if (stageBeforeEntry) ShowFailure();
            else LoadSingle(destination);
        }

        private IEnumerator ActivatePrepared(PreparedChapterRoom staged)
        {
            loadingView?.Show(ChapterLoadingView.Phase.Room, ReturnToTitle);
            while (!staged.Operation.isDone)
            {
                loadingView?.SetProgress(staged.Operation.progress);
                yield return null;
            }
            if (!staged.Ready && !staged.Failed)
                loadingView?.Show(ChapterLoadingView.Phase.Preparing, ReturnToTitle);
            while (!staged.Ready && !staged.Failed) yield return null;

            transition = null;
            if (ActivateRoom(staged)) yield break;
            ReleasePreparation();
            ShowFailure();
        }

        private bool ActivateRoom(PreparedChapterRoom staged)
        {
            if (!staged.Activate(wakeAudio)) return false;
            wakeAudio = null;
            return true;
        }

        private void StopWakeAudio()
        {
            if (wakeAudio != null) wakeAudio.Stop();
            wakeAudio = null;
        }

        private void LoadSingle(string scene)
        {
            try
            {
                var operation = SceneManager.LoadSceneAsync(scene, LoadSceneMode.Single);
                if (operation == null)
                {
                    ShowFailure();
                    return;
                }
                if (loadingView != null)
                {
                    loadingView.Show(scene == Title ? ChapterLoadingView.Phase.Returning : ChapterLoadingView.Phase.Opening);
                    StartCoroutine(ReportProgress(operation));
                }
                else
                {
                    retry.gameObject.SetActive(false);
                    status.text = "Loading…";
                }
            }
            catch (Exception error)
            {
                Debug.LogException(error, this);
                ShowFailure();
            }
        }

        private IEnumerator ReportProgress(AsyncOperation operation)
        {
            while (!operation.isDone)
            {
                loadingView.SetProgress(operation.progress);
                yield return null;
            }
        }

        private void ReturnToTitle()
        {
            StopWakeAudio();
            if (transition != null) StopCoroutine(transition);
            transition = null;
            ReleasePreparation();
            ChapterSaveSession.SetRestore(null);
            IsLoading = true;
            LoadSingle(Title);
        }

        private void ShowFailure()
        {
            StopWakeAudio();
            IsLoading = false;
            if (loadingView != null)
            {
                loadingView.Show(ChapterLoadingView.Phase.Error, ReturnToTitle, Begin);
                return;
            }
            status.text = "Unable to load. Try again.";
            retry.gameObject.SetActive(true);
            if (EventSystem.current != null)
                EventSystem.current.SetSelectedGameObject(retry.gameObject);
        }
    }
}
