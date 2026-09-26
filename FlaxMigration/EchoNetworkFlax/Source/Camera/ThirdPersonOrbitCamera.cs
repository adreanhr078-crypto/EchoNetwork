using System;
using FlaxEngine;

namespace EchoNetwork.Camera
{
    /// <summary>
    /// Premium Third-Person Orbit Camera for Echo in Flax Engine.
    /// Features collision sweep avoidance (spring-arm replacement), dynamic combat FOV,
    /// soft target lock-on, framing pitch/yaw limits, and cinematic camera shake.
    /// </summary>
    public class ThirdPersonOrbitCamera : Script
    {
        [Header("Target & Distance")]
        public Actor Target;
        public Vector3 TargetOffset = new Vector3(0f, 1.4f, 0f);
        public float DefaultDistance = 4.2f;
        public float MinDistance = 1.0f;
        public float MaxDistance = 6.0f;
        public float DistanceSmoothing = 12.0f;

        [Header("Orbit & Sensitivity")]
        public float MouseSensitivityX = 140.0f;
        public float MouseSensitivityY = 100.0f;
        public float MinPitch = -40.0f;
        public float MaxPitch = 70.0f;
        public float OrbitSmoothing = 15.0f;

        [Header("Collision Avoidance")]
        public float CollisionProbeRadius = 0.25f;
        public LayerMask CollisionLayers = -1;

        [Header("Dynamic FOV")]
        public float BaseFOV = 75.0f;
        public float SprintFOV = 84.0f;
        public float CombatFOV = 68.0f;
        public float FOVSmoothing = 6.0f;

        [Header("Lock-On")]
        public Actor LockOnTarget;
        public bool IsLockedOn => LockOnTarget != null;

        private FlaxEngine.Camera _camera;
        private float _currentYaw;
        private float _currentPitch = 15.0f;
        private float _targetYaw;
        private float _targetPitch = 15.0f;
        private float _currentDistance;
        private float _shakeIntensity;
        private float _shakeDuration;

        public override void OnStart()
        {
            _camera = Actor.As<FlaxEngine.Camera>();
            if (_camera == null)
                _camera = Actor.GetChild<FlaxEngine.Camera>();

            _currentDistance = DefaultDistance;
            _targetYaw = Actor.Orientation.EulerAngles.Y;
            _currentYaw = _targetYaw;

            // Lock cursor
            Screen.CursorVisible = false;
            Screen.CursorLock = CursorLockMode.Locked;
        }

        public override void OnUpdate()
        {
            if (Target == null)
                return;

            HandleInput();
            HandleTargetLockOn();
            UpdateCameraTransform();
            UpdateDynamicFOV();
            UpdateCameraShake();
        }

        private void HandleInput()
        {
            if (!IsLockedOn)
            {
                float mouseX = Input.GetAxis("Mouse X");
                float mouseY = Input.GetAxis("Mouse Y");

                _targetYaw += mouseX * MouseSensitivityX * Time.DeltaTime;
                _targetPitch -= mouseY * MouseSensitivityY * Time.DeltaTime;
                _targetPitch = Mathf.Clamp(_targetPitch, MinPitch, MaxPitch);
            }

            // Scroll zoom
            float scroll = Input.GetAxis("Mouse ScrollWheel");
            if (Mathf.Abs(scroll) > 0.01f)
            {
                DefaultDistance = Mathf.Clamp(DefaultDistance - scroll * 1.5f, MinDistance, MaxDistance);
            }
        }

        private void HandleTargetLockOn()
        {
            if (Input.GetAction("LockOn"))
            {
                if (IsLockedOn)
                    LockOnTarget = null;
                else
                    FindNearestLockOnTarget();
            }

            if (IsLockedOn)
            {
                Vector3 toEnemy = LockOnTarget.Position - (Target.Position + TargetOffset);
                toEnemy.Y = 0f;
                if (toEnemy.LengthSquared > 0.1f)
                {
                    Quaternion lookRot = Quaternion.LookRotation(toEnemy.Normalized, Vector3.Up);
                    _targetYaw = lookRot.EulerAngles.Y;
                    _targetPitch = 18.0f;
                }
            }
        }

        private void FindNearestLockOnTarget()
        {
            // Sphere cast or query nearby enemies within 25m
            RayCastHit[] hits = Physics.SphereCastAll(Target.Position, 25.0f, CollisionLayers);
            Actor bestTarget = null;
            float closestDist = float.MaxValue;

            foreach (var hit in hits)
            {
                if (hit.Actor != null && hit.Actor.GetScript<Enemies.EnemyBase>() != null)
                {
                    float dist = Vector3.Distance(Target.Position, hit.Actor.Position);
                    if (dist < closestDist)
                    {
                        closestDist = dist;
                        bestTarget = hit.Actor;
                    }
                }
            }
            LockOnTarget = bestTarget;
        }

        private void UpdateCameraTransform()
        {
            _currentYaw = Mathf.Lerp(_currentYaw, _targetYaw, OrbitSmoothing * Time.DeltaTime);
            _currentPitch = Mathf.Lerp(_currentPitch, _targetPitch, OrbitSmoothing * Time.DeltaTime);

            Quaternion rotation = Quaternion.Euler(_currentPitch, _currentYaw, 0f);
            Vector3 targetPivot = Target.Position + TargetOffset;

            // Calculate desired camera position
            Vector3 desiredDir = -(rotation * Vector3.Forward);
            float desiredDistance = DefaultDistance;

            // Sphere cast collision avoidance
            if (Physics.SphereCast(targetPivot, CollisionProbeRadius, desiredDir, out RayCastHit hit, DefaultDistance, CollisionLayers))
            {
                desiredDistance = Mathf.Clamp(hit.Distance - 0.15f, MinDistance, DefaultDistance);
            }

            _currentDistance = Mathf.Lerp(_currentDistance, desiredDistance, DistanceSmoothing * Time.DeltaTime);
            Vector3 newPosition = targetPivot + desiredDir * _currentDistance;

            Actor.Position = newPosition;
            Actor.Orientation = rotation;
        }

        private void UpdateDynamicFOV()
        {
            if (_camera == null)
                return;

            float targetFOV = BaseFOV;

            var locomotion = Target.GetScript<Player.EchoLocomotion>();
            if (locomotion != null && locomotion.IsSprinting)
                targetFOV = SprintFOV;

            var combat = Target.GetScript<Combat.CombatController>();
            if (combat != null && combat.IsAttacking)
                targetFOV = CombatFOV;

            _camera.FieldOfView = Mathf.Lerp(_camera.FieldOfView, targetFOV, FOVSmoothing * Time.DeltaTime);
        }

        private void UpdateCameraShake()
        {
            if (_shakeDuration > 0f)
            {
                _shakeDuration -= Time.DeltaTime;
                float offsetX = (Mathf.Sin(Time.GameTime * 50f) * 0.5f) * _shakeIntensity;
                float offsetY = (Mathf.Cos(Time.GameTime * 45f) * 0.5f) * _shakeIntensity;
                Actor.Position += Actor.Transform.Right * offsetX + Actor.Transform.Up * offsetY;
            }
        }

        public void TriggerCameraShake(float intensity, float duration)
        {
            _shakeIntensity = intensity;
            _shakeDuration = duration;
        }
    }
}
