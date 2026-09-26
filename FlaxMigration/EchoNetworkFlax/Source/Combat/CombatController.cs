using System;
using FlaxEngine;

namespace EchoNetwork.Combat
{
    /// <summary>
    /// Master Combat Controller for Echo in Flax Engine.
    /// Manages katana combos, deflection/parry timing, dodge invincible frames (i-frames),
    /// input buffering, and damage dispatching.
    /// </summary>
    public class CombatController : Script
    {
        [Header("Combo Configuration")]
        public float[] ComboDamage = new float[] { 85f, 110f, 140f, 220f };
        public float[] ComboStaminaCost = new float[] { 12f, 15f, 18f, 25f };
        public float ComboBufferWindow = 0.45f;
        public float ComboResetTime = 0.9f;

        [Header("Dodge / Evade")]
        public float DodgeStaminaCost = 18f;
        public float DodgeDuration = 0.4f;
        public float DodgeSpeed = 12f;
        public float IFrameDuration = 0.28f;

        [Header("Deflection")]
        public float DeflectWindowDuration = 0.18f;
        public float GuardPostureRegen = 15f;

        [Header("Subsystems")]
        public KatanaBladeSocket KatanaSocket;
        public DeflectParrySystem DeflectSystem;
        public HitStopController HitStop;
        public Camera.ThirdPersonOrbitCamera CombatCamera;
        public Player.EchoPlayer Player;

        public bool IsAttacking { get; private set; }
        public bool IsDodgeActive { get; private set; }
        public bool HasIFrames { get; private set; }
        public bool IsGuarding { get; private set; }
        public bool IsDeflecting => IsGuarding && _guardTimer <= DeflectWindowDuration;
        public int CurrentComboIndex { get; private set; } = 0;

        private float _attackTimer;
        private float _comboBufferTimer;
        private float _lastAttackTime;
        private float _guardTimer;
        private float _dodgeTimer;
        private Vector3 _dodgeDirection;

        public override void OnStart()
        {
            if (Player == null)
                Player = Actor.GetScript<Player.EchoPlayer>();

            if (KatanaSocket == null)
                KatanaSocket = Actor.GetScript<KatanaBladeSocket>();

            if (DeflectSystem == null)
                DeflectSystem = Actor.GetScript<DeflectParrySystem>();

            if (HitStop == null)
                HitStop = Actor.GetScript<HitStopController>();
        }

        public override void OnUpdate()
        {
            if (Player != null && Player.IsDead)
                return;

            HandleGuardInput();
            HandleDodge();
            HandleAttackInput();
            UpdateTimers();
        }

        private void HandleGuardInput()
        {
            if (Input.GetAction("Guard") && !IsAttacking && !IsDodgeActive)
            {
                if (!IsGuarding)
                {
                    IsGuarding = true;
                    _guardTimer = 0f;
                }
                else
                {
                    _guardTimer += Time.DeltaTime;
                }
            }
            else
            {
                IsGuarding = false;
            }
        }

        private void HandleAttackInput()
        {
            if (Input.GetAction("Attack") && !IsGuarding && !IsDodgeActive)
            {
                _comboBufferTimer = ComboBufferWindow;
            }

            if (_comboBufferTimer > 0f && !IsAttacking)
            {
                ExecuteNextComboStep();
                _comboBufferTimer = 0f;
            }
        }

        private void ExecuteNextComboStep()
        {
            if (Time.GameTime - _lastAttackTime > ComboResetTime)
            {
                CurrentComboIndex = 0;
            }

            float staminaCost = ComboStaminaCost[CurrentComboIndex];
            if (Player != null && !Player.ConsumeStamina(staminaCost))
                return;

            IsAttacking = true;
            _attackTimer = 0.55f;
            _lastAttackTime = Time.GameTime;

            // Enable blade collision hitbox for current attack step
            float dmg = ComboDamage[CurrentComboIndex];
            KatanaSocket?.EnableHitbox(dmg, CurrentComboIndex == 3);

            // Step forward slightly during slash
            Actor.Position += Actor.Transform.Forward * 0.45f;

            // Advance combo index
            CurrentComboIndex = (CurrentComboIndex + 1) % ComboDamage.Length;
        }

        private void HandleDodge()
        {
            if (Input.GetAction("Dodge") && !IsDodgeActive)
            {
                if (Player == null || Player.ConsumeStamina(DodgeStaminaCost))
                {
                    StartDodge();
                }
            }

            if (IsDodgeActive)
            {
                _dodgeTimer -= Time.DeltaTime;
                HasIFrames = (DodgeDuration - _dodgeTimer) <= IFrameDuration;

                // Move actor in dodge direction
                var controller = Actor.As<CharacterController>();
                if (controller != null)
                {
                    controller.Move(_dodgeDirection * DodgeSpeed * Time.DeltaTime);
                }

                if (_dodgeTimer <= 0f)
                {
                    IsDodgeActive = false;
                    HasIFrames = false;
                }
            }
        }

        private void StartDodge()
        {
            IsDodgeActive = true;
            _dodgeTimer = DodgeDuration;
            HasIFrames = true;
            IsAttacking = false;
            KatanaSocket?.DisableHitbox();

            float inputH = Input.GetAxis("Horizontal");
            float inputV = Input.GetAxis("Vertical");
            Vector3 inputDir = new Vector3(inputH, 0f, inputV);

            if (inputDir.LengthSquared > 0.01f)
            {
                inputDir.Normalize();
                Vector3 fwd = Actor.Transform.Forward;
                Vector3 right = Actor.Transform.Right;
                _dodgeDirection = (fwd * inputDir.Z + right * inputDir.X).Normalized;
            }
            else
            {
                _dodgeDirection = -Actor.Transform.Forward; // Back-step dodge
            }
        }

        private void UpdateTimers()
        {
            if (_comboBufferTimer > 0f)
                _comboBufferTimer -= Time.DeltaTime;

            if (IsAttacking)
            {
                _attackTimer -= Time.DeltaTime;
                if (_attackTimer <= 0f)
                {
                    IsAttacking = false;
                    KatanaSocket?.DisableHitbox();
                }
            }
        }

        public void OnSuccessfulDeflect(Vector3 impactDir)
        {
            DeflectSystem?.TriggerDeflectEffects(Actor.Position + Actor.Transform.Forward * 0.8f + Vector3.Up * 1.2f);
            HitStop?.TriggerHitStop(0.08f);
            CombatCamera?.TriggerCameraShake(0.35f, 0.15f);
            Player?.AddAwakeningCharge(12f);
        }

        public void TriggerHitReaction(float damage, Vector3 impactDir)
        {
            if (HasIFrames)
                return;

            IsAttacking = false;
            KatanaSocket?.DisableHitbox();
            CombatCamera?.TriggerCameraShake(0.5f, 0.2f);
            HitStop?.TriggerHitStop(0.06f);
        }
    }
}
