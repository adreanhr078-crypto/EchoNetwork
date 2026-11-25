using System;
using System.IO;
using System.Linq;
using ElevenEleven.Opening;
using UnityEditor;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;
using UnityEngine.SceneManagement;
using UnityEngine.UI;

namespace ElevenEleven.Editor
{
    [InitializeOnLoad]
    internal static class ChapterR01Smoke
    {
        private const string Running = "ElevenEleven.R01.Playing";
        private const string Connected = "ElevenEleven.R01.Connected";
        private const string DirectRoom = "ElevenEleven.R01.DirectRoom";
        private const string Deadline = "ElevenEleven.R01.Deadline";
        private static int stage;
        private static int checks;
        private static Keyboard keyboard;
        private static Vector3 startPosition;
        private static int waitFrames;
        private static bool conduitFirst;
        private static AsyncOperation reload;
        private static bool PhotographyEntryOnly =>
            Environment.GetEnvironmentVariable("ECHO_PHOTOGRAPHY_ENTRY_ONLY") == "1";
        private static bool FullOpening => Environment.GetEnvironmentVariable("ECHO_R01_FULL_OPENING") == "1";

        static ChapterR01Smoke()
        {
            if (!SessionState.GetBool(Running, false)) return;
            if (SessionState.GetBool(DirectRoom, false)) stage = 3;
            EditorApplication.update += Advance;
        }

        public static void Run()
        {
            if (!Application.isBatchMode) throw new InvalidOperationException("Use Unity batch mode.");
            ChapterSceneBuilder.OpenRegisteredTitle();
            SessionState.SetBool(Running, true);
            var openingLimit = SessionState.GetBool(Connected, false) ? 600f : FullOpening ? 240f : 120f;
            SessionState.SetFloat(Deadline, (float)EditorApplication.timeSinceStartup + openingLimit);
            EditorApplication.update += Advance;
            EditorApplication.EnterPlaymode();
        }

        public static void RunConnected()
        {
            var fixture = Environment.GetEnvironmentVariable("ECHO_R02_FIXTURE_DIRECTORY");
            if (!Application.isBatchMode || string.IsNullOrWhiteSpace(fixture) ||
                (Directory.Exists(fixture) && Directory.EnumerateFileSystemEntries(fixture).Any()))
                throw new InvalidOperationException("Use batch mode with an empty, isolated checkpoint directory.");

            Directory.CreateDirectory(fixture);
            SessionState.SetBool(Connected, true);
            Run();
        }

        public static void RunFromRoomAndContinue()
        {
            var fixture = Environment.GetEnvironmentVariable("ECHO_R02_FIXTURE_DIRECTORY");
            if (!Application.isBatchMode || string.IsNullOrWhiteSpace(fixture) ||
                (Directory.Exists(fixture) && Directory.EnumerateFileSystemEntries(fixture).Any()))
                throw new InvalidOperationException("Use batch mode with an empty, isolated checkpoint directory.");
            Directory.CreateDirectory(fixture);
            UnityEditor.SceneManagement.EditorSceneManager.OpenScene("Assets/ElevenEleven/Scenes/ChapterRoom01.unity");
            stage = 3;
            SessionState.SetBool(DirectRoom, true);
            SessionState.SetBool(Connected, true);
            SessionState.SetBool(Running, true);
            SessionState.SetFloat(Deadline, (float)EditorApplication.timeSinceStartup + 600f);
            EditorApplication.update += Advance;
            EditorApplication.EnterPlaymode();
        }

        public static void RebuildRoomAndRun()
        {
            if (!Application.isBatchMode) throw new InvalidOperationException("Use Unity batch mode.");
            ChapterSceneBuilder.RebuildRoom();
            Run();
        }

