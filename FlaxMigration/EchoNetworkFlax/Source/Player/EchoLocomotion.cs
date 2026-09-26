using System;
using FlaxEngine;

namespace EchoNetwork.Player
{
    /// <summary>
    /// Locomotion controller for Echo in Flax Engine.
    /// Handles camera-relative movement vectors, smooth character rotation,
    /// inertial banking/tilt, acceleration curves, and slope physics.
    /// </summary>
    public class EchoLocomotion : Script
    {
        [Header("Locomotion Speeds")]
        public float WalkSpeed = 4.0f;
        public float RunSpeed = 7.5f;
        public float SprintSpeed = 11.5f;
        public float Acceleration = 18.0f;
        public float Deceleration = 22.0f;
        public float RotationSpeed = 14.0f;

        [Header("Physics & Gravity")]
        public float Gravity = -22.0f;
        public float FallMultiplier = 1.4f;
        public float JumpForce = 8.5f;

        [Header("Inertial Banking")]
        [Tooltip("Max roll angle in degrees when banking into sharp turns at high speed.")]
        public float MaxBankAngle = 12.0f;
        public float BankSmoothing = 8.0f;

        [Header("References")]
        public CharacterController Controller;
        public Actor CameraRig;
        public EchoPlayer Player;

        public bool IsGrounded => Controller != null && Controller.IsGrounded;
        public bool IsSprinting { get; private set; }
        public Vector3 Velocity => _currentVelocity;
        public float CurrentSpeed => new Vector2(_currentVelocity.X, _currentVelocity.Z).Length;

        private Vector3 _currentVelocity;
        private float _verticalVelocity;
        private float _currentBankAngle;
        private float _lastYaw;

        public override void OnStart()
        {
            if (Controller == null)
                Controller = Actor.As<CharacterController>();

            if (Player == null)
                Player = Actor.GetScript<EchoPlayer>();

            if (CameraRig == null)
                CameraRig = Camera.Main != null ? Camera.Main.Actor : null;

            _lastYaw = Actor.Orientation.EulerAngles.Y;
        }

        public override void OnUpdate()
        {
            if (Player != null && Player.IsDead)
                return;

            HandleInputAndMovement();
        }

        private void HandleInputAndMovement()
        {
            float inputH = Input.GetAxis("Horizontal");
            float inputV = Input.GetAxis("Vertical");
            Vector3 inputDir = new Vector3(inputH, 0f, inputV);

            bool sprintRequested = Input.GetAction("Sprint");
            float targetSpeed = 0f;

            if (inputDir.LengthSquared > 0.01f)
            {
                inputDir.Normalize();

                if (sprintRequested && (Player == null || Player.ConsumeStamina(15f * Time.DeltaTime)))
                {
                    targetSpeed = SprintSpeed;
                    IsSprinting = true;
                }
                else
                {
                    targetSpeed = inputDir.Length > 0.7f ? RunSpeed : WalkSpeed;
                    IsSprinting = false;
                }
            }
            else
            {
                IsSprinting = false;
            }

            // Camera-relative direction
            Vector3 moveDir = Vector3.Zero;
            if (CameraRig != null && inputDir.LengthSquared > 0.01f)
            {
                Vector3 camFwd = CameraRig.Transform.Forward;
                camFwd.Y = 0f;
                camFwd.Normalize();

                Vector3 camRight = CameraRig.Transform.Right;
                camRight.Y = 0f;
                camRight.Normalize();

                moveDir = (camFwd * inputDir.Z + camRight * inputDir.X).Normalized;
            }
            else if (inputDir.LengthSquared > 0.01f)
            {
                moveDir = inputDir;
            }

            // Smooth horizontal velocity
            Vector3 targetHorizVelocity = moveDir * targetSpeed;
            Vector3 currentHorizVelocity = new Vector3(_currentVelocity.X, 0f, _currentVelocity.Z);

            float accelRate = targetSpeed > 0.1f ? Acceleration : Deceleration;
            currentHorizVelocity = Vector3.MoveTowards(currentHorizVelocity, targetHorizVelocity, accelRate * Time.DeltaTime);

            // Gravity & Vertical movement
            if (IsGrounded)
            {
                if (_verticalVelocity < 0f)
                    _verticalVelocity = -2.0f; // Ground snap bias

                if (Input.GetAction("Jump") && (Player == null || Player.ConsumeStamina(10f)))
                {
                    _verticalVelocity = JumpForce;
                }
            }
            else
            {
                float grav = Gravity;
                if (_verticalVelocity < 0f)
                    grav *= FallMultiplier; // Faster fall for snappy feel

                _verticalVelocity += grav * Time.DeltaTime;
            }

            _currentVelocity = new Vector3(currentHorizVelocity.X, _verticalVelocity, currentHorizVelocity.Z);

            // Execute PhysX movement
            if (Controller != null)
            {
                Controller.Move(_currentVelocity * Time.DeltaTime);
            }

            // Character rotation towards movement vector
            if (moveDir.LengthSquared > 0.01f)
            {
                Quaternion targetRot = Quaternion.LookRotation(moveDir, Vector3.Up);
                Actor.Orientation = Quaternion.Slerp(Actor.Orientation, targetRot, RotationSpeed * Time.DeltaTime);
            }

            // Dynamic banking / tilt into turns
            UpdateInertialBanking();
        }

        private void UpdateInertialBanking()
        {
            float currentYaw = Actor.Orientation.EulerAngles.Y;
            float yawDelta = Mathf.DeltaAngle(_lastYaw, currentYaw);
            _lastYaw = currentYaw;

            float targetBank = 0f;
            if (CurrentSpeed > WalkSpeed)
            {
                // Bank into turn proportionally to turn speed and movement speed
                targetBank = Mathf.Clamp(-yawDelta * 1.5f, -MaxBankAngle, MaxBankAngle);
            }

            _currentBankAngle = Mathf.Lerp(_currentBankAngle, targetBank, BankSmoothing * Time.DeltaTime);

            // Apply roll banking to visual model without affecting character controller collision
            if (Player != null && Player.CharacterModel != null)
            {
                Float3 euler = Player.CharacterModel.LocalEulerAngles;
                euler.Z = _currentBankAngle;
                Player.CharacterModel.LocalEulerAngles = euler;
            }
        }
    }
}
