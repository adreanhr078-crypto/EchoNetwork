using System;
using System.IO;
using System.Linq;
using System.Reflection;
using ElevenEleven.Opening;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.SceneManagement;
using UnityEngine.UI;
using UnityEngine.Video;

namespace ElevenEleven.Editor
{
    [InitializeOnLoad]
    internal static class StormworksSmoke
    {
        private const string Running = "11.11.StationSmoke";
        private const string Room = "Assets/ElevenEleven/Scenes/ChapterRoom01.unity";
        private const BindingFlags Private = BindingFlags.NonPublic | BindingFlags.Instance;
        private static int phase;
        private static int checks;
        private static int actorBeforeLoad;
        private static double timeout;
        private static Keyboard keyboard;
        private static float peak;
        private static bool sprintSeen;
        private static Vector3 revealStart;
        private static string Fixture => Environment.GetEnvironmentVariable("ECHO_R02_FIXTURE_DIRECTORY");
        private static string Checkpoint => Path.Combine(Fixture, "system_opening_v1.json");

        static StormworksSmoke()
        {
            if (SessionState.GetBool(Running, false)) EditorApplication.update += Advance;
        }

        public static void Run()
        {
            if (!Application.isBatchMode || string.IsNullOrEmpty(Fixture))
                throw new InvalidOperationException("Run in batch mode with a separate checkpoint fixture.");
            Directory.CreateDirectory(Fixture);
            var state = new Room01Checkpoint { Wake = true, Clock = true, Photo = true, Memory = true, Terminal = true,
                Conduit = true, Ending = true, Frequency = 111, Phase = 45, Channel = 7 };
            Require(state.Save(Checkpoint), "Fixture saves");
            var old = File.ReadAllText(Checkpoint).Replace(",\"station\":0", "");
            File.WriteAllText(Checkpoint, old);
            SessionState.SetString(Running + ".Legacy", old);
            Require(!old.Contains("\"station\"") && Room01Checkpoint.Load(Checkpoint)?.StationStage == 0, "Legacy save loads");
            state.Ending = false;
            state.StationStage = 2;
            Require(!state.Save(Checkpoint), "Station progress requires blast gate crossing");
            EditorSceneManager.OpenScene(Room);
            SessionState.SetBool(Running, true);
            EditorApplication.update += Advance;
            EditorApplication.EnterPlaymode();
        }

