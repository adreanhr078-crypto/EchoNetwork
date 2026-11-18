using System;
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
        private const string Deadline = "ElevenEleven.R01.Deadline";
        private static int stage;
        private static int checks;
        private static Keyboard keyboard;
        private static Vector3 startPosition;
        private static int waitFrames;
        private static bool conduitFirst;
        private static AsyncOperation reload;

        static ChapterR01Smoke()
        {
            if (SessionState.GetBool(Running, false)) EditorApplication.update += Advance;
        }

        public static void Run()
        {
            if (!Application.isBatchMode) throw new InvalidOperationException("Use Unity batch mode.");
            ChapterSceneBuilder.OpenRegisteredTitle();
            SessionState.SetBool(Running, true);
            SessionState.SetFloat(Deadline, (float)EditorApplication.timeSinceStartup + 120f);
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
                    throw new TimeoutException($"Chapter entry stalled at stage {stage}.");
                if (!EditorApplication.isPlaying) return;

                var scene = SceneManager.GetActiveScene().name;
                switch (stage)
                {
                    case 0 when scene == "ChapterTitle" && FindButton("Chapter entry").interactable:
                        Application.targetFrameRate = 45;
                        Application.runInBackground = true;
                        InputSystem.settings.backgroundBehavior = InputSettings.BackgroundBehavior.IgnoreFocus;
                        InputSystem.settings.editorInputBehaviorInPlayMode = InputSettings.EditorInputBehaviorInPlayMode.AllDeviceInputAlwaysGoesToGameView;
                        Press("Motion on");
                        Require(ChapterSceneLink.ReducedMotion, "Title exposes reduced motion");
                        stage = 14;
                        break;
                    case 14 when scene == "ChapterTitle" && HasButton("Chapter entry") && FindButton("Chapter entry").interactable:
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
                        Press("Continue");
                        Require(film.Beat == OpeningBeat.Complete, "Wake fires the room handoff");
                        stage++;
                        break;
                    case 3 when scene == "ChapterRoom01":
                        var player = UnityEngine.Object.FindFirstObjectByType<Room01Player>();
                        var bones = player.GetComponentsInChildren<SkinnedMeshRenderer>().SelectMany(skin => skin.bones).Distinct().Count();
                        Require(bones == 65 && !player.name.Contains("V31"), "Normal entry spawns School65");
                        Require(Camera.main != null && Camera.main.isActiveAndEnabled, "Room camera owns the view");
                        Require(player.GetComponentInChildren<Animation>().IsPlaying("Idle"), "First playable frame uses School Idle");
                        Require(Objective() == "Find the stopped clock.", "Arrival starts at the first clue");
                        Require(Physics.Raycast(new Vector3(0, 0.7f, 17), Vector3.forward, 2f), "North exit is sealed");
                        keyboard = InputSystem.AddDevice<Keyboard>();
                        keyboard.MakeCurrent();
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
                        Physics.SyncTransforms();
                        Require(!GateBlocked(), "Open door clears the physical opening");
                        Place(new Vector3(0, 0.04f, 16.6f));
                        SetKey(Key.W);
                        stage++;
                        break;
                    case 12:
                        if (Player().transform.position.z < 19.05f) return;
                        SetKey();
                        Require(Objective() == "The signal leads deeper into Sector 11.", "Walking through the door completes the threshold");
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
            SessionState.EraseBool(Running);
            EditorApplication.update -= Advance;
            if (keyboard != null && keyboard.added) InputSystem.RemoveDevice(keyboard);
            EditorApplication.Exit(code);
        }
    }
}
