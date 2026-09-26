using System;
using FlaxEngine;

namespace EchoNetwork.Combat
{
    /// <summary>
    /// Sekiro-style Deflection and Posture System in Flax Engine.
    /// Manages posture gauge accumulation, deflection spark VFX, and guard-break stagger states.
    /// </summary>
    public class DeflectParrySystem : Script
    {
        [Header("Posture Settings")]
        public float MaxPosture = 100f;
        public float CurrentPosture = 0f;
        public float PostureRecoveryRate = 20f;
        public float DeflectPostureBonusDamage = 35f;

        [Header("Effects")]
        public ParticleEffect DeflectSparksPrefab;
        public AudioSource DeflectAudioSource;

        public bool IsGuardBroken => CurrentPosture >= MaxPosture;

        public event Action OnGuardBreak;
        public event Action<float, float> OnPostureChanged;

        public override void OnUpdate()
        {
            if (CurrentPosture > 0f && !IsGuardBroken)
            {
                CurrentPosture = Mathf.Max(0f, CurrentPosture - PostureRecoveryRate * Time.DeltaTime);
                OnPostureChanged?.Invoke(CurrentPosture, MaxPosture);
            }
        }

        public void AddPostureDamage(float amount)
        {
            CurrentPosture = Mathf.Min(MaxPosture, CurrentPosture + amount);
            OnPostureChanged?.Invoke(CurrentPosture, MaxPosture);

            if (CurrentPosture >= MaxPosture)
            {
                TriggerGuardBreak();
            }
        }

        public void TriggerDeflectEffects(Vector3 sparkLocation)
        {
            if (DeflectSparksPrefab != null)
            {
                // In Flax, spawn or position particle system
                var sparkActor = Level.SpawnActor<ParticleEffect>();
                if (sparkActor != null)
                {
                    sparkActor.Position = sparkLocation;
                    Destroy(sparkActor, 1.2f);
                }
            }

            if (DeflectAudioSource != null)
            {
                DeflectAudioSource.Play();
            }
        }

        private void TriggerGuardBreak()
        {
            OnGuardBreak?.Invoke();
            // Stun and enable visceral death blow window
        }

        public void ResetPosture()
        {
            CurrentPosture = 0f;
            OnPostureChanged?.Invoke(CurrentPosture, MaxPosture);
        }
    }
}
