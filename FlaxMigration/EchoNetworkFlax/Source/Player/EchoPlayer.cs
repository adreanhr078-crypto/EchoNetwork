using System;
using FlaxEngine;

namespace EchoNetwork.Player
{
    /// <summary>
    /// Core Player controller for Echo in Flax Engine.
    /// Manages player status, input dispatching, health, stamina, and subsystem coordination.
    /// </summary>
    public class EchoPlayer : Script
    {
        [Header("Character Stats")]
        [Tooltip("Maximum player health points.")]
        public float MaxHealth = 1000f;

        [Tooltip("Current health points.")]
        public float CurrentHealth = 1000f;

        [Tooltip("Maximum stamina for sprint, dodge, and parkour.")]
        public float MaxStamina = 100f;

        [Tooltip("Current stamina points.")]
        public float CurrentStamina = 100f;

        [Tooltip("Stamina recovery rate per second.")]
        public float StaminaRecoveryRate = 25f;

        [Tooltip("Monarch awakening gauge (0 to 100).")]
        public float AwakeningGauge = 0f;

        [Header("Subsystem References")]
        public CharacterController Controller;
        public EchoLocomotion Locomotion;
        public PlayerTraversalController Traversal;
        public Combat.CombatController Combat;
        public AnimatedModel CharacterModel;

        public bool IsDead => CurrentHealth <= 0f;
        public bool IsAwakened { get; private set; }

        public event Action<float, float> OnHealthChanged;
        public event Action<float, float> OnStaminaChanged;
        public event Action<float> OnAwakeningGaugeChanged;
        public event Action OnPlayerDied;

        public override void OnStart()
        {
            if (Controller == null)
                Controller = Actor.As<CharacterController>();

            if (Locomotion == null)
                Locomotion = Actor.GetScript<EchoLocomotion>();

            if (Traversal == null)
                Traversal = Actor.GetScript<PlayerTraversalController>();

            if (Combat == null)
                Combat = Actor.GetScript<Combat.CombatController>();

            CurrentHealth = MaxHealth;
            CurrentStamina = MaxStamina;
        }

        public override void OnUpdate()
        {
            if (IsDead)
                return;

            HandleStaminaRegen();
            HandleAwakeningInput();
        }

        private void HandleStaminaRegen()
        {
            if (Combat != null && Combat.IsAttacking)
                return;

            if (Locomotion != null && Locomotion.IsSprinting)
                return;

            if (CurrentStamina < MaxStamina)
            {
                CurrentStamina = Mathf.Min(MaxStamina, CurrentStamina + StaminaRecoveryRate * Time.DeltaTime);
                OnStaminaChanged?.Invoke(CurrentStamina, MaxStamina);
            }
        }

        private void HandleAwakeningInput()
        {
            if (Input.GetAction("Awakening") && AwakeningGauge >= 100f && !IsAwakened)
            {
                TriggerMonarchAwakening();
            }
        }

        public bool ConsumeStamina(float amount)
        {
            if (CurrentStamina >= amount)
            {
                CurrentStamina -= amount;
                OnStaminaChanged?.Invoke(CurrentStamina, MaxStamina);
                return true;
            }
            return false;
        }

        public void TakeDamage(float damage, Vector3 impactDirection)
        {
            if (IsDead)
                return;

            if (Combat != null && Combat.IsDeflecting)
            {
                // Successful deflect - zero damage to player
                Combat.OnSuccessfulDeflect(impactDirection);
                return;
            }

            CurrentHealth = Mathf.Max(0f, CurrentHealth - damage);
            OnHealthChanged?.Invoke(CurrentHealth, MaxHealth);

            // Additive hit reaction in combat controller
            Combat?.TriggerHitReaction(damage, impactDirection);

            if (CurrentHealth <= 0f)
            {
                Die();
            }
        }

        public void Heal(float amount)
        {
            if (IsDead)
                return;

            CurrentHealth = Mathf.Min(MaxHealth, CurrentHealth + amount);
            OnHealthChanged?.Invoke(CurrentHealth, MaxHealth);
        }

        public void AddAwakeningCharge(float amount)
        {
            AwakeningGauge = Mathf.Clamp(AwakeningGauge + amount, 0f, 100f);
            OnAwakeningGaugeChanged?.Invoke(AwakeningGauge);
        }

        public void TriggerMonarchAwakening()
        {
            IsAwakened = true;
            AwakeningGauge = 0f;
            OnAwakeningGaugeChanged?.Invoke(AwakeningGauge);
            // Boost speed, attack speed, and spawn shadow aura
        }

        private void Die()
        {
            OnPlayerDied?.Invoke();
            // Trigger death animation
        }
    }
}
