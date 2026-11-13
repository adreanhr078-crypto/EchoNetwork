using System;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using ElevenEleven.Opening;
using UnityEditor;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.SceneManagement;
using UnityEngine.UI;

namespace ElevenEleven.Editor
{
    [InitializeOnLoad]
    internal static class ChapterLoadingSmoke
    {
        private const string Running = "ElevenEleven.R06.Running";
        private const string Deadline = "ElevenEleven.R06.Deadline";
        private const string Title = "ChapterTitle";
        private const string Opening = "ChapterOpening";
        private const string Room = "ChapterRoom01";
        private const string Saved = "{\"schema\":\"echo-opening-local-v1\",\"avatar\":\"V31\",\"milestones\":{\"wake\":true,\"clock\":true,\"photo\":false,\"memory\":false,\"terminal\":false,\"conduit\":false,\"ending\":false},\"terminal\":{\"frequency\":96.5,\"phase\":20,\"harmonic\":3}}";
        private static string SavePath => Path.Combine(Environment.GetEnvironmentVariable("ECHO_R02_FIXTURE_DIRECTORY"), "system_opening_v1.json");
        private static int step;
        private static int checks;
        private static ChapterSceneLink continueLink;
        private static ChapterSceneLink filmLink;
        private static string saveBeforeOpening;

        static ChapterLoadingSmoke()
        {
            if (SessionState.GetBool(Running, false)) EditorApplication.update += Tick;
        }

        public static void RebuildAndRun()
        {
            ChapterSceneBuilder.RebuildLoadingScenes();
            Run();
        }

        public static void Run()
        {
            var fixture = Path.GetDirectoryName(SavePath);
            if (!Application.isBatchMode || Directory.Exists(fixture))
                throw new InvalidOperationException("A fresh fixture is required.");
            Directory.CreateDirectory(fixture);
            File.WriteAllText(SavePath, Saved);
            ChapterSceneBuilder.OpenRegisteredTitle();
            SessionState.SetBool(Running, true);
            SessionState.SetFloat(Deadline, (float)EditorApplication.timeSinceStartup + 110f);
            EditorApplication.update += Tick;
            EditorApplication.EnterPlaymode();
        }

        private static void Tick()
        {
            try
            {
                if (EditorApplication.timeSinceStartup > SessionState.GetFloat(Deadline, 0f))
                    throw new TimeoutException($"Loading smoke stalled at step {step}.");
                if (!EditorApplication.isPlaying) return;
                var scene = SceneManager.GetActiveScene().name;
                switch (step)
                {
                    case 0 when scene == Title && Button("Continue game") != null:
                        Application.targetFrameRate = 45;
                        Application.runInBackground = true;
                        VerifyConcurrentCheckpointReads();
                        Press("Motion on");
                        Press("Continue game");
                        Require(Message() == "Loading Room 01…" && GameObject.Find("Loading progress") != null,
                            "Continue uses the shared status and real engine-progress bar.");
                        Require(ChapterSceneLink.ReducedMotion && Camera.main == null && Selected("Back to title"),
                            "Reduced motion shows a static, cancellable panel while the room owns no camera.");
                        Press("Back to title");
                        Require(Message() == "Returning to the title…", "Cancelling reports its actual state.");
                        step++;
                        break;
                    case 1 when scene == Title && SceneManager.sceneCount == 1 && GameObject.Find("Chapter loading") == null:
                        if (Button("Continue game") == null) return;
                        Require(File.ReadAllText(SavePath) == Saved && UnityEngine.Object.FindFirstObjectByType<Room01Player>() == null,
                            "Continue cancellation preserves the saved bytes and clears the staged actor.");
                        continueLink = UnityEngine.Object.FindObjectsByType<ChapterSceneLink>(FindObjectsSortMode.None)
                            .Single(link => Destination(link).stringValue == Room);
                        SetDestination(continueLink, "UnavailableRoomFixture");
                        Press("Continue game");
                        Require(Message() == "The scene could not load." && Selected("Try again"),
                            "Missing room reports the failure and focuses retry.");
                        Require(Button("Try again").FindSelectableOnRight() == Button("Back to title") &&
                            GameObject.Find("Loading progress") == null,
                            "Error presents only actual recovery actions with bounded keyboard navigation.");
                        SetDestination(continueLink, Room);
                        Press("Try again");
                        Require(Message() == "Loading Room 01…", "Retry restarts the scene operation through the same panel.");
                        step++;
                        break;
                    case 2 when scene == Room && SceneManager.sceneCount == 1:
                        var objective = GameObject.Find("Current objective");
                        if (objective == null || objective.GetComponent<Text>().text != "Find the personal trace.") return;
                        Require(File.ReadAllText(SavePath) == Saved && GameObject.Find("Chapter loading") == null,
                            "Successful retry restores the saved room and clears the overlay without writing a replacement.");
                        Press("Back to title");
                        step++;
                        break;
                    case 3 when scene == Title && Button("Continue game") != null:
                        saveBeforeOpening = File.ReadAllText(SavePath);
                        SceneManager.sceneLoaded += HoldFilmPreparation;
                        Press("Tap to Start");
                        Require(Message() == "Loading the opening…", "A new game uses the same loading view from the title.");
                        step++;
                        break;
                    case 4 when scene == Opening:
                        Press("Piece 1");
                        Press("Piece 2");
                        Press("Piece 5");
                        Press("Piece 6");
                        step++;
                        break;
                    case 5 when scene == Opening && Button("Continue") != null:
                        SetDestination(filmLink, Room);
                        Press("Continue");
                        Press("Continue");
                        Press("I am ready.");
                        Press("Continue");
                        Press("Continue");
                        Press("Continue");
                        Require(scene == SceneManager.GetActiveScene().name && Selected("Back to title"),
                            "Earliest skip safely waits behind the loading view and allows returning.");
                        Press("Back to title");
                        step++;
                        break;
                    case 6 when scene == Title && SceneManager.sceneCount == 1 && Button("Continue game") != null:
                        Require(File.ReadAllText(SavePath) == saveBeforeOpening && Camera.main == null,
                            "Opening cancellation leaves the previous checkpoint and the title owns input again.");
                        Require(GameObject.Find("Chapter loading") == null && UnityEngine.Object.FindFirstObjectByType<ChapterRoomStage>() == null,
                            "The temporary view and staged room are released after cancel.");
                        SceneManager.sceneLoaded += DisableFixtureFloor;
                        Press("Continue game");
                        step++;
                        break;
                    case 7 when scene == Title && SceneManager.sceneCount == 1 && Message() == "The scene could not load.":
                        Require(File.ReadAllText(SavePath) == saveBeforeOpening && Camera.main == null,
                            "Failed floor preparation retains the previous checkpoint and title ownership.");
                        Press("Try again");
                        step++;
                        break;
                    case 8 when scene == Room && SceneManager.sceneCount == 1:
                        Require(Camera.main != null && GameObject.Find("Chapter loading") == null,
                            "Retry prepares a new room with a valid floor and releases the loading view.");
                        Debug.Log($"R06_LOADING_PASS {checks} checks");
                        Finish(0);
                        break;
                }
            }
            catch (Exception error)
            {
                Debug.LogException(error);
                Finish(1);
            }
        }

