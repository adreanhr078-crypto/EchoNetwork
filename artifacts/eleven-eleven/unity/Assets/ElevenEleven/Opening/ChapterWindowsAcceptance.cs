#if ECHO_R10_PLAYER_PROBE
using System;
using System.Collections;
using System.IO;
using System.Linq;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.EventSystems;
using UnityEngine.InputSystem.LowLevel;
using UnityEngine.SceneManagement;
using UnityEngine.UI;

namespace ElevenEleven.Opening
{
    internal sealed class ChapterWindowsAcceptance : MonoBehaviour
    {
        private string output;
        private Gamepad pad;
        private Room01Player actor;
        private int checks;
        private float travelled;

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        private static void StartProbe()
        {
            var output = Environment.GetEnvironmentVariable("ECHO_R10_CAPTURE_DIRECTORY");
            if (string.IsNullOrWhiteSpace(output)) return;
            if (string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("ECHO_R02_FIXTURE_DIRECTORY")))
            {
                Application.Quit(1);
                throw new InvalidOperationException("The Windows review requires an isolated save directory.");
            }
            var probe = new GameObject("Windows chapter route review").AddComponent<ChapterWindowsAcceptance>();
            DontDestroyOnLoad(probe.gameObject);
            probe.output = output;
            Application.runInBackground = true;
            Application.targetFrameRate = 45;
            probe.StartCoroutine(probe.Run());
        }

