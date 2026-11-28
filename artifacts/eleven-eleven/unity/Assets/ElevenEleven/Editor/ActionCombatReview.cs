using System;
using System.IO;
using System.Linq;
using System.Reflection;
using ElevenEleven.Opening;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.SceneManagement;

namespace ElevenEleven.Editor
{
    internal static class ActionCombatReview
    {
        private const string RunningKey = "ElevenEleven.ActionCombatReview.Running";
        private static readonly MethodInfo PlaceMethod = typeof(Room01Player).GetMethod("Place", BindingFlags.Instance | BindingFlags.NonPublic);
        private static readonly MethodInfo ApplyPactMethod = typeof(Room01Player).GetMethod("ApplyPactAppearance", BindingFlags.Instance | BindingFlags.NonPublic);
        private static readonly MethodInfo FaceMethod = typeof(Room01Player).GetMethod("FaceRouteFocus", BindingFlags.Instance | BindingFlags.NonPublic);
        private static readonly MethodInfo TryMantleMethod = typeof(Room01Player).GetMethod("TryDetectAndStartLedgeMantle", BindingFlags.Instance | BindingFlags.NonPublic);
        private static readonly PropertyInfo DodgeInvulnProp = typeof(Room01Player).GetProperty("IsDodgeInvulnerable", BindingFlags.Instance | BindingFlags.NonPublic);
        private static readonly FieldInfo SchoolMotionField = typeof(Room01Player).GetField("schoolMotion", BindingFlags.Instance | BindingFlags.NonPublic);
        private static readonly FieldInfo PactMotionField = typeof(Room01Player).GetField("pactMotion", BindingFlags.Instance | BindingFlags.NonPublic);
        private static readonly MethodInfo EnterGameplayMethod = typeof(Room01Player).GetMethod("EnterGameplay", BindingFlags.Instance | BindingFlags.NonPublic);
        private static readonly MethodInfo SetRestoreMethod = typeof(Room01Player).Assembly
            .GetType("ElevenEleven.Opening.ChapterSaveSession")
            .GetMethod("SetRestore", BindingFlags.Static | BindingFlags.NonPublic);
        private static readonly PropertyInfo SavePathProp = typeof(Room01Player).Assembly
            .GetType("ElevenEleven.Opening.ChapterSaveSession")
            .GetProperty("SavePath", BindingFlags.Static | BindingFlags.NonPublic);

        private enum Phase { WaitScene, VerifyPathSafe, VerifyRoll, VerifyMantle, VerifyPactCombo, VerifyDash, Done }
        private static Phase phase;
        private static int frames;
        private static double deadline;
        private static string captureDir;
        private static Vector3 rollStart;
        private static float mantleStartY;

        [InitializeOnLoadMethod]
        private static void Hook()
        {
            EditorApplication.playModeStateChanged -= OnPlayStateChanged;
            EditorApplication.playModeStateChanged += OnPlayStateChanged;
            if (SessionState.GetBool(RunningKey, false) && EditorApplication.isPlaying)
                Resume();
        }

        private static void OnPlayStateChanged(PlayModeStateChange change)
        {
            if (change == PlayModeStateChange.EnteredPlayMode && SessionState.GetBool(RunningKey, false))
                Resume();
        }

        public static void Run()
        {
            if (!Application.isBatchMode || SystemInfo.graphicsDeviceType == GraphicsDeviceType.Null)
                throw new InvalidOperationException("ActionCombatReview requires Unity batchmode with D3D11.");

            captureDir = Environment.GetEnvironmentVariable("ECHO_STATION_CAPTURE");
            var fixtureDir = Environment.GetEnvironmentVariable("ECHO_R02_FIXTURE_DIRECTORY");
            if (string.IsNullOrWhiteSpace(captureDir) || string.IsNullOrWhiteSpace(fixtureDir))
                throw new InvalidOperationException("Set ECHO_STATION_CAPTURE and ECHO_R02_FIXTURE_DIRECTORY.");

            Directory.CreateDirectory(captureDir);
            if (Directory.Exists(fixtureDir)) Directory.Delete(fixtureDir, true);
            Directory.CreateDirectory(fixtureDir);

            var saveFile = (string)SavePathProp.GetValue(null);
            var seed = new Room01Checkpoint
            {
                Wake = true, Clock = true, Photo = true, Memory = true,
                Terminal = true, Conduit = true, Ending = true,
                StationStage = 10, ArchiveFragments = 7, ReactorBreakers = 3,
                Frequency = 111, Phase = 45, Channel = 7
            };
            if (!seed.Save(saveFile)) throw new IOException("Failed to seed ActionCombatReview checkpoint.");

            EditorSceneManager.OpenScene("Assets/ElevenEleven/Scenes/ChapterRoom01.unity");
            SessionState.SetBool(RunningKey, true);
            phase = Phase.WaitScene;
            frames = 0;
            Resume();
            EditorApplication.EnterPlaymode();
        }