        private static void VerifyConcurrentCheckpointReads()
        {
            var path = Path.Combine(Path.GetDirectoryName(SavePath), "atomic-checkpoint.json");
            var state = new Room01Checkpoint { Wake = true };
            if (!state.Save(path)) throw new IOException("Unable to prepare an atomic checkpoint fixture.");
            using var stop = new CancellationTokenSource();
            using var readOnce = new ManualResetEventSlim();
            var reads = 0;
            var reader = Task.Run(() =>
            {
                while (!stop.IsCancellationRequested)
                {
                    var snapshot = Room01Checkpoint.Load(path);
                    if (snapshot == null || !snapshot.Wake) throw new IOException("Observed a partial checkpoint.");
                    reads++;
                    readOnce.Set();
                }
            });
            try
            {
                if (!readOnce.Wait(3000)) throw new TimeoutException("Concurrent checkpoint reader did not start.");
                for (var i = 0; i < 16; i++)
                {
                    state.Clock = i % 2 == 0;
                    if (!state.Save(path)) throw new IOException($"Atomic replacement failed while a reader was active at iteration {i}.");
                }
            }
            finally
            {
                stop.Cancel();
                reader.GetAwaiter().GetResult();
            }
            Require(reads > 0 && Room01Checkpoint.Load(path) is { Wake: true, Clock: false },
                "Concurrent reads preserve all 16 atomic replacements and their final milestone state.");
        }

        private static void DisableFixtureFloor(Scene scene, LoadSceneMode mode)
        {
            if (scene.name != Room || mode != LoadSceneMode.Additive) return;
            SceneManager.sceneLoaded -= DisableFixtureFloor;
            var stage = scene.GetRootGameObjects().Single(root => root.name == "Room content");
            stage.transform.Find("Sector 11/Flooded deck").GetComponent<BoxCollider>().enabled = false;
        }

        private static void HoldFilmPreparation(Scene scene, LoadSceneMode mode)
        {
            if (scene.name != Opening) return;
            SceneManager.sceneLoaded -= HoldFilmPreparation;
            var host = UnityEngine.Object.FindFirstObjectByType<OpeningReviewHost>();
            filmLink = host.GetComponentInChildren<ChapterSceneLink>(true);
            SetDestination(filmLink, "DelayedForCancellationFixture");
        }

        private static SerializedProperty Destination(ChapterSceneLink link) => new SerializedObject(link).FindProperty("destination");

        private static void SetDestination(ChapterSceneLink link, string name)
        {
            var data = new SerializedObject(link);
            data.FindProperty("destination").stringValue = name;
            data.ApplyModifiedPropertiesWithoutUndo();
        }

        private static string Message() => GameObject.Find("Loading message")?.GetComponent<Text>().text;
        private static bool Selected(string name) => EventSystem.current?.currentSelectedGameObject?.name == name;
        private static Button Button(string name) => UnityEngine.Object.FindObjectsByType<Button>(FindObjectsSortMode.None)
            .FirstOrDefault(button => button.name == name);

        private static void Press(string name)
        {
            var button = Button(name);
            if (button == null || !button.interactable) throw new InvalidOperationException("Unavailable control: " + name);
            button.onClick.Invoke();
        }

        private static void Require(bool condition, string reason)
        {
            if (!condition) throw new InvalidOperationException(reason);
            checks++;
        }

        private static void Finish(int code)
        {
            SessionState.EraseBool(Running);
            SceneManager.sceneLoaded -= HoldFilmPreparation;
            SceneManager.sceneLoaded -= DisableFixtureFloor;
            EditorApplication.update -= Tick;
            EditorApplication.Exit(code);
        }
    }
}
