using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using ElevenEleven.Opening;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.SceneManagement;
using UnityEngine.UI;
using Object = UnityEngine.Object;

namespace ElevenEleven.Editor
{
    [InitializeOnLoad]
    internal static class SignalAndLiveRoomReview
    {
        private const string Running = "11.11.SignalAndLiveRoomReview";
        private const string DeadlineKey = "11.11.SignalAndLiveRoomReview.Deadline";
        private const string Title = "Assets/ElevenEleven/Scenes/ChapterTitle.unity";
        private const BindingFlags Private = BindingFlags.Instance | BindingFlags.NonPublic;
        private static readonly MethodInfo PlaceMethod = typeof(Room01Player).GetMethod("Place", Private);
        private static readonly FieldInfo YawField = typeof(Room01Player).GetField("viewYaw", Private);
        private static readonly FieldInfo PitchField = typeof(Room01Player).GetField("viewPitch", Private);
        private static readonly PropertyInfo AlignedProp = typeof(Room01Player).GetProperty("SignalAligned", Private);
        private static readonly PropertyInfo PoweredProp = typeof(Room01Player).GetProperty("ConduitPowered", Private);
        private static readonly PropertyInfo SavePath = typeof(Room01Player).Assembly
            .GetType("ElevenEleven.Opening.ChapterSaveSession")
            .GetProperty("SavePath", BindingFlags.Static | BindingFlags.NonPublic);

        private enum Step
        {
            RoomInit,
            WaitClockPrompt,
            WaitTracePrompt,
            WaitConduitPrompt,
            WaitTunerPrompt,
            WaitGateOpen,
            SignalOnline,
            LiveRoomsSurvey
        }

        private static Step step;
        private static double deadline;
        private static string captureDir;
        private static string fixtureDir;
        private static int waitFrames;

        static SignalAndLiveRoomReview()
        {
            if (SessionState.GetBool(Running, false)) ResumeWatch();
        }

        public static void Run()
        {
            if (!Application.isBatchMode || SystemInfo.graphicsDeviceType == GraphicsDeviceType.Null)
                throw new InvalidOperationException("SignalAndLiveRoomReview requires Unity batchmode with D3D11.");

            captureDir = Environment.GetEnvironmentVariable("ECHO_STATION_CAPTURE");
            fixtureDir = Environment.GetEnvironmentVariable("ECHO_R02_FIXTURE_DIRECTORY");
            if (string.IsNullOrWhiteSpace(captureDir) || string.IsNullOrWhiteSpace(fixtureDir))
                throw new InvalidOperationException("Set ECHO_STATION_CAPTURE and ECHO_R02_FIXTURE_DIRECTORY.");

            if (Directory.Exists(fixtureDir)) Directory.Delete(fixtureDir, true);
            Directory.CreateDirectory(fixtureDir);
            Directory.CreateDirectory(captureDir);

            var saveFile = (string)SavePath.GetValue(null);
            var seed = new Room01Checkpoint
            {
                Wake = true, Clock = true, Photo = true, Memory = true,
                Terminal = false, Conduit = false, Ending = false,
                Frequency = 111, Phase = 45, Channel = 7
            };
            if (!seed.Save(saveFile)) throw new IOException("Failed to save Signal fixture.");

            EditorSceneManager.OpenScene("Assets/ElevenEleven/Scenes/ChapterRoom01.unity");
            SessionState.SetBool(Running, true);
            SessionState.SetFloat(DeadlineKey, (float)(EditorApplication.timeSinceStartup + 360.0));
            step = Step.RoomInit;
            ResumeWatch();
            EditorApplication.EnterPlaymode();
        }

        private static void ResumeWatch()
        {
            captureDir = Environment.GetEnvironmentVariable("ECHO_STATION_CAPTURE");
            fixtureDir = Environment.GetEnvironmentVariable("ECHO_R02_FIXTURE_DIRECTORY");
            deadline = 0.0;
            step = Step.RoomInit;
            EditorApplication.update -= Advance;
            EditorApplication.update += Advance;
        }

