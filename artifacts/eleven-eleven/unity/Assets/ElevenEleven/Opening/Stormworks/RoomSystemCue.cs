using UnityEngine;

namespace ElevenEleven.Opening
{
    [DisallowMultipleComponent]
    public sealed class RoomSystemCue : MonoBehaviour
    {
        public enum SystemChannel { Pressure, WestBreaker, EastBreaker, Quarantine, Surveillance }

        private static readonly int Emission = Shader.PropertyToID("_EmissionColor");
        private static readonly int BaseColor = Shader.PropertyToID("_BaseColor");
        private static readonly Color Warning = new Color(1f, .32f, .105f);
        private static readonly Color Venting = new Color(1f, .70f, .285f);
        private static readonly Color Ready = new Color(.16f, .79f, .60f);
        [SerializeField] private StormworksRoute route;
        [SerializeField] private SystemChannel channel;
        [SerializeField] private Renderer lens;
        [SerializeField] private Light spill;
        [SerializeField] private Transform ventMeter;
        private MaterialPropertyBlock properties;
        private Vector3 meterSize;
        private Vector3 meterHome;
        private int previous = -1;
        private float previousVent = -1f;

        private void Awake()
        {
            properties = new MaterialPropertyBlock();
            if (!ventMeter) return;
            meterSize = ventMeter.localScale;
            meterHome = ventMeter.localPosition;
        }

        private void OnEnable()
        {
            previous = -1;
            previousVent = -1f;
            UpdateCue();
        }

        private void LateUpdate() => UpdateCue();

        private void UpdateCue()
        {
            var vent = channel == SystemChannel.Pressure ? route.PressureVentFraction : 0f;
            var state = channel switch
            {
                SystemChannel.Pressure => vent > 0f ? 1 : route.PressureIsSafe ? 2 : 0,
                SystemChannel.WestBreaker => (route.PoweredBreakers & 1) != 0 ? 2 : 0,
                SystemChannel.EastBreaker => (route.PoweredBreakers & 2) != 0 ? 2 : 0,
                SystemChannel.Quarantine => route.Stage >= StormworksRoute.QuarantineOverridden ? 2 : 0,
                _ => route.Stage >= StormworksRoute.SurveillanceOverridden ? 2 : 0
            };
            if (ventMeter)
            {
                var remaining = ChapterSceneLink.ReducedMotion && vent > 0f ? 1f : vent;
                if (remaining != previousVent)
                {
                    ventMeter.gameObject.SetActive(remaining > 0f);
                    ventMeter.localScale = new Vector3(meterSize.x, meterSize.y * remaining, meterSize.z);
                    ventMeter.localPosition = meterHome + Vector3.down * (meterSize.y * (1f - remaining) * .5f);
                    previousVent = remaining;
                }
            }
            if (state == previous) return;
            var color = state == 2 ? Ready : state == 1 ? Venting : Warning;
            lens.GetPropertyBlock(properties);
            properties.SetColor(BaseColor, color);
            properties.SetColor(Emission, color * 2.1f);
            lens.SetPropertyBlock(properties);
            spill.color = color;
            spill.intensity = state == 1 ? 2.5f : 1.65f;
            previous = state;
        }
    }
}
