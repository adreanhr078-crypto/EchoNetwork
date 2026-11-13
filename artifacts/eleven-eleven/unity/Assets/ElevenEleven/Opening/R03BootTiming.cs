#if ECHO_R03_PLAYER_PROBE && UNITY_STANDALONE_WIN
using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.SceneManagement;
using UnityEngine.UI;

namespace ElevenEleven.Opening
{
    internal sealed class R03BootTiming : MonoBehaviour
    {
        [StructLayout(LayoutKind.Sequential)]
        private struct IoCounters
        {
            public ulong readOperations, writeOperations, otherOperations;
            public ulong readBytes, writeBytes, otherBytes;
        }

        [DllImport("kernel32.dll")]
        private static extern IntPtr GetCurrentProcess();

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool GetProcessIoCounters(IntPtr process, out IoCounters counters);

        [Serializable]
        private sealed class Marker
        {
            public string name;
            public double milliseconds;
            public long logicalReadBytes;
            public long logicalReadOperations;
        }

        [Serializable]
        private sealed class Sample
        {
            public string route;
            public string graphicsDevice;
            public string graphicsApi;
            public int width;
            public int height;
            public double worstUpdateGapMilliseconds;
            public double worstVisibleLoadUpdateGapMilliseconds;
            public double worstReadyCutUpdateGapMilliseconds;
            public bool usedOffscreenRenderRequest;
            public Marker[] marks;
        }

        private static R03BootTiming instance;
        private readonly Dictionary<string, Marker> marks = new Dictionary<string, Marker>();
        private string output;
        private string route;
        private double lastUpdate;
        private double worstGap;
        private double visibleGap;
        private double cutGap;
        private int visibleViews;