        private static void Advance()
        {
            try
            {
                if (!EditorApplication.isPlaying) return;
                if (deadline <= 0.0) deadline = EditorApplication.timeSinceStartup + 240.0;
                if (EditorApplication.timeSinceStartup > deadline)
                    throw new TimeoutException($"SignalAndLiveRoomReview timed out at {step}.");

                Application.runInBackground = true;
                if (step == Step.RoomInit) ChapterSceneLink.ReducedMotion = false;
                ChapterSceneLink.Muted = true;

                if (SceneManager.GetActiveScene().name != "ChapterRoom01") return;
                var player = Object.FindFirstObjectByType<Room01Player>();
                var gate = Object.FindFirstObjectByType<Room01Gate>();
                if (!player || !gate || !Camera.main) return;
                if (player.IsStaged) return;

                switch (step)
                {
                    case Step.RoomInit:
                    {
                        var layer = GameObject.Find(ChapterWallFabrication.SignalPresentationLayer)?.transform;
                        Require(layer != null, "Signal presentation layer missing.");
                        var face = layer.Find("Inset signal and feed readout");
                        Require(face != null, "Inset signal and feed readout missing.");
                        if (++waitFrames < 4) return;
                        waitFrames = 0;

                        Require(ReadText(face, "Signal state") == "SEARCH", "Expected initial SEARCH state.");
                        Require(ReadText(face, "Feed state") == "FAULT", "Expected initial FAULT state.");
                        Require(ReadText(face, "Interlock state") == "HELD", "Expected initial HELD state.");
                        Require(!(bool)AlignedProp.GetValue(player) && !(bool)PoweredProp.GetValue(player), "Signal and conduit should start inactive.");

                        MovePlayer(player, new Vector3(-0.35f, 0.04f, 9.65f), 8f, 10f, false);
                        Capture("01-Signal-FaultSearch-Full");
                        CaptureAt("02-Signal-Close-Fault", face.position + face.forward * 1.18f + face.up * 0.04f, face.position);
                        CaptureAt("05-Signal-Bay-Wide", new Vector3(0.75f, 1.84f, -5.8f), new Vector3(0.25f, 2.70f, 13.2f));
                        CaptureAt("05B-Signal-Reverse", new Vector3(-2.2f, 1.86f, 14.1f), new Vector3(-4.85f, 2.6f, 0.10f));

                        var clock = GameObject.Find("StoppedClock pedestal").transform.position;
                        MovePlayer(player, new Vector3(clock.x + 0.9f, 0.04f, clock.z + 0.25f), -90f, 13f, false);
                        waitFrames = 0;
                        step = Step.WaitClockPrompt;
                        return;
                    }
                    case Step.WaitClockPrompt:
                    {
                        if (!HasAnyInspect())
                        {
                            if (++waitFrames < 120) return;
                            throw new InvalidOperationException("StoppedClock inspect prompt did not appear.");
                        }
                        PressInspectAny();
                        PressButton("Keep this trace");
                        var tracePedestal = GameObject.Find("PersonalTrace pedestal").transform.position;
                        MovePlayer(player, new Vector3(tracePedestal.x - 0.8f, 0.04f, tracePedestal.z), 90f, 13f, false);
                        waitFrames = 0;
                        step = Step.WaitTracePrompt;
                        return;
                    }
                    case Step.WaitTracePrompt:
                    {
                        if (!HasAnyInspect())
                        {
                            if (++waitFrames < 120) return;
                            throw new InvalidOperationException("PersonalTrace inspect prompt did not appear.");
                        }
                        PressInspectAny();
                        PressButton("Keep this trace");
                        var conduit = GameObject.Find("PowerConduit").transform.position;
                        MovePlayer(player, new Vector3(conduit.x + 1.0f, 0.04f, conduit.z), -90f, 13f, false);
                        waitFrames = 0;
                        step = Step.WaitConduitPrompt;
                        return;
                    }
                    case Step.WaitConduitPrompt:
                    {
                        if (!HasAnyInspect())
                        {
                            if (++waitFrames < 120) return;
                            throw new InvalidOperationException("Conduit inspect prompt did not appear.");
                        }
                        PressInspectAny();
                        Require((bool)PoweredProp.GetValue(player), "Conduit must energize via real E button.");

                        var terminal = GameObject.Find("SignalTerminal").transform.position;
                        MovePlayer(player, new Vector3(terminal.x, 0.04f, terminal.z + 1.05f), 180f, 13f, false);
                        waitFrames = 0;
                        step = Step.WaitTunerPrompt;
                        return;
                    }
                    case Step.WaitTunerPrompt:
                    {
                        if (!HasAnyInspect())
                        {
                            if (++waitFrames < 120) return;
                            throw new InvalidOperationException("Terminal tune prompt did not appear.");
                        }
                        PressInspectAny();
                        FindSlider("Channel").value = 7;
                        FindSlider("Frequency").value = 218;
                        FindSlider("Phase").value = 50;
                        PressButton("Return to room");
                        Require((bool)AlignedProp.GetValue(player), "Signal must align via real tuner UI.");

                        step = Step.WaitGateOpen;
                        waitFrames = 0;
                        return;
                    }
                    case Step.WaitGateOpen:
                    {
                        if (!gate.IsOpen) return;
                        waitFrames = 0;
                        step = Step.SignalOnline;
                        return;
                    }
                    case Step.SignalOnline:
                    {
                        if (++waitFrames < 5) return;
                        var layer = GameObject.Find(ChapterWallFabrication.SignalPresentationLayer).transform;
                        var face = layer.Find("Inset signal and feed readout");
                        Require(ReadText(face, "Signal state") == "ALIGNED", "Expected ALIGNED state.");
                        Require(ReadText(face, "Feed state") == "ONLINE", "Expected ONLINE state.");
                        Require(ReadText(face, "Interlock state") == "OPEN", "Expected OPEN state.");

                        var relay = face.Find("Rigid feed relay flag");
                        Require(relay.localPosition.x > -0.35f, $"Relay should slide right when powered (got x={relay.localPosition.x:F3}).");
                        var trace = face.Find("Signal trace").GetComponent<LineRenderer>();
                        Require(trace.positionCount == 48, "Trace LineRenderer must have 48 points.");

                        MovePlayer(player, new Vector3(-0.35f, 0.04f, 9.65f), 8f, 10f, false);
                        Capture("03-Signal-AlignedOnline-Full");
                        CaptureAt("04-Signal-Close-Online", face.position + face.forward * 1.18f + face.up * 0.04f, face.position);

                        MovePlayer(player, new Vector3(-0.35f, 0.04f, 9.65f), 8f, 10f, true);
                        Capture("03B-Signal-AlignedOnline-Reduced");

                        Debug.Log("ECHO_SIGNAL_PRESENTATION_PASS");
                        step = Step.LiveRoomsSurvey;
                        return;
                    }
                    case Step.LiveRoomsSurvey:
                    {
                        ChapterSceneLink.ReducedMotion = false;
                        // Capture live views of all remaining wings to audit defects accurately
                        CaptureAt("04B-SchoolJump-Landing-Live", new Vector3(-7.3f, 2.25f, 46.5f), new Vector3(-8.4f, -0.25f, 54.0f));
                        CaptureAt("06-Observatory-Bridge-Live", new Vector3(0.2f, 1.85f, 57.4f), new Vector3(0f, 4.1f, 72.6f));
                        CaptureAt("06B-Observatory-Rear-Live", new Vector3(0.2f, 2.2f, 41.5f), new Vector3(0f, 3.2f, 65f));
                        CaptureAt("07-MemoryLab-Live", new Vector3(13.2f, 2.2f, 61.5f), new Vector3(17.35f, 2.5f, 66.2f));
                        CaptureAt("07B-Archive-Live", new Vector3(-33.4f, 2.15f, 105.5f), new Vector3(-35.5f, 2.35f, 117.5f));

                        // Security arrival + exit gate
                        var secX = StationSecurityWing.CenterX;
                        var secZ = StationSecurityWing.EntranceZ;
                        MovePlayer(player, new Vector3(secX - 3.36f, 0.046f, secZ + 1.67f), 15f, 11f, false);
                        Capture("08-Security-Arrival-Live");
                        CaptureAt("09-Security-ExitGate-Live", new Vector3(secX - 1.2f, 1.85f, secZ + 9.2f), new Vector3(secX + 0.4f, 2.1f, secZ + 18.2f));

                        // Specimen
                        CaptureAt("10-Specimen-Live", new Vector3(16.7f, 3.35f, 101.1f), new Vector3(8.9f, 2.32f, 111.8f));

                        // Reactor balcony + under-bridge check
                        CaptureAt("11-Reactor-Balcony-Live", new Vector3(-34.6f, 2.25f, 148.6f), new Vector3(-35.5f, 2.9f, 172f));
                        CaptureAt("11B-Reactor-UnderBridge-Live", new Vector3(-29.2f, 1.55f, 162.5f), new Vector3(-36.2f, 2.8f, 173f));

                        // Quarantine
                        CaptureAt("12-Quarantine-Live", new Vector3(-38.8f, 6.1f, 208.5f), new Vector3(-35.5f, 6.4f, 220f));

                        // Surveillance bay + Inspection mirror view
                        CaptureAt("13-Surveillance-Bay-Live", new Vector3(-38.0f, 6.2f, 247.2f), new Vector3(-32.0f, 6.4f, 257f));
                        MovePlayer(player, new Vector3(-28.8f, 4.045f, 252f), 90f, 13f, false);
                        Capture("14-Surveillance-Mirror-Live");
                        CaptureAt("14B-Surveillance-NorthGate-Live", new Vector3(-35.5f, 5.85f, 270.0f), new Vector3(-35.5f, 6.45f, 278.5f));
                        var survWing = Object.FindFirstObjectByType<StationSurveillanceWing>();
                        if (survWing)
                        {
                            var present = typeof(StationSurveillanceWing).GetMethod("Present", BindingFlags.Instance | BindingFlags.NonPublic);
                            present?.Invoke(survWing, new object[] { true, true, 1f });
                            CaptureAt("14C-Surveillance-PathSafe-Live", new Vector3(-35.5f, 5.85f, 270.0f), new Vector3(-35.5f, 6.45f, 278.5f));
                            present?.Invoke(survWing, new object[] { false, false, 1f });
                        }

                        // Examination theatre & observation alcove & Zero altar
                        CaptureAt("15-Examination-Theatre-Live", new Vector3(-29.7f, 8.05f, 291.7f), new Vector3(-35.5f, 5.9f, 302f));
                        MovePlayer(player, new Vector3(-39.6f, 5.245f, 301.03f), 0f, 13f, false);
                        Capture("16-Examination-Observation-Live");
                        CaptureAt("17-Zero-Altar-Live", new Vector3(-31.0f, 6.65f, 308.8f), new Vector3(-35.5f, 4.9f, 313.1f));

                        AuditSuspiciousObjects();
                        Debug.Log("ECHO_LIVE_ROOMS_SURVEY_PASS");
                        Finish(0);
                        return;
                    }
                }
            }
            catch (Exception error)
            {
                Debug.LogException(error);
                Finish(1);
            }
        }