        private IEnumerator Run()
        {
            yield return null;
            Require(SceneManager.GetActiveScene().name == "ChapterTitle",
                "The public build registers the native title first.");
            yield return Await(() => Button("Chapter entry")?.interactable == true, "startup scene preparation");
            Require(GameObject.Find("Chapter loading") == null,
                "An empty save starts on the public title.");
            Directory.CreateDirectory(output);
            var title = FindFirstObjectByType<ChapterTitle>();
            Require(EntryCopy.Arabic && Button("Chapter entry").GetComponentInChildren<Text>().text == EntryCopy.Start,
                "The native title opens with the original Arabic preference.");
            yield return Await(() => title.ShowingVideo && title.VideoFrame >= 24, "decoded title frame");
            CaptureUi(title.GetComponent<Canvas>(), "00-title-ar.png");
            yield return Await(() => title.CompletedLoops >= 2 && title.VideoFrame >= 8 && title.VideoFrame < 45, "two title video wraps");
            Require(title.ShowingVideo, "The decoded video survives two infinite loop boundaries.");
            Press("Sound off");
            Require(!ChapterSceneLink.Muted && title.GetComponent<AudioSource>().isPlaying, "Water SFX toggles on.");
            Press("Sound off");
            Require(ChapterSceneLink.Muted && !title.GetComponent<AudioSource>().isPlaying, "Water SFX mutes.");
            Press("Motion on");
            Require(!title.ShowingVideo && ChapterSceneLink.ReducedMotion, "Reduced motion replaces video with its matching poster.");
            if (Environment.GetEnvironmentVariable("ECHO_R10_REDUCED_MOTION") != "1")
            {
                Press("Motion on");
                yield return Await(() => title.ShowingVideo, "resume video from poster");
            }
            Require(GameObject.Find("Chapter loading") == null, "Startup loading is gone before the entry button.");
            Press("Chapter entry");
            Require(GameObject.Find("Chapter loading") == null, "The ready scene enters without a loading panel.");
            yield return Await(() => SceneManager.GetActiveScene().name == "ChapterOpening", "opening");
            yield return null;
            var cover = FindFirstObjectByType<CoverRecoveryPresenter>();
            var canvas = cover.GetComponentInParent<Canvas>();
            CaptureUi(canvas, "01-cover-ar.png");
            Press("Language");
            Require(!EntryCopy.Arabic && GameObject.Find("Heading").GetComponent<Text>().text == EntryCopy.CoverTitle,
                "English copy changes on the real puzzle.");
            CaptureUi(canvas, "02-cover-en.png");
            Press("View or hide cover");
            Require(!Button("Piece 1").interactable && GameObject.Find("Full Cover") != null,
                "The reference displays the uncut image and suspends tile interaction.");
            CaptureUi(canvas, "03-reference.png");
            Press("View or hide cover");
            Require(Button("Piece 1").interactable && GameObject.Find("Full Cover") == null, "Closing the reference restores input.");
            var origin = Button("Piece 1").GetComponent<CoverTileInput>();
            var destination = Button("Piece 2").GetComponent<CoverTileInput>();
            var originUv = origin.GetComponent<RawImage>().uvRect;
            var pointer = new PointerEventData(EventSystem.current)
            {
                button = PointerEventData.InputButton.Left,
                pointerDrag = origin.gameObject,
                position = new Vector2(400, 420),
                pointerCurrentRaycast = new RaycastResult { gameObject = destination.gameObject }
            };
            origin.OnBeginDrag(pointer);
            Require(GameObject.Find("Cover piece preview") != null, "Dragging creates a nonblocking image preview.");
            CaptureUi(canvas, "04-drag.png");
            origin.OnEndDrag(pointer);
            Require(origin.GetComponent<RawImage>().uvRect == originUv, "A cancelled drag leaves the board unchanged.");
            origin.OnBeginDrag(pointer);
            destination.OnDrop(pointer);
            origin.OnEndDrag(pointer);
            Require(origin.GetComponent<RawImage>().uvRect != originUv && Button("Undo").interactable, "Dropping swaps the two pieces.");
            Press("Undo");
            Require(origin.GetComponent<RawImage>().uvRect == originUv && !Button("Undo").interactable, "Undo restores the previous permutation.");
            Press("Piece 1");
            Press("Piece 2");
            Press("Shuffle again");
            Require(origin.GetComponent<RawImage>().uvRect == originUv, "Shuffle restores the canonical start order.");
            foreach (var name in new[] { "Piece 1", "Piece 2", "Piece 5", "Piece 6" }) Press(name);
            Require(cover.IsSolved, "Two original swaps solve the cover.");
            var film = FindFirstObjectByType<OpeningCinematicPresenter>(FindObjectsInactive.Include);
            yield return Await(() => film != null && film.isActiveAndEnabled, "cover resolution");
            var filmCanvas = film.GetComponentInParent<Canvas>();
            var video = film.GetComponent<UnityEngine.Video.VideoPlayer>();
            var audio = film.GetComponent<AudioSource>();
            var full = !ChapterSceneLink.ReducedMotion;
            if (full)
            {
                yield return Await(() => film.ShowingVideo && video.frame >= 18, "school playback");
                Require(video.audioOutputMode == UnityEngine.Video.VideoAudioOutputMode.AudioSource &&
                    video.controlledAudioTrackCount == 1 && video.GetTargetAudioSource(0) == audio,
                    "School video routes its embedded soundtrack through the scene audio source.");
                Require(!film.CanSkip && !Button("Skip shot").interactable, "Skip stays hidden before ten seconds.");
                Press("Sound on");
                Require(!audio.mute, "Sound toggle unmutes the embedded mix.");
                Press("Pause");
                Require(film.Paused && !video.isPlaying, "Pause suspends the cinematic.");
                Press("Pause");
                Require(!film.Paused, "Resume releases the pause.");
                CaptureUi(filmCanvas, "05-school-film.png");
                yield return Await(() => film.Beat == OpeningBeat.Laboratory, "school automatic end");
                yield return Await(() => film.ShowingVideo && video.frame >= 52, "laboratory playback");
                CaptureUi(filmCanvas, "06-laboratory-film.png");
                yield return Await(() => film.CanSkip, "10 seconds watched");
                Require(Button("Skip shot").interactable, "Skip is available after ten seconds of playback.");
                var skipVisibility = Button("Skip shot").GetComponent<CanvasGroup>();
                yield return Await(() => skipVisibility.alpha >= 0.95f, "skip fade-in");
                CaptureUi(filmCanvas, "06b-delayed-skip.png");
                Press("Skip shot");
                Require(!Button("Skip shot").interactable && Button("Skip shot").transform.localScale.x < 1f,
                    "A skip press immediately locks the button and plays feedback.");
                yield return Await(() => film.Beat == OpeningBeat.Questions, "laboratory automatic end");
            }
            else
            {
                Require(film.Beat == OpeningBeat.School && !film.ShowingVideo, "Reduced motion starts on the school still.");
                Press("Continue");
                Require(film.Beat == OpeningBeat.Laboratory && !film.ShowingVideo, "Reduced motion uses the lab still.");
                Press("Continue");
            }
            Press("I am ready.");
            if (full)
            {
                yield return Await(() => film.Beat == OpeningBeat.Experiment && film.ShowingVideo && video.frame >= 37, "trial playback");
                CaptureUi(filmCanvas, "07-trial-film.png");
                yield return Await(() => film.Beat == OpeningBeat.Experiment && video.frame >= 77, "memory cut during experiment");
                CaptureUi(filmCanvas, "08-memory-in-trial.png");
                yield return Await(() => film.Beat == OpeningBeat.Memory && film.ShowingVideo && video.frame >= 85, "world transition playback");
                CaptureUi(filmCanvas, "09-threshold-film.png");
                yield return Await(() => film.Beat == OpeningBeat.SystemWake, "system wake");
                Require(GameObject.Find("System Wake panel") != null, "The system overlay is present before the room.");
                CaptureUi(filmCanvas, "10-system-wake.png");
            }
            else
            {
                Require(film.Beat == OpeningBeat.Experiment && !film.ShowingVideo, "Reduced motion uses the trial still.");
                Press("Continue");
                Require(film.Beat == OpeningBeat.Memory && !film.ShowingVideo, "Reduced motion uses the threshold still.");
                Press("Continue");
                Require(film.Beat == OpeningBeat.SystemWake, "Reduced motion reaches the system.");
                yield return Await(() => Button("Continue")?.interactable == true, "ready room before wake confirmation");
                CaptureUi(filmCanvas, "10-system-wake.png");
                Press("Continue");
                Require(GameObject.Find("Chapter loading") == null, "Wake enters the prepared room without a loading panel.");
            }
            yield return Await(() => SceneManager.GetActiveScene().name == "ChapterRoom01", "room arrival");
            yield return null;
            actor = FindFirstObjectByType<Room01Player>();
            Require(IsSchool() && Camera.main != null && actor.GetComponentInChildren<Animation>().IsPlaying("Idle"),
                "First gameplay frame retains School65 and the idle animation.");
            Directory.CreateDirectory(output);
            R01WindowsSmoke.Capture(Camera.main, Path.Combine(output, "01-wake.png"));

            InputSystem.settings.backgroundBehavior = InputSettings.BackgroundBehavior.IgnoreFocus;
            pad = InputSystem.AddDevice<Gamepad>();
            pad.MakeCurrent();
            yield return Walk(-0.94f, -1.55f);
            yield return Inspect("Inspect  [E]");
            Press("Keep this trace");
            Require(Objective() == "Find the personal trace.", "Clock changes the next objective.");

            yield return Walk(0.75f, -0.65f);
            yield return Walk(2.78f, 1.5f);
            yield return Inspect("Inspect  [E]");
            Press("Keep this trace");
            Require(Objective() == "Align the terminal and energize the conduit.", "Second clue unlocks both gate tasks.");

            yield return Walk(2.8f, -1.34f);
            yield return Inspect("Tune signal  [E]");
            Slider("Frequency").value = 218;
            Slider("Phase").value = 45;
            Slider("Channel").value = 7;
            Press("Return to room");
            Require(!Gate().IsOpen && Objective() == "Energize the power conduit.", "Alignment alone preserves the gate lock.");

            yield return Walk(0f, 0.65f);
            yield return Walk(0f, 3.2f);
            yield return Walk(-2.48f, 4.0f);
            yield return Inspect("Energize  [E]");
            yield return Await(() => Gate().IsOpen, "physical gate opening");
            Require(Objective() == "Cross the blast gate.", "Opening announces the player's next action.");

            yield return Walk(0f, 8.25f);
            yield return Walk(0f, 16.3f);
            yield return Walk(0f, 19.42f);
            Require(travelled > 30f && actor.transform.position.z > 19.05f && IsSchool() &&
                Objective() == "The signal leads deeper into Sector 11.", "Continuous gamepad motion physically crossed the gate in School65.");
            R01WindowsSmoke.Capture(Camera.main, Path.Combine(output, "02-crossing.png"));
            InputSystem.RemoveDevice(pad);
            Press("Back to title");
            yield return Await(() => SceneManager.GetActiveScene().name == "ChapterTitle" && Button("Chapter entry") != null,
                "title after saving the crossing");
            Require(GameObject.Find("Chapter loading") == null, "Startup loading is gone before the entry button.");
            Press("Chapter entry");
            Require(GameObject.Find("Chapter loading") == null, "The ready scene enters without a loading panel.");
            yield return Await(() => SceneManager.GetActiveScene().name == "ChapterRoom01", "continue from crossing");
            yield return null;
            actor = FindFirstObjectByType<Room01Player>();
            Require(IsSchool() && Gate().IsOpen && actor.transform.position.z > 19.05f &&
                Objective() == "The signal leads deeper into Sector 11.", "Continue restores School65 beyond the open gate.");
            R01WindowsSmoke.Capture(Camera.main, Path.Combine(output, "03-continue.png"));
            var line = $"ENTRY_WINDOWS_ROUTE_PASS checks={checks} walked_metres={travelled:F2} reduced_motion={ChapterSceneLink.ReducedMotion} " +
                $"graphics={SystemInfo.graphicsDeviceType} device={SystemInfo.graphicsDeviceName}";
            Debug.Log(line);
            File.WriteAllText(Path.Combine(output, "route.txt"), line);
            Application.Quit(0);
        }

