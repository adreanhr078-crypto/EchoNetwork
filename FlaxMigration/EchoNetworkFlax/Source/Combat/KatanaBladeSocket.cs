using System;
using System.Collections.Generic;
using FlaxEngine;

namespace EchoNetwork.Combat
{
    /// <summary>
    /// Katana weapon socket and collision hitbox controller in Flax Engine.
    /// Synchronizes blade transform to the RightHand skeletal bone socket,
    /// traces blade sweep arcs during attack swings, and applies damage to struck enemies.
    /// </summary>
    public class KatanaBladeSocket : Script
    {
        [Header("Socket Configuration")]
        public AnimatedModel OwnerModel;
        public string SocketBoneName = "RightHand";
        public Vector3 SocketOffsetPosition = new Vector3(0.05f, 0.02f, 0.1f);
        public Vector3 SocketOffsetRotation = new Vector3(0f, 90f, 0f);

        [Header("Hitbox Blade Extents")]
        public Vector3 BladeBaseOffset = new Vector3(0f, 0f, 0.15f);
        public Vector3 BladeTipOffset = new Vector3(0f, 0f, 1.15f);
        public float BladeSweepRadius = 0.18f;
        public LayerMask HitLayers = -1;

        [Header("Visual Effects")]
        public ParticleEffect SlashTrailEffect;

        public bool IsHitboxActive { get; private set; }

        private float _currentDamage;
        private bool _isHeavyFinisher;
        private readonly HashSet<Actor> _alreadyStruckActors = new HashSet<Actor>();
        private Vector3 _lastBasePos;
        private Vector3 _lastTipPos;

        public override void OnStart()
        {
            if (OwnerModel == null && Actor.Parent != null)
                OwnerModel = Actor.Parent.As<AnimatedModel>();
        }

        public override void OnUpdate()
        {
            UpdateSocketTransform();

            if (IsHitboxActive)
            {
                PerformBladeSweep();
            }
        }

        private void UpdateSocketTransform()
        {
            if (OwnerModel != null && !string.IsNullOrEmpty(SocketBoneName))
            {
                // In Flax Engine, extract bone socket transform directly
                OwnerModel.GetSocketTransform(SocketBoneName, out Transform boneTransform);

                Quaternion offsetRot = Quaternion.Euler(SocketOffsetRotation);
                Actor.Position = boneTransform.LocalToWorld(SocketOffsetPosition);
                Actor.Orientation = boneTransform.Orientation * offsetRot;
            }
        }

        public void EnableHitbox(float damage, bool isHeavy)
        {
            IsHitboxActive = true;
            _currentDamage = damage;
            _isHeavyFinisher = isHeavy;
            _alreadyStruckActors.Clear();

            _lastBasePos = Actor.Transform.LocalToWorld(BladeBaseOffset);
            _lastTipPos = Actor.Transform.LocalToWorld(BladeTipOffset);

            if (SlashTrailEffect != null)
                SlashTrailEffect.IsActive = true;
        }

        public void DisableHitbox()
        {
            IsHitboxActive = false;
            _alreadyStruckActors.Clear();

            if (SlashTrailEffect != null)
                SlashTrailEffect.IsActive = false;
        }

        private void PerformBladeSweep()
        {
            Vector3 currentBase = Actor.Transform.LocalToWorld(BladeBaseOffset);
            Vector3 currentTip = Actor.Transform.LocalToWorld(BladeTipOffset);

            // Sweep segment from base to tip, plus history from last frame
            Vector3 sweepDir = (currentTip - _lastTipPos);
            float sweepDist = sweepDir.Length;

            if (sweepDist > 0.001f)
            {
                RayCastHit[] hits = Physics.SphereCastAll(currentTip, BladeSweepRadius, HitLayers);
                foreach (var hit in hits)
                {
                    if (hit.Actor == null || hit.Actor == Actor.Parent)
                        continue;

                    if (_alreadyStruckActors.Contains(hit.Actor))
                        continue;

                    // Check for Enemy component
                    var enemy = hit.Actor.GetScript<Enemies.EnemyBase>();
                    if (enemy != null)
                    {
                        _alreadyStruckActors.Add(hit.Actor);
                        Vector3 impactDir = (hit.Actor.Position - Actor.Position).Normalized;
                        enemy.TakeDamage(_currentDamage, impactDir, _isHeavyFinisher);
                    }
                }
            }

            _lastBasePos = currentBase;
            _lastTipPos = currentTip;
        }
    }
}