        private static void AuditSuspiciousObjects()
        {
            var sec = GameObject.Find("Security wing")?.transform;
            if (sec)
            {
                foreach (var r in sec.GetComponentsInChildren<Renderer>(true))
                {
                    if (!r.enabled || !r.gameObject.activeInHierarchy) continue;
                    var b = r.bounds;
                    if (r.name.Contains("_MeshInstance3D_163") || r.name.Contains("_MeshInstance3D_90") ||
                        r.name.Contains("_MeshInstance3D_91") || (b.size.y < 0.35f && b.center.y > 0.9f && b.size.magnitude < 2.5f))
                        Debug.Log($"AUDIT_SEC obj={PathOf(r.transform)} pos={b.center:F3} size={b.size:F3} mat={r.sharedMaterial?.name}");
                }
            }

            var surv = GameObject.Find("Surveillance and mirror")?.transform;
            if (surv)
            {
                foreach (var r in surv.GetComponentsInChildren<Renderer>(true))
                {
                    if (!r.enabled || !r.gameObject.activeInHierarchy) continue;
                    var b = r.bounds;
                    if (b.center.x > -31.5f && b.center.z > 249f && b.center.z < 260f && b.center.y > 4.2f)
                        Debug.Log($"AUDIT_MIRROR obj={PathOf(r.transform)} pos={b.center:F3} size={b.size:F3} mat={r.sharedMaterial?.name}");
                }
            }

            var exam = Object.FindFirstObjectByType<StationExaminationWing>(FindObjectsInactive.Include)?.transform;
            if (exam)
            {
                foreach (var r in exam.GetComponentsInChildren<Renderer>(true))
                {
                    if (!r.enabled || !r.gameObject.activeInHierarchy) continue;
                    var b = r.bounds;
                    if (b.center.y > 6.5f && b.center.y < 10.5f && b.size.magnitude < 4.5f)
                        Debug.Log($"AUDIT_EXAM obj={PathOf(r.transform)} pos={b.center:F3} size={b.size:F3} mat={r.sharedMaterial?.name}");
                }
            }

            var obs = GameObject.Find("Memory Observatory")?.transform;
            if (obs)
            {
                foreach (var r in obs.GetComponentsInChildren<Renderer>(true))
                {
                    if (!r.enabled || !r.gameObject.activeInHierarchy) continue;
                    var b = r.bounds;
                    if (b.center.y > 7.0f && b.size.magnitude < 3.0f)
                        Debug.Log($"AUDIT_OBS obj={PathOf(r.transform)} pos={b.center:F3} size={b.size:F3} mat={r.sharedMaterial?.name}");
                }
            }
        }