        private void CaptureUi(Canvas canvas, string name)
        {
            var cameraObject = new GameObject("Entry evidence camera");
            var camera = cameraObject.AddComponent<Camera>();
            camera.enabled = false;
            camera.clearFlags = CameraClearFlags.SolidColor;
            camera.backgroundColor = Color.black;
            var previous = canvas.renderMode;
            try
            {
                canvas.renderMode = RenderMode.ScreenSpaceCamera;
                canvas.worldCamera = camera;
                canvas.planeDistance = 1f;
                Canvas.ForceUpdateCanvases();
                R01WindowsSmoke.Capture(camera, Path.Combine(output, name));
            }
            finally
            {
                canvas.renderMode = previous;
                canvas.worldCamera = null;
                Destroy(cameraObject);
            }
        }

        private IEnumerator Walk(float x, float z)
        {
            var target = new Vector2(x, z);
            var started = Time.realtimeSinceStartupAsDouble;
            var previous = actor.transform.position;
            while (true)
            {
                var position = actor.transform.position;
                travelled += Vector3.Distance(previous, position);
                previous = position;
                var delta = target - new Vector2(position.x, position.z);
                if (delta.magnitude <= 0.13f) break;
                if (Time.realtimeSinceStartupAsDouble - started >= 19.0 || position.y <= -0.25f)
                    Require(false, $"Walk blocked en route to {target}, actor at {position}.");
                SetStick(delta.normalized * Mathf.Clamp(delta.magnitude * 5f, 0.35f, 1f));
                yield return null;
            }
            SetStick(Vector2.zero);
            checks++;
            yield return null;
        }

