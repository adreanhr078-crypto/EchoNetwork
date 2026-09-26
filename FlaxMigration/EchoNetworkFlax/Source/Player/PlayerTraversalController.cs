using System;
using FlaxEngine;

namespace EchoNetwork.Player
{
    public enum TraversalState
    {
        Standard,
        Sliding,
        WallRunning,
        LedgeGrabbing,
        Vaulting,
        RollingRecovery
    }

    /// <summary>
    /// Advanced Traversal and Parkour Controller for Echo in Flax Engine.
    /// Handles running slide, wall running, ledge detection, vaulting, and impact roll recovery.
    /// </summary>
    public class PlayerTraversalController : Script
    {
        [Header("Parkour Parameters")]
        public float SlideDuration = 0.85f;
        public float SlideInitialSpeed = 13.0f;
        public float SlideMinSpeed = 5.0f;
        public float SlideStaminaCost = 15.0f;

        public float WallRunMaxDuration = 1.8f;
        public float WallRunSpeed = 9.0f;
        public float WallRunGravityScale = 0.2f;

        public float LedgeDetectForwardDist = 0.9f;
        public float LedgeDetectHeight = 2.0f;

        [Header("References")]
        public CharacterController Controller;
        public EchoLocomotion Locomotion;
        public EchoPlayer Player;

        public TraversalState CurrentState { get; private set; } = TraversalState.Standard;
        public bool IsParkourActive => CurrentState != TraversalState.Standard;

        private float _stateTimer;
        private Vector3 _parkourVelocity;
        private Vector3 _wallNormal;
        private bool _isWallOnRight;
        private float _originalCapsuleHeight = 1.8f;
        private float _slidingCapsuleHeight = 0.9f;

        public override void OnStart()
        {
            if (Controller == null)
                Controller = Actor.As<CharacterController>();

            if (Locomotion == null)
                Locomotion = Actor.GetScript<EchoLocomotion>();

            if (Player == null)
                Player = Actor.GetScript<EchoPlayer>();

            if (Controller != null)
                _originalCapsuleHeight = Controller.Height;
        }

        public override void OnUpdate()
        {
            if (Player != null && Player.IsDead)
                return;

            switch (CurrentState)
            {
                case TraversalState.Standard:
                    CheckTraversalTriggers();
                    break;

                case TraversalState.Sliding:
                    UpdateSlide();
                    break;

                case TraversalState.WallRunning:
                    UpdateWallRun();
                    break;

                case TraversalState.LedgeGrabbing:
                    UpdateLedgeGrab();
                    break;

                case TraversalState.Vaulting:
                    UpdateVault();
                    break;

                case TraversalState.RollingRecovery:
                    UpdateRollingRecovery();
                    break;
            }
        }

        private void CheckTraversalTriggers()
        {
            // Running Slide trigger (Crouch / Slide action while sprinting)
            if (Locomotion != null && Locomotion.IsSprinting && Input.GetAction("Crouch"))
            {
                if (Player == null || Player.ConsumeStamina(SlideStaminaCost))
                {
                    StartSlide();
                    return;
                }
            }

            // Wall-run trigger (in air, moving forward, wall nearby)
            if (Locomotion != null && !Locomotion.IsGrounded && Locomotion.CurrentSpeed > 4f)
            {
                if (DetectWallRun(out Vector3 wallNorm, out bool onRight))
                {
                    StartWallRun(wallNorm, onRight);
                    return;
                }
            }

            // Ledge detection when jumping
            if (Locomotion != null && !Locomotion.IsGrounded && Input.GetAxis("Vertical") > 0.5f)
            {
                if (DetectLedge(out Vector3 ledgePos))
                {
                    StartLedgeGrab(ledgePos);
                    return;
                }
            }
        }

        private void StartSlide()
        {
            CurrentState = TraversalState.Sliding;
            _stateTimer = SlideDuration;

            if (Controller != null)
                Controller.Height = _slidingCapsuleHeight;

            Vector3 fwd = Actor.Transform.Forward;
            _parkourVelocity = fwd * SlideInitialSpeed;
        }

        private void UpdateSlide()
        {
            _stateTimer -= Time.DeltaTime;
            float t = 1.0f - (_stateTimer / SlideDuration);
            float currentSpeed = Mathf.Lerp(SlideInitialSpeed, SlideMinSpeed, t);

            Vector3 move = _parkourVelocity.Normalized * currentSpeed;
            if (Controller != null)
            {
                // Apply slight gravity to keep grounded
                move.Y = -2f;
                Controller.Move(move * Time.DeltaTime);
            }

            // Interrupt or finish slide
            if (_stateTimer <= 0f || Input.GetAction("Jump"))
            {
                EndSlide();
            }
        }

