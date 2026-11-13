using System;
using System.IO;
using System.Linq;
using ElevenEleven.Opening;
using UnityEditor;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;

namespace ElevenEleven.Editor
{
    [InitializeOnLoad]
    internal static class RoomPreloadSmoke
    {
        private const string Running = "ElevenEleven.R04.Running";
        private const string Deadline = "ElevenEleven.R04.Deadline";
        private const string Room = "ChapterRoom01";
        private const string Title = "ChapterTitle";
        private const string Opening = "ChapterOpening";
        private static int step;
        private static int checks;
        private static ChapterSceneLink failedLink;

        static RoomPreloadSmoke()
        {
            if (SessionState.GetBool(Running, false)) EditorApplication.update += Tick;
        }

        public static void RebuildAndRun()
        {
            ChapterSceneBuilder.RebuildRoom();
            Run();
        }

        public static void Run()
        {
            var fixture = Environment.GetEnvironmentVariable("ECHO_R02_FIXTURE_DIRECTORY");
            if (!Application.isBatchMode || string.IsNullOrWhiteSpace(fixture) || Directory.Exists(fixture))
                throw new InvalidOperationException("An unused R04 fixture directory is required.");
            Directory.CreateDirectory(fixture);
            Inventory(Path.Combine(fixture, "entry-dependencies.txt"));
            ChapterSceneBuilder.OpenRegisteredTitle();
            SessionState.SetBool(Running, true);
            SessionState.SetFloat(Deadline, (float)EditorApplication.timeSinceStartup + 200f);
            EditorApplication.update += Tick;
            EditorApplication.EnterPlaymode();
        }

