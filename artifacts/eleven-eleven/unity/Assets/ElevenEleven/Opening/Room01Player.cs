using System;
using System.Collections;
using System.Threading.Tasks;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.InputSystem;
using UnityEngine.UI;

namespace ElevenEleven.Opening
{
    [RequireComponent(typeof(CharacterController))]
    public sealed class Room01Player : MonoBehaviour
    {
        [SerializeField] private Transform school;
        [SerializeField] private Animation schoolMotion;
        [SerializeField] private AnimationClip schoolIdle;
        [SerializeField] private AnimationClip schoolWalk;
        [SerializeField] private AnimationClip schoolRun;
        [SerializeField] private Camera roomCamera;
        [SerializeField] private LayerMask cameraObstacles;
        [SerializeField] private Room01TouchStick touchMove;
        [SerializeField] private Transform[] landmarks;
        [SerializeField] private Transform terminal;
        [SerializeField] private Transform conduit;
        [SerializeField] private Light conduitSignal;
        [SerializeField] private Room01SignalTuner tuner;
        [SerializeField] private Room01Gate gate;
        [SerializeField] private Text objective;
        [SerializeField] private Text observation;
        [SerializeField] private Button inspect;
        [SerializeField] private GameObject inspection;
        [SerializeField] private Text inspectionText;
        [SerializeField] private Button keep;
        [SerializeField] private ChapterSceneLink titleLink;
        [SerializeField] private Text saveStatus;
        [SerializeField] private StormworksRoute station;
        [SerializeField] private Button jumpControl;
        [SerializeField] private Button skipVista;
        [SerializeField] private Text stationObservation;
        private readonly EchoFollowCamera followCamera = new EchoFollowCamera();
        private Vector3 planarVelocity;
        private float turnInput;
        private float jumpBuffer;
        private float groundGrace;

        private static readonly string[] InspectionNotes =
        {
            "The stopped clock\nBoth hands are still.",
            "A personal trace\nThe photograph has worn away, but something familiar remains."
        };

        private enum Target { None, Evidence, Terminal, Conduit }
        private CharacterController controller;
        private int nextClue;
        private const float WalkSpeed = 1.55f;
        private const float AuthoredWalkSpeed = 1.3587f;
        private string locomotion = "Idle";
        private bool signalAligned;
        private bool powered;
        private bool crossed;
        private Vector3 spawnPosition;
        public bool IsStaged { get; private set; }
        internal bool HasGroundContact => controller != null && controller.isGrounded;
        private Text inspectLabel;
        private float verticalSpeed;
        private float viewYaw;
        private float viewPitch = 13f;
        private Task<bool> initialSave;

        private void Awake()
        {
            controller = GetComponent<CharacterController>();
            schoolMotion.AddClip(schoolIdle, "Idle");
            schoolMotion.AddClip(schoolWalk, "Walk");
            if (schoolRun != null) schoolMotion.AddClip(schoolRun, "Run");
            schoolIdle.SampleAnimation(schoolMotion.gameObject, 0f);
            schoolMotion.Play("Idle");
            inspectLabel = inspect.GetComponentInChildren<Text>(true);
            tuner.Closed += OnTunerClosed;
            RefreshObjective();
            UpdateCamera();
        }

        private void OnDestroy()
        {
            if (tuner != null) tuner.Closed -= OnTunerClosed;
        }

        private void Start()
        {
            spawnPosition = transform.position;
            if (!IsStaged) EnterGameplay(false);
        }

        internal void HoldForStaging() => IsStaged = true;

        internal void ReleaseFromStaging()
        {
            if (!IsStaged) return;
            IsStaged = false;
            EnterGameplay(true);
        }