        private static void Advance()
        {
            try
            {
                if (EditorApplication.timeSinceStartup > SessionState.GetFloat(Deadline, 0f))
                {
                    var room = UnityEngine.Object.FindFirstObjectByType<ChapterRoomStage>();
                    var film = UnityEngine.Object.FindFirstObjectByType<OpeningCinematicPresenter>();
                    throw new TimeoutException($"Chapter entry stalled at stage {stage}, film {film?.Beat}, " +
                        $"room ready {room?.IsReady}, room failed {room?.IsFailed}, render warmed {room?.RenderWarmupCompleted}.");
                }
                if (!EditorApplication.isPlaying) return;

                var scene = SceneManager.GetActiveScene().name;
                switch (stage)
                {
                    case 0 when scene == "ChapterTitle" && FindButton("Chapter entry").interactable:
                        Application.targetFrameRate = 45;
                        Application.runInBackground = true;
                        InputSystem.settings.backgroundBehavior = InputSettings.BackgroundBehavior.IgnoreFocus;
                        InputSystem.settings.editorInputBehaviorInPlayMode = InputSettings.EditorInputBehaviorInPlayMode.AllDeviceInputAlwaysGoesToGameView;
                        if (!FullOpening)
                        {
                            Press("Motion on");
                            Require(ChapterSceneLink.ReducedMotion, "Title exposes reduced motion");
                        }
                        stage = 14;
                        break;
                    case 14 when scene == "ChapterTitle" && HasButton("Chapter entry") && FindButton("Chapter entry").interactable:
                        if (SessionState.GetBool(Connected, false))
                        {
                            if (FindButton("Language").GetComponentInChildren<Text>().text == "English")
                                Press("Language");
                            Require(FindButton("Chapter entry").GetComponentInChildren<Text>().text == "Tap to Start",
                                "An empty fixture starts a fresh chapter from the title");
                        }
                        Press("Chapter entry");
                        stage = 1;
                        break;
                    case 1 when scene == "ChapterOpening":
                        Press("Piece 1");
                        Press("Piece 2");
                        Press("Piece 5");
                        Press("Piece 6");
                        stage++;
                        break;
                    case 2 when scene == "ChapterOpening":
                        var film = UnityEngine.Object.FindFirstObjectByType<OpeningCinematicPresenter>();
                        if (film == null) return;
                        if (FullOpening)
                        {
                            stage = 20;
                            break;
                        }
                        Require(film.Beat == OpeningBeat.School && !film.ShowingVideo, "Cover hands off to School under reduced motion");
                        Press("Pause");
                        Require(film.Paused && !FindButton("Continue").interactable, "Pause suspends the film");
                        Press("Pause");
                        Press("Continue");
                        Require(film.Beat == OpeningBeat.Laboratory, "School hands off to the laboratory");
                        Press("Continue");
                        Press("What is this experiment?");
                        Require(film.Beat == OpeningBeat.ExperimentReply, "Laboratory retains the experiment question");
                        Press("Back to questions");
                        Press("What about safety?");
                        Require(film.Beat == OpeningBeat.SafetyReply, "Laboratory retains the safety question");
                        Press("Back to questions");
                        Press("I am ready.");
                        Require(film.Beat == OpeningBeat.Experiment, "Ready starts the experiment");
                        Press("Continue");
                        Require(film.Beat == OpeningBeat.Memory, "Experiment restores the school memory");
                        Press("Continue");
                        Require(film.Beat == OpeningBeat.SystemWake, "The system reveals the wake after the memory");
                        stage = 24;
                        break;
                    case 24 when !FullOpening && scene == "ChapterOpening" && HasButton("Continue") && FindButton("Continue").interactable:
                        var wake = UnityEngine.Object.FindFirstObjectByType<OpeningCinematicPresenter>();
                        if (wake.Beat != OpeningBeat.SystemWake) return;
                        Press("Continue");
                        Require(wake.Beat == OpeningBeat.Complete, "Wake fires the room handoff after the destination is ready");
                        stage = 3;
                        break;
                    case 20 when scene == "ChapterOpening":
                        var school = UnityEngine.Object.FindFirstObjectByType<OpeningCinematicPresenter>();
                        var schoolVideo = school.GetComponent<UnityEngine.Video.VideoPlayer>();
                        if (school.Beat != OpeningBeat.School || !school.ShowingVideo || schoolVideo.frame < 24) return;
                        Require(!school.CanSkip, "Skip stays hidden before ten seconds of playback");
                        Press("Pause");
                        Require(school.Paused && !schoolVideo.isPlaying, "Full opening uses decoded video and honors pause");
                        Press("Pause");
                        stage++;
                        break;
                    case 21 when scene == "ChapterOpening":
                        var lab = UnityEngine.Object.FindFirstObjectByType<OpeningCinematicPresenter>();
                        var labVideo = lab.GetComponent<UnityEngine.Video.VideoPlayer>();
                        if (lab.Beat != OpeningBeat.Laboratory || !lab.ShowingVideo || labVideo.frame < 118) return;
                        Require(labVideo.clip.name == "Opening3D-lab-continuity" && labVideo.clip.audioTrackCount == 1,
                            "Native lab decodes the chair splice and retains one local SFX track");
                        stage++;
                        break;
                    case 22 when scene == "ChapterOpening":
                        var questions = UnityEngine.Object.FindFirstObjectByType<OpeningCinematicPresenter>();
                        if (questions.Beat != OpeningBeat.Questions) return;
                        Press("What is this experiment?");
                        Require(questions.Beat == OpeningBeat.ExperimentReply, "The seated shot hands off to the existing interactive experiment question");
                        Press("Back to questions");
                        Press("What about safety?");
                        Require(questions.Beat == OpeningBeat.SafetyReply, "The safety question survives the recut");
                        Press("Back to questions");
                        Press("I am ready.");
                        stage++;
                        break;
                    case 23 when scene == "ChapterOpening":
                        var trial = UnityEngine.Object.FindFirstObjectByType<OpeningCinematicPresenter>();
                        var trialVideo = trial.GetComponent<UnityEngine.Video.VideoPlayer>();
                        if (trial.Beat != OpeningBeat.Experiment || !trial.ShowingVideo || trialVideo.frame < 155) return;
                        Require(trialVideo.clip.name == "Opening3D-trial-continuity" && trialVideo.clip.audioTrackCount == 1,
                            "Native trial decodes beyond the recovered Kinja footage into the existing memory insert");
                        stage++;
                        break;
                    case 24 when scene == "ChapterOpening":
                        var threshold = UnityEngine.Object.FindFirstObjectByType<OpeningCinematicPresenter>();
                        var thresholdVideo = threshold.GetComponent<UnityEngine.Video.VideoPlayer>();
                        if (threshold.Beat != OpeningBeat.Memory || !threshold.ShowingVideo || thresholdVideo.frame < 24) return;
                        Require(thresholdVideo.clip.name == "Opening3D-threshold" && threshold.CanSkip,
                            "The completed trial hands off to the decoded threshold and preserves the skip window");
                        Press("Skip shot");
                        Require(threshold.Beat == OpeningBeat.SystemWake, "Skipping the threshold reaches the System Wake screen");
                        stage = 3;
                        break;
                    case 3 when scene == "ChapterRoom01":
                        var player = UnityEngine.Object.FindFirstObjectByType<Room01Player>();
                        if (SessionState.GetBool(DirectRoom, false))
                        {
                            if (!player || !Camera.main) return;
                            if (CameraProbe && !ObserveCameraFraming()) return;
                            if (UtilityProbe && !ObserveUtilityEffects()) return;
                            if (!PhotographyEntryOnly && !player.GetComponent<CharacterController>().isGrounded) return;
                            Application.runInBackground = true;
                            InputSystem.settings.backgroundBehavior = InputSettings.BackgroundBehavior.IgnoreFocus;
                            InputSystem.settings.editorInputBehaviorInPlayMode = InputSettings.EditorInputBehaviorInPlayMode.AllDeviceInputAlwaysGoesToGameView;
                            ChapterSceneLink.ReducedMotion = true;
                        }
                        var bones = player.GetComponentsInChildren<SkinnedMeshRenderer>().SelectMany(skin => skin.bones).Distinct().Count();
                        Require(bones == 65 && !player.name.Contains("V31"), "Normal entry spawns School65");
                        Require(Camera.main != null && Camera.main.isActiveAndEnabled, "Room camera owns the view");
                        Require(player.GetComponentInChildren<Animation>().IsPlaying("Idle"), "First playable frame uses School Idle");
                        Require(Objective() == "Find the stopped clock.", "Arrival starts at the first clue");
                        Require(Physics.Raycast(new Vector3(0, 0.7f, 17), Vector3.forward, 2f), "North exit is sealed");
                        keyboard = InputSystem.AddDevice<Keyboard>();
                        keyboard.MakeCurrent();
                        if (PhotographyEntryOnly)
                        {
                            MoveNear("StoppedClock pedestal", new Vector3(.9f, 0f, .25f));
                            stage = 5;
                            break;
                        }
                        startPosition = player.transform.position;
                        SetKey(Key.W);
                        Require(keyboard.wKey.isPressed, "Input System received the virtual W key");
                        stage++;
                        break;
                    case 4:
                        var actor = UnityEngine.Object.FindFirstObjectByType<Room01Player>();
                        if (actor.transform.position.z < startPosition.z + 0.15f) return;
                        Require(Mathf.Abs(actor.transform.position.y) < 0.15f, "Keyboard moves School65 on the floor");
                        Require(actor.GetComponentInChildren<Animation>().IsPlaying("Walk"), "Actual capsule travel drives School Walk");
                        SetKey();
                        MoveNear("StoppedClock pedestal", new Vector3(0.9f, 0, 0.25f));
                        stage++;
                        break;
                    case 5:
                        if (!HasButton("Inspect  [E]")) return;
                        Press("Inspect  [E]");
                        Press("Back");
                        Require(Objective() == "Find the stopped clock.", "Cancel leaves the clue pending");
                        Press("Inspect  [E]");
                        Press("Keep this trace");
                        Require(Objective() == "Find the personal trace.", "Clock unlocks the personal trace");
                        MoveNear("PersonalTrace pedestal", new Vector3(-0.8f, 0, 0));
                        stage++;
                        break;
                    case 6:
                        if (++waitFrames < 4 || !HasButton("Inspect  [E]")) return;
                        Press("Inspect  [E]");
                        Press("Keep this trace");
                        Require(Objective() == "Align the terminal and energize the conduit.", "Trace unlocks both objectives");
                        if (conduitFirst) MoveNear("PowerConduit", new Vector3(1, 0, 0));
                        else MoveNear("SignalTerminal", new Vector3(0, 0, 1.05f));
                        waitFrames = 0;
                        stage = conduitFirst ? 7 : 8;
                        break;
                    case 7:
                        if (!InteractionIs("Energize  [E]")) return;
                        Press("Inspect  [E]");
                        Require(Objective() == "Align the signal at the terminal." && GateBlocked(), "Power alone keeps the gate sealed");
                        MoveNear("SignalTerminal", new Vector3(0, 0, 1.05f));
                        stage++;
                        break;
                    case 8:
                        if (!InteractionIs("Tune signal  [E]")) return;
                        Press("Inspect  [E]");
                        Require(FindSlider("Frequency").value == 160f, "Tuner starts at 80 MHz");
                        startPosition = Player().transform.position;
                        waitFrames = 0;
                        SetKey(Key.W);
                        stage++;
                        break;
                    case 9:
                        if (++waitFrames < 5) return;
                        Require(Vector3.Distance(Player().transform.position, startPosition) < 0.002f,
                            "Tuner owns input and blocks movement");
                        SetKey();
                        FindSlider("Frequency").value = 192;
                        FindSlider("Phase").value = 45;
                        FindSlider("Channel").value = 7;
                        Require(!HasButton("Return to room") && GateBlocked(), "Wrong frequency cannot align or open the gate");
                        Press("Close tuner");
                        Require(InteractionIs("Tune signal  [E]"), "Cancel restores the interaction prompt");
                        Press("Inspect  [E]");
                        Require(FindSlider("Frequency").value == 192f, "Retry retains the tuner values");
                        FindSlider("Phase").value = 51;
                        FindSlider("Frequency").value = 218;
                        Require(!HasButton("Return to room"), "One degree beyond the tolerance does not solve");
                        FindSlider("Phase").value = 50;
                        Require(HasButton("Return to room") && GateBlocked(), "Inclusive signal tolerances align while the modal owns input");
                        Press("Return to room");
                        if (conduitFirst)
                        {
                            Require(Objective() == "The blast gate is opening." && GateBlocked(), "Full motion slides the door after both objectives");
                            stage = 11;
                            break;
                        }
                        Require(Objective() == "Energize the power conduit." && GateBlocked(), "Alignment alone keeps the gate sealed");
                        MoveNear("PowerConduit", new Vector3(1, 0, 0));
                        stage++;
                        break;
                    case 10:
                        if (!InteractionIs("Energize  [E]")) return;
                        Press("Inspect  [E]");
                        Require(Gate().IsOpen, "Reduced Motion opens the door without a slide");
                        stage++;
                        break;
                    case 11:
                        if (!Gate().IsOpen) return;
                        if (UtilityProbe)
                        {
                            var light = GameObject.Find("Intermittent arc reflection on the conduit").GetComponent<Light>();
                            if (light.color.g <= light.color.b) return;
                            Require(!utilityArc.enabled, "The conduit switches to stable light after real power input");
                            Debug.Log("ECHO_R37_UTILITIES_PLAY_PASS arc=true sparks=true runoff=true flame=true pause=true reduced_motion=true restored_conduit=true");
                        }
                        Physics.SyncTransforms();
                        Require(!GateBlocked(), "Open door clears the physical opening");
                        if (PhotographyEntryOnly)
                        {
                            Debug.Log($"ECHO_PHOTOGRAPHY_ENTRY_PASS {checks} checks");
                            Finish(0);
                            break;
                        }
                        Place(new Vector3(0, 0.04f, 16.6f));
                        SetKey(Key.W);
                        stage++;
                        break;
                    case 12:
                        if (Player().transform.position.z < 19.05f) return;
                        SetKey();
                        Require(Objective() == "The signal leads deeper into Sector 11.", "Walking through the door completes the threshold");
                        if (SessionState.GetBool(Connected, false))
                        {
                            var fixture = Environment.GetEnvironmentVariable("ECHO_R02_FIXTURE_DIRECTORY");
                            var save = Room01Checkpoint.Load(Path.Combine(fixture, "system_opening_v1.json"));
                            Require(save != null && save.Wake && save.Ending && save.StationStage == 0,
                                "Gate crossing writes the starting checkpoint for the station");
                            Debug.Log($"ECHO_CONNECTED_ENTRY_PASS {checks} checks");
                            Stop();
                            // The station probe exercises the animated vista and mirror.
                            ChapterSceneLink.ReducedMotion = false;
                            StormworksSmoke.ContinueFromGate();
                            break;
                        }
                        if (conduitFirst)
                        {
                            Debug.Log($"CHAPTER_R01_NATIVE_PLAY_PASS {checks} checks");
                            Finish(0);
                            break;
                        }
                        conduitFirst = true;
                        ChapterSceneLink.ReducedMotion = false;
                        reload = SceneManager.LoadSceneAsync("ChapterRoom01");
                        stage++;
                        break;
                    case 13:
                        if (!reload.isDone) return;
                        Require(Objective() == "Find the stopped clock." && GateBlocked(), "A fresh room resets clues and gate");
                        MoveNear("StoppedClock pedestal", new Vector3(0.9f, 0, 0.25f));
                        waitFrames = 0;
                        stage = 5;
                        break;
                }
            }
            catch (Exception error)
            {
                Debug.LogException(error);
                Finish(1);
            }
        }

