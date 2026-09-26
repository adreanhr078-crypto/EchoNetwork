using System;
using FlaxEngine;

namespace EchoNetwork.Enemies
{
    /// <summary>
    /// Base class for all Enemy AI actors in Flax Engine.
    /// Provides shared health, poise/posture systems, damage reactions, and death handling.
    /// </summary>
    public abstract class EnemyBase : Script
    {
        [Header("Base Enemy Stats")]
        public string EnemyName = "Enemy";
        public float MaxHealth = 500f;
        public float CurrentHealth = 500f;
        public float MaxPosture = 100f;
        public float CurrentPosture = 0f;
        public float PoiseHealth = 50f;
        public float PostureRecoveryRate = 15f;

        [Header("State")]
        public bool IsDead => CurrentHealth <= 0f;
        public bool IsStaggered { get; protected set; }
        public bool IsPostureBroken => CurrentPosture >= MaxPosture;

        public event Action<float, float> OnHealthChanged;
        public event Action<float, float> OnPostureChanged;
        public event Action OnEnemyDied;

        protected float _staggerTimer = 0f;
        protected float _currentPoise = 50f;

        public override void OnStart()
        {
            CurrentHealth = MaxHealth;
            _currentPoise = PoiseHealth;
        }

        public override void OnUpdate()
        {
            if (IsDead)
                return;

            if (IsStaggered)
            {
                _staggerTimer -= Time.DeltaTime;
                if (_staggerTimer <= 0f)
                {
                    IsStaggered = false;
                }
            }

            if (CurrentPosture > 0f && !IsPostureBroken)
            {
                CurrentPosture = Mathf.Max(0f, CurrentPosture - PostureRecoveryRate * Time.DeltaTime);
                OnPostureChanged?.Invoke(CurrentPosture, MaxPosture);
            }
        }

        public virtual void TakeDamage(float damage, Vector3 impactDir, bool isHeavy)
        {
            if (IsDead)
                return;

            CurrentHealth = Mathf.Max(0f, CurrentHealth - damage);
            OnHealthChanged?.Invoke(CurrentHealth, MaxHealth);

            // Accumulate posture damage
            float postureDmg = isHeavy ? 30f : 15f;
            CurrentPosture = Mathf.Min(MaxPosture, CurrentPosture + postureDmg);
            OnPostureChanged?.Invoke(CurrentPosture, MaxPosture);

            // Poise depletion
            _currentPoise -= isHeavy ? 35f : 15f;
            if (_currentPoise <= 0f || CurrentPosture >= MaxPosture)
            {
                TriggerStagger(isHeavy ? 1.2f : 0.6f);
                _currentPoise = PoiseHealth;
            }

            if (CurrentHealth <= 0f)
            {
                Die();
            }
        }

        protected virtual void TriggerStagger(float duration)
        {
            IsStaggered = true;
            _staggerTimer = duration;
        }

        protected virtual void Die()
        {
            OnEnemyDied?.Invoke();
            // Disable colliders, play death animation, dissolve mesh
            Destroy(Actor, 3.5f);
        }
    }
}