        private static void Tick()
        {
            try
            {
                if (EditorApplication.timeSinceStartup > SessionState.GetFloat(Deadline, 0f))
                    throw new TimeoutException($"Room preload stalled at step {step}.");
                if (!EditorApplication.isPlaying) return;
                var active = SceneManager.GetActiveScene().name;
                switch (step)
                {
                    case 0 when active == Title:
                        Application.runInBackground = true;
                        Application.targetFrameRate = 45;
                        Press("Motion on");
                        Press("Tap to Start");
                        step++;
                        break;
                    case 1 when active == Opening:
                        var prepared = SceneManager.GetSceneByName(Room);
                        if (!prepared.isLoaded) return;
                        var content = prepared.GetRootGameObjects().Single(root => root.name == "Room content");
                        Require(!content.activeSelf || (Actor() != null && Actor().IsStaged),
                            "The prepared room cannot consume gameplay input behind the opening.");
                        Require(Camera.main == null, "The staged camera does not steal the opening view.");
                        Require(!File.Exists(Path.Combine(Environment.GetEnvironmentVariable("ECHO_R02_FIXTURE_DIRECTORY"),
                            "system_opening_v1.json")), "Preparing the room cannot write a save.");
                        SolveCover();
                        step++;
                        break;
                    case 2 when active == Opening && FilmReady():
                        FinishOpening();
                        step++;
                        break;
                    case 3 when active == Room && !SceneManager.GetSceneByName(Opening).isLoaded:
                        if (Actor() == null || Camera.main == null)
                            throw new InvalidOperationException("Handoff did not activate the gameplay actor and camera.");
                        if (SceneManager.sceneCount != 1) return;
                        Require(SceneManager.GetActiveScene().name == Room, "Handoff activates gameplay and unloads the previous scene.");
                        Require(Actor().GetComponentInChildren<Animation>().IsPlaying("Idle"),
                            "Prepared entry still starts with School Idle.");
                        Press("Back to title");
                        step++;
                        break;
                    case 4 when active == Title && Button("Tap to Start") != null:
                        Press("Tap to Start");
                        step++;
                        break;
                    case 5 when active == Opening && SceneManager.GetSceneByName(Room).isLoaded:
                        SceneManager.LoadSceneAsync(Title, LoadSceneMode.Single);
                        step++;
                        break;
                    case 6 when active == Title && !SceneManager.GetSceneByName(Room).isLoaded:
                        if (SceneManager.sceneCount != 1) return;
                        Require(Actor() == null, "Leaving the opening releases the prepared room.");
                        SceneManager.sceneLoaded += SubstituteMissingDestination;
                        Press("Tap to Start");
                        step++;
                        break;
                    case 7 when active == Opening:
                        Require(failedLink != null && !SceneManager.GetSceneByName(Room).isLoaded,
                            "A missing destination never stages a partial room.");
                        SolveCover();
                        step++;
                        break;
                    case 8 when active == Opening && FilmReady():
                        FinishOpening();
                        Require(Button("Try again") != null && !failedLink.IsLoading, "Missing room shows an actionable retry.");
                        Require(GameObject.Find("Loading message").GetComponent<Text>().text == "The scene could not load.",
                            "Missing room reports a readable error.");
                        Destination(failedLink, Room);
                        Press("Try again");
                        step++;
                        break;
                    case 9 when active == Room && Actor() != null:
                        if (SceneManager.sceneCount != 1) return;
                        Require(Camera.main != null, "Retry loads a single normal room.");
                        Debug.Log($"R04_PRELOADED_ENTRY_PASS {checks} checks");
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

        private static void Inventory(string file)
        {
            var names = new[] { Title, Opening, Room };
            using var report = new StreamWriter(file);
            foreach (var name in names)
            {
                var path = $"Assets/ElevenEleven/Scenes/{name}.unity";
                var dependencies = AssetDatabase.GetDependencies(path).Where(dep => dep.StartsWith("Assets/", StringComparison.Ordinal)).ToArray();
                var hasSchool = dependencies.Any(dep => dep.EndsWith("EchoSchool-Tripo-Original.glb", StringComparison.Ordinal));
                if (hasSchool != (name == Room)) throw new InvalidOperationException("School mesh depends on the wrong entry scene.");
                report.WriteLine($"{name} {dependencies.Length} source assets");
                foreach (var dependency in dependencies.OrderBy(dep => dep))
                    report.WriteLine($"  {new FileInfo(dependency).Length} {dependency}");
            }
        }

        private static void SubstituteMissingDestination(Scene scene, LoadSceneMode mode)
        {
            if (scene.name != Opening) return;
            SceneManager.sceneLoaded -= SubstituteMissingDestination;
            var host = UnityEngine.Object.FindFirstObjectByType<OpeningReviewHost>();
            failedLink = host.GetComponentInChildren<ChapterSceneLink>(true);
            Destination(failedLink, "RoomFileMissingInThisFixture");
        }

        private static void Destination(ChapterSceneLink link, string value)
        {
            var data = new SerializedObject(link);
            data.FindProperty("destination").stringValue = value;
            data.ApplyModifiedPropertiesWithoutUndo();
        }

        private static Room01Player Actor() => UnityEngine.Object.FindFirstObjectByType<Room01Player>();
        private static bool FilmReady() => UnityEngine.Object.FindFirstObjectByType<OpeningCinematicPresenter>() != null;

        private static void SolveCover()
        {
            Press("Piece 1");
            Press("Piece 2");
            Press("Piece 5");
            Press("Piece 6");
        }

        private static void FinishOpening()
        {
            Press("Continue");
            Press("Continue");
            Press("I am ready.");
            Press("Continue");
            Press("Continue");
            Press("Continue");
        }

        private static Button Button(string name) => UnityEngine.Object
            .FindObjectsByType<Button>(FindObjectsInactive.Exclude, FindObjectsSortMode.None).FirstOrDefault(button => button.name == name);

        private static void Press(string name)
        {
            var button = Button(name);
            if (button == null || !button.interactable) throw new InvalidOperationException("Unavailable control: " + name);
            button.onClick.Invoke();
        }

        private static void Require(bool condition, string message)
        {
            if (!condition) throw new InvalidOperationException(message);
            checks++;
        }

        private static void Finish(int code)
        {
            SessionState.EraseBool(Running);
            SceneManager.sceneLoaded -= SubstituteMissingDestination;
            EditorApplication.update -= Tick;
            EditorApplication.Exit(code);
        }
    }
}