        private void EnterGameplay(bool fromStaging)
        {
            var state = ChapterSaveSession.TakeRestore();
            if (state == null)
            {
                if (fromStaging) SaveInitialCheckpoint();
                else SaveCheckpoint();
                return;
            }

            nextClue = state.Memory ? 2 : state.Clock ? 1 : 0;
            signalAligned = state.Terminal;
            powered = state.Conduit;
            crossed = state.Ending;
            tuner.Restore(state);
            station?.Restore(state.StationStage, state.ArchiveFragments, state.ReactorBreakers);
            if (powered) ShowPower();
            if (signalAligned && powered) gate.RestoreOpen();
            if (crossed) Place(station != null && station.Stage > 0 ? station.ReturnPoint : gate.ResumePosition);
            RefreshObjective();
            RefreshInteraction();
        }

        private void Update()
        {
            if (IsStaged)
            {
                if (!HasGroundContact) Move(Vector2.zero, Time.deltaTime);
                return;
            }
            var keyboard = Keyboard.current;
            var pad = Gamepad.current;
            var dt = Time.deltaTime;
            if (station != null && station.GameplayHeld)
            {
                if (keyboard?.escapeKey.wasPressedThisFrame == true || pad?.buttonEast.wasPressedThisFrame == true ||
                    (station.InReveal && ChapterSceneLink.ReducedMotion)) station.EndReveal();
                else
                {
                    station.Tick(this, dt, false, crossed);
                    skipVista.gameObject.SetActive(station.GameplayHeld);
                    return;
                }
                skipVista.gameObject.SetActive(false);
            }
            if (inspection.activeSelf || tuner.IsOpen)
            {
                station?.Tick(this, dt, true, crossed);
                if (keyboard?.escapeKey.wasPressedThisFrame == true || pad?.buttonEast.wasPressedThisFrame == true)
                {
                    if (tuner.IsOpen) tuner.Close();
                    else CloseInspection();
                }
                return;
            }

            var move = touchMove.Value;
            if (keyboard != null)
                move += new Vector2(
                    Axis(keyboard.aKey.isPressed || keyboard.leftArrowKey.isPressed, keyboard.dKey.isPressed || keyboard.rightArrowKey.isPressed),
                    Axis(keyboard.sKey.isPressed || keyboard.downArrowKey.isPressed, keyboard.wKey.isPressed || keyboard.upArrowKey.isPressed));
            if (pad != null) move += pad.leftStick.ReadValue();

            var look = (pad?.rightStick.ReadValue() ?? Vector2.zero) * (110f * Time.deltaTime);
            var mouse = Mouse.current;
            if (mouse?.rightButton.isPressed == true) look += mouse.delta.ReadValue() * 0.18f;
            turnInput = look.x;
            viewYaw += look.x;
            viewPitch = Mathf.Clamp(viewPitch - look.y, 4f, 42f);

            if (keyboard?.spaceKey.wasPressedThisFrame == true || pad?.buttonSouth.wasPressedThisFrame == true)
                RequestJump();
            var sprint = keyboard?.leftShiftKey.isPressed == true || pad?.leftStickButton.isPressed == true;
            Move(Vector2.ClampMagnitude(move, 1f), dt, sprint);
            if (transform.position.y < -4f)
            {
                Place(station != null && station.Stage > 0 ? station.ReturnPoint :
                    crossed ? gate.ResumePosition : spawnPosition);
                observation.text = "Returned to the last safe position";
            }
            if (!crossed && gate.HasCrossed(transform.position))
            {
                crossed = true;
                observation.text = "Blast gate crossed";
                SaveCheckpoint();
            }
            if (station != null)
            {
                station.Tick(this, dt, false, crossed);
                if (skipVista.gameObject.activeSelf != station.GameplayHeld) skipVista.gameObject.SetActive(station.GameplayHeld);
                var showJump = station.Stage > 0 && !station.GameplayHeld && (Touchscreen.current != null ||
                    Application.isMobilePlatform);
                if (jumpControl.gameObject.activeSelf != showJump) jumpControl.gameObject.SetActive(showJump);
            }
            RefreshObjective();
            RefreshInteraction();
            if (inspect.gameObject.activeSelf && (keyboard?.eKey.wasPressedThisFrame == true || pad?.buttonWest.wasPressedThisFrame == true))
                OpenInspection();
        }