        private static void Advance()
        {
            try
            {
                if (!EditorApplication.isPlaying) return;
                if (timeout == 0) timeout = EditorApplication.timeSinceStartup + 330;
                if (EditorApplication.timeSinceStartup > timeout) throw new TimeoutException($"Phase {phase}");
                var player = UnityEngine.Object.FindFirstObjectByType<Room01Player>();
                if (player == null) return;
                var position = player.transform.position;
                var route = UnityEngine.Object.FindFirstObjectByType<StormworksRoute>();
                var camera = Camera.main;
                switch (phase)
                {
                    case 0:
                        Application.targetFrameRate = 50;
                        Application.runInBackground = true;
                        InputSystem.settings.backgroundBehavior = InputSettings.BackgroundBehavior.IgnoreFocus;
                        InputSystem.settings.editorInputBehaviorInPlayMode = InputSettings.EditorInputBehaviorInPlayMode.AllDeviceInputAlwaysGoesToGameView;
                        keyboard = InputSystem.AddDevice<Keyboard>();
                        keyboard.MakeCurrent();
                        Require(route != null && camera != null, "Normal Room 01 scene owns the extension and camera");
                        Require(camera.GetUniversalAdditionalCameraData().renderPostProcessing, "URP scene grade active");
                        Require(!GameObject.Find("Next corridor bulkhead"), "Old dead end is open");
                        Require(GameObject.Find("Hydraulic pressure governor")?.GetComponentInChildren<MeshRenderer>() != null,
                            "Optimized pressure governor is imported into the live room");
                        Capture(camera, "01-Containment");
                        File.WriteAllText(Checkpoint, SessionState.GetString(Running + ".Legacy", ""));
                        LoadCheckpoint();
                        phase++;
                        break;
                    case 1:
                        if (position.z < 19f) return;
                        Require(UnityEngine.Object.FindFirstObjectByType<Room01Gate>().IsOpen, "Old saves restore the original gate");
                        Place(player, new Vector3(0f, 0.04f, 24.95f));
                        SetKeys(Key.W);
                        phase++;
                        break;
                    case 2:
                        if (position.z >= 24.1f) return;
                        SetKeys();
                        Require(position.z >= 23.3f, "High pressure recovers to a safe bay");
                        Require(Room01Checkpoint.Load(Checkpoint).StationStage == 0, "Failure does not grant progress");
                        Place(player, new Vector3(-2.28f, 0.04f, 23.12f));
                        phase++;
                        break;
                    case 3:
                        if (!((Button)typeof(Room01Player).GetField("inspect", Private).GetValue(player)).isActiveAndEnabled) return;
                        player.OpenInspection();
                        Place(player, new Vector3(0f, 0.04f, 24.3f));
                        SetKeys(Key.W);
                        Capture(camera, "02-Pressure");
                        phase++;
                        break;
                    case 4:
                        if (position.z < 27f) return;
                        Require(Room01Checkpoint.Load(Checkpoint).StationStage == 1, "Walking through vented pressure writes stage one");
                        phase++;
                        break;
                    case 5:
                        if (!Get<bool>(route, "InReveal")) return;
                        revealStart = position;
                        phase++;
                        break;
                    case 6:
                        if (Get<float>(route, "RevealWeight") < 0.90f) return;
                        Require(Vector3.Distance(revealStart, position) < 0.05f, "In-engine vista temporarily owns input");
                        Capture(camera, "03-EchoStation");
                        player.SkipStationVista();
                        Require(!Get<bool>(route, "InReveal"), "Vista can be skipped");
                        SetKeys();
                        Place(player, new Vector3(-1.05f, 0.04f, 51.7f));
                        phase++;
                        break;
                    case 7:
                        if (!player.GetComponent<CharacterController>().isGrounded) return;
                        Capture(camera, "04-ServicePlatforms");
                        sprintSeen = false;
                        SetKeys(Key.A, Key.LeftShift);
                        phase = 70;
                        break;
                    case 70:
                        var running = player.GetComponentInChildren<Animation>().IsPlaying("Run");
                        sprintSeen |= running;
                        if (position.x > -2.35f) return;
                        Require(sprintSeen, "Sprint uses remapped School65 Run");
                        SetKeys(Key.A, Key.LeftShift, Key.Space);
                        phase = 8;
                        break;
                    case 8:
                        if (position.z < 50f) throw new InvalidOperationException($"Jump missed; returned from peak {peak:0.00} m.");
                        peak = Mathf.Max(peak, position.y);
                        if (position.x > -4.17f) return;
                        SetKeys();
                        phase++;
                        break;
                    case 9:
                        if (!player.GetComponent<CharacterController>().isGrounded) return;
                        Require(position.x < -3.72f && position.y > 0.30f && peak > 0.85f, "Jump input reaches the first suspended plate");
                        Place(player, new Vector3(-15f, 0.04f, 50.07f));
                        SetKeys(Key.W);
                        phase++;
                        break;
                    case 10:
                        if (position.z < 55.6f) return;
                        SetKeys();
                        Require(position.y > 0.9f, "Alternate stair route reaches relay on foot");
                        player.OpenInspection();
                        Require(Room01Checkpoint.Load(Checkpoint).StationStage == 2, "Relay writes stage two");
                        phase++;
                        break;
                    case 11:
                        if (GameObject.Find("Lab isolation shutter").transform.position.y < 4.5f) return;
                        Require(GameObject.Find("Security sector shutter").transform.position.y < 2f, "Security requires the station log");
                        Place(player, new Vector3(15f, 0.04f, 61.7f));
                        SetKeys(Key.W);
                        phase++;
                        break;
                    case 12:
                        if (position.z < 66.7f) return;
                        SetKeys();
                        player.OpenInspection();
                        Require(Room01Checkpoint.Load(Checkpoint).StationStage == 3, "Lab log writes stage three");
                        Capture(camera, "05-MemoryLab");
                        LoadCheckpoint();
                        phase++;
                        break;
                    case 13:
                        if (position.z < 66.5f || position.x > 13.65f) return;
                        Require(GameObject.Find("Lab isolation shutter").transform.position.y > 6f, "Lab progress restores door and safe position");
                        Require(!Get<bool>(route, "InReveal"), "Continuing after the relay does not replay the vista");
                        Require(GameObject.Find("Security sector shutter").transform.position.y > 3f, "Lab restore opens the route to Security");
                        Place(player, new Vector3(StationSecurityWing.CenterX - 3.36f, 0.046f, StationSecurityWing.EntranceZ + 1.67f));
                        phase++;
                        break;
                    case 14:
                        player.OpenInspection();
                        var security = UnityEngine.Object.FindFirstObjectByType<StationSecurityWing>();
                        var remaining = (float)typeof(StationSecurityWing).GetField("diversionRemaining", Private).GetValue(security);
                        Require(remaining > 7f, "Original diversion station earns a scanning window");
                        Capture(camera, "06-Security");
                        Place(player, new Vector3(StationSecurityWing.CenterX, 0.04f, StationSecurityWing.EntranceZ + 15.55f));
                        phase++;
                        break;
                    case 15:
                        Require(Physics.Raycast(position + Vector3.up * 0.8f, Vector3.forward, 1.5f, ~(1 << 2),
                            QueryTriggerInteraction.Ignore), "Security gate has a physical collider");
                        player.OpenInspection();
                        phase++;
                        break;
                    case 16:
                        if (GameObject.Find("SecurityGate").transform.position.y < 3.8f) return;
                        SetKeys(Key.W);
                        phase++;
                        break;
                    case 17:
                        if (position.z < StationSecurityWing.EntranceZ + 17.7f) return;
                        SetKeys();
                        Require(Room01Checkpoint.Load(Checkpoint).StationStage == 4, "Security traversal advances the route checkpoint");
                        LoadCheckpoint();
                        phase++;
                        break;
                    case 18:
                        if (player.GetInstanceID() == actorBeforeLoad) return;
                        if (position.z < StationSecurityWing.EntranceZ + 17.6f) return;
                        Require(GameObject.Find("SecurityGate").transform.position.y > 4.3f, "Security checkpoint restores beyond the released gate");
                        Require(GameObject.Find("Containment entry shutter").transform.position.y > 4.7f,
                            "Passing security opens the original specimen wing");
                        SetKeys(Key.W);
                        phase++;
                        break;
                    case 19:
                        if (position.z < 100.2f) return;
                        SetKeys();
                        Require(position.y >= -0.04f && position.y < 0.13f, "Security and specimen floors are connected");
                        CaptureAt(camera, "07-Specimens", new Vector3(16.7f, 3.35f, 101.1f), new Vector3(8.9f, 2.32f, 111.8f));
                        var terminal = GameObject.Find("EX-011 terminal reach").transform.position;
                        Place(player, new Vector3(terminal.x + 0.68f, 0.04f, terminal.z - 0.45f));
                        phase++;
                        break;
                    case 20:
                        player.OpenInspection();
                        Require(Room01Checkpoint.Load(Checkpoint).StationStage == 5, "The canonical EX-011 record unlocks the west gate");
                        var specimen = GameObject.Find("Specimen containment").transform;
                        Place(player, specimen.TransformPoint(new Vector3(-27.6f, 0.04f, 12f)));
                        phase++;
                        break;
                    case 21:
                        if (GameObject.Find("ExitBlastGate").transform.position.y < 4.25f) return;
                        SetKeys(Key.A);
                        phase++;
                        break;
                    case 22:
                        if (position.x > StationSecurityWing.CenterX + 2.5f - 30.4f) return;
                        SetKeys();
                        Require(Room01Checkpoint.Load(Checkpoint).StationStage == 6, "West specimen crossing persists");
                        LoadCheckpoint();
                        phase++;
                        break;
                    case 23:
                        if (player.GetInstanceID() == actorBeforeLoad) return;
                        if (position.x > StationSecurityWing.CenterX + 2.5f - 30.48f) return;
                        Require(GameObject.Find("ExitBlastGate").transform.position.y > 4.65f, "Specimen progress restores gate and west landing");
                        Require(GameObject.Find("Return catwalk shutter").transform.position.y > 4.6f,
                            "Clearing specimens unlocks the Station shortcut");
                        Place(player, new Vector3(-12.36f, 0.04f, 82.14f));
                        SetKeys(Key.S);
                        phase++;
                        break;
                    case 24:
                        if (position.z > 79.4f) return;
                        SetKeys();
                        Require(position.y >= -0.04f && position.y < 0.13f, "Shortcut physically joins the Station perimeter");
                        Place(player, new Vector3(-12.1f, 0.04f, 117f));
                        SetKeys(Key.A, Key.LeftShift);
                        phase++;
                        break;
                    case 25:
                        if (position.x > -25.20f) return;
                        SetKeys();
                        Require(position.y >= -0.04f && position.y < 0.13f, "Specimen gate also leads directly to the Archive");
                        PlaceForArchive(player, "Archive reach 0");
                        phase++;
                        break;
                    case 26:
                        player.OpenInspection();
                        var state = Room01Checkpoint.Load(Checkpoint);
                        Require(state.StationStage == 6 && state.ArchiveFragments == 1, "First fragment stores partial archive progress");
                        Require(Get<bool>(route, "GameplayHeld"), "A recovered shard presents a skippable memory");
                        Require(GameObject.Find("Archive memory frame").GetComponent<RawImage>().texture != null,
                            "The memory presents a still while the clip is preparing");
                        phase++;
                        break;
                    case 27:
                        var playerFrame = GameObject.Find("Memory fragments playback").GetComponent<VideoPlayer>().frame;
                        if (SystemInfo.graphicsDeviceType != GraphicsDeviceType.Null && playerFrame < 1 &&
                            Get<bool>(route, "GameplayHeld")) return;
                        Debug.Log(playerFrame >= 1 ? "ARCHIVE_MEMORY_VIDEO_DECODED" : "ARCHIVE_MEMORY_STILL_FALLBACK");
                        player.SkipStationVista();
                        LoadCheckpoint();
                        phase++;
                        break;
                    case 28:
                        if (player.GetInstanceID() == actorBeforeLoad) return;
                        Require(!Get<bool>(route, "GameplayHeld") && GameObject.Find("Shard_shard_shizuka") == null,
                            "Partial save restores the collected shard without replay");
                        PlaceForArchive(player, "Archive reach 1");
                        phase++;
                        break;
                    case 29:
                        player.OpenInspection();
                        Require(Room01Checkpoint.Load(Checkpoint).ArchiveFragments == 3, "Second memory is independently recoverable");
                        player.SkipStationVista();
                        PlaceForArchive(player, "Archive reach 2");
                        phase++;
                        break;
                    case 30:
                        player.OpenInspection();
                        Require(Room01Checkpoint.Load(Checkpoint).ArchiveFragments == 7, "Upper catwalk third memory restores the full record");
                        player.SkipStationVista();
                        PlaceForArchive(player, "Memory decoder reach");
                        phase++;
                        break;
                    case 31:
                        player.OpenInspection();
                        Require(Room01Checkpoint.Load(Checkpoint).StationStage == 7, "Decoding requires the recovered record and opens the gate");
                        CaptureAt(camera, "08-Archive", new Vector3(-30.8f, 2.32f, 114.8f), new Vector3(-35.35f, 2.26f, 111.58f));
                        Place(player, new Vector3(-35.5f, 0.04f, 129.5f));
                        phase++;
                        break;
                    case 32:
                        if (GameObject.Find("NorthExitBlastGate").transform.position.y < 4.25f) return;
                        SetKeys(Key.W);
                        phase++;
                        break;
                    case 33:
                        if (position.z < 131.41f) return;
                        SetKeys();
                        Require(Room01Checkpoint.Load(Checkpoint).StationStage == 8, "Archive exit stores the reactor approach");
                        LoadCheckpoint();
                        phase++;
                        break;
                    case 34:
                        if (player.GetInstanceID() == actorBeforeLoad || position.z < 131.5f) return;
                        Require(GameObject.Find("NorthExitBlastGate").transform.position.y > 4.66f,
                            "Archive gate and landing survive restart");
                        SetKeys(Key.W, Key.LeftShift);
                        phase++;
                        break;
                    case 35:
                        if (position.z < 147.3f) return;
                        SetKeys();
                        Require(position.y < 0.14f && position.y >= -0.08f, "Reserve conduit reaches the reactor entry balcony");
                        CaptureAt(camera, "09-Reactor", new Vector3(-34.6f, 2.25f, 148.6f), new Vector3(-35.5f, 2.9f, 172f));
                        PlaceAtBreaker(player, "East breaker reach");
                        phase++;
                        break;
                    case 36:
                        player.OpenInspection();
                        Require(Room01Checkpoint.Load(Checkpoint).ReactorBreakers == 2, "Reactor breakers accept either order");
                        Require(GameObject.Find("HydraulicBridge").transform.position.y < 1f, "One breaker keeps the bridge recessed");
                        LoadCheckpoint();
                        phase++;
                        break;
                    case 37:
                        if (player.GetInstanceID() == actorBeforeLoad || position.z < 148f) return;
                        Require(Room01Checkpoint.Load(Checkpoint).ReactorBreakers == 2, "Partial circuit power survives reload");
                        PlaceAtBreaker(player, "West breaker reach");
                        phase++;
                        break;
                    case 38:
                        player.OpenInspection();
                        Require(Room01Checkpoint.Load(Checkpoint).ReactorBreakers == 3, "Both breakers restore hydraulic power");
                        phase++;
                        break;
                    case 39:
                        if (GameObject.Find("HydraulicBridge").transform.position.y < 3.95f ||
                            GameObject.Find("NorthExitGate").transform.position.y < 8.65f) return;
                        Require(Physics.Raycast(new Vector3(-35.5f, 7.2f, 181.8f), Vector3.down, 3.5f,
                            ~(1 << 2), QueryTriggerInteraction.Ignore), "Restored hydraulic bridge is physically solid at the raised height");
                        Place(player, new Vector3(-35.5f, 4.04f, 188.6f));
                        SetKeys(Key.W);
                        phase++;
                        break;
                    case 40:
                        if (position.z < 190.44f) return;
                        SetKeys();
                        Require(Room01Checkpoint.Load(Checkpoint).StationStage == 9, "Crossing the reactor stores its exit checkpoint");
                        LoadCheckpoint();
                        phase++;
                        break;
                    case 41:
                        if (player.GetInstanceID() == actorBeforeLoad || position.z < 190.5f) return;
                        Require(GameObject.Find("HydraulicBridge").transform.position.y > 3.98f, "Reactor bridge restores on resume");
                        SetKeys(Key.W, Key.LeftShift);
                        phase++;
                        break;
                    case 42:
                        if (position.z < 202.5f) return;
                        SetKeys();
                        Require(Mathf.Abs(position.y - 4f) < 0.24f, "Walkable pressure seal connects reactor and quarantine");
                        CaptureAt(camera, "10-Quarantine", new Vector3(-38.8f, 6.1f, 208.5f), new Vector3(-35.5f, 6.4f, 220f));
                        Place(player, new Vector3(-36.9f, 4.04f, 217.06f));
                        phase++;
                        break;
                    case 43:
                        player.OpenInspection();
                        Require(Room01Checkpoint.Load(Checkpoint).StationStage == 9, "Override cannot be triggered through the catwalk floor");
                        Place(player, new Vector3(-44f, 4.06f, 209.03f));
                        SetKeys(Key.W);
                        phase++;
                        break;
                    case 44:
                        if (position.z < 215.55f) return;
                        SetKeys();
                        Require(position.y >= 7.1f && position.y <= 7.36f, "Authored west ramp is climbable to the quarantine catwalk");
                        Place(player, new Vector3(-36.9f, 7.25f, 217.06f));
                        phase++;
                        break;
                    case 45:
                        player.OpenInspection();
                        Require(Room01Checkpoint.Load(Checkpoint).StationStage == 10, "Quarantine override saves at the console");
                        LoadCheckpoint();
                        phase++;
                        break;
                    case 46:
                        if (player.GetInstanceID() == actorBeforeLoad) return;
                        var quarantine = UnityEngine.Object.FindFirstObjectByType<StationQuarantineWing>();
                        Require(Vector3.Distance(position, new Vector3(-36.9f, 7.25f, 217.06f)) < 0.22f, "Cleared quarantine restores to its safe catwalk");
                        Require(quarantine.GetComponentsInChildren<Transform>(true)
                            .Any(t => t.name == "Atmospheric extraction standpipes" && !t.gameObject.activeSelf),
                            "Cleared quarantine restores with spray disabled");
                        Place(player, new Vector3(-35.5f, 4.04f, 231.55f));
                        SetKeys(Key.W, Key.LeftShift);
                        phase++;
                        break;
                    case 47:
                        if (position.z < 243.65f) return;
                        SetKeys();
                        Require(Room01Checkpoint.Load(Checkpoint).StationStage == 11, "Quarantine and surveillance joined through a physical connector");
                        CaptureAt(camera, "11-Surveillance", new Vector3(-38f, 6.2f, 247.2f), new Vector3(-32f, 6.4f, 257f));
                        Place(player, new Vector3(-35.5f, 4.04f, 249.47f));
                        SetKeys(Key.W);
                        phase++;
                        break;
                    case 48:
                        if (position.z > 248.0f) return;
                        SetKeys();
                        Require(position.z < 247f, "Scanner contact returns to the surveillance arrival bay");
                        Place(player, new Vector3(-36.74f, 6.445f, 259.48f));
                        phase++;
                        break;
                    case 49:
                        player.OpenInspection();
                        Require(Room01Checkpoint.Load(Checkpoint).StationStage == 13, "Surveillance console can be used before the mirror");
                        LoadCheckpoint();
                        phase++;
                        break;
                    case 50:
                        if (player.GetInstanceID() == actorBeforeLoad) return;
                        Require(Vector3.Distance(position, new Vector3(-37.70f, 6.445f, 259.48f)) < 0.22f,
                            "Partial surveillance progress resumes on the command dais");
                        var exitGate = GameObject.Find("SurveillanceExitGate");
                        Require(exitGate.transform.position.y < 5.68f, "Grid shutdown alone keeps the north gate shut");
                        Place(player, new Vector3(-28.8f, 4.045f, 252f));
                        typeof(Room01Player).GetField("viewYaw", Private).SetValue(player, 90f);
                        phase++;
                        break;
                    case 51:
                        player.OpenInspection();
                        Require(Room01Checkpoint.Load(Checkpoint).StationStage == 14, "Mirror inspection lifts the final interlock");
                        phase++;
                        break;
                    case 52:
                        if (GameObject.Find("SurveillanceExitGate").transform.position.y < 8.0f) return;
                        if (SystemInfo.graphicsDeviceType != GraphicsDeviceType.Null)
                        {
                            var mirror = GameObject.Find("Live two-way inspection mirror").GetComponent<MeshRenderer>();
                            var reflectionState = new MaterialPropertyBlock();
                            mirror.GetPropertyBlock(reflectionState);
                            if (reflectionState.GetFloat("_ReflectionReady") < 0.5f) return;
                            Require(reflectionState.GetTexture("_ReflectionMap") is RenderTexture, "The live mirror rendered a planar color target");
                        }
                        Capture(camera, "12-InspectionMirror");
                        typeof(Room01Player).GetField("viewYaw", Private).SetValue(player, 0f);
                        Place(player, new Vector3(-35.5f, 4.04f, 276.65f));
                        SetKeys(Key.W);
                        phase++;
                        break;
                    case 53:
                        if (position.z < 278.58f) return;
                        SetKeys();
                        Require(Room01Checkpoint.Load(Checkpoint).StationStage == 15, "Walking through surveillance saves the examination landing");
                        LoadCheckpoint();
                        phase++;
                        break;
                    case 54:
                        if (player.GetInstanceID() == actorBeforeLoad) return;
                        Require(Vector3.Distance(position, new Vector3(-35.5f, 4.045f, 279.45f)) < 0.24f,
                            "Examination landing is a safe reload point");
                        Debug.Log($"ECHO_STATION_PASS {checks} checks");
                        Finish(0);
                        break;
                }
            }
            catch (Exception error)
            {
                Debug.LogError($"Station phase {phase}, checks {checks}");
                Debug.LogException(error);
                Finish(1);
            }
        }

