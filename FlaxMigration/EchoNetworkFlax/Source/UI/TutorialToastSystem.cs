using System;
using FlaxEngine;
using FlaxEngine.GUI;

namespace EchoNetwork.UI
{
    /// <summary>
    /// Contextual Tutorial Toast System in Flax Engine.
    /// Displays animated onscreen button prompts and instructions for traversal,
    /// parkour, combat deflections, and story interactions.
    /// </summary>
    public class TutorialToastSystem : Script
    {
        [Header("UI References")]
        public UIControl ToastContainer;
        public UIControl TitleLabelControl;
        public UIControl DescriptionLabelControl;
        public UIControl ActionKeyPromptControl;

        public bool IsToastActive { get; private set; }

        private float _toastTimer = 0f;
        private float _toastDuration = 4.0f;

        public override void OnStart()
        {
            if (ToastContainer != null)
                ToastContainer.IsActive = false;
        }

        public override void OnUpdate()
        {
            if (IsToastActive)
            {
                _toastTimer -= Time.DeltaTime;
                if (_toastTimer <= 0f)
                {
                    HideToast();
                }
            }
        }

        public void ShowToast(string title, string description, string actionKey, float duration = 4.0f)
        {
            _toastDuration = duration;
            _toastTimer = duration;
            IsToastActive = true;

            if (ToastContainer != null)
                ToastContainer.IsActive = true;

            // In Flax UI, set label text components
        }

        public void HideToast()
        {
            IsToastActive = false;
            if (ToastContainer != null)
                ToastContainer.IsActive = false;
        }
    }
}