        private void LateUpdate() => UpdateCamera();

        private static float Axis(bool negative, bool positive) => (positive ? 1f : 0f) - (negative ? 1f : 0f);

        private void Move(Vector2 input, float deltaTime, bool sprint = false)
        {
            var travel = Quaternion.Euler(0f, viewYaw, 0f) * new Vector3(input.x, 0f, input.y);
            if (travel.sqrMagnitude > 0.01f)
                school.rotation = Quaternion.RotateTowards(school.rotation, Quaternion.LookRotation(travel), 720f * deltaTime);
            var freeTraversal = station != null && station.Stage > 0 && !IsStaged;
            var grounded = controller.isGrounded && verticalSpeed <= 0f;
            var desired = travel * (freeTraversal ? sprint ? 3.45f : 2.45f : WalkSpeed);
            if (station == null || IsStaged) planarVelocity = desired;
            else
            {
                var response = grounded ? (input.sqrMagnitude > 0.001f ? 13f : 26f) : 5f;
                planarVelocity = Vector3.Lerp(planarVelocity, desired, 1f - Mathf.Exp(-response * deltaTime));
            }

            groundGrace = grounded ? 0.10f : Mathf.Max(0f, groundGrace - deltaTime);
            verticalSpeed = grounded ? -1f : Mathf.Max(-18f, verticalSpeed - 20f * deltaTime);
            if (freeTraversal && jumpBuffer > 0f && groundGrace > 0f)
            {
                verticalSpeed = 7.15f;
                groundGrace = jumpBuffer = 0f;
            }
            jumpBuffer = Mathf.Max(0f, jumpBuffer - deltaTime);

            var before = transform.position;
            var flags = controller.Move((planarVelocity + Vector3.up * verticalSpeed) * deltaTime);
            if ((flags & CollisionFlags.Above) != 0 && verticalSpeed > 0f) verticalSpeed = 0f;
            if (!grounded && controller.isGrounded && verticalSpeed < -2.5f && !IsStaged)
            {
                followCamera.Land(-verticalSpeed);
                station?.Land(transform.position, -verticalSpeed / 9f);
            }
            var displacement = transform.position - before;
            var speed = new Vector2(displacement.x, displacement.z).magnitude / Mathf.Max(deltaTime, 0.0001f);
            PlayLocomotion(freeTraversal && !controller.isGrounded ? 0f : speed);
        }

        private void PlayLocomotion(float speed)
        {
            var speedThreshold = locomotion == "Run" ? 2.67f : 2.89f;
            var clip = speed <= 0.04f ? "Idle" : schoolRun != null && speed > speedThreshold ? "Run" : "Walk";
            if (clip != locomotion)
            {
                locomotion = clip;
                schoolMotion.CrossFade(clip, 0.105f);
            }
            if (clip == "Walk") schoolMotion[clip].speed = Mathf.Clamp(speed / AuthoredWalkSpeed, 0.4f, 3.5f);
            if (clip == "Run") schoolMotion[clip].speed = Mathf.Clamp(speed / 3.3f, 0.8f, 1.17f);
        }

        private void UpdateCamera()
        {
            if (station != null)
            {
                followCamera.Draw(roomCamera, transform.position, planarVelocity, viewPitch, viewYaw,
                    turnInput, cameraObstacles, station, Time.deltaTime);
                return;
            }
            var focus = transform.position + Vector3.up * 1.4f;
            var orbit = Quaternion.Euler(viewPitch, viewYaw, 0f);
            var back = orbit * Vector3.back;
            var distance = 3.6f;
            if (Physics.SphereCast(focus, 0.19f, back, out var hit, distance, cameraObstacles, QueryTriggerInteraction.Ignore))
                distance = Mathf.Max(0.12f, hit.distance - 0.08f);
            roomCamera.transform.SetPositionAndRotation(focus + back * distance, orbit);
        }

