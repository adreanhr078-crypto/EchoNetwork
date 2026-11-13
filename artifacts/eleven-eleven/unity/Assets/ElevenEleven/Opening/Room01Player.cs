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
        private bool walking;
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
            if (powered) ShowPower();
            if (signalAligned && powered) gate.RestoreOpen();
            if (crossed) Place(gate.ResumePosition);
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
            if (inspection.activeSelf || tuner.IsOpen)
            {
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
            viewYaw += look.x;
            viewPitch = Mathf.Clamp(viewPitch - look.y, 4f, 42f);

            Move(Vector2.ClampMagnitude(move, 1f), Time.deltaTime);
            if (transform.position.y < -4f)
            {
                Place(crossed ? gate.ResumePosition : spawnPosition);
                observation.text = "Returned to the last safe position";
            }
            if (!crossed && gate.HasCrossed(transform.position))
            {
                crossed = true;
                observation.text = "Blast gate crossed";
                SaveCheckpoint();
            }
            RefreshObjective();
            RefreshInteraction();
            if (inspect.gameObject.activeSelf && (keyboard?.eKey.wasPressedThisFrame == true || pad?.buttonWest.wasPressedThisFrame == true))
                OpenInspection();
        }

        private void LateUpdate() => UpdateCamera();

        private static float Axis(bool negative, bool positive) => (positive ? 1f : 0f) - (negative ? 1f : 0f);

        private void Move(Vector2 input, float deltaTime)
        {
            var travel = Quaternion.Euler(0f, viewYaw, 0f) * new Vector3(input.x, 0f, input.y);
            if (travel.sqrMagnitude > 0.01f)
                school.rotation = Quaternion.RotateTowards(school.rotation, Quaternion.LookRotation(travel), 720f * deltaTime);
            verticalSpeed = controller.isGrounded ? -1f : Mathf.Max(-18f, verticalSpeed - 20f * deltaTime);
            var before = transform.position;
            controller.Move((travel * WalkSpeed + Vector3.up * verticalSpeed) * deltaTime);
            var displacement = transform.position - before;
            var speed = new Vector2(displacement.x, displacement.z).magnitude / Mathf.Max(deltaTime, 0.0001f);
            PlayLocomotion(speed);
        }

        private void PlayLocomotion(float speed)
        {
            var moving = speed > 0.04f;
            if (moving != walking)
            {
                walking = moving;
                schoolMotion.Play(walking ? "Walk" : "Idle");
            }
            if (walking) schoolMotion["Walk"].speed = Mathf.Clamp(speed / AuthoredWalkSpeed, 0.4f, 3.5f);
        }

        private void UpdateCamera()
        {
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
            var copy = nearby switch
            {
                Target.Evidence => "Inspect  [E]",
                Target.Terminal => "Tune signal  [E]",
                Target.Conduit => "Energize  [E]",
                _ => "",
            };
            if (inspectLabel.text != copy) inspectLabel.text = copy;
            inspect.gameObject.SetActive(nearby != Target.None);
        }

        public void OpenInspection()
        {
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
            verticalSpeed = 0f;
            PlayLocomotion(0f);
            UpdateCamera();
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
                _ when crossed => "The signal leads deeper into Sector 11.",
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