        private void EndSlide()
        {
            if (Controller != null)
                Controller.Height = _originalCapsuleHeight;

            CurrentState = TraversalState.Standard;
        }

        private bool DetectWallRun(out Vector3 wallNorm, out bool onRight)
        {
            wallNorm = Vector3.Zero;
            onRight = false;

            Vector3 origin = Actor.Position + Vector3.Up * 0.9f;
            Vector3 right = Actor.Transform.Right;

            // Check right side
            if (Physics.RayCast(origin, right, out RayCastHit hitR, 1.2f))
            {
                wallNorm = hitR.Normal;
                onRight = true;
                return Vector3.Dot(hitR.Normal, Vector3.Up) < 0.2f;
            }

            // Check left side
            if (Physics.RayCast(origin, -right, out RayCastHit hitL, 1.2f))
            {
                wallNorm = hitL.Normal;
                onRight = false;
                return Vector3.Dot(hitL.Normal, Vector3.Up) < 0.2f;
            }

            return false;
        }

        private void StartWallRun(Vector3 wallNorm, bool onRight)
        {
            CurrentState = TraversalState.WallRunning;
            _stateTimer = WallRunMaxDuration;
            _wallNormal = wallNorm;
            _isWallOnRight = onRight;
        }

        private void UpdateWallRun()
        {
            _stateTimer -= Time.DeltaTime;

            // Calculate wall forward vector (perpendicular to wall normal)
            Vector3 wallFwd = Vector3.Cross(_wallNormal, Vector3.Up);
            if (!_isWallOnRight)
                wallFwd = -wallFwd;

            Vector3 move = wallFwd * WallRunSpeed;
            move.Y = -1.5f; // Slight downward slide

            if (Controller != null)
                Controller.Move(move * Time.DeltaTime);

            // Re-orient actor along wall
            Actor.Orientation = Quaternion.Slerp(Actor.Orientation, Quaternion.LookRotation(wallFwd, Vector3.Up), 10f * Time.DeltaTime);

            // Check for wall jump or timeout
            if (Input.GetAction("Jump"))
            {
                Vector3 jumpOff = (_wallNormal * 1.2f + Vector3.Up * 1.5f).Normalized * 7.5f;
                if (Locomotion != null)
                    Locomotion.Actor.Orientation = Quaternion.LookRotation(_wallNormal, Vector3.Up);
                CurrentState = TraversalState.Standard;
            }
            else if (_stateTimer <= 0f || (Locomotion != null && Locomotion.IsGrounded))
            {
                CurrentState = TraversalState.Standard;
            }
        }

        private bool DetectLedge(out Vector3 ledgePos)
        {
            ledgePos = Vector3.Zero;
            Vector3 origin = Actor.Position + Vector3.Up * LedgeDetectHeight;
            Vector3 fwd = Actor.Transform.Forward;

            // Cast forward at head height to find wall
            if (Physics.RayCast(origin, fwd, out RayCastHit wallHit, LedgeDetectForwardDist))
            {
                // Cast down from above the wall hit to find horizontal ledge top surface
                Vector3 ledgeTopOrigin = wallHit.Point + fwd * 0.15f + Vector3.Up * 0.5f;
                if (Physics.RayCast(ledgeTopOrigin, Vector3.Down, out RayCastHit topHit, 0.8f))
                {
                    ledgePos = topHit.Point;
                    return true;
                }
            }
            return false;
        }

        private void StartLedgeGrab(Vector3 ledgePos)
        {
            CurrentState = TraversalState.LedgeGrabbing;
            // Snap to hang position below ledge
        }

        private void UpdateLedgeGrab()
        {
            if (Input.GetAction("Jump"))
            {
                // Vault up to top
                CurrentState = TraversalState.Vaulting;
                _stateTimer = 0.4f;
            }
            else if (Input.GetAction("Crouch"))
            {
                // Release ledge
                CurrentState = TraversalState.Standard;
            }
        }

        private void UpdateVault()
        {
            _stateTimer -= Time.DeltaTime;
            if (_stateTimer <= 0f)
            {
                CurrentState = TraversalState.Standard;
            }
        }

        private void UpdateRollingRecovery()
        {
            _stateTimer -= Time.DeltaTime;
            if (_stateTimer <= 0f)
            {
                CurrentState = TraversalState.Standard;
            }
        }

        public void TriggerRollRecovery()
        {
            CurrentState = TraversalState.RollingRecovery;
            _stateTimer = 0.6f;
        }
    }
}