        private float DistanceSquared(Transform item)
        {
            var delta = item.position - transform.position;
            return delta.x * delta.x + delta.z * delta.z;
        }

        private Target Nearby()
        {
            if (nextClue < landmarks.Length)
                return DistanceSquared(landmarks[nextClue]) <= 2.1f * 2.1f ? Target.Evidence : Target.None;
            var terminalDistance = signalAligned ? float.PositiveInfinity : DistanceSquared(terminal);
            var conduitDistance = powered ? float.PositiveInfinity : DistanceSquared(conduit);
            if (terminalDistance <= 1.55f * 1.55f &&
                (conduitDistance > 1.5f * 1.5f || terminalDistance <= conduitDistance))
                return Target.Terminal;
            return conduitDistance <= 1.5f * 1.5f ? Target.Conduit : Target.None;
        }

        private void RefreshInteraction()
        {
            var nearby = Nearby();
            var routeAction = crossed ? station?.Action(transform.position) : null;
            var copy = !string.IsNullOrEmpty(routeAction) ? routeAction : nearby switch
            {
                Target.Evidence => "Inspect  [E]",
                Target.Terminal => "Tune signal  [E]",
                Target.Conduit => "Energize  [E]",
                _ => "",
            };
            if (inspectLabel.text != copy) inspectLabel.text = copy;
            if (inspect.gameObject.activeSelf != (copy.Length > 0)) inspect.gameObject.SetActive(copy.Length > 0);
        }

        public void OpenInspection()
        {
            if (crossed && station != null && !string.IsNullOrEmpty(station.Action(transform.position)))
            {
                station.Interact(this);
                return;
            }
            if (inspection.activeSelf || tuner.IsOpen) return;
            switch (Nearby())
            {
                case Target.Evidence:
                    BeginModal();
                    inspectionText.text = InspectionNotes[nextClue];
                    keep.GetComponentInChildren<Text>().text = nextClue == 0 ? "Keep this trace" : "Follow the trace";
                    inspection.SetActive(true);
                    if (EventSystem.current != null) EventSystem.current.SetSelectedGameObject(keep.gameObject);
                    break;
                case Target.Terminal:
                    BeginModal();
                    tuner.Open();
                    break;
                case Target.Conduit:
                    powered = true;
                    ShowPower();
                    observation.text = "Conduit energized";
                    CheckGate();
                    RefreshInteraction();
                    SaveCheckpoint();
                    break;
            }
        }

        public void KeepObservation()
        {
            if (!inspection.activeSelf) return;
            observation.text = nextClue == 0 ? "Clock examined" : "Personal trace examined";
            nextClue++;
            CloseInspection();
            RefreshObjective();
            SaveCheckpoint();
        }

        public void CloseInspection()
        {
            if (!inspection.activeSelf) return;
            inspection.SetActive(false);
            EndModal();
        }

        private void OnTunerClosed(bool aligned)
        {
            if (aligned)
            {
                signalAligned = true;
                observation.text = "Signal aligned";
                CheckGate();
            }
            EndModal();
            SaveCheckpoint();
        }

        private void ShowPower() => conduitSignal.color = new Color(0.18f, 0.92f, 1f);

        private void Place(Vector3 position)
        {
            controller.enabled = false;
            transform.position = position;
            controller.enabled = true;
            verticalSpeed = groundGrace = jumpBuffer = 0f;
            planarVelocity = Vector3.zero;
            followCamera.Reset();
            PlayLocomotion(0f);
            UpdateCamera();
        }

        public void RequestJump()
        {
            if (station != null && station.Stage > 0 && !station.GameplayHeld)
                jumpBuffer = 0.14f;
        }