        internal static void TrackLoadingView(bool visible)
        {
            if (instance != null) instance.visibleViews += visible ? 1 : -1;
        }
        private bool offscreen;

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSceneLoad)]
        private static void Initialize()
        {
            var output = Environment.GetEnvironmentVariable("ECHO_R03_EVIDENCE");
            var route = Environment.GetEnvironmentVariable("ECHO_R03_ROUTE");
            if (string.IsNullOrWhiteSpace(output)) return;
            if (route != "fresh" && route != "continue" && route != "legacy")
                throw new InvalidOperationException("Unrecognized R03 route.");
            var probe = new GameObject("R03 boot timing observer").AddComponent<R03BootTiming>();
            DontDestroyOnLoad(probe.gameObject);
            instance = probe;
            probe.output = output;
            probe.route = route;
            Application.runInBackground = true;
            Application.targetFrameRate = 45;
            SceneManager.sceneLoaded += probe.OnSceneLoaded;
            Canvas.willRenderCanvases += probe.OnCanvas;
            RenderPipelineManager.endContextRendering += probe.OnRender;
            Mark("managed_before_title_load");
            probe.StartCoroutine(probe.CheckRoute());
        }

        internal static void Mark(string name)
        {
            if (instance == null || instance.marks.ContainsKey(name)) return;
            if (!GetProcessIoCounters(GetCurrentProcess(), out var io))
                throw new IOException("Could not read Windows process I/O counters.");
            instance.marks.Add(name, new Marker
            {
                name = name,
                milliseconds = Time.realtimeSinceStartupAsDouble * 1000d,
                logicalReadBytes = (long)io.readBytes,
                logicalReadOperations = (long)io.readOperations,
            });
        }

        private void OnSceneLoaded(Scene scene, LoadSceneMode mode) => Mark(scene.name + "_scene_loaded");

        private void OnCanvas()
        {
            if (SceneManager.GetActiveScene().name == "ChapterTitle") Mark("title_canvas_submission");
        }

        private void OnRender(ScriptableRenderContext _, List<Camera> cameras)
        {
            if (SceneManager.GetActiveScene().name == "ChapterRoom01" && cameras.Contains(Camera.main))
                Mark(offscreen ? "room_render_request_end" : "room_render_context_end");
        }

        private void Update()
        {
            var now = Time.realtimeSinceStartupAsDouble;
            if (lastUpdate > 0d)
            {
                var gap = (now - lastUpdate) * 1000d;
                worstGap = Math.Max(worstGap, gap);
                var liveRoom = marks.ContainsKey("gameplay_released");
                if (!liveRoom && visibleViews > 0)
                    visibleGap = Math.Max(visibleGap, gap);
                if (liveRoom && !marks.ContainsKey("room_motion_applied") &&
                    marks.TryGetValue("warmup_render_done", out var warm) &&
                    marks.TryGetValue("entry_requested_ChapterRoom01", out var entry) && warm.milliseconds <= entry.milliseconds)
                    cutGap = Math.Max(cutGap, gap);
            }
            lastUpdate = now;
        }

        private IEnumerator CheckRoute()
        {
            yield return null;
            Require(SceneManager.GetActiveScene().name == "ChapterTitle", "The player must boot from the normal title.");
            Press("Motion on");
            if (route == "fresh")
            {
                Require(FindButton("Continue game") == null, "Fresh boot has no Continue.");
                Press("Tap to Start");
                yield return Await(() => SceneManager.GetActiveScene().name == "ChapterOpening", "opening");
                yield return null;
                if (Environment.GetEnvironmentVariable("ECHO_R03_WAIT_FOR_ROOM") == "1")
                    yield return Await(() => marks.ContainsKey("warmup_render_done"), "early room render preparation");
                Press("Piece 1");
                Press("Piece 2");
                Press("Piece 5");
                Press("Piece 6");
                yield return Await(() => FindFirstObjectByType<OpeningCinematicPresenter>() != null, "film");
                Press("Continue");
                Press("Continue");
                Press("I am ready.");
                Press("Continue");
            }
            else
            {
                Press("Continue game");
            }

            yield return Await(() => SceneManager.GetActiveScene().name == "ChapterRoom01", "Room 01");
            yield return null;
            var actor = FindFirstObjectByType<Room01Player>();
            Require(actor != null && actor.transform.Find("School65 facing") != null, "Room 01 must select School65.");
            if (route != "fresh")
                Require(GameObject.Find("Current objective").GetComponent<Text>().text == "Find the personal trace.",
                    "Resume must restore the saved clock.");
            InputSystem.settings.backgroundBehavior = InputSettings.BackgroundBehavior.IgnoreFocus;
            var keyboard = InputSystem.AddDevice<Keyboard>();
            keyboard.MakeCurrent();
            Mark("movement_queued");
            InputSystem.QueueStateEvent(keyboard, new KeyboardState(Key.W));
            InputSystem.Update();
            yield return Await(() => marks.ContainsKey("room_motion_applied"), "first movement consumed by the capsule");
            InputSystem.RemoveDevice(keyboard);
            yield return Await(() => marks.ContainsKey("room_ground_contact"), "first physics contact");
            var camera = Camera.main;
            Require(camera != null && camera.isActiveAndEnabled, "Gameplay camera missing.");
            for (var count = 0; count < 10 && !marks.ContainsKey("room_render_context_end"); count++) yield return null;
            if (!marks.ContainsKey("room_render_context_end"))
            {
                offscreen = true;
                var target = new RenderTexture(Screen.width, Screen.height, 24, RenderTextureFormat.ARGB32);
                target.Create();
                try
                {
                    var request = new UniversalRenderPipeline.SingleCameraRequest { destination = target };
                    Require(RenderPipeline.SupportsRenderRequest(camera, request), "The player cannot render the camera.");
                    Mark("room_render_request_begin");
                    RenderPipeline.SubmitRenderRequest(camera, request);
                    Mark("room_render_request_end");
                }
                finally
                {
                    target.Release();
                    Destroy(target);
                }
            }
            Require(marks.ContainsKey("request_ChapterRoom01"), "Room load request marker missing.");
            Directory.CreateDirectory(output);
            var report = new Sample
            {
                route = route, graphicsDevice = SystemInfo.graphicsDeviceName, graphicsApi = SystemInfo.graphicsDeviceType.ToString(),
                width = Screen.width, height = Screen.height, worstUpdateGapMilliseconds = worstGap,
                worstVisibleLoadUpdateGapMilliseconds = visibleGap,
                worstReadyCutUpdateGapMilliseconds = cutGap,
                usedOffscreenRenderRequest = offscreen,
                marks = marks.Values.OrderBy(value => value.milliseconds).ToArray(),
            };
            File.WriteAllText(Path.Combine(output, "timing.json"), JsonUtility.ToJson(report, true));
            Debug.Log($"R03_WINDOWS_SAMPLE_PASS route={route} marks={marks.Count}");
            Application.Quit(0);
        }

        private static IEnumerator Await(Func<bool> ready, string label)
        {
            var deadline = Time.realtimeSinceStartup + 65f;
            while (!ready() && Time.realtimeSinceStartup < deadline) yield return null;
            Require(ready(), "Timed out at " + label);
        }

        private static Button FindButton(string name) =>
            Array.Find(FindObjectsByType<Button>(FindObjectsInactive.Exclude, FindObjectsSortMode.None), button => button.name == name);

        private static void Press(string name)
        {
            var button = FindButton(name);
            Require(button != null && button.interactable, "Unavailable control: " + name);
            button.onClick.Invoke();
        }

        private static void Require(bool condition, string message)
        {
            if (condition) return;
            Application.Quit(1);
            throw new InvalidOperationException(message);
        }
    }
}
#endif
