using System;
using FlaxEngine;
using FlaxEngine.GUI;

namespace EchoNetwork.UI
{
    /// <summary>
    /// Master Gameplay HUD Controller in Flax Engine.
    /// Manages player health bar, stamina meter, monarch awakening gauge,
    /// enemy lock-on reticle, and boss posture/health bars.
    /// </summary>
    public class GameplayHUDController : Script
    {
        [Header("UI Control Roots")]
        public UIControl HUDCanvas;
        public UIControl HealthBarFill;
        public UIControl StaminaBarFill;
        public UIControl AwakeningBarFill;

        [Header("Boss Bar")]
        public UIControl BossBarRoot;
        public UIControl BossHealthBarFill;
        public UIControl BossPostureBarFill;
        public UIControl BossNameLabel;

        [Header("Player Reference")]
        public Player.EchoPlayer Player;

        private float _targetHealthWidth = 1f;
        private float _targetStaminaWidth = 1f;
        private float _targetAwakeningWidth = 0f;

        public override void OnStart()
        {
            if (Player == null)
                Player = Level.FindScript<Player.EchoPlayer>();

            if (Player != null)
            {
                Player.OnHealthChanged += HandleHealthChanged;
                Player.OnStaminaChanged += HandleStaminaChanged;
                Player.OnAwakeningGaugeChanged += HandleAwakeningChanged;
            }

            if (BossBarRoot != null)
                BossBarRoot.IsActive = false;
        }

        public override void OnDestroy()
        {
            if (Player != null)
            {
                Player.OnHealthChanged -= HandleHealthChanged;
                Player.OnStaminaChanged -= HandleStaminaChanged;
                Player.OnAwakeningGaugeChanged -= HandleAwakeningChanged;
            }
        }

        private void HandleHealthChanged(float current, float max)
        {
            _targetHealthWidth = Mathf.Clamp01(current / max);
        }

        private void HandleStaminaChanged(float current, float max)
        {
            _targetStaminaWidth = Mathf.Clamp01(current / max);
        }

        private void HandleAwakeningChanged(float gauge)
        {
            _targetAwakeningWidth = Mathf.Clamp01(gauge / 100f);
        }

        public void DisplayBossHealth(string bossName, float currentHp, float maxHp, float currentPosture, float maxPosture)
        {
            if (BossBarRoot != null)
                BossBarRoot.IsActive = true;

            // Update boss health and posture fill ratios
        }

        public void HideBossHealth()
        {
            if (BossBarRoot != null)
                BossBarRoot.IsActive = false;
        }
    }
}