        private void SetStick(Vector2 value)
        {
            InputSystem.QueueStateEvent(pad, new GamepadState { leftStick = value });
            InputSystem.Update();
        }

        private IEnumerator Inspect(string caption)
        {
            yield return Await(() => Button("Inspect  [E]")?.GetComponentInChildren<Text>()?.text == caption, caption);
            Press("Inspect  [E]");
        }

        private bool IsSchool() => actor != null && !actor.IsStaged && actor.transform.Find("School65 facing") is Transform school &&
            school.GetComponentsInChildren<SkinnedMeshRenderer>().SelectMany(skin => skin.bones).Distinct().Count() == 65;

        private static Room01Gate Gate() => FindFirstObjectByType<Room01Gate>();
        private static string Objective() => GameObject.Find("Current objective")?.GetComponent<Text>().text;
        private static Slider Slider(string name) => FindObjectsByType<Slider>(FindObjectsSortMode.None).Single(value => value.name == name);
        private static Button Button(string name) => FindObjectsByType<Button>(FindObjectsSortMode.None).FirstOrDefault(value => value.name == name);

        private void Press(string name)
        {
            var button = Button(name);
            Require(button != null && button.interactable, "Unavailable public control: " + name);
            button.onClick.Invoke();
        }

        private IEnumerator Await(Func<bool> condition, string stage)
        {
            var deadline = Time.realtimeSinceStartup + 22f;
            while (!condition() && Time.realtimeSinceStartup < deadline) yield return null;
            Require(condition(), "Timed out at " + stage);
        }

        private void Require(bool condition, string reason)
        {
            if (condition)
            {
                checks++;
                return;
            }
            Application.Quit(1);
            throw new InvalidOperationException(reason);
        }
    }
}
#endif
