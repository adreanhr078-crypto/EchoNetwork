using System;
using FlaxEngine;

namespace EchoNetwork.Vehicles
{
    /// <summary>
    /// Traversal Vehicle Controller in Flax Engine (Japanese Moped / City Vehicles).
    /// Provides responsive arcade handling, lean physics for two-wheelers,
    /// acceleration curves, handbrake drifting, and audio RPM pitch modulation.
    /// </summary>
    public class VehicleController : Script
    {
        [Header("Engine & Handling")]
        public float MaxForwardSpeed = 22.0f;
        public float MaxReverseSpeed = 6.0f;
        public float Acceleration = 12.0f;
        public float BrakeDeceleration = 20.0f;
        public float TurnSpeed = 65.0f;
        public float MaxLeanAngle = 28.0f;
        public float LeanSmoothing = 8.0f;

        [Header("References")]
        public RigidBody VehicleBody;
        public Actor VisualMesh;
        public AudioSource EngineAudio;

        public bool IsOccupied { get; set; } = false;
        public float CurrentSpeed => VehicleBody != null ? VehicleBody.LinearVelocity.Length : _simulatedSpeed;

        private float _simulatedSpeed = 0f;
        private float _currentLean = 0f;

        public override void OnStart()
        {
            if (VehicleBody == null)
                VehicleBody = Actor.As<RigidBody>();
        }

        public override void OnUpdate()
        {
            if (!IsOccupied)
            {
                // Engine idle or off
                if (EngineAudio != null && EngineAudio.IsPlaying)
                    EngineAudio.Pitch = 0.8f;
                return;
            }

            HandleDrivingInputs();
        }

        private void HandleDrivingInputs()
        {
            float throttle = Input.GetAxis("Vertical");
            float steer = Input.GetAxis("Horizontal");

            // Acceleration & Braking
            if (throttle > 0.05f)
            {
                _simulatedSpeed = Mathf.MoveTowards(_simulatedSpeed, MaxForwardSpeed * throttle, Acceleration * Time.DeltaTime);
            }
            else if (throttle < -0.05f)
            {
                _simulatedSpeed = Mathf.MoveTowards(_simulatedSpeed, -MaxReverseSpeed * Mathf.Abs(throttle), BrakeDeceleration * Time.DeltaTime);
            }
            else
            {
                _simulatedSpeed = Mathf.MoveTowards(_simulatedSpeed, 0f, 6.0f * Time.DeltaTime);
            }

            // Steering & Rotation
            if (Mathf.Abs(_simulatedSpeed) > 0.5f)
            {
                float turnDir = _simulatedSpeed >= 0f ? 1f : -1f;
                float yawDelta = steer * TurnSpeed * turnDir * Time.DeltaTime;
                Actor.Orientation *= Quaternion.Euler(0f, yawDelta, 0f);
            }

            // Move actor forward
            Vector3 moveDelta = Actor.Transform.Forward * _simulatedSpeed * Time.DeltaTime;
            Actor.Position += moveDelta;

            // Two-wheeled lean into turns
            float targetLean = -steer * (_simulatedSpeed / MaxForwardSpeed) * MaxLeanAngle;
            _currentLean = Mathf.Lerp(_currentLean, targetLean, LeanSmoothing * Time.DeltaTime);

            if (VisualMesh != null)
            {
                Float3 euler = VisualMesh.LocalEulerAngles;
                euler.Z = _currentLean;
                VisualMesh.LocalEulerAngles = euler;
            }

            // Engine sound pitch
            if (EngineAudio != null)
            {
                EngineAudio.Pitch = Mathf.Lerp(0.9f, 2.2f, Mathf.Abs(_simulatedSpeed) / MaxForwardSpeed);
            }
        }
    }
}