        private static int cameraStep;
        private static int cameraFrame;
        private static float cameraWait;
        private static Vector3 cameraStart;
        private static float cameraOpenArm;
        private static readonly System.Reflection.BindingFlags PlayerFields =
            System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic;
        private static bool CameraProbe =>
            Environment.GetEnvironmentVariable("ECHO_PHOTOGRAPHY_CAMERA_PROBE") == "1";

        private static bool ObserveCameraFraming()
        {
            if (cameraStep == 5) return true;
            var player = Player();
            var camera = Camera.main;
            void Look(float yaw, float pitch)
            {
                typeof(Room01Player).GetField("viewYaw", PlayerFields).SetValue(player, yaw);
                typeof(Room01Player).GetField("viewPitch", PlayerFields).SetValue(player, pitch);
            }
            var feet = player.transform.position;
            var arm = Vector3.Distance(camera.transform.position, feet + Vector3.up * 1.4f);
            switch (cameraStep)
            {
                case 0:
                    Require(camera.GetComponent<ChapterCameraFraming>(), "The playable camera owns the room framing");
                    cameraStart = feet;
                    ChapterSceneLink.ReducedMotion = false;
                    Place(new Vector3(.61f,.04f,7.8f));
                    Look(0f,8f);
                    cameraWait = Time.time + .63f;
                    break;
                case 1:
                    if (Time.time < cameraWait) return false;
                    cameraOpenArm = arm;
                    Require(Mathf.Abs(camera.fieldOfView - 57f) < .7f && cameraOpenArm > 2.9f,
                        "Signal uses the narrower authored gameplay lens in clear space");
                    StormworksSmoke.Capture(camera, "68-Live-Signal-Follow-Camera");
                    ChapterSceneLink.ReducedMotion = true;
                    cameraFrame = Time.frameCount + 2;
                    break;
                case 2:
                    if (Time.frameCount < cameraFrame) return false;
                    Require(Mathf.Abs(camera.fieldOfView - 60f) < .03f, "Reduced Motion locks the gameplay field of view");
                    Place(new Vector3(10.64f,.04f,7.25f));
                    Look(-90f,4f);
                    cameraFrame = Time.frameCount + 2;
                    break;
                case 3:
                    if (Time.frameCount < cameraFrame) return false;
                    Require(arm < 1.64f && camera.transform.position.x < 11.61f,
                        "Follow camera retracts before the containment wall");
                    Place(new Vector3(.61f,.04f,7.8f));
                    Look(0f,8f);
                    ChapterSceneLink.ReducedMotion = false;
                    cameraWait = Time.time + .67f;
                    break;
                case 4:
                    if (Time.time < cameraWait) return false;
                    Require(arm > cameraOpenArm*.87f, "Camera releases gently to room framing after wall clearance");
                    Place(cameraStart);
                    Look(0f,8f);
                    Debug.Log("ECHO_PHOTOGRAPHY_CAMERA_PASS lens=57 reduced=60 collision=true release=true");
                    break;
            }
            ++cameraStep;
            return false;
        }