        public void SkipStationVista()
        {
            station?.EndReveal();
            if (skipVista != null) skipVista.gameObject.SetActive(false);
        }

        internal void ReturnToSafePoint(Vector3 position, string message)
        {
            Place(position);
            ShowRouteNote(message);
        }

        internal void FaceRouteFocus(Vector3 target)
        {
            var direction = target - transform.position;
            direction.y = 0f;
            if (direction.sqrMagnitude > 0.001f) school.rotation = Quaternion.LookRotation(direction);
        }

        internal void ShowRouteNote(string message)
        {
            stationObservation.gameObject.SetActive(!string.IsNullOrEmpty(message));
            stationObservation.text = message;
        }

        internal void SaveRouteProgress(string message)
        {
            ShowRouteNote(message);
            observation.text = "";
            SaveCheckpoint();
        }

        public void ReturnToTitle()
        {
            SaveCheckpoint();
            titleLink.Begin();
        }

        private Room01Checkpoint CaptureCheckpoint()
        {
            var state = new Room01Checkpoint
            {
                Wake = true, Clock = nextClue >= 1, Photo = nextClue >= 2, Memory = nextClue >= 2,
                Terminal = signalAligned, Conduit = powered, Ending = crossed,
                StationStage = station?.Stage ?? 0, ArchiveFragments = station?.MemoryFragments ?? 0,
                ReactorBreakers = station?.PoweredBreakers ?? 0,
            };
            tuner.Capture(state);
            return state;
        }

        private void SaveInitialCheckpoint()
        {
            var snapshot = CaptureCheckpoint();
            var path = ChapterSaveSession.SavePath;
            initialSave = Task.Run(() => snapshot.Save(path));
            StartCoroutine(ReportInitialSave(initialSave));
        }

        private IEnumerator ReportInitialSave(Task<bool> write)
        {
            while (!write.IsCompleted) yield return null;
            if (initialSave == write) CompleteInitialSave();
        }

        private void CompleteInitialSave()
        {
            var write = initialSave;
            if (write == null) return;
            initialSave = null;
            try
            {
                ReportSave(write.GetAwaiter().GetResult());
            }
            catch (Exception error)
            {
                Debug.LogException(error, this);
                ReportSave(false);
            }
        }

        private void OnApplicationQuit() => CompleteInitialSave();

        private void SaveCheckpoint()
        {
            CompleteInitialSave();
            ReportSave(CaptureCheckpoint().Save(ChapterSaveSession.SavePath));
        }

        private void ReportSave(bool success) => saveStatus.text = success ? "" : "Could not save this checkpoint.";

        private void BeginModal()
        {
            planarVelocity = Vector3.zero;
            jumpBuffer = 0f;
            PlayLocomotion(0f);
            inspect.gameObject.SetActive(false);
            touchMove.gameObject.SetActive(false);
        }

        private void EndModal()
        {
            touchMove.gameObject.SetActive(true);
            RefreshInteraction();
            if (EventSystem.current != null)
                EventSystem.current.SetSelectedGameObject(inspect.gameObject.activeSelf ? inspect.gameObject : null);
        }

        private void CheckGate()
        {
            if (signalAligned && powered) gate.Open();
            RefreshObjective();
        }

        private void RefreshObjective()
        {
            var copy = nextClue switch
            {
                0 => "Find the stopped clock.",
                1 => "Find the personal trace.",
                _ when crossed => station?.Objective(transform.position) ?? "The signal leads deeper into Sector 11.",
                _ when gate.IsOpen => "Cross the blast gate.",
                _ when powered && signalAligned => "The blast gate is opening.",
                _ when signalAligned => "Energize the power conduit.",
                _ when powered => "Align the signal at the terminal.",
                _ => "Align the terminal and energize the conduit.",
            };
            if (objective.text != copy) objective.text = copy;
        }
    }
}
