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
        private const int SchoolJumpSettlePhase = 1700;
        private static int phase;
        private static int checks;
        private static AsyncOperation reload;
        private static int lastPhase = -1;
        private static double timeout;
        private static Keyboard keyboard;
        private static float peak;
        private static bool sprintSeen;
        private static float jumpLaunchHeight;
        private static float jumpApexHeight;
        private static float lastJumpSample;
        private static int schoolJumpFlightFrames;
        private static Quaternion jumpTakeoffShin;
        private static Transform jumpShin;
        private static bool jumpKneeMoved;
        private static string jumpBeforeJson;
        private static bool jumpPreviousReducedMotion;
        private static Vector3 revealStart;
        private static bool observatoryPriorReducedMotion;
        private static Quaternion initialClockRotation;
        private static Vector4 initialClockDots;
        private static Vector3[] initialObservatoryDrift;
        private static string Fixture => Environment.GetEnvironmentVariable("ECHO_R02_FIXTURE_DIRECTORY");
        private static bool ExaminationOnly => Environment.GetEnvironmentVariable("ECHO_EXAMINATION_ONLY") == "1";
        private static bool connected;
        private static bool ExercisePact => connected || Environment.GetEnvironmentVariable("ECHO_STATION_PACT") == "1";
        private static bool ProveSchoolJump => Environment.GetEnvironmentVariable("ECHO_STATION_SCHOOL_JUMP") == "1";
        private static string Checkpoint => Path.Combine(Fixture, "system_opening_v1.json");

        static StormworksSmoke()
        {
            if (SessionState.GetBool(Running, false)) EditorApplication.update += Advance;
        }

        public static void RebuildAndRun()
        {
            if (Environment.GetEnvironmentVariable("ECHO_STATION_REBUILD_OPENING") == "1")
                ChapterSceneBuilder.RebuildEntry();
            StormworksConstruction.Upgrade();
            Run();
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

        internal static void ContinueFromGate()
        {
            connected = true;
            EditorApplication.update += Advance;
        }

        private static void Advance()
        {
            try
            {
                if (!EditorApplication.isPlaying) return;
                if (lastPhase != phase)
                {
                    lastPhase = phase;
                    timeout = EditorApplication.timeSinceStartup + 90;
                }

                if (EditorApplication.timeSinceStartup > timeout)
                    throw new TimeoutException($"Station phase {phase} in {SceneManager.GetActiveScene().name}");
                if (reload != null)
                {
                    if (!reload.isDone) return;
                    reload = null;
                }
                if (connected && phase == 106)
                {
                    var entry = GameObject.Find("Chapter entry")?.GetComponent<Button>();
                    if (entry == null || !entry.interactable) return;
                    Require(entry.GetComponentInChildren<Text>().text is "Continue" or "ﺔﻌﺑﺎﺘﻣ",
                        "The ordinary title entry offers Continue after chapter clear");
                    entry.onClick.Invoke();
                    phase = 101;
                    return;
                }

                var player = UnityEngine.Object.FindFirstObjectByType<Room01Player>();
                if (player == null) return;
                if (Environment.GetEnvironmentVariable("ECHO_STATION_ROOM_MOTION") == "1" && !ChapterRoomMotionReview.Step(player)) return;
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
                        var wardSeed = Environment.GetEnvironmentVariable("ECHO_STATION_WARD_SEED");
                        if (!connected && !string.IsNullOrEmpty(wardSeed))
                        {
                            File.Copy(wardSeed, Checkpoint, true);
                            Require(PactBeat() == 7 && KinjaProgress() == 5 && WardProgress() == 1,
                                "Mirror review uses a verified awake ward checkpoint");
                            LoadCheckpoint();
                            phase = 98;
                            break;
                        }
                        var pactSeed = Environment.GetEnvironmentVariable("ECHO_STATION_PACT_SEED");
                        if (!connected && !string.IsNullOrEmpty(pactSeed))
                        {
                            File.Copy(pactSeed, Checkpoint, true);
                            Require(PactBeat() == 7 && KinjaProgress() == 0, "The dedicated fixture starts from a saved Pact72 before facing Kinja");
                            LoadCheckpoint();
                            phase = 84;
                            break;
                        }
                        Require(route != null && camera != null, "Normal Room 01 scene owns the extension and camera");
                        Require(camera.GetUniversalAdditionalCameraData().renderPostProcessing, "URP scene grade active");
                        Require(!GameObject.Find("Next corridor bulkhead"), "Old dead end is open");
                        Require(GameObject.Find("Hydraulic pressure governor")?.GetComponentInChildren<MeshRenderer>() != null,
                            "Optimized pressure governor is imported into the live room");
                        if (!connected && ExaminationOnly)
                        {
                            File.WriteAllText(Checkpoint, SessionState.GetString(Running + ".Legacy", ""));
                            var initial = Room01Checkpoint.Load(Checkpoint);
                            initial.StationStage = 14;
                            initial.ArchiveFragments = 7;
                            initial.ReactorBreakers = 3;
                            initial.ExaminationCompleted = true;
                            Require(!initial.Save(Checkpoint), "A checkpoint cannot skip surveillance to complete the examination");
                            initial.ExaminationCompleted = false;
                            initial.StationStage = 15;
                            Require(initial.Save(Checkpoint), "A scoped fixture can resume at the surveillance landing");
                            File.WriteAllText(Checkpoint, File.ReadAllText(Checkpoint).Replace(",\"examination\":false", ""));
                            Require(Room01Checkpoint.Load(Checkpoint)?.ExaminationCompleted == false, "Prior station saves have no examination progress");
                            ChapterSceneLink.ReducedMotion = true;
                            ChapterSceneLink.Muted = true;
                            LoadCheckpoint();
                            phase = 54;
                            break;
                        }
                        Capture(camera, "01-Containment");
                        if (!connected)
                        {
                            File.WriteAllText(Checkpoint, SessionState.GetString(Running + ".Legacy", ""));
                            LoadCheckpoint();
                        }
                        phase++;
                        break;
                    case 1:
                        if (position.z < 19f) return;
                        Require(UnityEngine.Object.FindFirstObjectByType<Room01Gate>().IsOpen, "The original gate is open at the start of the station route");
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
                        CaptureRoomView(player, camera, "72-Pressure-VentedPass", "already on the vented pressure pass");
                        Capture(camera, "02-Pressure");
                        phase++;
                        break;
                    case 4:
                        if (R40Review && !ventCueVerified)
                        {
                            var ventIndicator = GameObject.Find("Pressure vent state");
                            var lamp = ventIndicator.GetComponentInChildren<Light>();
                            ventCueVerified = lamp.color.r > .9f && lamp.color.g > .55f &&
                                ventIndicator.transform.Find("Vent time lens").gameObject.activeSelf;
                            if (ventCueVerified)
                                CaptureAt(camera, "90-Pressure-Vent-Readout", new Vector3(-.69f,1.53f,23.39f),
                                    new Vector3(-2.19f,1.39f,24.65f));
                        }
                        if (position.z < 27f) return;
                        if (R40Review) Require(ventCueVerified,
                            "Actual valve interaction exposes the live vent state and remaining time");
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
                        CaptureRoomView(player, camera, "73-Observatory-Bridge", "bridge after the vista releases input");
                        Capture(camera, "04-ServicePlatforms");
                        // Keep the input test independent of a cold native capture's render hitch.
                        Time.captureDeltaTime = 1f / 50f;
                        sprintSeen = false;
                        if (ProveSchoolJump)
                        {
                            jumpPreviousReducedMotion = ChapterSceneLink.ReducedMotion;
                            ChapterSceneLink.ReducedMotion = Environment.GetEnvironmentVariable("ECHO_STATION_JUMP_REDUCED") == "1";
                            var configuredHz = Environment.GetEnvironmentVariable("ECHO_STATION_JUMP_HZ");
                            if (!string.IsNullOrEmpty(configuredHz))
                            {
                                var hz = int.Parse(configuredHz);
                                if (hz != 30 && hz != 60) throw new InvalidOperationException("Jump proof accepts 30 or 60 Hz.");
                                Time.captureDeltaTime = 1f / hz;
                            }
                            jumpBeforeJson = File.ReadAllText(Checkpoint);
                            Require(HasSchool(player) && PactBeat() == 0 && Room01Checkpoint.Load(Checkpoint).StationStage == 1,
                                "School jump starts before pact and with the pressure crossing checkpoint");
                        }
                        SetKeys(Key.A, Key.LeftShift);
                        phase = 70;
                        break;
                    case 70:
                        var running = player.GetComponentInChildren<Animation>().IsPlaying("Run");
                        sprintSeen |= running;
                        if (position.x > -2.35f) return;
                        Require(sprintSeen, "Sprint uses remapped School65 Run");
                        if (!player.GetComponent<CharacterController>().isGrounded)
                            throw new InvalidOperationException($"Jump input reached phase 70 after leaving the bridge at {position}.");
                        if (ProveSchoolJump)
                        {
                            jumpLaunchHeight = jumpApexHeight = position.y;
                            lastJumpSample = 24f / 30f - 0.001f;
                            schoolJumpFlightFrames = 0;
                            jumpKneeMoved = false;
                            jumpShin = SchoolJumpMotion(player).GetComponentsInChildren<Transform>(true)
                                .Single(joint => joint.name.EndsWith(":LeftLeg", StringComparison.Ordinal));
                        }
                        SetKeys(Key.A, Key.LeftShift, Key.Space);
                        phase = 8;
                        break;
                    case 8:
                        if (position.z < 50f) throw new InvalidOperationException($"Jump missed; returned from peak {peak:0.00} m.");
                        peak = Mathf.Max(peak, position.y);
                        if (ProveSchoolJump) SampleSchoolJumpPhysics(player);
                        if (position.x > -4.17f) return;
                        SetKeys();
                        phase++;
                        break;
                    case 9:
                        if (!player.GetComponent<CharacterController>().isGrounded)
                        {
                            if (ProveSchoolJump) SampleSchoolJumpPhysics(player);
                            return;
                        }
                        Require(position.x < -3.72f && position.y > 0.30f && peak > 0.85f, "Jump input reaches the first suspended plate");
                        if (ProveSchoolJump)
                        {
                            var jump = SchoolJumpMotion(player);
                            Require(jump.IsPlaying("Jump") && Mathf.Abs(jump["Jump"].time - 42f / 30f) < 0.04f,
                                "Capsule contact selects the authored landing pose");
                            Require(schoolJumpFlightFrames >= 8 && jumpKneeMoved &&
                                    jumpApexHeight - jumpLaunchHeight >= 0.95f && jumpApexHeight - jumpLaunchHeight <= 1.40f,
                                "The school body articulates in flight while the original capsule arc reaches the platform");
                            Capture(camera, "04B-SchoolJump-Landing");
                            phase = SchoolJumpSettlePhase;
                            break;
                        }
                        goto case SchoolJumpSettlePhase;
                    case SchoolJumpSettlePhase:
                        if (ProveSchoolJump)
                        {
                            var motion = SchoolJumpMotion(player);
                            if (motion.IsPlaying("Jump")) return;
                            Require(player.GetComponent<CharacterController>().isGrounded && HasSchool(player) && PactBeat() == 0 &&
                                    File.ReadAllText(Checkpoint) == jumpBeforeJson,
                                "The school landing returns to ground locomotion with the same save and pact authority");
                            Debug.Log(FormattableString.Invariant($"SCHOOL_JUMP_PHYSICS_PASS frames={schoolJumpFlightFrames} clearance_m={jumpApexHeight - jumpLaunchHeight:F4} reduced={ChapterSceneLink.ReducedMotion}"));
                            ChapterSceneLink.ReducedMotion = jumpPreviousReducedMotion;
                        }
                        Time.captureDeltaTime = 0f;
                        Place(player, new Vector3(-15f, 0.04f, 50.07f));
                        SetKeys(Key.W);
                        phase = 10;
                        break;
                    case 10:
                        if (position.z < 55.6f) return;
                        SetKeys();
                        Require(position.y > 0.9f, "Alternate stair route reaches relay on foot");
                        CaptureRoomView(player, camera, "74-Relay-StairApproach", "relay stair approach before activation");
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
                        CaptureRoomView(player, camera, "75-MemoryLab-LogApproach", "inside the memory lab before logging");
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
                        if (Environment.GetEnvironmentVariable("ECHO_STATION_VISTA_ONLY") == "1")
                        {
                            CaptureAt(camera, "06-Relay-Approach", new Vector3(-11.7f, 2.9f, 49.8f),
                                new Vector3(-15.1f, 1.42f, 56.9f));
                            if (Environment.GetEnvironmentVariable("ECHO_CHRONOSTAT_DETAIL") == "1")
                            {
                                var finish = GameObject.Find("Rebuilt station infrastructure");
                                Require(finish != null && finish.GetComponentsInChildren<Transform>()
                                    .Count(item => item.name == "Tripo observation pylon cladding") == 4,
                                    "Both gantries use four instances of the qualified Tripo pylon");
                                if (Environment.GetEnvironmentVariable("ECHO_STATION_FIELDS") == "1")
                                {
                                    var water = GameObject.Find("Boat Attack reservoir surface");
                                    var liveSparks = GameObject.Find("Relay housing sparks").GetComponent<ParticleSystem>();
                                    Require(water.GetComponent<MeshRenderer>().sharedMaterial.shader.name == "ElevenEleven/Station Reservoir" &&
                                        water.GetComponent<MeshFilter>().sharedMesh.vertexCount > 10000,
                                        "The Boat Attack Gerstner shader owns the tessellated basin");
                                    Require(liveSparks.emission.enabled, "Relay sparks are enabled after the restored station powers up");
                                }
                                CaptureAt(camera, "07-Chronostat-Detail", new Vector3(-0.92f, 3.35f, 63.2f),
                                    new Vector3(0f, 12.6f, 82.2f));
                                CaptureAt(camera, "08-Memory-Lab-Facade", new Vector3(12.1f, 2.71f, 56.8f),
                                    new Vector3(15f, 2.25f, 63.0f));
                            }
                            if (Environment.GetEnvironmentVariable("ECHO_OBSERVATORY_DETAIL") == "1")
                            {
                                var observatory = GameObject.Find("Memory Observatory");
                                Require(observatory != null && observatory.GetComponent<StationMemoryObservatory>() != null,
                                    "Memory Observatory is present in the live Room 01 scene");
                                var gyro = observatory.transform.Find("Floating gimbal drift pivot");
                                var projection = observatory.transform.Find("School memory shard/Projected memory image");
                                Require(gyro?.GetComponentInChildren<MeshRenderer>() != null &&
                                    projection?.GetComponent<MeshRenderer>().sharedMaterial.GetTexture("_Memory") != null,
                                    "The flying gyroscope and a memory projection use real imported assets");
                                Require(observatory.transform.Find("Deep star field").GetComponent<Renderer>().enabled,
                                    "The station camera enables the observatory star field");
                                observatoryPriorReducedMotion = ChapterSceneLink.ReducedMotion;
                                ChapterSceneLink.ReducedMotion = false;
                                revealStart = gyro.localPosition;
                                if (Environment.GetEnvironmentVariable("ECHO_ENTRANCE_DETAIL") == "1")
                                {
                                    var runtime = observatory.GetComponent<StationMemoryObservatory>();
                                    initialClockRotation = GetObservatoryField<Transform>(runtime,"clockRotor").localRotation;
                                    initialClockDots = ReadClockDots(GetObservatoryField<Renderer>(runtime,"clockReadout"));
                                    initialObservatoryDrift = GetObservatoryField<Transform[]>(runtime,"driftingMemories")
                                        .Select(item => item.localPosition).ToArray();
                                    CaptureAt(camera,"15-Clock-First",new Vector3(2.1f,6.2f,58.8f),new Vector3(0,13.5f,81f));
                                }
                                phase = 108;
                                break;
                            }
                            Debug.Log($"ECHO_STATION_VISTA_PASS {checks} checks");
                            Finish(0);
                            break;
                        }
                        Place(player, new Vector3(StationSecurityWing.CenterX - 3.36f, 0.046f, StationSecurityWing.EntranceZ + 1.67f));
                        phase++;
                        break;
                    case 108:
                    {
                        var gyro = GameObject.Find("Floating gimbal drift pivot").transform;
                        if (Vector3.Distance(gyro.localPosition, revealStart) < .055f) return;
                        var entrances = Environment.GetEnvironmentVariable("ECHO_ENTRANCE_DETAIL") == "1";
                        if (entrances)
                        {
                            var runtime = GameObject.Find("Memory Observatory").GetComponent<StationMemoryObservatory>();
                            var angle = Quaternion.Angle(initialClockRotation,GetObservatoryField<Transform>(runtime,"clockRotor").localRotation);
                            var dots = ReadClockDots(GetObservatoryField<Renderer>(runtime,"clockReadout"));
                            if (angle < 4.2f || Mathf.Abs(dots.x-initialClockDots.x) < .17f) return;
                            Require((dots.x-initialClockDots.x)*(dots.y-initialClockDots.y)<0f,
                                "The two hour separator lights pulse in opposite phases as the clock rotates");
                            var drifting = GetObservatoryField<Transform[]>(runtime,"driftingMemories");
                            Require(drifting.Length >= 5 && drifting.Select((item,index) =>
                                (item.localPosition-initialObservatoryDrift[index]).sqrMagnitude > .001f).All(moved => moved),
                                "The memory shards and both groups of floating slate drift in live play");
                            Debug.Log($"ECHO_OBSERVATORY_CLOCK_DELTA {angle:0.00} deg; upper {initialClockDots.x:0.00} to {dots.x:0.00}; lower {initialClockDots.y:0.00} to {dots.y:0.00}");
                            CaptureAt(camera,"16-Clock-Second",new Vector3(2.1f,6.2f,58.8f),new Vector3(0,13.5f,81f));
                        }
                        Require(true, "The suspended gimbal moves during live play");
                        CaptureAt(camera, "07-Observatory-Floating-Memories", new Vector3(-0.4f, 3.6f, 42.4f),
                            new Vector3(-3.4f, 10.6f, 61f));
                        CaptureAt(camera, "08-Observatory-Archive", new Vector3(11.4f, 2.5f, 55.7f),
                            new Vector3(15.4f, 3.45f, 63.2f));
                        if (Environment.GetEnvironmentVariable("ECHO_CATWALK_DETAIL") == "1")
                        {
                            var catwalk = GameObject.Find("Fitted Tripo catwalk");
                            Require(catwalk != null && catwalk.GetComponentsInChildren<MeshRenderer>().Length == 8,
                                "The Tripo catwalk covers the seven original bridge bays and the lab branch");
                            Require(Physics.Raycast(new Vector3(-1.6f,.6f,47f),Vector3.left,out var guard,1.95f) &&
                                guard.collider.transform.IsChildOf(catwalk.transform),
                                "A regular bridge bay has a physical safety rail");
                            Require(!Physics.Raycast(new Vector3(-1.6f,.6f,51.7f),Vector3.left,1.95f) &&
                                !Physics.Raycast(new Vector3(1.6f,.6f,62.65f),Vector3.right,1.95f),
                                "The service jump and lab access both have open rail gaps");
                            CaptureAt(camera,"09-Observatory-Catwalk", new Vector3(.68f,1.70f,42.7f),
                                new Vector3(.40f,3.1f,65.7f));
                            CaptureAt(camera,"10-Observatory-Workshop", new Vector3(-9.7f,2.65f,50.7f),
                                new Vector3(-17.65f,2.9f,58.65f));
                        }
                        if (entrances)
                        {
                            var art = GameObject.Find("Rebuilt station entrances").transform;
                            Require(art.Find("East memory laboratory entrance/Carved archive facade") != null &&
                                art.Find("West relay workshop entrance/Recessed relay and furnace shelter") != null,
                                "Both entrances render the new fitted PBR structures");
                            Require(GameObject.Find("Lab isolation shutter").transform.Find("Tripo moving shutter cladding") != null,
                                "The new laboratory face follows the real moving shutter");
                            var lateral = GameObject.Find("Fitted lateral catwalks").transform;
                            var central = GameObject.Find("Central catwalk bay 1").GetComponent<MeshRenderer>().sharedMaterial;
                            Require(lateral.Find("West service catwalk").GetComponentsInChildren<MeshRenderer>().All(x => x.sharedMaterial == central) &&
                                lateral.Find("East observation catwalk").GetComponentsInChildren<MeshRenderer>().All(x => x.sharedMaterial == central),
                                "Both side catwalks use the same materials as the main steel bridge");
                            Require(!Physics.Raycast(new Vector3(-1.4f,.6f,65f),Vector3.left,2.25f) &&
                                !Physics.Raycast(new Vector3(1.6f,.6f,40f),Vector3.right,1.95f),
                                "The north relay connector and first right branch both have open joins");
                            CaptureAt(camera,"11-East-Lab-Entrance",new Vector3(12.5f,2.21f,55.7f),new Vector3(15.4f,3.51f,63.3f));
                            CaptureAt(camera,"12-West-Relay-Entrance",new Vector3(-12.95f,2.34f,49.72f),new Vector3(-17.1f,3.08f,57.9f));
                            CaptureAt(camera,"13-East-Branch",new Vector3(15.34f,1.72f,43.7f),new Vector3(15f,2.70f,62f));
                            CaptureAt(camera,"14-West-Branch",new Vector3(-15.24f,1.72f,41.7f),new Vector3(-15.7f,2.72f,56f));
                        }
                        ChapterSceneLink.ReducedMotion = observatoryPriorReducedMotion;
                        Debug.Log($"ECHO_STATION_VISTA_PASS {checks} checks");
                        Finish(0);
                        break;
                    }
                    case 14:
                        CaptureRoomView(player, camera, "76-Security-Diversion", "security arrival before activating the diversion");
                        player.OpenInspection();
                        var security = UnityEngine.Object.FindFirstObjectByType<StationSecurityWing>();
                        var remaining = (float)typeof(StationSecurityWing).GetField("diversionRemaining", Private).GetValue(security);
                        Require(remaining > 7f, "Original diversion station earns a scanning window");
                        Capture(camera, "06-Security");
                        if (security.transform.Find("Station wing finish") != null)
                        {
                            var observatory = GameObject.Find("Memory Observatory").transform;
                            Require(MemoryObservatoryArt.SecurityEnvelopeIsClear(observatory),
                                "Observatory scenery stays outside the security corridor");
                            CaptureAt(camera, "06B-Security-Lane", new Vector3(15.1f, 1.72f, 81.45f),
                                new Vector3(17.23f, 1.91f, 94.9f));
                        }
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
                        CaptureRoomView(player, camera, "77-Specimen-EX011", "checked EX-011 terminal approach");
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
                        CaptureRoomView(player, camera, "78-Archive-Decoder", "checked archive decoder approach");
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
                        if (position.z < 131.5f) return;
                        Require(GameObject.Find("NorthExitBlastGate").transform.position.y > 4.66f,
                            "Archive gate and landing survive restart");
                        SetKeys(Key.W, Key.LeftShift);
                        phase++;
                        break;
                    case 35:
                        if (position.z < 147.3f) return;
                        SetKeys();
                        Require(position.y < 0.14f && position.y >= -0.08f, "Reserve conduit reaches the reactor entry balcony");
                        CaptureRoomView(player, camera, "79-Reactor-EntryBalcony", "reactor entry balcony");
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
                        if (position.z < 148f) return;
                        Require(Room01Checkpoint.Load(Checkpoint).ReactorBreakers == 2, "Partial circuit power survives reload");
                        if (R40Review)
                        {
                            if (!CueIsReady("East breaker's bus state")) return;
                            Require(!CueIsReady("West breaker's bus state"),
                                "Restoring one breaker lights only its physical bus indicator");
                        }
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
                        if (R40Review)
                        {
                            Require(CueIsReady("East breaker's bus state") && CueIsReady("West breaker's bus state"),
                                "The two reactor indicators turn green with actual hydraulic restoration");
                            CaptureAt(camera, "91-Reactor-Breaker-Readout", new Vector3(-45.19f,3.1f,161.3f),
                                new Vector3(-47.98f,3.65f,162f));
                        }
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
                        if (position.z < 190.5f) return;
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
                        CaptureRoomView(player, camera, "80-Quarantine-UpperCatwalk", "upper catwalk beside the override before activation");
                        player.OpenInspection();
                        Require(Room01Checkpoint.Load(Checkpoint).StationStage == 10, "Quarantine override saves at the console");
                        LoadCheckpoint();
                        phase++;
                        break;
                    case 46:
                        var quarantine = UnityEngine.Object.FindFirstObjectByType<StationQuarantineWing>();
                        Require(Vector3.Distance(position, new Vector3(-36.9f, 7.25f, 217.06f)) < 0.22f, "Cleared quarantine restores to its safe catwalk");
                        if (R40Review)
                        {
                            if (!CueIsReady("Quarantine extraction state")) return;
                            Require(CueIsReady("Quarantine extraction state"),
                                "The quarantine indicator restores clear after the actual console override");
                            CaptureAt(camera, "92-Quarantine-Override-Readout", new Vector3(-36.8f,7.35f,215.35f),
                                new Vector3(-35.77f,8.1f,216.9f));
                        }
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
                        if (SurveillanceApproachReview)
                        {
                            var bay = UnityEngine.Object.FindFirstObjectByType<StationSurveillanceWing>();
                            Require(bay, "The playable surveillance wing is loaded");
                            FollowView(player, camera, bay.transform, "93-Surveillance-Arrival", new Vector3(.05f, .045f, 6.7f), 0f, 13f);
                            FollowView(player, camera, bay.transform, "94-Surveillance-Side-Aisle", new Vector3(5.24f, .045f, 8.4f), -17f, 13f);
                            FollowView(player, camera, bay.transform, "95-Surveillance-Approach-Emitter", new Vector3(4.41f, .045f, 7.25f), -29f, 19f);
                            FollowView(player, camera, bay.transform, "96-Surveillance-Reduced-Motion", new Vector3(.05f, .045f, 6.7f), 0f, 13f, true);
                            if (Environment.GetEnvironmentVariable("ECHO_R41_EXPECT_FIT") == "1")
                            {
                                var guides = bay.transform.Find("Surveillance scanner gallery/Fitted surveillance approach guides");
                                Require(guides && guides.childCount == 16, "Both walkable aisles have inset guides at the four scanner crossings");
                                Require(bay.GetComponentsInChildren<Transform>(true).Count(t => t.name == "Flush deck flange") == 8,
                                    "Each scanner endpoint has a floor-mounted flange");
                                Require(bay.GetComponentsInChildren<Transform>(false).Count(t => t.name == "Crossing limit inlay") == 8,
                                    "Live amber limits are visible at each scanner endpoint");
                            }
                        }
                        CaptureAt(camera, "11-Surveillance", new Vector3(-38f, 6.2f, 247.2f), new Vector3(-32f, 6.4f, 257f));
                        Place(player, new Vector3(-35.5f, 4.04f, 249.47f));
                        SetKeys(Key.W);
                        phase++;
                        break;
                    case 48:
                        if (position.z > 248.0f) return;
                        SetKeys();
                        Require(position.z < 247f, "Scanner contact returns to the surveillance arrival bay");
                        CaptureRoomView(player, camera, "81-Surveillance-RecoveryAisle", "playable surveillance bay after scanner recovery");
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
                        Require(Vector3.Distance(position, new Vector3(-37.70f, 6.445f, 259.48f)) < 0.22f,
                            "Partial surveillance progress resumes on the command dais");
                        if (R40Review)
                        {
                            if (!CueIsReady("Surveillance discharge authorization")) return;
                            Require(!GameObject.Find("Surveillance scanner grid"),
                                "The mechanical command terminal displays the restored scanner shutdown");
                        }
                        if (SurveillanceApproachReview)
                        {
                            var bay = UnityEngine.Object.FindFirstObjectByType<StationSurveillanceWing>();
                            FollowView(player, camera, bay.transform, "97-Surveillance-After-Reload", new Vector3(.05f, .045f, 6.7f), 0f, 13f);
                            if (Environment.GetEnvironmentVariable("ECHO_R41_EXPECT_FIT") == "1")
                            {
                                Require(!bay.GetComponentsInChildren<Transform>(false).Any(t => t.name == "Crossing limit inlay"),
                                    "Amber crossing limits stay off after resuming scanner shutdown");
                                Require(bay.transform.Find("Surveillance scanner gallery/Fitted surveillance approach guides").gameObject.activeInHierarchy,
                                    "Nonhazard aisle guides remain visible after resuming shutdown");
                            }
                        }
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
                        CaptureRoomView(player, camera, "82-InspectionMirror-Interlock", "live reflection after unlocking the interlock");
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
                        Require(Vector3.Distance(position, new Vector3(-35.5f, 4.045f, 279.45f)) < 0.24f,
                            "Examination landing is a safe reload point");
                        typeof(Room01Player).GetField("viewYaw", Private).SetValue(player, 0f);
                        SetKeys(Key.W);
                        phase++;
                        break;
                    case 55:
                        if (position.z < 298.45f) return;
                        Require(Mathf.Abs(position.x + 35.5f) < 0.15f && position.y > 5.18f,
                            "Walking from the landing crosses the entrance and climbs the examination ramp");
                        CaptureRoomView(player, camera, "83-ExaminationTheatre-RampArrival", "theatre ramp arrival before dialogue");
                        SetKeys(Key.D);
                        phase++;
                        break;
                    case 56:
                        if (position.x < -33.05f) return;
                        SetKeys(Key.E);
                        phase++;
                        break;
                    case 57:
                        if (!GameObject.Find("Examination dialogue")) return;
                        SetKeys();
                        Require(!Room01Checkpoint.Load(Checkpoint).ExaminationCompleted, "Starting Kinja's dialogue commits no progress");
                        revealStart = position;
                        SetKeys(Key.W);
                        phase++;
                        break;
                    case 58:
                        Require(Vector3.Distance(position, revealStart) < 0.02f, "Examination dialogue holds locomotion");
                        CaptureLabUi(camera, "13-Kinja-Dialogue");
                        SetKeys(Key.Escape);
                        phase++;
                        break;
                    case 59:
                        if (GameObject.Find("Examination dialogue")) return;
                        Require(Vector3.Distance(position, new Vector3(-35.5f, 4.045f, 279.45f)) < 0.24f,
                            "Cancel returns to the landing without committing examination");
                        Require(!Room01Checkpoint.Load(Checkpoint).ExaminationCompleted, "Cancelled examination is retryable");
                        Place(player, new Vector3(-33f, 5.245f, 299.3f));
                        SetKeys(Key.E);
                        phase++;
                        break;
                    case 60:
                        if (!GameObject.Find("Examination dialogue")) return;
                        SetKeys();
                        for (var line = 0; line < 5; line++) Click("Continue examination");
                        Require(!GameObject.Find("Examination dialogue"), "Five lines hand control back for the two memories");
                        var kinja = GameObject.Find("Kinja");
                        Require(kinja.GetComponentInChildren<SkinnedMeshRenderer>() != null, "The Godot Kinja rig is visible in the theatre");
                        CaptureAt(camera, "14-Examination-Theatre", new Vector3(-29.7f, 8.05f, 291.7f),
                            new Vector3(-35.5f, 5.9f, 302f));
                        Place(player, GameObject.Find("Neural overload record").transform.position);
                        player.OpenInspection();
                        Require(GameObject.Find("Archive memory frame"), "The overload screen opens a replay without collecting a memory");
                        player.SkipStationVista();
                        Place(player, GameObject.Find("Repeat trial record").transform.position);
                        player.OpenInspection();
                        Require(GameObject.Find("Archive memory frame"), "The repeat test screen provides a second independent replay");
                        player.SkipStationVista();
                        Place(player, new Vector3(-31.4f, 5.245f, 303.23f));
                        SetKeys(Key.E);
                        phase++;
                        break;
                    case 61:
                        if (!GameObject.Find("Manhwa memory")) return;
                        SetKeys();
                        var memory = GameObject.Find("Manhwa memory").GetComponent<RawImage>();
                        Require(memory.texture.name == "Yuki-PDF041", "Yuki can be examined first using the approved memory crop");
                        CaptureLabUi(camera, "15-Yuki-Memory");
                        Click("Continue examination");
                        phase++;
                        break;
                    case 62:
                        player.OpenInspection();
                        Require(!GameObject.Find("Examination dialogue"), "The same memory cannot count twice");
                        Place(player, new Vector3(-39.6f, 5.245f, 301.03f));
                        CaptureRoomView(player, camera, "85-ObservationAlcove-ShizukaCue", "checked Shizuka cue within the authored observation alcove");
                        player.OpenInspection();
                        Require(GameObject.Find("Manhwa memory").GetComponent<RawImage>().texture.name == "Shizuka-PDF041",
                            "The opposite cue opens Shizuka's approved memory crop");
                        Click("Continue examination");
                        Require(GameObject.Find("Review memories") && GameObject.Find("Choose Shizuka") &&
                            GameObject.Find("Choose Yuki") && GameObject.Find("Kinja countdown"),
                            "The two memories open the timed ultimatum with two choices, review, and refusal");
                        Click("Review memories");
                        Require(!GameObject.Find("Examination dialogue"), "Review returns control to reread the memories");
                        player.OpenInspection();
                        Click("Continue examination");
                        Place(player, new Vector3(-31.4f, 5.245f, 303.23f));
                        player.OpenInspection();
                        Click("Continue examination");
                        Click("Continue examination");
                        Require(!Room01Checkpoint.Load(Checkpoint).ExaminationCompleted,
                            "Refusing to sacrifice a memory still does not complete the trial");
                        phase++;
                        break;
                    case 63:
                        using (var locked = new FileStream(Checkpoint, FileMode.Open, FileAccess.Read, FileShare.Read))
                            Click("Continue examination");
                        Require(GameObject.Find("Examination dialogue") && !Room01Checkpoint.Load(Checkpoint).ExaminationCompleted,
                            "Failed durable write leaves the resistance action retryable");
                        Click("Continue examination");
                        Require(!GameObject.Find("Examination dialogue") && Room01Checkpoint.Load(Checkpoint).ExaminationCompleted,
                            "Reaching for the light commits the trial before handoff");
                        CaptureAt(camera, "16-Zero-Altar", new Vector3(-31.0f, 6.65f, 308.8f), new Vector3(-35.5f, 4.9f, 313.1f));
                        LoadCheckpoint();
                        phase++;
                        break;
                    case 64:
                        Require(Vector3.Distance(position, new Vector3(-33.3f, 4.045f, 311.53f)) < 0.24f &&
                            GameObject.Find("Presence at the altar").GetComponent<Light>().enabled,
                            "Resume restores the completed examination and altar cue");
                        Require(!GameObject.Find("Examination dialogue") && !GameObject.Find("Examination wing interlock"),
                            "Resume opens the altar approach without replaying the trial");
                        CaptureRoomView(player, camera, "84-ZeroThreshold-AfterContinue", "altar approach after restoring completed examination");
                        if (ExercisePact)
                        {
                            phase = 80;
                            break;
                        }
                        Debug.Log($"ECHO_STATION_PASS {checks} checks");
                        Finish(0);
                        break;
                    case 80:
                        Require(HasSchool(player) && PactBeat() == 0, "Legitimate altar entry starts with School65");
                        player.OpenInspection();
                        Require(GameObject.Find("Zero pact dialogue") && PactBeat() == 1,
                            "Normal interaction from the saved altar opens the encounter and records its first beat");
                        Require(GameObject.Find("Archive memory frame"), "Opening Zero plays the cached descent without changing pact authority");
                        Click("Advance Zero");
                        Click("Advance Zero");
                        Click("Advance Zero");
                        Require(PactBeat() == 4 && GameObject.Find("Zero manifestation") && HasSchool(player),
                            "Zero manifests before the decision without exposing Pact72");
                        phase++;
                        break;
                    case 81:
                        CaptureModal(camera, "Zero pact dialogue", "17-Zero-Manifestation");
                        Click("Advance Zero");
                        Require(!GameObject.Find("Advance Zero"), "Decision stays hidden until all three questions are heard");
                        for (var question = 1; question <= 3; question++)
                        {
                            Click("Question " + question);
                            Require(GameObject.Find("Zero line").GetComponent<Text>().text.Length > 12,
                                "Zero answers question " + question);
                            Click("Advance Zero");
                        }
                        Click("Advance Zero");
                        Require(PactBeat() == 6 && HasSchool(player) &&
                            UnityEngine.EventSystems.EventSystem.current.currentSelectedGameObject.name == "Defer Zero",
                            "Consent requires all questions and its default focus defers");
                        CaptureModal(camera, "Zero pact dialogue", "18-Zero-Decision");
                        Click("Defer Zero");
                        Require(!GameObject.Find("Zero pact dialogue") && HasSchool(player) && PactDeferred(),
                            "Deferring returns control with the school avatar and saves the choice");
                        LoadCheckpoint();
                        phase++;
                        break;
                    case 82:
                        Require(PactDeferred() && HasSchool(player) && !GameObject.Find("Zero pact dialogue"),
                            "Reloaded defer stays at the altar without revealing the pact");
                        player.OpenInspection();
                        Require(!PactDeferred() && PactBeat() == 6 && GameObject.Find("Zero pact dialogue"),
                            "Deliberate interaction reopens the saved decision");
                        using (var locked = new FileStream(Checkpoint, FileMode.Open, FileAccess.Read, FileShare.Read))
                            Click("Advance Zero");
                        Require(PactBeat() == 6 && HasSchool(player) && GameObject.Find("Zero pact dialogue"),
                            "A locked checkpoint leaves consent retryable with no transformation");
                        Click("Advance Zero");
                        Require(PactBeat() == 7 && !HasSchool(player) && GameObject.Find("Pact72 facing"),
                            "One explicit successful consent transaction exposes Pact72");
                        Require(!GameObject.Find("Zero manifestation"), "The manifestation gives way to the earned avatar");
                        phase++;
                        break;
                    case 83:
                        CaptureModal(camera, "Zero pact dialogue", "19-Pact-Sealed");
                        Click("Advance Zero");
                        Require(!GameObject.Find("Zero pact dialogue") && PactBeat() == 7, "The recap hands back control without repeating consent");
                        LoadCheckpoint();
                        phase++;
                        break;
                    case 84:
                        Require(PactBeat() == 7 && !HasSchool(player) && GameObject.Find("Pact72 facing"),
                            "Reload restores precisely the earned avatar");
                        var pactMotion = player.GetComponentsInChildren<Animation>().Single(motion => motion["Strike"] != null);
                        Require(pactMotion.IsPlaying("Idle"), "Pact idle binds to the live skinned model");
                        var joints = pactMotion.GetComponentsInChildren<SkinnedMeshRenderer>()
                            .SelectMany(skin => skin.bones).Distinct();
                        var head = joints.Single(bone => bone.name.EndsWith(":Head", StringComparison.Ordinal));
                        var hips = joints.Single(bone => bone.name.EndsWith(":Hips", StringComparison.Ordinal));
                        Require(head.position.y > hips.position.y + 0.35f && head.position.y - position.y < 1.9f,
                            "Pact72 stands upright at player scale after the animated reload");
                        revealStart = position;
                        Place(player, position + new Vector3(1.15f, 0f, -1.0f));
                        revealStart = player.transform.position;
                        SetKeys(Key.S);
                        phase++;
                        break;
                    case 85:
                        if (Vector3.Distance(position, revealStart) < 0.27f) return;
                        SetKeys();
                        var animation = player.GetComponentsInChildren<Animation>().Single(motion => motion["Strike"] != null);
                        Require(animation.IsPlaying("Walk"), "Pact72 walks through normal input after resume");
                        Capture(camera, "20-Pact-After-Reload");
                        if (connected || Environment.GetEnvironmentVariable("ECHO_STATION_KINJA") == "1")
                        {
                            player.RequestPactStrike();
                            Require(KinjaProgress() == 0 && !animation.IsPlaying("Strike"), "Pact strike cannot reach Kinja from the altar");
                            Place(player, GameObject.Find("Confrontation resume").transform.position);
                            phase = 86;
                            break;
                        }
                        Debug.Log($"ECHO_STATION_PASS {checks} checks");
                        Finish(0);
                        break;
                    case 86:
                        if (!player.GetComponent<CharacterController>().isGrounded) return;
                        SetKeys(Key.F);
                        phase++;
                        break;
                    case 87:
                        if (!player.GetComponentsInChildren<Animation>().Any(motion => motion.IsPlaying("Strike"))) return;
                        SetKeys();
                        phase++;
                        break;
                    case 88:
                        if (KinjaProgress() != 1) return;
                        Require(!GameObject.Find("Kinja decision"), "First input contact saves without opening the decision");
                        LoadCheckpoint();
                        phase++;
                        break;
                    case 89:
                        if (!player.GetComponent<CharacterController>().isGrounded) return;
                        Require(KinjaProgress() == 1 && !HasSchool(player), "Reload resumes the encounter with the first contact and earned Pact72");
                        SetKeys(Key.F);
                        phase++;
                        break;
                    case 90:
                        if (!player.GetComponentsInChildren<Animation>().Any(motion => motion.IsPlaying("Strike"))) return;
                        SetKeys();
                        phase++;
                        break;
                    case 91:
                        if (KinjaProgress() != 2 || player.GetComponentsInChildren<Animation>().Any(motion => motion.IsPlaying("Strike"))) return;
                        player.RequestPactStrike();
                        phase++;
                        break;
                    case 92:
                        player.RequestPactStrike();
                        if (KinjaProgress() != 3) return;
                        player.OpenInspection();
                        if (!GameObject.Find("Kinja decision")) return;
                        Require(Mathf.Abs(position.y - GameObject.Find("Confrontation resume").transform.position.y) < 0.18f,
                            "Kinja confrontation opens on the theatre floor after recovery from the third contact");
                        phase++;
                        break;
                    case 93:
                        CaptureModal(camera, "Kinja decision", "21-Kinja-Confrontation");
                        Click("Kinja back");
                        Require(!GameObject.Find("Kinja decision") && KinjaProgress() == 3, "Backing away preserves the confrontation");
                        player.OpenInspection();
                        Click("Kinja confirm");
                        Require(KinjaProgress() == 4 && GameObject.Find("Kinja decision"), "Echo releases Kinja before the escape wish");
                        using (var locked = new FileStream(Checkpoint, FileMode.Open, FileAccess.Read, FileShare.Read))
                            Click("Kinja confirm");
                        Require(KinjaProgress() == 4 && GameObject.Find("Kinja decision"), "Failed wish write allows retry");
                        Click("Kinja back");
                        LoadCheckpoint();
                        phase++;
                        break;
                    case 94:
                        player.OpenInspection();
                        Require(GameObject.Find("Kinja decision") && KinjaProgress() == 4, "Reload restores the unconfirmed wish");
                        phase++;
                        break;
                    case 95:
                        CaptureModal(camera, "Kinja decision", "22-Zero-Wish");
                        Click("Kinja confirm");
                        Require(!GameObject.Find("Kinja decision") && KinjaProgress() == 5, "Explicit consent commits the escape wish once");
                        LoadCheckpoint();
                        phase++;
                        break;
                    case 96:
                        player.OpenInspection();
                        Require(!GameObject.Find("Kinja decision") && KinjaProgress() == 5, "Confirmed wish does not replay on return");
                        if (connected || Environment.GetEnvironmentVariable("ECHO_STATION_WARD") == "1")
                        {
                            phase = 97;
                            break;
                        }
                        Debug.Log($"ECHO_STATION_PASS {checks} checks");
                        Finish(0);
                        break;
                    case 97:
                        if (!GameObject.Find("Hospital recovery")) return;
                        Require(HasSchool(player) && !GameObject.Find("Pact72 facing") && WardProgress() == 0,
                            "The escape resumes at the bedside without the wing or an automatic wake");
                        Require(Vector3.Distance(position, GameObject.Find("Ward bedside resume").transform.position) < 0.22f,
                            "The hospital uses its authored bedside safe anchor");
                        CaptureModal(camera, "Hospital recovery", "23-Hospital-Bedside");
                        Click("Ward advance");
                        Require(WardProgress() == 1 && !GameObject.Find("Hospital recovery"), "Explicit wake opens the ward");
                        LoadCheckpoint();
                        phase++;
                        break;
                    case 98:
                        if (!GameObject.Find("Awakening ward")) return;
                        Require(HasSchool(player) && WardProgress() == 1 && !GameObject.Find("Hospital recovery"),
                            "Ward reload preserves wake without repeating the film");
                        CaptureRoomView(player, camera, "86-Ward-AwakeAfterContinue", "normal ward control after restoring awake checkpoint");
                        if (!string.IsNullOrEmpty(Environment.GetEnvironmentVariable("ECHO_STATION_WARD_SEED")))
                        {
                            var wardRoom = GameObject.Find("Awakening ward").transform;
                            CaptureAt(camera, "26-Ward-Bed-and-Window", wardRoom.TransformPoint(new Vector3(2.44f, 1.74f, 2.31f)),
                                wardRoom.TransformPoint(new Vector3(-1.05f, 1.05f, -0.93f)));
                            CaptureAt(camera, "27-Ward-Egress", wardRoom.TransformPoint(new Vector3(-2.46f, 1.66f, -2.24f)),
                                wardRoom.TransformPoint(new Vector3(0.30f, 1.31f, 2.65f)));
                            phase = 104;
                        }
                        else phase = 99;
                        Place(player, GameObject.Find("Ward mirror resume").transform.position);
                        break;
                    case 104:
                        if (!HospitalMirrorFlag("MirageSequenceActive") || HospitalMirageActive()) return;
                        Require(HasSchool(player) && WardProgress() == 1, "Mirror opens with a normal reflection before the reveal");
                        Place(player, GameObject.Find("Ward bedside resume").transform.position);
                        phase = 105;
                        break;
                    case 105:
                        if (HospitalMirrorFlag("MirageSequenceActive")) return;
                        Require(WardProgress() == 1, "Walking away interrupts the approach without clearing the chapter");
                        Place(player, GameObject.Find("Ward mirror resume").transform.position);
                        phase = 99;
                        break;
                    case 99:
                        if (!HospitalMirageActive()) return;
                        Require(HasSchool(player) && !GameObject.Find("Pact72 facing") &&
                            player.GetComponentsInChildren<Transform>().Any(item => item.name == "Persistent experiment trace"),
                            "The temporary wing is mirror-only while examination injuries persist on the live avatar");
                        using (var locked = new FileStream(Checkpoint, FileMode.Open, FileAccess.Read, FileShare.Read))
                            player.OpenInspection();
                        Require(WardProgress() == 1 && !GameObject.Find("Hospital recovery"),
                            "A failed mirror write remains retryable");
                        player.OpenInspection();
                        Require(WardProgress() == 2 && GameObject.Find("Ward speaker").GetComponent<Text>().text == "EX-011",
                            "Reading the live mirror persists the EX-011 and chapter clear");
                        phase++;
                        break;
                    case 100:
                        var reflector = GameObject.Find("Hospital live mirror").GetComponent<StationReflection>();
                        var elapsed = (float)typeof(StationReflection).GetProperty("MirageElapsed", Private).GetValue(reflector);
                        if (elapsed < 2.55f) return;
                        Require(GameObject.Find("Ward line").GetComponent<StoryTextReveal>() != null &&
                            !GameObject.Find("System objective hologram").GetComponent<CanvasGroup>().blocksRaycasts,
                            "Story text uses its own reveal while the separate system hologram never blocks input");
                        CaptureModal(camera, "Hospital recovery", "24-Hospital-Pact-Reflection");
                        phase = 102;
                        break;
                    case 102:
                        if (HospitalMirrorFlag("MirageSequenceActive")) return;
                        phase = 103;
                        break;
                    case 103:
                        CaptureModal(camera, "Hospital recovery", "25-Hospital-Normal-Reflection");
                        Require(HasSchool(player) && !HospitalMirageActive(),
                            "The memory ends and the live mirror returns to normal");
                        Click("Ward advance");
                        if (connected)
                        {
                            reload = SceneManager.LoadSceneAsync("ChapterTitle");
                            phase = 106;
                            break;
                        }
                        LoadCheckpoint();
                        phase = 101;
                        break;
                    case 101:
                        if (SceneManager.GetActiveScene().name != "ChapterRoom01" || !GameObject.Find("Awakening ward")) return;
                        Require(WardProgress() == 2 && !GameObject.Find("Hospital recovery") &&
                            Vector3.Distance(position, GameObject.Find("Ward mirror resume").transform.position) < 0.22f,
                            "Chapter-cleared saves resume by the mirror with no duplicate grant");
                        var result = connected ? "ECHO_CONNECTED_WARD_PASS" : "ECHO_STATION_PASS";
                        Debug.Log($"{result} {checks} checks");
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

        private static void Click(string name) => GameObject.Find(name).GetComponent<Button>().onClick.Invoke();

        private static bool HasSchool(Room01Player player) => player.transform.Find("School65 facing").gameObject.activeSelf;

        private static Newtonsoft.Json.Linq.JToken PactState() =>
            Newtonsoft.Json.Linq.JObject.Parse(File.ReadAllText(Checkpoint))["milestones"]["zero"];

        private static int PactBeat() => (int)PactState()["beat"];

        private static int KinjaProgress() =>
            (int?)Newtonsoft.Json.Linq.JObject.Parse(File.ReadAllText(Checkpoint))["milestones"]["after_pact"] ?? 0;

        private static bool PactDeferred() => (bool)PactState()["deferred"];

        private static bool HospitalMirageActive() => HospitalMirrorFlag("MirageActive");

        private static bool HospitalMirrorFlag(string name)
        {
            var reflection = GameObject.Find("Hospital live mirror").GetComponent<StationReflection>();
            return (bool)typeof(StationReflection).GetProperty(name, Private).GetValue(reflection);
        }

        private static int WardProgress() =>
            (int)Newtonsoft.Json.Linq.JObject.Parse(File.ReadAllText(Checkpoint))["milestones"]["ward"];

        private static void CaptureLabUi(Camera camera, string name) => CaptureModal(camera, "Examination dialogue", name);

        private static void CaptureModal(Camera camera, string panel, string name)
        {
            if (SystemInfo.graphicsDeviceType == GraphicsDeviceType.Null) return;
            var canvas = GameObject.Find(panel).GetComponentInParent<Canvas>();
            var mode = canvas.renderMode;
            var previousCamera = canvas.worldCamera;
            var previousDistance = canvas.planeDistance;
            try
            {
                canvas.renderMode = RenderMode.ScreenSpaceCamera;
                canvas.worldCamera = camera;
                canvas.planeDistance = camera.nearClipPlane + 0.25f;
                Canvas.ForceUpdateCanvases();
                Capture(camera, name);
            }
            finally
            {
                canvas.renderMode = mode;
                canvas.worldCamera = previousCamera;
                canvas.planeDistance = previousDistance;
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
            var session = typeof(Room01Player).Assembly.GetType("ElevenEleven.Opening.ChapterSaveSession", true);
            session.GetMethod("SetRestore", BindingFlags.NonPublic | BindingFlags.Static)
                .Invoke(null, new object[] { Room01Checkpoint.Load(Checkpoint) });
            reload = SceneManager.LoadSceneAsync("ChapterRoom01");
            if (reload == null) throw new InvalidOperationException("Could not reload the chapter checkpoint.");
        }

        private static void Place(Room01Player player, Vector3 position)
        {
            typeof(Room01Player).GetMethod("Place", Private).Invoke(player, new object[] { position });
            Physics.SyncTransforms();
        }

        private static T Get<T>(StormworksRoute route, string property) =>
            (T)typeof(StormworksRoute).GetProperty(property, Private).GetValue(route);

        private static Animation SchoolJumpMotion(Room01Player player) => player.GetComponentsInChildren<Animation>(true)
            .Single(motion => motion.GetClip("Jump") != null);

        private static void SampleSchoolJumpPhysics(Room01Player player)
        {
            if (player.GetComponent<CharacterController>().isGrounded) return;
            var height = player.transform.position.y;
            var motion = SchoolJumpMotion(player);
            var sourceTime = motion["Jump"].time;
            if (!motion.IsPlaying("Jump") || sourceTime + 0.001f < lastJumpSample || sourceTime > 42f / 30f + 0.001f)
                throw new InvalidOperationException($"Jump pose does not follow the capsule flight: time={sourceTime:F4}.");
            if (schoolJumpFlightFrames == 0)
                jumpTakeoffShin = jumpShin.localRotation;
            else if (Quaternion.Angle(jumpTakeoffShin, jumpShin.localRotation) > 18f)
                jumpKneeMoved = true;
            schoolJumpFlightFrames++;
            lastJumpSample = sourceTime;
            jumpApexHeight = Mathf.Max(jumpApexHeight, height);
        }

        private static void SetKeys(params Key[] keys)
        {
            InputSystem.QueueStateEvent(keyboard, new KeyboardState(keys));
        }

        private static T GetObservatoryField<T>(StationMemoryObservatory observatory, string field) =>
            (T)typeof(StationMemoryObservatory).GetField(field, Private).GetValue(observatory);

        private static Vector4 ReadClockDots(Renderer renderer)
        {
            var block = new MaterialPropertyBlock();
            renderer.GetPropertyBlock(block);
            return block.GetVector("_ClockDotIntensity");
        }

        private static bool ventCueVerified;
        private static bool R40Review => Environment.GetEnvironmentVariable("ECHO_R40_CUES") == "1";

        private static bool CueIsReady(string name)
        {
            var go = GameObject.Find(name);
            if (!go || !go.TryGetComponent<RoomSystemCue>(out _)) throw new InvalidDataException(name);
            return go.GetComponentInChildren<Light>().color.g > .75f &&
                   go.GetComponentInChildren<Light>().color.r < .4f;
        }

        private static bool SurveillanceApproachReview => Environment.GetEnvironmentVariable("ECHO_R41_APPROACH_REVIEW") == "1";

        private static void FollowView(Room01Player player, Camera camera, Transform room, string shot,
            Vector3 point, float yaw, float pitch, bool reduced = false)
        {
            var yawField = typeof(Room01Player).GetField("viewYaw", Private);
            var pitchField = typeof(Room01Player).GetField("viewPitch", Private);
            var oldYaw = yawField.GetValue(player);
            var oldPitch = pitchField.GetValue(player);
            var oldPoint = player.transform.position;
            var oldReduced = ChapterSceneLink.ReducedMotion;
            try
            {
                ChapterSceneLink.ReducedMotion = reduced;
                yawField.SetValue(player, room.eulerAngles.y + yaw);
                pitchField.SetValue(player, pitch);
                Place(player, room.TransformPoint(point));
                Require(Vector3.Distance(camera.transform.position, player.transform.position + Vector3.up * 1.4f) > .32f,
                    shot + " retains a usable production follow arm");
                if (reduced) Require(Mathf.Abs(camera.fieldOfView - 60f) < .03f, shot + " retains the fixed reduced-motion lens");
                var fit = room.GetComponentsInChildren<Transform>(false).Where(t => t.name is
                    "Fitted surveillance approach guides" or "Flush deck flange" or "Live crossing threshold").ToArray();
                if (fit.Length > 0)
                {
                    try
                    {
                        foreach (var part in fit) part.gameObject.SetActive(false);
                        Capture(camera, shot + "-R40");
                    }
                    finally
                    {
                        foreach (var part in fit) part.gameObject.SetActive(true);
                    }
                }
                Capture(camera, shot + "-R41");
            }
            finally
            {
                ChapterSceneLink.ReducedMotion = oldReduced;
                yawField.SetValue(player, oldYaw);
                pitchField.SetValue(player, oldPitch);
                Place(player, oldPoint);
            }
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

        internal static void CaptureRoomView(Room01Player player, Camera camera, string name, string scope)
        {
            if (Environment.GetEnvironmentVariable("ECHO_ALL_ROOM_VIEWS") != "1" || !camera || !camera.isActiveAndEnabled ||
                SystemInfo.graphicsDeviceType == GraphicsDeviceType.Null) return;
            var destination = Environment.GetEnvironmentVariable("ECHO_STATION_CAPTURE");
            if (string.IsNullOrWhiteSpace(destination)) return;

            var routeChecks = checks;
            try
            {
                Capture(camera, name);
                if (File.Exists(Path.Combine(destination, name + ".png")))
                    Debug.Log($"ECHO_ALL_ROOM_VIEW {name} scope={scope} feet={player.transform.position:F3} " +
                        $"eye={camera.transform.position:F3} forward={camera.transform.forward:F3} fov={camera.fieldOfView:F2} " +
                        $"reducedMotion={ChapterSceneLink.ReducedMotion}");
            }
            finally { checks = routeChecks; }
        }
        internal static void Capture(Camera camera, string name)
        {
            var destination = Environment.GetEnvironmentVariable("ECHO_STATION_CAPTURE");
            if (string.IsNullOrEmpty(destination) || SystemInfo.graphicsDeviceType == GraphicsDeviceType.Null) return;
            var only = Environment.GetEnvironmentVariable("ECHO_STATION_CAPTURE_ONLY");
            if (!string.IsNullOrEmpty(only) && !only.Split(',').Contains(name.Split('-')[0])) return;
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