        private static readonly int UtilityPhase = Shader.PropertyToID("_UtilityPhase");
        private static readonly int UtilityDrip = Shader.PropertyToID("_UtilityDrip");
        private static readonly int UtilityLoad = Shader.PropertyToID("_UtilityLoad");
        private static int utilityStep;
        private static int utilityCaptured;
        private static Vector3 utilityStart;
        private static float utilityPausePhase;
        private static LineRenderer utilityArc;
        private static Renderer utilityWater;
        private static Renderer utilityFlame;
        private static bool UtilityProbe => SessionState.GetBool(DirectRoom, false) &&
            Environment.GetEnvironmentVariable("ECHO_R37_UTILITY_PROBE") == "1";

        private static bool ObserveUtilityEffects()
        {
            if (utilityStep == 4) return true;
            if (utilityStep == 0)
            {
                utilityArc = GameObject.Find("White ion channel").GetComponent<LineRenderer>();
                utilityWater = GameObject.Find("West viewport condensate spill").transform
                    .Find("Shallow water over the steel deck").GetComponent<Renderer>();
                utilityFlame = GameObject.Find("Turbulent flame tongue 1").GetComponent<Renderer>();
                utilityStart = Player().transform.position;
                ChapterSceneLink.ReducedMotion = false;
                Place(new Vector3(-1.05f,.04f,5.11f));
                utilityStep++;
                return false;
            }

            var block = new MaterialPropertyBlock();
            utilityWater.GetPropertyBlock(block);
            var phase = block.GetFloat(UtilityPhase);
            var drip = block.GetVector(UtilityDrip);
            if (utilityStep == 1)
            {
                if ((utilityCaptured & 1) == 0 && utilityArc.enabled &&
                    GameObject.Find("Expelled hot copper sparks").GetComponent<ParticleSystem>().particleCount > 0)
                {
                    CaptureUtility("65-Live-ConduitArc", new Vector3(-1.48f,1.71f,.62f), new Vector3(-3.32f,1.27f,3.53f));
                    utilityCaptured |= 1;
                }
                if ((utilityCaptured & 2) == 0 && drip.w > 0f && phase > drip.z)
                {
                    CaptureUtility("66-Live-Water", new Vector3(-3.01f,1.55f,6.45f), new Vector3(-6.59f,.25f,8.42f));
                    utilityCaptured |= 2;
                }
                utilityFlame.GetPropertyBlock(block);
                if ((utilityCaptured & 4) == 0 && block.GetFloat(UtilityPhase) > .25f && block.GetFloat(UtilityLoad) > .1f)
                {
                    CaptureUtility("67-Live-Pilot", new Vector3(4.69f,1.54f,10.85f), new Vector3(7.28f,.68f,13.40f));
                    utilityCaptured |= 4;
                }
                if (utilityCaptured != 7) return false;
                utilityPausePhase = phase;
                Time.timeScale = 0f;
                utilityStep++;
                return false;
            }
            if (utilityStep == 2)
            {
                Time.timeScale = 1f;
                Require(Mathf.Approximately(phase,utilityPausePhase), "Runoff holds its phase when paused");
                ChapterSceneLink.ReducedMotion = true;
                utilityStep++;
                return false;
            }
            if (phase > 0f) return false;
            Require(!utilityArc.enabled && drip.w == 0f, "Reduced Motion settles live arc and runoff");
            Place(utilityStart);
            utilityStep++;
            return false;
        }

