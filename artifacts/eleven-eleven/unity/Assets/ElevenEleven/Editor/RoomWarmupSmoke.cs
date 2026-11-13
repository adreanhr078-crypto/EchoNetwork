using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using ElevenEleven.Opening;
using UnityEditor;
using UnityEngine;
using UnityEngine.Profiling;
using UnityEngine.Rendering;
using UnityEngine.SceneManagement;
using UnityEngine.UI;

namespace ElevenEleven.Editor
{
    [InitializeOnLoad]
    internal static class RoomWarmupSmoke
    {
        private const string Running = "ElevenEleven.R05.Running";
        private const string Deadline = "ElevenEleven.R05.Deadline";
        private const int WarmupCycles = 3;
        private static readonly List<long> retainedBytes = new List<long>();
        private static int step;
        private static int completed;
        private static bool rendered;
        private static int RequiredCycles => SystemInfo.graphicsDeviceType == GraphicsDeviceType.Null ? 30 + WarmupCycles : 1;

        static RoomWarmupSmoke()
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
                throw new InvalidOperationException("A fresh fixture is required.");
            Directory.CreateDirectory(fixture);
            ChapterSceneBuilder.OpenRegisteredTitle();
            SessionState.SetBool(Running, true);
            SessionState.SetFloat(Deadline, (float)EditorApplication.timeSinceStartup + 570f);
            EditorApplication.update += Tick;
            EditorApplication.EnterPlaymode();
        }

        private static void Tick()
        {
            try
            {
                if (EditorApplication.timeSinceStartup > SessionState.GetFloat(Deadline, 0f))
                    throw new TimeoutException($"Room warmup stalled at cycle {completed}, step {step}.");
                if (!EditorApplication.isPlaying) return;
                var scene = SceneManager.GetActiveScene().name;
                switch (step)
                {
                    case 0 when scene == "ChapterTitle":
                        Application.targetFrameRate = 45;
                        Application.runInBackground = true;
                        if (!ChapterSceneLink.ReducedMotion) Press("Motion on");
                        Press("Tap to Start");
                        step++;
                        break;
                    case 1 when scene == "ChapterOpening":
                        var stage = UnityEngine.Object.FindFirstObjectByType<ChapterRoomStage>();
                        if (stage == null) return;
                        Require(!stage.IsFailed, "Room warmup reported failure.");
                        if (!stage.IsReady) return;
                        var staged = UnityEngine.Object.FindFirstObjectByType<Room01Player>();
                        Require(staged != null && staged.IsStaged && staged.GetComponent<CharacterController>().isGrounded,
                            "The staged player has real floor contact and gameplay input is still held.");
                        Require(Camera.main == null && GameObject.Find("Current objective") == null, "Opening owns the view and UI before the cut.");
                        if (SystemInfo.graphicsDeviceType != GraphicsDeviceType.Null)
                        {
                            Require(stage.RenderWarmupCompleted, "The actual renderer must warm before input release.");
                            rendered = true;
                        }
                        Press("Piece 1");
                        Press("Piece 2");
                        Press("Piece 5");
                        Press("Piece 6");
                        step++;
                        break;
                    case 2 when scene == "ChapterOpening" && UnityEngine.Object.FindFirstObjectByType<OpeningCinematicPresenter>() != null:
                        Press("Continue");
                        Press("Continue");
                        Press("I am ready.");
                        Press("Continue");
                        Press("Continue");
                        Press("Continue");
                        step++;
                        break;
                    case 3 when scene == "ChapterRoom01" && SceneManager.sceneCount == 1:
                        var player = UnityEngine.Object.FindFirstObjectByType<Room01Player>();
                        Require(player != null && !player.IsStaged && Camera.main != null &&
                            GameObject.Find("Current objective") != null, "Room handoff releases input, HUD and the gameplay camera.");
                        Press("Back to title");
                        step++;
                        break;
                    case 4 when scene == "ChapterTitle" && SceneManager.sceneCount == 1:
                        Require(UnityEngine.Object.FindFirstObjectByType<ChapterRoomStage>(FindObjectsInactive.Include) == null &&
                            UnityEngine.Object.FindFirstObjectByType<Room01Player>(FindObjectsInactive.Include) == null,
                            "No staged room or player survives return to title.");
                        completed++;
                        if (completed > WarmupCycles) retainedBytes.Add(Profiler.GetTotalAllocatedMemoryLong());
                        if (completed == RequiredCycles)
                        {
                            var path = Path.Combine(Environment.GetEnvironmentVariable("ECHO_R02_FIXTURE_DIRECTORY"), "retained-bytes.txt");
                            File.WriteAllLines(path, retainedBytes.Select(value => value.ToString()).ToArray());
                            Debug.Log($"R05_WARMUP_PASS cycles={completed} retainedSamples={retainedBytes.Count} rendered={rendered}");
                            Finish(0);
                        }
                        else
                        {
                            if (completed % 10 == 0) Debug.Log($"R05_WARMUP_PROGRESS cycles={completed}");
                            step = 0;
                        }
                        break;
                }
            }
            catch (Exception error)
            {
                Debug.LogException(error);
                Finish(1);
            }
        }

        private static void Press(string name)
        {
            var button = UnityEngine.Object.FindObjectsByType<Button>(FindObjectsInactive.Exclude, FindObjectsSortMode.None)
                .FirstOrDefault(value => value.name == name);
            Require(button != null && button.interactable, "Unavailable control: " + name);
            button.onClick.Invoke();
        }

        private static void Require(bool condition, string reason)
        {
            if (!condition) throw new InvalidOperationException(reason);
        }

        private static void Finish(int code)
        {
            SessionState.EraseBool(Running);
            EditorApplication.update -= Tick;
            EditorApplication.Exit(code);
        }
    }
}
