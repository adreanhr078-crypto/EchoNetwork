using System;
using FlaxEngine;

namespace EchoNetwork.Enemies
{
    /// <summary>
    /// Dr. Kinga Neuro-Lab Boss AI in Flax Engine.
    /// Manages ranged psychic singularity projectiles, defensive teleportation evasions,
    /// and lab barrier shield mechanics.
    /// </summary>
    public class DrKingaAI : EnemyBase
    {
        [Header("Kinga Combat Stats")]
        public float TeleportProximityThreshold = 3.2f;
        public float TeleportCooldown = 4.5f;
        public float SingularityDamage = 130f;
        public float CastCooldown = 3.0f;

        [Header("Teleport Anchors")]
        public Transform[] LabTeleportAnchors;

        [Header("Target")]
        public Actor TargetPlayer;

        private float _teleportTimer = 0f;
        private float _castTimer = 0f;
        private int _lastAnchorIndex = -1;

        public override void OnStart()
        {
            base.OnStart();
            EnemyName = "Dr. Kinga (Chief Neuro-Architect)";
            MaxHealth = 2800f;
            CurrentHealth = 2800f;
            MaxPosture = 200f;
            PoiseHealth = 120f;

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

            if (_teleportTimer > 0f)
                _teleportTimer -= Time.DeltaTime;

            if (_castTimer > 0f)
                _castTimer -= Time.DeltaTime;

            if (TargetPlayer != null)
            {
                // Face player
                Vector3 toPlayer = TargetPlayer.Position - Actor.Position;
                toPlayer.Y = 0f;
                if (toPlayer.LengthSquared > 0.01f)
                {
                    Actor.Orientation = Quaternion.Slerp(Actor.Orientation, Quaternion.LookRotation(toPlayer.Normalized, Vector3.Up), 6f * Time.DeltaTime);
                }

                // Check emergency teleport evasion if player is too close
                float dist = Vector3.Distance(Actor.Position, TargetPlayer.Position);
                if (dist <= TeleportProximityThreshold && _teleportTimer <= 0f)
                {
                    ExecuteTeleportEvasion();
                    return;
                }

                // Cast ranged singularity attack
                if (_castTimer <= 0f && !IsStaggered)
                {
                    CastSingularityProjectile();
                    _castTimer = CastCooldown;
                }
            }
        }

        private void ExecuteTeleportEvasion()
        {
            _teleportTimer = TeleportCooldown;

            if (LabTeleportAnchors != null && LabTeleportAnchors.Length > 0)
            {
                int newIndex = (_lastAnchorIndex + 1) % LabTeleportAnchors.Length;
                _lastAnchorIndex = newIndex;
                Actor.Position = LabTeleportAnchors[newIndex].Translation;
            }
            else
            {
                // Fallback: Teleport 8 meters backward
                Actor.Position -= Actor.Transform.Forward * 8f;
            }
        }

        private void CastSingularityProjectile()
        {
            if (TargetPlayer == null)
                return;

            Vector3 spawnPos = Actor.Position + Vector3.Up * 1.5f + Actor.Transform.Forward * 1.0f;
            Vector3 aimDir = ((TargetPlayer.Position + Vector3.Up * 1.0f) - spawnPos).Normalized;

            // Spawn projectile actor or raycast hit
            if (Physics.RayCast(spawnPos, aimDir, out RayCastHit hit, 30.0f))
            {
                var player = hit.Actor.GetScript<Player.EchoPlayer>();
                if (player != null)
                {
                    player.TakeDamage(SingularityDamage, aimDir);
                }
            }
        }
    }
}