        private static void Resume()
        {
            captureDir = Environment.GetEnvironmentVariable("ECHO_STATION_CAPTURE");
            deadline = EditorApplication.timeSinceStartup + 240.0;
            EditorApplication.update -= Step;
            EditorApplication.update += Step;
        }

        private static void Step()
        {
            try
            {
                if (!EditorApplication.isPlaying) return;
                if (EditorApplication.timeSinceStartup > deadline)
                    throw new TimeoutException($"ActionCombatReview timed out in phase {phase}.");

                Application.runInBackground = true;
                ChapterSceneLink.ReducedMotion = false;
                ChapterSceneLink.Muted = true;

                if (SceneManager.GetActiveScene().name != "ChapterRoom01") return;
                var player = UnityEngine.Object.FindFirstObjectByType<Room01Player>();
                var route = UnityEngine.Object.FindFirstObjectByType<StormworksRoute>();
                if (!player || !route || !Camera.main) return;
                if (player.IsStaged) return;

                switch (phase)
                {
                    case Phase.WaitScene:
                    {
                        if (++frames < 5) return;
                        var seed = new Room01Checkpoint
                        {
                            Wake = true, Clock = true, Photo = true, Memory = true,
                            Terminal = true, Conduit = true, Ending = true,
                            StationStage = 10, ArchiveFragments = 7, ReactorBreakers = 3,
                            Frequency = 111, Phase = 45, Channel = 7
                        };
                        SetRestoreMethod.Invoke(null, new object[] { seed });
                        EnterGameplayMethod.Invoke(player, new object[] { false });
                        player.SkipStationVista();
                        frames = 0;
                        phase = Phase.VerifyPathSafe;
                        return;
                    }
                    case Phase.VerifyPathSafe:
                    {
                        if (++frames < 3) return;
                        var survWing = UnityEngine.Object.FindFirstObjectByType<StationSurveillanceWing>();
                        if (!survWing) throw new InvalidDataException("Missing StationSurveillanceWing.");
                        var present = typeof(StationSurveillanceWing).GetMethod("Present", BindingFlags.Instance | BindingFlags.NonPublic);
                        present?.Invoke(survWing, new object[] { true, true, 1f });
                        CaptureAt("14C-Surveillance-PathSafe-Live", new Vector3(-35.5f, 5.85f, 270.0f), new Vector3(-35.5f, 6.45f, 278.5f));
                        present?.Invoke(survWing, new object[] { false, false, 1f });
                        var stageVal = typeof(StormworksRoute).GetProperty("Stage", BindingFlags.Instance | BindingFlags.NonPublic)?.GetValue(route);
                        var heldVal = typeof(StormworksRoute).GetProperty("GameplayHeld", BindingFlags.Instance | BindingFlags.NonPublic)?.GetValue(route);
                        Debug.Log($"ACTION_VERIFY_PATHSAFE_PASS stage={stageVal} held={heldVal}");

                        PlaceMethod.Invoke(player, new object[] { new Vector3(0f, 0.04f, 60.0f) });
                        rollStart = player.transform.position;
                        player.RequestDodge();
                        var inv = (bool)DodgeInvulnProp.GetValue(player);
                        if (!inv) throw new InvalidDataException($"Expected dodge invulnerability on SchoolRoll (stage={stageVal} held={heldVal}).");
                        frames = 0;
                        phase = Phase.VerifyRoll;
                        return;
                    }
                    case Phase.VerifyRoll:
                    {
                        if (++frames < 5) return;
                        var schoolAnim = (Animation)SchoolMotionField.GetValue(player);
                        if (!schoolAnim || schoolAnim["Roll"] == null)
                            throw new InvalidDataException("Missing baked SchoolRoll clip.");
                        var moved = Vector3.Distance(rollStart, player.transform.position);
                        if (moved < 0.25f)
                            throw new InvalidDataException($"SchoolRoll displacement too small: {moved:F3}");
                        CaptureAt("18-School-Roll-Live", player.transform.position + new Vector3(2.3f, 1.15f, -1.8f), player.transform.position + Vector3.up * 0.55f);
                        Debug.Log($"ACTION_VERIFY_ROLL_PASS dist={moved:F2} clip={schoolAnim.IsPlaying("Roll")}");

                        // Position directly in front of SurgicalDaisPlatform north vertical lip (z=295.03, top y=5.20 -> rise +0.95m)
                        PlaceMethod.Invoke(player, new object[] { new Vector3(-38.0f, 4.25f, 294.55f) });
                        mantleStartY = player.transform.position.y;
                        var mantled = (bool)TryMantleMethod.Invoke(player, new object[] { Vector3.forward });
                        if (!mantled)
                            throw new InvalidDataException("Expected SurgicalDaisPlatform Ledge Mantle to engage!");
                        Debug.Log($"ACTION_MANTLE_TRIGGERED={mantled}");
                        frames = 0;
                        phase = Phase.VerifyMantle;
                        return;
                    }
                    case Phase.VerifyMantle:
                    {
                        if (++frames < 5) return;
                        var schoolAnim = (Animation)SchoolMotionField.GetValue(player);
                        if (!schoolAnim || schoolAnim["Mantle"] == null || schoolAnim["Hang"] == null)
                            throw new InvalidDataException("Missing baked SchoolMantle/SchoolHang clips.");
                        var rise = player.transform.position.y - mantleStartY;
                        CaptureAt("19-School-Mantle-Live", new Vector3(-35.4f, 5.55f, 291.6f), player.transform.position + Vector3.up * 0.75f);
                        Debug.Log($"ACTION_VERIFY_MANTLE_PASS rise={rise:F2}");

                        // Wait or let mantle finish before switching to Pact combo
                        ApplyPactMethod.Invoke(player, new object[] { true });
                        var pactAnim = (Animation)PactMotionField.GetValue(player);
                        if (!pactAnim || pactAnim["StrikeBoxing"] == null || pactAnim["StrikeHorizontal"] == null || pactAnim["StrikeOverhead"] == null)
                            throw new InvalidDataException("Missing baked PactStrike* combo clips on pactMotion.");
                        PlaceMethod.Invoke(player, new object[] { new Vector3(-37.7f, 5.245f, 298.6f) });
                        FaceMethod.Invoke(player, new object[] { new Vector3(-37.7f, 5.245f, 300.2f) });
                        frames = 0;
                        phase = Phase.VerifyPactCombo;
                        return;
                    }
                    case Phase.VerifyPactCombo:
                    {
                        frames++;
                        if (frames == 2)
                        {
                            player.RequestPactStrike();
                        }
                        else if (frames == 6)
                        {
                            CaptureAt("20-Pact-Combo-Hit1-Boxing", player.transform.position + new Vector3(2.2f, 1.45f, -2.0f), player.transform.position + Vector3.up * 1.1f);
                        }
                        else if (frames == 38)
                        {
                            player.RequestPactStrike();
                        }
                        else if (frames == 42)
                        {
                            CaptureAt("21-Pact-Combo-Hit2-Horizontal", player.transform.position + new Vector3(2.3f, 1.55f, -1.9f), player.transform.position + Vector3.up * 1.1f);
                        }
                        else if (frames == 74)
                        {
                            player.RequestPactStrike();
                        }
                        else if (frames == 79)
                        {
                            CaptureAt("22-Pact-Combo-Hit3-Overhead", player.transform.position + new Vector3(2.2f, 1.65f, -2.1f), player.transform.position + Vector3.up * 1.1f);
                            Debug.Log("ACTION_VERIFY_COMBO_PASS hits=3");
                            player.RequestDodge();
                            frames = 0;
                            phase = Phase.VerifyDash;
                        }
                        return;
                    }
                    case Phase.VerifyDash:
                    {
                        if (++frames < 6) return;
                        CaptureAt("23-Pact-ShadowDash-Live", player.transform.position + new Vector3(2.4f, 1.5f, -2.2f), player.transform.position + Vector3.up * 1.0f);
                        Debug.Log("ACTION_COMBAT_REVIEW_ALL_PASS");
                        Finish(0);
                        return;
                    }
                }
            }
            catch (Exception ex)
            {
                Debug.LogException(ex);
                Finish(1);
            }
        }

        private static void CaptureAt(string name, Vector3 eye, Vector3 lookAt)
        {
            var cam = Camera.main;
            cam.transform.SetPositionAndRotation(eye, Quaternion.LookRotation(lookAt - eye, Vector3.up));
            cam.fieldOfView = 52f;
            var path = Path.Combine(captureDir, name + ".png");
            var rt = RenderTexture.GetTemporary(1280, 720, 24, RenderTextureFormat.ARGB32);
            var prev = cam.targetTexture;
            cam.targetTexture = rt;
            cam.Render();
            var prevActive = RenderTexture.active;
            RenderTexture.active = rt;
            var tex = new Texture2D(1280, 720, TextureFormat.RGB24, false);
            tex.ReadPixels(new Rect(0, 0, 1280, 720), 0, 0);
            tex.Apply(false);
            File.WriteAllBytes(path, tex.EncodeToPNG());
            RenderTexture.active = prevActive;
            cam.targetTexture = prev;
            RenderTexture.ReleaseTemporary(rt);
            UnityEngine.Object.DestroyImmediate(tex);
        }

        private static void Finish(int code)
        {
            SessionState.SetBool(RunningKey, false);
            EditorApplication.update -= Step;
            EditorApplication.Exit(code);
        }
    }
}