        private static void CaptureUtility(string name, Vector3 origin, Vector3 target)
        {
            var camera = Camera.main;
            var position = camera.transform.position;
            var rotation = camera.transform.rotation;
            try
            {
                camera.transform.SetPositionAndRotation(origin, Quaternion.LookRotation(target-origin));
                StormworksSmoke.Capture(camera, name);
            }
            finally
            {
                camera.transform.SetPositionAndRotation(position, rotation);
            }
        }

        private static string Objective() => GameObject.Find("Current objective").GetComponent<Text>().text;
        private static Room01Player Player() => UnityEngine.Object.FindFirstObjectByType<Room01Player>();
        private static Room01Gate Gate() => UnityEngine.Object.FindFirstObjectByType<Room01Gate>();
        private static bool GateBlocked() => Physics.Raycast(new Vector3(0, 0.7f, 17), Vector3.forward, 2f);

        private static void SetKey(params Key[] keys)
        {
            InputSystem.QueueStateEvent(keyboard, new KeyboardState(keys));
            InputSystem.Update();
        }

        private static void MoveNear(string name, Vector3 offset)
        {
            var target = GameObject.Find(name).transform.position + offset;
            Place(new Vector3(target.x, 0.04f, target.z));
        }

        private static void Place(Vector3 target)
        {
            var controller = Player().GetComponent<CharacterController>();
            controller.enabled = false;
            controller.transform.position = target;
            controller.enabled = true;
            Physics.SyncTransforms();
        }

