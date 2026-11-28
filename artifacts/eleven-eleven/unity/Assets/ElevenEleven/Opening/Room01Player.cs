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
        [SerializeField] private AnimationClip schoolJump;
        [SerializeField] private AnimationClip schoolRoll;
        [SerializeField] private AnimationClip schoolMantle;
        [SerializeField] private AnimationClip schoolHang;
        [SerializeField] private AnimationClip pactStrikeBoxing;
        [SerializeField] private AnimationClip pactStrikeHorizontal;
        [SerializeField] private AnimationClip pactStrikeOverhead;
        [SerializeField] private Transform pact;
        [SerializeField] private Animation pactMotion;
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
        private bool schoolJumpInFlight;
        private float schoolJumpRecovery;
        private StationActionFx actionFx;
        private float dodgeTimer;
        private float dodgeCooldown;
        private float dodgeInvulnTimer;
        private Vector3 dodgeDir;
        private bool mantling;
        private float mantleTimer;
        private Vector3 mantleStart;
        private Vector3 mantleEnd;
        private float strikeTimer;
        private float comboResetTimer;
        private int comboIndex;
        private bool queuedCombo;
        private string activeStrikeClip = "Strike";

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
        private const float JumpTakeoffSpeed = 7.15f;
        private const float SchoolJumpLaunchTime = 24f / 30f;
        private const float SchoolJumpContactTime = 42f / 30f;
        private const float SchoolJumpRecoveryTime = 0.12f;
        private string locomotion = "Idle";
        private bool earnedPact;
        private bool signalAligned;
        private bool powered;
        private bool crossed;
        private Vector3 spawnPosition;
        public bool IsStaged { get; private set; }
        internal bool HasGroundContact => controller != null && controller.isGrounded;
        internal bool ConduitPowered => powered;
        internal bool SignalAligned => signalAligned;
        internal bool UtilityMotionPaused => inspection.activeSelf || tuner.IsOpen || (station && station.InExamination);
        private Text inspectLabel;
        private float verticalSpeed;
        private float viewYaw;
        private float viewPitch = 13f;
        private Task<bool> initialSave;

        private void Awake()
        {
            controller = GetComponent<CharacterController>();
            actionFx = GetComponent<StationActionFx>() ?? gameObject.AddComponent<StationActionFx>();
            schoolMotion.AddClip(schoolIdle, "Idle");
            schoolMotion.AddClip(schoolWalk, "Walk");
            if (schoolRun != null) schoolMotion.AddClip(schoolRun, "Run");
            if (schoolJump != null) schoolMotion.AddClip(schoolJump, "Jump");
            if (schoolRoll != null) schoolMotion.AddClip(schoolRoll, "Roll");
            if (schoolMantle != null) schoolMotion.AddClip(schoolMantle, "Mantle");
            if (schoolHang != null) schoolMotion.AddClip(schoolHang, "Hang");
            if (pactMotion != null)
            {
                if (pactStrikeBoxing != null) pactMotion.AddClip(pactStrikeBoxing, "StrikeBoxing");
                if (pactStrikeHorizontal != null) pactMotion.AddClip(pactStrikeHorizontal, "StrikeHorizontal");
                if (pactStrikeOverhead != null) pactMotion.AddClip(pactStrikeOverhead, "StrikeOverhead");
            }
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
            ApplyPactAppearance(state.Zero.Accepted && state.AfterPact < KinjaBeat.WishConfirmed);
            GetComponent<EchoExperimentInjuries>()?.Apply(state.ExaminationCompleted);
            station?.Restore(state.StationStage, state.ArchiveFragments, state.ReactorBreakers, state.ExaminationCompleted, state.Zero, state.AfterPact, state.Ward, state.WardCompress);
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
            if (station != null && station.InExamination)
            {
                station.Tick(this, dt, true, crossed);
                if (keyboard?.escapeKey.wasPressedThisFrame == true || pad?.buttonEast.wasPressedThisFrame == true)
                    CancelExamination();
                return;
            }
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
            if (keyboard?.leftCtrlKey.wasPressedThisFrame == true || keyboard?.cKey.wasPressedThisFrame == true || pad?.buttonEast.wasPressedThisFrame == true)
                RequestDodge();
            var sprint = keyboard?.leftShiftKey.isPressed == true || pad?.leftStickButton.isPressed == true;
            var mouseAttack = mouse?.leftButton.wasPressedThisFrame == true &&
                (EventSystem.current == null || !EventSystem.current.IsPointerOverGameObject()) &&
                station != null && station.Stage > 0 && !station.GameplayHeld && !station.InExamination;
            if (keyboard?.fKey.wasPressedThisFrame == true || pad?.rightShoulder.wasPressedThisFrame == true || mouseAttack)
                RequestPactStrike();
            if (earnedPact && IsPlayingAnyStrike) move = Vector2.zero;
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
            dodgeCooldown = Mathf.Max(0f, dodgeCooldown - deltaTime);
            dodgeInvulnTimer = Mathf.Max(0f, dodgeInvulnTimer - deltaTime);
            strikeTimer = Mathf.Max(0f, strikeTimer - deltaTime);
            if (comboResetTimer > 0f)
            {
                comboResetTimer -= deltaTime;
                if (comboResetTimer <= 0f) comboIndex = 0;
            }
            if (queuedCombo && strikeTimer <= 0f && earnedPact)
            {
                queuedCombo = false;
                RequestPactStrike();
            }

            if (mantling)
            {
                StepMantle(deltaTime);
                return;
            }

            if (dodgeTimer > 0f)
            {
                dodgeTimer = Mathf.Max(0f, dodgeTimer - deltaTime);
                var dashSpeed = earnedPact ? 8.4f : Mathf.Lerp(2.8f, 6.2f, dodgeTimer / 0.42f);
                planarVelocity = dodgeDir * dashSpeed;
                verticalSpeed = controller.isGrounded ? -1f : Mathf.Max(-14f, verticalSpeed - 18f * deltaTime);
                controller.Move((planarVelocity + Vector3.up * verticalSpeed) * deltaTime);
                if (dodgeTimer <= 0f) locomotion = null;
                return;
            }

            var travel = Quaternion.Euler(0f, viewYaw, 0f) * new Vector3(input.x, 0f, input.y);
            if (travel.sqrMagnitude > 0.01f && !IsPlayingAnyStrike)
                ActiveAvatar.rotation = Quaternion.RotateTowards(ActiveAvatar.rotation, Quaternion.LookRotation(travel), 720f * deltaTime);
            var freeTraversal = station != null && station.Stage > 0 && !IsStaged;
            var grounded = controller.isGrounded && verticalSpeed <= 0f;
            var strikeLunge = IsPlayingAnyStrike && strikeTimer > 0.30f ? ActiveAvatar.forward * 2.4f : Vector3.zero;
            var desired = IsPlayingAnyStrike ? strikeLunge : travel * (freeTraversal ? sprint ? 3.45f : 2.45f : WalkSpeed);
            if (station == null || IsStaged) planarVelocity = desired;
            else
            {
                var response = grounded ? (input.sqrMagnitude > 0.001f ? 13f : 26f) : 5f;
                planarVelocity = Vector3.Lerp(planarVelocity, desired, 1f - Mathf.Exp(-response * deltaTime));
            }

            groundGrace = grounded ? 0.13f : Mathf.Max(0f, groundGrace - deltaTime);
            verticalSpeed = grounded ? -1f : Mathf.Max(-18f, verticalSpeed - 20f * deltaTime);
            if (freeTraversal && jumpBuffer > 0f && groundGrace > 0f)
            {
                verticalSpeed = JumpTakeoffSpeed;
                groundGrace = jumpBuffer = 0f;
                schoolJumpInFlight = schoolJump != null && !earnedPact;
                schoolJumpRecovery = 0f;
            }
            jumpBuffer = Mathf.Max(0f, jumpBuffer - deltaTime);

            var before = transform.position;
            var flags = controller.Move((planarVelocity + Vector3.up * verticalSpeed) * deltaTime);
            if ((flags & CollisionFlags.Above) != 0 && verticalSpeed > 0f) verticalSpeed = 0f;
            if (!grounded && controller.isGrounded && verticalSpeed < -2.5f && !IsStaged)
            {
                followCamera.Land(-verticalSpeed);
                station?.Land(transform.position, -verticalSpeed / 9f);
                actionFx?.PlayMantle(transform.position);
            }
            if (freeTraversal && !controller.isGrounded && !earnedPact && verticalSpeed < 2.2f && travel.sqrMagnitude > 0.04f &&
                TryDetectAndStartLedgeMantle(travel.normalized))
                return;

            var displacement = transform.position - before;
            var speed = new Vector2(displacement.x, displacement.z).magnitude / Mathf.Max(deltaTime, 0.0001f);
            if (PlaySchoolJumpPose(deltaTime)) return;
            PlayLocomotion(freeTraversal && !controller.isGrounded ? 0f : speed);
        }

        private bool PlaySchoolJumpPose(float deltaTime)
        {
            if (schoolJumpInFlight)
            {
                if (!controller.isGrounded)
                {
                    var flight = Mathf.Clamp01((JumpTakeoffSpeed - verticalSpeed) / (2f * JumpTakeoffSpeed));
                    SampleSchoolJump(Mathf.Lerp(SchoolJumpLaunchTime, SchoolJumpContactTime, flight));
                    return true;
                }

                schoolJumpInFlight = false;
                schoolJumpRecovery = SchoolJumpRecoveryTime;
                SampleSchoolJump(SchoolJumpContactTime);
                return true;
            }

            if (!controller.isGrounded) schoolJumpRecovery = 0f;
            if (schoolJumpRecovery <= 0f) return false;
            schoolJumpRecovery = Mathf.Max(0f, schoolJumpRecovery - deltaTime);
            if (schoolJumpRecovery <= 0f) return false;
            SampleSchoolJump(SchoolJumpContactTime + (SchoolJumpRecoveryTime - schoolJumpRecovery) * 1.4f);
            return true;
        }

        private void SampleSchoolJump(float time)
        {
            var state = schoolMotion["Jump"];
            state.speed = 0f;
            if (locomotion != "Jump")
            {
                schoolMotion.Play("Jump");
                locomotion = "Jump";
            }
            state.time = time;
            schoolMotion.Sample();
        }

        private void PlayLocomotion(float speed)
        {
            if (earnedPact && IsPlayingAnyStrike) return;
            if (dodgeTimer > 0f || mantling) return;
            var speedThreshold = locomotion == "Run" ? 2.67f : 2.89f;
            var clip = speed <= 0.04f ? "Idle" : schoolRun != null && speed > speedThreshold ? "Run" : "Walk";
            var motion = earnedPact ? pactMotion : schoolMotion;
            if (clip != locomotion)
            {
                locomotion = clip;
                motion.CrossFade(clip, 0.105f);
            }
            if (clip == "Walk") motion[clip].speed = Mathf.Clamp(speed / AuthoredWalkSpeed, 0.4f, 3.5f);
            if (clip == "Run") motion[clip].speed = Mathf.Clamp(speed / 3.3f, 0.8f, 1.17f);
        }

        private void UpdateCamera()
        {
            if (station != null)
            {
                var shot = station.ExaminationShot;
                if (shot != null)
                {
                    var abrupt = ChapterSceneLink.ReducedMotion ||
                        (roomCamera.transform.position - shot.position).sqrMagnitude > 42f;
                    var blend = abrupt ? 1f : 1f - Mathf.Exp(-12f * Time.unscaledDeltaTime);
                    roomCamera.fieldOfView = Mathf.Lerp(roomCamera.fieldOfView, station.ExaminationFov, blend);
                    roomCamera.transform.SetPositionAndRotation(
                        Vector3.Lerp(roomCamera.transform.position, shot.position, blend),
                        Quaternion.Slerp(roomCamera.transform.rotation, shot.rotation, blend));
                    return;
                }
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
            schoolJumpInFlight = false;
            schoolJumpRecovery = 0f;
            dodgeTimer = dodgeInvulnTimer = strikeTimer = comboResetTimer = 0f;
            mantling = queuedCombo = false;
            followCamera.Reset();
            PlayLocomotion(0f);
            UpdateCamera();
        }

        public void RequestJump()
        {
            if (station != null && station.Stage > 0 && !station.GameplayHeld && !station.InExamination)
                jumpBuffer = 0.15f;
        }

        public void RequestDodge()
        {
            if (station == null || station.Stage <= 0 || IsStaged || station.GameplayHeld || station.InExamination || Time.timeScale <= 0f)
                return;
            if (dodgeTimer > 0f || dodgeCooldown > 0f || mantling) return;
            if (!earnedPact && schoolRoll == null) return;

            var keyboard = Keyboard.current;
            var moveInput = keyboard != null
                ? new Vector2(Axis(keyboard.aKey.isPressed || keyboard.leftArrowKey.isPressed, keyboard.dKey.isPressed || keyboard.rightArrowKey.isPressed),
                              Axis(keyboard.sKey.isPressed || keyboard.downArrowKey.isPressed, keyboard.wKey.isPressed || keyboard.upArrowKey.isPressed))
                : Vector2.zero;
            var dir = moveInput.sqrMagnitude > 0.01f
                ? Quaternion.Euler(0f, viewYaw, 0f) * new Vector3(moveInput.x, 0f, moveInput.y).normalized
                : ActiveAvatar.forward;
            dir.y = 0f;
            dodgeDir = dir.sqrMagnitude > 0.001f ? dir.normalized : ActiveAvatar.forward;
            ActiveAvatar.rotation = Quaternion.LookRotation(dodgeDir);

            schoolJumpInFlight = false;
            schoolJumpRecovery = 0f;
            strikeTimer = 0f;
            dodgeTimer = earnedPact ? 0.30f : 0.42f;
            dodgeCooldown = earnedPact ? 0.48f : 0.60f;
            dodgeInvulnTimer = earnedPact ? 0.38f : 0.34f;
            if (earnedPact)
            {
                followCamera.ImpulseTrauma(0.18f, 4.2f);
                actionFx?.PlayShadowDash(transform.position);
            }
            else
            {
                if (schoolRoll != null)
                {
                    locomotion = "Roll";
                    var rollState = schoolMotion["Roll"];
                    rollState.time = Mathf.Min(0.42f, rollState.length * 0.25f);
                    rollState.speed = 2.45f;
                    schoolMotion.Play("Roll");
                }
                actionFx?.PlayRoll(transform.position);
            }
        }

        internal bool IsDodgeInvulnerable => dodgeInvulnTimer > 0f;

        internal bool TryHazardReturn(Vector3 position, string message)
        {
            if (IsDodgeInvulnerable)
            {
                actionFx?.PlayEvade(transform.position);
                ShowRouteNote(EntryCopy.Arabic ? "تفادٍ متقن!" : "EVADED!");
                return false;
            }
            ReturnToSafePoint(position, message);
            return true;
        }

        private bool TryDetectAndStartLedgeMantle(Vector3 moveDir)
        {
            if (schoolMantle == null) return false;
            var pos = transform.position;
            if (!Physics.Raycast(pos + Vector3.up * 0.65f, moveDir, 0.78f, ~(1 << 2), QueryTriggerInteraction.Ignore))
                return false;
            if (Physics.Raycast(pos + Vector3.up * 2.02f, moveDir, 0.85f, ~(1 << 2), QueryTriggerInteraction.Ignore))
                return false;
            if (!Physics.Raycast(pos + moveDir * 0.64f + Vector3.up * 1.85f, Vector3.down, out var topHit, 1.40f, ~(1 << 2), QueryTriggerInteraction.Ignore))
                return false;
            if (topHit.normal.y < 0.72f) return false;
            var rise = topHit.point.y - pos.y;
            if (rise < 0.50f || rise > 1.52f) return false;

            mantling = true;
            mantleTimer = 0f;
            mantleStart = pos;
            mantleEnd = new Vector3(topHit.point.x, topHit.point.y + 0.04f, topHit.point.z);
            schoolJumpInFlight = false;
            schoolJumpRecovery = 0f;
            verticalSpeed = 0f;
            planarVelocity = Vector3.zero;
            ActiveAvatar.rotation = Quaternion.LookRotation(new Vector3(moveDir.x, 0f, moveDir.z));
            if (schoolHang != null)
            {
                locomotion = "Hang";
                schoolMotion.CrossFade("Hang", 0.04f);
            }
            actionFx?.PlayMantle(transform.position);
            return true;
        }

        private void StepMantle(float dt)
        {
            const float hangTime = 0.07f;
            const float totalTime = 0.42f;
            var prev = mantleTimer;
            mantleTimer += dt;
            if (prev < hangTime && mantleTimer >= hangTime && schoolMantle != null)
            {
                locomotion = "Mantle";
                schoolMotion["Mantle"].speed = Mathf.Max(1.0f, schoolMantle.length / (totalTime - hangTime));
                schoolMotion.CrossFade("Mantle", 0.06f);
            }
            var u = Mathf.Clamp01((mantleTimer - hangTime) / (totalTime - hangTime));
            var smooth = Mathf.SmoothStep(0f, 1f, u);
            var desired = Vector3.Lerp(mantleStart, mantleEnd, smooth);
            controller.Move(desired - transform.position);
            if (mantleTimer >= totalTime)
            {
                mantling = false;
                locomotion = null;
                PlayLocomotion(0f);
            }
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
            if (direction.sqrMagnitude > 0.001f) ActiveAvatar.rotation = Quaternion.LookRotation(direction);
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

        internal void HoldForExamination(bool held)
        {
            objective.transform.parent.gameObject.SetActive(!held);
            if (held)
            {
                BeginModal();
                jumpControl.gameObject.SetActive(false);
            }
            else EndModal();
        }

        internal void CancelExamination() => station.CancelExamination(this);

        internal bool TrySaveExamination()
        {
            CompleteInitialSave();
            var checkpoint = CaptureCheckpoint();
            checkpoint.ExaminationCompleted = true;
            var saved = checkpoint.Save(ChapterSaveSession.SavePath);
            if (saved) GetComponent<EchoExperimentInjuries>()?.Apply(true);
            ReportSave(saved);
            return saved;
        }

        private Transform ActiveAvatar => earnedPact ? pact : school;

        private bool IsPlayingAnyStrike => pactMotion != null && (
            pactMotion.IsPlaying("Strike") ||
            pactMotion.IsPlaying("StrikeBoxing") ||
            pactMotion.IsPlaying("StrikeHorizontal") ||
            pactMotion.IsPlaying("StrikeOverhead")) && strikeTimer > 0f;

        public void RequestPactStrike()
        {
            if (!earnedPact || IsStaged || Time.timeScale <= 0f) return;
            if (strikeTimer > 0.14f && strikeTimer < 0.36f)
            {
                queuedCombo = true;
                return;
            }
            station?.RequestPactStrike(this);
            if (!IsPlayingAnyStrike && station != null && station.Stage > 0 && !station.GameplayHeld && !station.InExamination)
                TryPlayPactStrike(transform.position + ActiveAvatar.forward * 2.2f, out _);
        }

        internal bool TryPlayPactStrike(Vector3 target, out float duration)
        {
            duration = 0f;
            if (!earnedPact || !controller.isGrounded || IsPlayingAnyStrike) return false;
            FaceRouteFocus(target);

            var hit = comboIndex % 3;
            var clipKey = hit switch
            {
                0 when pactMotion["StrikeBoxing"] != null => "StrikeBoxing",
                1 when pactMotion["StrikeHorizontal"] != null => "StrikeHorizontal",
                2 when pactMotion["StrikeOverhead"] != null => "StrikeOverhead",
                _ => "Strike"
            };
            if (pactMotion[clipKey] == null) clipKey = "Strike";
            if (pactMotion[clipKey] == null) return false;

            var state = pactMotion[clipKey];
            state.time = clipKey switch
            {
                "StrikeBoxing" => Mathf.Min(0.32f, state.length * 0.25f),
                "StrikeHorizontal" => Mathf.Min(0.22f, state.length * 0.15f),
                "StrikeOverhead" => Mathf.Min(0.18f, state.length * 0.15f),
                _ => 0f
            };
            state.speed = clipKey == "Strike" ? 1f : 1.65f;
            pactMotion.Play(clipKey);
            activeStrikeClip = clipKey;
            duration = Mathf.Clamp(state.length / Mathf.Max(0.5f, state.speed), 0.42f, 0.72f);
            strikeTimer = duration;
            comboIndex = (hit + 1) % 3;
            comboResetTimer = 1.65f;
            locomotion = null;
            actionFx?.PlaySlash(ActiveAvatar, hit, pactMotion, activeStrikeClip);
            followCamera.ImpulseTrauma(hit == 2 ? 0.22f : 0.11f, hit == 2 ? 3.0f : 1.4f);
            return true;
        }

        internal void OnCombatImpact(Vector3 worldPos, bool finisher)
        {
            actionFx?.PlayImpact(worldPos, finisher);
            followCamera.ImpulseTrauma(finisher ? 0.46f : 0.25f, finisher ? 4.8f : 2.5f);
        }

        internal void ApplyPactAppearance(bool accepted)
        {
            if (earnedPact == accepted || pact == null) return;
            var facing = ActiveAvatar.rotation;
            schoolJumpInFlight = false;
            schoolJumpRecovery = 0f;
            earnedPact = accepted;
            ActiveAvatar.rotation = facing;
            school.gameObject.SetActive(!accepted);
            pact.gameObject.SetActive(accepted);
            locomotion = "Idle";
            (accepted ? pactMotion : schoolMotion).Play(locomotion);
        }

        internal bool TrySaveZero(ZeroPactProgress before, ZeroPactProgress after)
        {
            CompleteInitialSave();
            var path = ChapterSaveSession.SavePath;
            lock (CheckpointFile.WriteLock)
            {
                var checkpoint = Room01Checkpoint.Load(path);
                var saved = checkpoint != null && checkpoint.ExaminationCompleted &&
                    checkpoint.Zero.Equals(before);
                if (saved)
                {
                    checkpoint.Zero = after;
                    saved = checkpoint.Save(path);
                }
                ReportSave(saved);
                return saved;
            }
        }

        internal bool TrySaveKinjaBeat(KinjaBeat current, KinjaBeat next)
        {
            CompleteInitialSave();
            var path = ChapterSaveSession.SavePath;
            lock (CheckpointFile.WriteLock)
            {
                var state = Room01Checkpoint.Load(path);
                var saved = state != null && state.Zero.Accepted && state.AfterPact == current && next == current + 1;
                if (saved)
                {
                    state.AfterPact = next;
                    saved = state.Save(path);
                }
                ReportSave(saved);
                return saved;
            }
        }

        internal bool TrySaveWardBeat(WardBeat current, WardBeat next)
        {
            CompleteInitialSave();
            var path = ChapterSaveSession.SavePath;
            lock (CheckpointFile.WriteLock)
            {
                var state = Room01Checkpoint.Load(path);
                var saved = state != null && state.AfterPact == KinjaBeat.WishConfirmed &&
                    state.Ward == current && next == current + 1;
                if (saved)
                {
                    state.Ward = next;
                    saved = state.Save(path);
                }
                ReportSave(saved);
                return saved;
            }
        }

        internal bool TrySaveWardCompress()
        {
            CompleteInitialSave();
            var path = ChapterSaveSession.SavePath;
            lock (CheckpointFile.WriteLock)
            {
                var state = Room01Checkpoint.Load(path);
                var saved = state != null && state.Ward >= WardBeat.Awake && !state.WardCompress;
                if (saved)
                {
                    state.WardCompress = true;
                    saved = state.Save(path);
                }
                ReportSave(saved);
                return saved;
            }
        }

        private Room01Checkpoint CaptureCheckpoint()
        {
            var state = new Room01Checkpoint
            {
                Wake = true, Clock = nextClue >= 1, Photo = nextClue >= 2, Memory = nextClue >= 2,
                Terminal = signalAligned, Conduit = powered, Ending = crossed,
                StationStage = station?.Stage ?? 0, ArchiveFragments = station?.MemoryFragments ?? 0,
                ReactorBreakers = station?.PoweredBreakers ?? 0,
                ExaminationCompleted = station?.ExaminationCompleted ?? false,
                Zero = station?.ZeroProgress ?? default,
                AfterPact = station?.AfterPact ?? default,
                Ward = station?.WardProgress ?? default,
                WardCompress = station?.WardCompressEquipped ?? false,
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

        [SerializeField] private StationSystemBanner systemBanner;

        private void BeginModal()
        {
            systemBanner?.Hide();
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
            if (objective.text == copy) return;
            objective.text = copy;
            systemBanner?.Show(copy);
        }
    }
}