        private static void PlaceAtBreaker(Room01Player player, string name)
        {
            var target = GameObject.Find(name).transform.position;
            Place(player, new Vector3(target.x + 0.28f, target.y - 0.81f, target.z - 0.63f));
        }

        private static void PlaceForArchive(Room01Player player, string name)
        {
            var target = GameObject.Find(name).transform.position;
            var feet = target.y > 3f ? 3.645f : 0.043f;
            Place(player, new Vector3(target.x + 0.33f, feet, target.z - 0.32f));
        }

        private static void LoadCheckpoint()
        {
            actorBeforeLoad = UnityEngine.Object.FindFirstObjectByType<Room01Player>().GetInstanceID();
            var session = typeof(Room01Player).Assembly.GetType("ElevenEleven.Opening.ChapterSaveSession", true);
            session.GetMethod("SetRestore", BindingFlags.NonPublic | BindingFlags.Static)
                .Invoke(null, new object[] { Room01Checkpoint.Load(Checkpoint) });
            SceneManager.LoadScene("ChapterRoom01");
        }

        private static void Place(Room01Player player, Vector3 position)
        {
            typeof(Room01Player).GetMethod("Place", Private).Invoke(player, new object[] { position });
            Physics.SyncTransforms();
        }

        private static T Get<T>(StormworksRoute route, string property) =>
            (T)typeof(StormworksRoute).GetProperty(property, Private).GetValue(route);