        private static string PathOf(Transform t)
        {
            var parts = new List<string>();
            while (t != null) { parts.Add(t.name); t = t.parent; }
            parts.Reverse();
            return string.Join("/", parts);
        }

        private static string ReadText(Transform parent, string childName) =>
            parent.Find(childName).GetComponent<TextMesh>().text;

        private static void MovePlayer(Room01Player player, Vector3 point, float yaw, float pitch, bool reduced)
        {
            ChapterSceneLink.ReducedMotion = reduced;
            YawField.SetValue(player, yaw);
            PitchField.SetValue(player, pitch);
            PlaceMethod.Invoke(player, new object[] { point });
        }

        private static bool HasAnyInspect()
        {
            var btn = Object.FindObjectsByType<Button>(FindObjectsInactive.Include, FindObjectsSortMode.None)
                .Single(b => b.gameObject.name == "Inspect  [E]");
            return btn.gameObject.activeInHierarchy && btn.interactable;
        }

        private static void PressInspectAny()
        {
            var btn = Object.FindObjectsByType<Button>(FindObjectsInactive.Include, FindObjectsSortMode.None)
                .Single(b => b.gameObject.name == "Inspect  [E]");
            Require(btn.gameObject.activeInHierarchy && btn.interactable, "Inspect  [E] button unavailable.");
            btn.onClick.Invoke();
        }

