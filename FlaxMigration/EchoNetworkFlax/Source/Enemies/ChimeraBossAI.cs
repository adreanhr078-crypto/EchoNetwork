using System;
using FlaxEngine;

namespace EchoNetwork.Enemies
{
    public enum ChimeraPhase
    {
        Phase1_Stalking,
        Phase2_Enraged
    }

    /// <summary>
    /// Chimera Boss (Specimen EX-000) AI in Flax Engine.
    /// Manages multi-phase combat, leaping pounce attacks, sweeping claw swipes,
    /// AOE shockwaves, and enraged transformation.
    /// </summary>
    public class ChimeraBossAI : EnemyBase
    {
        [Header("Boss Attributes")]
        public ChimeraPhase Phase = ChimeraPhase.Phase1_Stalking;
        public float EnrageHealthThreshold = 0.5f; // 50% HP
        public float LeapAttackRange = 18.0f;
        public float MeleeSwipeRange = 3.5f;

        [Header("Damage Stats")]
        public float ClawDamage = 95f;
        public float LeapSmashDamage = 175f;
        public float RoarShockwaveDamage = 60f;

        [Header("References")]
        public Actor TargetPlayer;
        public ParticleEffect ShockwaveVFX;

        private float _actionCooldown = 0f;
        private bool _isPerformingLeap = false;
        private Vector3 _leapStartPos;
        private Vector3 _leapTargetPos;
        private float _leapProgress = 0f;

        public override void OnStart()
        {
            base.OnStart();
            EnemyName = "Chimera (Specimen EX-000)";
            MaxHealth = 3200f;
            CurrentHealth = 3200f;
            MaxPosture = 250f;
            PoiseHealth = 180f;

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

            CheckEnrageTransition();

            if (_isPerformingLeap)
            {
                UpdateLeapMotion();
                return;
            }

            if (_actionCooldown > 0f)
                _actionCooldown -= Time.DeltaTime;

            if (TargetPlayer != null && _actionCooldown <= 0f && !IsStaggered)
            {
                DecideNextBossAction();
            }
        }

        private void CheckEnrageTransition()
        {
            if (Phase == ChimeraPhase.Phase1_Stalking && (CurrentHealth / MaxHealth) <= EnrageHealthThreshold)
            {
                Phase = ChimeraPhase.Phase2_Enraged;
                TriggerRoarShockwave();
            }
        }

        private void DecideNextBossAction()
        {
            float dist = Vector3.Distance(Actor.Position, TargetPlayer.Position);

            // Orient towards player
            Vector3 toPlayer = (TargetPlayer.Position - Actor.Position);
            toPlayer.Y = 0f;
            if (toPlayer.LengthSquared > 0.01f)
            {
                Actor.Orientation = Quaternion.Slerp(Actor.Orientation, Quaternion.LookRotation(toPlayer.Normalized, Vector3.Up), 8f * Time.DeltaTime);
            }

            if (dist <= MeleeSwipeRange)
            {
                ExecuteClawCombo();
            }
            else if (dist <= LeapAttackRange && dist > MeleeSwipeRange * 1.5f)
            {
                StartLeapSmash(TargetPlayer.Position);
            }
            else
            {
                // Stalk forward
                float stalkSpeed = Phase == ChimeraPhase.Phase2_Enraged ? 6.5f : 4.0f;
                Actor.Position += toPlayer.Normalized * stalkSpeed * Time.DeltaTime;
            }
        }

        private void ExecuteClawCombo()
        {
            _actionCooldown = Phase == ChimeraPhase.Phase2_Enraged ? 1.4f : 2.2f;

            // Damage player if within forward sweep arc
            if (TargetPlayer != null)
            {
                var player = TargetPlayer.GetScript<Player.EchoPlayer>();
                if (player != null)
                {
                    player.TakeDamage(ClawDamage, Actor.Transform.Forward);
                }
            }
        }

        private void StartLeapSmash(Vector3 targetPos)
        {
            _isPerformingLeap = true;
            _leapProgress = 0f;
            _leapStartPos = Actor.Position;
            _leapTargetPos = targetPos;
            _actionCooldown = 3.0f;
        }

        private void UpdateLeapMotion()
        {
            _leapProgress += Time.DeltaTime * 1.6f;
            float t = Mathf.Clamp01(_leapProgress);

            // Parabolic arc: Y curve
            float heightArc = Mathf.Sin(t * Mathf.PI) * 4.5f;
            Vector3 currentHoriz = Vector3.Lerp(_leapStartPos, _leapTargetPos, t);
            currentHoriz.Y += heightArc;

            Actor.Position = currentHoriz;

            if (t >= 1.0f)
            {
                _isPerformingLeap = false;
                OnLeapImpact();
            }
        }

        private void OnLeapImpact()
        {
            // Spawn impact shockwave
            if (ShockwaveVFX != null)
                ShockwaveVFX.IsActive = true;

            // Damage player if in radius
            if (TargetPlayer != null)
            {
                float dist = Vector3.Distance(Actor.Position, TargetPlayer.Position);
                if (dist <= 5.5f)
                {
                    var player = TargetPlayer.GetScript<Player.EchoPlayer>();
                    player?.TakeDamage(LeapSmashDamage, (TargetPlayer.Position - Actor.Position).Normalized);
                }
            }
        }

        private void TriggerRoarShockwave()
        {
            _actionCooldown = 2.5f;
            // Knock back nearby actors
            if (TargetPlayer != null)
            {
                var player = TargetPlayer.GetScript<Player.EchoPlayer>();
                player?.TakeDamage(RoarShockwaveDamage, (TargetPlayer.Position - Actor.Position).Normalized);
            }
        }
    }
}