        private static Button FindButton(string name) =>
            UnityEngine.Object.FindObjectsByType<Button>(FindObjectsInactive.Include, FindObjectsSortMode.None)
                .Single(button => button.gameObject.name == name);

        private static bool HasButton(string name) => FindButton(name).gameObject.activeInHierarchy;
        private static bool InteractionIs(string caption)
        {
            var button = FindButton("Inspect  [E]");
            return button.gameObject.activeInHierarchy && button.GetComponentInChildren<Text>().text == caption;
        }
        private static Slider FindSlider(string name) => GameObject.Find(name).GetComponent<Slider>();

        private static void Press(string name)
        {
            var button = FindButton(name);
            if (!button.gameObject.activeInHierarchy || !button.interactable)
                throw new InvalidOperationException("Control unavailable: " + name);
            button.onClick.Invoke();
        }

        private static void Require(bool result, string label)
        {
            if (!result) throw new InvalidOperationException(label);
            checks++;
        }

        private static void Finish(int code)
        {
            Stop();
            EditorApplication.Exit(code);
        }

        private static void Stop()
        {
            SessionState.EraseBool(DirectRoom);
            SessionState.EraseBool(Running);
            SessionState.EraseBool(Connected);
            EditorApplication.update -= Advance;
            if (keyboard != null && keyboard.added) InputSystem.RemoveDevice(keyboard);
        }
    }
}