        private static Slider FindSlider(string name) => GameObject.Find(name).GetComponent<Slider>();

        private static void PressButton(string name)
        {
            var btn = Object.FindObjectsByType<Button>(FindObjectsInactive.Include, FindObjectsSortMode.None)
                .Single(b => b.gameObject.name == name);
            Require(btn.gameObject.activeInHierarchy && btn.interactable, $"Button '{name}' unavailable.");
            btn.onClick.Invoke();
        }

        private static void Capture(string name)
        {
            StormworksSmoke.Capture(Camera.main, name);
        }

        private static void CaptureAt(string name, Vector3 eye, Vector3 focus)
        {
            var cam = Camera.main;
            var oldPos = cam.transform.position;
            var oldRot = cam.transform.rotation;
            try
            {
                cam.transform.SetPositionAndRotation(eye, Quaternion.LookRotation(focus - eye));
                StormworksSmoke.Capture(cam, name);
            }
            finally
            {
                cam.transform.SetPositionAndRotation(oldPos, oldRot);
            }
        }

        private static void Require(bool cond, string msg)
        {
            if (!cond) throw new InvalidOperationException(msg);
            Debug.Log("ECHO_SIGNAL_CHECK " + msg);
        }

        private static void Finish(int code)
        {
            EditorApplication.update -= Advance;
            SessionState.EraseBool(Running);
            EditorApplication.Exit(code);
        }
    }
}