        private static void SetKeys(params Key[] keys)
        {
            InputSystem.QueueStateEvent(keyboard, new KeyboardState(keys));
        }

        private static void CaptureAt(Camera camera, string name, Vector3 at, Vector3 focus)
        {
            var position = camera.transform.position;
            var rotation = camera.transform.rotation;
            try
            {
                camera.transform.SetPositionAndRotation(at, Quaternion.LookRotation(focus - at));
                Capture(camera, name);
            }
            finally
            {
                camera.transform.SetPositionAndRotation(position, rotation);
            }
        }

        private static void Capture(Camera camera, string name)
        {
            var destination = Environment.GetEnvironmentVariable("ECHO_STATION_CAPTURE");
            if (string.IsNullOrEmpty(destination) || SystemInfo.graphicsDeviceType == GraphicsDeviceType.Null) return;
            var prefix = Environment.GetEnvironmentVariable("ECHO_STATION_CAPTURE_MINIMUM");
            if (int.TryParse(prefix, out var first) && int.TryParse(name.Split('-')[0], out var current) && current < first)
                return;
            Directory.CreateDirectory(destination);
            var target = RenderTexture.GetTemporary(1280, 720, 24, RenderTextureFormat.ARGB32);
            var before = RenderTexture.active;
            var image = new Texture2D(target.width, target.height, TextureFormat.RGB24, false);
            try
            {
                var request = new UniversalRenderPipeline.SingleCameraRequest { destination = target };
                Require(RenderPipeline.SupportsRenderRequest(camera, request), "URP direct capture supported");
                RenderPipeline.SubmitRenderRequest(camera, request);
                RenderTexture.active = target;
                image.ReadPixels(new Rect(0, 0, image.width, image.height), 0, 0);
                image.Apply();
                File.WriteAllBytes(Path.Combine(destination, name + ".png"), image.EncodeToPNG());
            }
            finally
            {
                RenderTexture.active = before;
                RenderTexture.ReleaseTemporary(target);
                UnityEngine.Object.DestroyImmediate(image);
            }
        }

        private static void Require(bool condition, string label)
        {
            if (!condition) throw new InvalidOperationException(label);
            checks++;
            Debug.Log("STATION_CHECK " + label);
        }

        private static void Finish(int code)
        {
            EditorApplication.update -= Advance;
            SessionState.EraseBool(Running);
            EditorApplication.Exit(code);
        }
    }
}

