using System;
using FlaxEngine;

namespace EchoNetwork.Combat
{
    /// <summary>
    /// Hit-Stop (Impact Freeze Frame) Controller in Flax Engine.
    /// Temporarily scales down Time.TimeScale for a few frames upon heavy katana impact
    /// to deliver visceral Genshin / DMC style impact crunch.
    /// </summary>
    public class HitStopController : Script
    {
        private float _freezeTimer = 0f;
        private float _originalTimeScale = 1f;
        private bool _isFreezing = false;

        public override void OnUpdate()
        {
            if (_isFreezing)
            {
                // Note: Use unscaled delta time during time freeze
                _freezeTimer -= Time.UnscaledDeltaTime;
                if (_freezeTimer <= 0f)
                {
                    Time.TimeScale = _originalTimeScale;
                    _isFreezing = false;
                }
            }
        }

        public void TriggerHitStop(float duration, float scale = 0.05f)
        {
            if (!_isFreezing)
                _originalTimeScale = Time.TimeScale;

            _freezeTimer = duration;
            _isFreezing = true;
            Time.TimeScale = scale;
        }

        public override void OnDestroy()
        {
            if (_isFreezing)
                Time.TimeScale = _originalTimeScale;
        }
    }
}
