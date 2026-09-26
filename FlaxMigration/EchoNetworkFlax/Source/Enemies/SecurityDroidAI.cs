using System;
using FlaxEngine;

namespace EchoNetwork.Enemies
{
    public enum DroidState
    {
        Patrol,
        Alert,
        Attack,
        Stunned,
        Dead
    }

    /// <summary>
    /// Sector 11 Security Droid AI in Flax Engine.
    /// Handles patrol routes, detection cones, ranged energy discharges, and stun states.
    /// </summary>
    public class SecurityDroidAI : EnemyBase
    {
        [Header("Perception & Range")]
        public float VisionRange = 16.0f;
        public float VisionAngle = 110.0f;
        public float AttackRange = 10.0f;
        public float MinPatrolWait = 2.0f;

        [Header("Combat")]
        public float AttackCooldown = 2.2f;
        public float ShockDamage = 65.0f;

        [Header("Target & Patrol")]
        public Actor TargetPlayer;
        public Transform[] PatrolWaypoints;

        public DroidState CurrentState { get; private set; } = DroidState.Patrol;

        private float _attackCooldownTimer;
        private int _currentWaypointIndex = 0;
        private float _patrolWaitTimer = 0f;

        public override void OnStart()
        {
            base.OnStart();
            EnemyName = "Sector 11 Droid";
            MaxHealth = 350f;
            CurrentHealth = 350f;

            if (TargetPlayer == null)
            {
                var playerScript = Level.FindScript<Player.EchoPlayer>();
                if (playerScript != null)
                    TargetPlayer = playerScript.Actor;
            }
        }

        public override void OnUpdate()
        {
            base.OnUpdate();

            if (IsDead)
                return;

            if (IsStaggered)
            {
                CurrentState = DroidState.Stunned;
                return;
            }

            if (_attackCooldownTimer > 0f)
                _attackCooldownTimer -= Time.DeltaTime;

            switch (CurrentState)
            {
                case DroidState.Patrol:
                    UpdatePatrol();
                    CheckPerception();
                    break;

                case DroidState.Alert:
                    UpdateAlert();
                    break;

                case DroidState.Attack:
                    UpdateAttack();
                    break;

                case DroidState.Stunned:
                    if (!IsStaggered)
                        CurrentState = DroidState.Alert;
                    break;
            }
        }

        private void CheckPerception()
        {
            if (TargetPlayer == null)
                return;

            Vector3 toTarget = TargetPlayer.Position - Actor.Position;
            float dist = toTarget.Length;

            if (dist <= VisionRange)
            {
                float angle = Vector3.Angle(Actor.Transform.Forward, toTarget.Normalized);
                if (angle <= VisionAngle * 0.5f)
                {
                    // Check line of sight
                    if (Physics.RayCast(Actor.Position + Vector3.Up * 1.2f, toTarget.Normalized, out RayCastHit hit, VisionRange))
                    {
                        if (hit.Actor == TargetPlayer || hit.Actor.IsChildOf(TargetPlayer))
                        {
                            CurrentState = DroidState.Alert;
                        }
                    }
                }
            }
        }

        private void UpdatePatrol()
        {
            if (PatrolWaypoints == null || PatrolWaypoints.Length == 0)
                return;

            Transform targetWp = PatrolWaypoints[_currentWaypointIndex];
            Vector3 toWp = targetWp.Translation - Actor.Position;
            toWp.Y = 0f;

            if (toWp.LengthSquared < 1.0f)
            {
                _patrolWaitTimer += Time.DeltaTime;
                if (_patrolWaitTimer >= MinPatrolWait)
                {
                    _currentWaypointIndex = (_currentWaypointIndex + 1) % PatrolWaypoints.Length;
                    _patrolWaitTimer = 0f;
                }
            }
            else
            {
                Vector3 moveDir = toWp.Normalized;
                Actor.Position += moveDir * 2.2f * Time.DeltaTime;
                Actor.Orientation = Quaternion.Slerp(Actor.Orientation, Quaternion.LookRotation(moveDir, Vector3.Up), 8f * Time.DeltaTime);
            }
        }

        private void UpdateAlert()
        {
            if (TargetPlayer == null)
            {
                CurrentState = DroidState.Patrol;
                return;
            }

            Vector3 toPlayer = TargetPlayer.Position - Actor.Position;
            float dist = toPlayer.Length;

            // Turn towards player
            Vector3 lookDir = new Vector3(toPlayer.X, 0f, toPlayer.Z).Normalized;
            if (lookDir.LengthSquared > 0.01f)
            {
                Actor.Orientation = Quaternion.Slerp(Actor.Orientation, Quaternion.LookRotation(lookDir, Vector3.Up), 10f * Time.DeltaTime);
            }

            if (dist <= AttackRange && _attackCooldownTimer <= 0f)
            {
                CurrentState = DroidState.Attack;
            }
            else if (dist > VisionRange * 1.5f)
            {
                CurrentState = DroidState.Patrol;
            }
            else if (dist > AttackRange * 0.8f)
            {
                // Advance towards player
                Actor.Position += lookDir * 3.5f * Time.DeltaTime;
            }
        }

        private void UpdateAttack()
        {
            if (_attackCooldownTimer <= 0f)
            {
                ExecuteLaserShock();
                _attackCooldownTimer = AttackCooldown;
                CurrentState = DroidState.Alert;
            }
        }

        private void ExecuteLaserShock()
        {
            if (TargetPlayer == null)
                return;

            Vector3 beamOrigin = Actor.Position + Vector3.Up * 1.4f;
            Vector3 toPlayer = (TargetPlayer.Position + Vector3.Up * 1.0f) - beamOrigin;

            if (Physics.RayCast(beamOrigin, toPlayer.Normalized, out RayCastHit hit, AttackRange * 1.2f))
            {
                var player = hit.Actor.GetScript<Player.EchoPlayer>();
                if (player != null)
                {
                    player.TakeDamage(ShockDamage, toPlayer.Normalized);
                }
            }
        }
    }
}
