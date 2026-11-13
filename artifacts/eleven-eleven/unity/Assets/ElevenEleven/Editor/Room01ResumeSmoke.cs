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
    internal static class Room01ResumeSmoke
    {
        private const string Running = "ElevenEleven.R02.Running";
        private const string Deadline = "ElevenEleven.R02.Deadline";
        private const string Legacy =
            "{\"schema\":\"echo-opening-local-v1\",\"avatar\":\"V31\",\"pact_accepted\":true," +
            "\"milestones\":{\"wake\":true,\"clock\":true,\"photo\":false,\"memory\":false," +
            "\"terminal\":false,\"conduit\":false,\"ending\":false}," +
            "\"terminal\":{\"frequency\":96.5,\"phase\":20,\"harmonic\":3}}";
        private static int step;
        private static int checks;
        private static string SavePath => Path.Combine(
            Environment.GetEnvironmentVariable("ECHO_R02_FIXTURE_DIRECTORY"), "system_opening_v1.json");
        private static string LegacyPath => Path.Combine(Path.GetDirectoryName(SavePath), "LegacyGodot", Path.GetFileName(SavePath));

        static Room01ResumeSmoke()
        {
            if (SessionState.GetBool(Running, false)) EditorApplication.update += Tick;
        }

        public static void RebuildAndRun()
        {
            if (!Application.isBatchMode || string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("ECHO_R02_FIXTURE_DIRECTORY")))
                throw new InvalidOperationException("A separate save fixture is required.");
            ChapterSceneBuilder.RebuildEntryAndRoom();
            Run();
        }

        public static void Run()
        {
            if (!Application.isBatchMode || string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("ECHO_R02_FIXTURE_DIRECTORY")))
                throw new InvalidOperationException("A separate save fixture is required.");
            Directory.CreateDirectory(Path.GetDirectoryName(SavePath));
            if (File.Exists(SavePath) || File.Exists(SavePath + ".bak") || File.Exists(LegacyPath))
                throw new IOException("Use a fresh save fixture directory.");
            Directory.CreateDirectory(Path.GetDirectoryName(LegacyPath));
            File.WriteAllText(LegacyPath, Legacy);
            ChapterSceneBuilder.OpenRegisteredTitle();
            SessionState.SetBool(Running, true);
            SessionState.SetFloat(Deadline, (float)EditorApplication.timeSinceStartup + 180f);
            EditorApplication.update += Tick;
            EditorApplication.EnterPlaymode();
        }

        private static void Tick()
        {
            try
            {
                if (EditorApplication.timeSinceStartup > SessionState.GetFloat(Deadline, 0f))
                    throw new TimeoutException($"Room 01 resume stalled at step {step}.");
                if (!EditorApplication.isPlaying) return;
                var scene = SceneManager.GetActiveScene().name;
                switch (step)
                {
                    case 0 when scene == "ChapterTitle" && ButtonIsActive("Continue game"):
                        Application.targetFrameRate = 45;
                        Application.runInBackground = true;
                        Press("Motion on");
                        Press("Continue game");
                        step++;
                        break;
                    case 1 when scene == "ChapterRoom01":
                        if (Objective() != "Find the personal trace.") return;
                        Require(HasSchool65(), "The legacy V31 field does not change School65.");
                        Require(!Gate().IsOpen, "Legacy clock checkpoint cannot open the gate.");
                        Require(!File.Exists(SavePath) && File.ReadAllText(LegacyPath) == Legacy,
                            "The legacy source is read-only and is not migrated until a Unity checkpoint.");
                        var actor = Actor().GetComponent<CharacterController>();
                        actor.enabled = false;
                        actor.transform.position = Vector3.down * 6;
                        actor.enabled = true;
                        step++;
                        break;
                    case 2:
                        if (Actor().transform.position.y < -0.1f) return;
                        Require(Objective() == "Find the personal trace." && HasSchool65(), "Fall recovery retains the clue and School65.");
                        Press("Back to title");
                        step++;
                        break;
                    case 3 when scene == "ChapterTitle" && ButtonIsActive("Continue game"):
                        Require(Room01Checkpoint.Load(SavePath).Clock, "Returning to title saves the restored checkpoint.");
                        Require(File.ReadAllText(LegacyPath) == Legacy, "Unity never overwrites the original Godot file.");
                        File.WriteAllText(SavePath + ".bak", Legacy);
                        File.WriteAllText(SavePath, "{malformed");
                        Press("Continue game");
                        step++;
                        break;
                    case 4 when scene == "ChapterRoom01":
                        if (Objective() != "Find the personal trace.") return;
                        Require(File.ReadAllText(SavePath) == "{malformed" && HasSchool65(),
                            "Continue recovers the Unity backup and keeps the corrupt primary untouched.");
                        Press("Back to title");
                        step++;
                        break;
                    case 5 when scene == "ChapterTitle" && ButtonIsActive("Continue game"):
                        Require(File.ReadAllText(SavePath + ".bak") == Legacy, "Restoring a corrupt primary preserves the valid backup.");
                        var complete = new Room01Checkpoint
                        {
                            Wake = true, Clock = true, Photo = true, Memory = true, Terminal = true, Conduit = true, Ending = true,
                            Frequency = 111, Phase = 45, Channel = 7,
                        };
                        Require(complete.Save(SavePath), "Can write the post-gate native checkpoint.");
                        Press("Continue game");
                        step++;
                        break;
                    case 6 when scene == "ChapterRoom01":
                        if (Objective() != "The signal leads deeper into Sector 11.") return;
                        Require(HasSchool65() && Gate().IsOpen, "The post-gate restore retains the School avatar and open gate.");
                        Require(Actor().transform.position.z > 19.05f, "The completed route restores beyond the door.");
                        Press("Back to title");
                        step++;
                        break;
                    case 7 when scene == "ChapterTitle" && ButtonIsActive("Tap to Start"):
                        Press("Tap to Start");
                        step++;
                        break;
                    case 8 when scene == "ChapterOpening":
                        Press("Piece 1");
                        Press("Piece 2");
                        Press("Piece 5");
                        Press("Piece 6");
                        step++;
                        break;
                    case 9 when scene == "ChapterOpening":
                        if (UnityEngine.Object.FindFirstObjectByType<OpeningCinematicPresenter>() == null) return;
                        Press("Continue");
                        Press("Continue");
                        Press("I am ready.");
                        Press("Continue");
                        Press("Continue");
                        Press("Continue");
                        step++;
                        break;
                    case 10 when scene == "ChapterRoom01":
                        var fresh = Room01Checkpoint.Load(SavePath);
                        if (fresh == null || fresh.Clock) return;
                        Require(Objective() == "Find the stopped clock." && !Gate().IsOpen && HasSchool65(),
                            "A new game follows the ordinary School65 entry with a fresh room.");
                        Require(!fresh.Terminal && !fresh.Conduit && !fresh.Ending, "New game saves no later milestones.");
                        Require(Room01Checkpoint.Load(SavePath + ".bak").Ending, "New game preserves the preceding valid checkpoint as backup.");
                        Debug.Log($"R02_NATIVE_OPENING_RESUME_PASS {checks} checks");
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

        private static Room01Player Actor() => UnityEngine.Object.FindFirstObjectByType<Room01Player>();
        private static Room01Gate Gate() => UnityEngine.Object.FindFirstObjectByType<Room01Gate>();
        private static string Objective() => GameObject.Find("Current objective").GetComponent<Text>().text;
        private static bool HasSchool65() => Actor().transform.Find("School65 facing").GetComponentsInChildren<SkinnedMeshRenderer>()
            .SelectMany(mesh => mesh.bones).Distinct().Count() == 65;

        private static Button FindButton(string name) => UnityEngine.Object
            .FindObjectsByType<Button>(FindObjectsInactive.Exclude, FindObjectsSortMode.None).FirstOrDefault(button => button.name == name);
        private static bool ButtonIsActive(string name) => FindButton(name) != null;

        private static void Press(string name)
        {
            var button = FindButton(name);
            if (button == null || !button.interactable) throw new InvalidOperationException("Unavailable control: " + name);
            button.onClick.Invoke();
        }

        private static void Require(bool value, string message)
        {
            if (!value) throw new InvalidOperationException(message);
            checks++;
        }

        private static void Finish(int code)
        {
            SessionState.EraseBool(Running);
            EditorApplication.update -= Tick;
            EditorApplication.Exit(code);
        }
    }
}
