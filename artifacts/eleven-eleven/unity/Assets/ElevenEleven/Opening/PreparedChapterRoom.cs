using System;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace ElevenEleven.Opening
{
    internal sealed class PreparedChapterRoom
    {
        private static PreparedChapterRoom current;
        private readonly Scene owner;
        private readonly string destination;
        private Scene scene;
        private ChapterRoomStage stage;
        private bool cancelled;
        private bool consumed;
        private bool loadCompleted;
        private bool closed;
        internal AsyncOperation Operation { get; private set; }
        internal bool Ready => stage != null && stage.IsReady;
        internal bool Failed => cancelled || (loadCompleted && (stage == null || stage.IsFailed));

        private PreparedChapterRoom(Scene owner, string destination)
        {
            this.owner = owner;
            this.destination = destination;
        }

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
        private static void Reset()
        {
            if (current != null) SceneManager.sceneLoaded -= current.OnLoaded;
            current = null;
        }

        internal static PreparedChapterRoom Begin(Scene owner, string destination)
        {
            if (current != null || !owner.IsValid() || !owner.isLoaded ||
                !Application.CanStreamedLevelBeLoaded(destination))
                return null;

            var pending = new PreparedChapterRoom(owner, destination);
            current = pending;
            SceneManager.sceneLoaded += pending.OnLoaded;
            try
            {
                pending.Operation = SceneManager.LoadSceneAsync(destination, LoadSceneMode.Additive);
                if (pending.Operation != null)
                {
                    pending.Operation.completed += pending.Complete;
                    return pending;
                }
            }
            catch (Exception error)
            {
                Debug.LogException(error);
            }
            pending.Close();
            return null;
        }

        internal static bool Holds(Scene scene) =>
            current != null && current.destination == scene.name && SceneManager.GetActiveScene() != scene;

        private void OnLoaded(Scene value, LoadSceneMode mode)
        {
            if (mode != LoadSceneMode.Additive || value.name != destination) return;
            scene = value;
            foreach (var root in scene.GetRootGameObjects())
            {
                if (!root.TryGetComponent(out stage)) continue;
                break;
            }
        }

        private void Complete(AsyncOperation _)
        {
            SceneManager.sceneLoaded -= OnLoaded;
            loadCompleted = true;
            if (cancelled || stage == null) Close();
            else stage.StartWarmup();
        }

        internal bool Activate()
        {
            if (cancelled || consumed || !Ready || !owner.isLoaded || SceneManager.GetActiveScene() != owner ||
                stage == null || !scene.isLoaded || !SceneManager.SetActiveScene(scene))
                return false;

            consumed = true;
            if (current == this) current = null;
            foreach (var root in owner.GetRootGameObjects()) root.SetActive(false);
            stage.Activate();
            var unload = SceneManager.UnloadSceneAsync(owner);
            if (unload != null) unload.completed += _ => Resources.UnloadUnusedAssets();
            return true;
        }

        internal void Cancel()
        {
            if (consumed || cancelled) return;
            cancelled = true;
            if (Operation == null || Operation.isDone) Close();
        }

        private void Close()
        {
            if (closed) return;
            closed = true;
            SceneManager.sceneLoaded -= OnLoaded;
            if (current == this) current = null;
            if (scene.IsValid() && scene.isLoaded && SceneManager.GetActiveScene() != scene)
                SceneManager.UnloadSceneAsync(scene);
        }
    }
}
