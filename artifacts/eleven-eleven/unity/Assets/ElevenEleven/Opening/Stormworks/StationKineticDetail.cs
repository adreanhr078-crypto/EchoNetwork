using UnityEngine;

namespace ElevenEleven.Opening
{
    /// <summary>
    /// Drives lightweight ambient mechanical, optical, and luminous kinetic motion for station fixtures
    /// without mutating RoomEnvironmentMotion component topology. Respects ReducedMotion.
    /// </summary>
    public sealed class StationKineticDetail : MonoBehaviour
    {
        public enum MotionMode
        {
            Spin = 0,
            OscillateAngle = 1,
            FloatBob = 2,
            PulseScale = 3,
        }

        [SerializeField] private MotionMode mode = MotionMode.Spin;
        [SerializeField] private Vector3 localAxis = Vector3.up;
        [SerializeField] private float speed = 45f;
        [SerializeField] private float amplitude = 18f;
        [SerializeField] private float phaseOffset;

        [Header("Optional Emissive Pulse")]
        [SerializeField] private Renderer pulseRenderer;
        [SerializeField] private Color pulseColor = Color.clear;
        [SerializeField] private float pulseMin = 0.72f;
        [SerializeField] private float pulseMax = 1.28f;
        [SerializeField] private float pulseHz = 0.85f;

        private Vector3 restLocalPos;
        private Quaternion restLocalRot;
        private Vector3 restLocalScale;
        private MaterialPropertyBlock mpb;
        private static readonly int Clock = Shader.PropertyToID("_EchoSurfaceClock");
        private static readonly int EmissionColorId = Shader.PropertyToID("_EmissionColor");

        private void Awake()
        {
            restLocalPos = transform.localPosition;
            restLocalRot = transform.localRotation;
            restLocalScale = transform.localScale;
        }

        public void Configure(
            MotionMode motionMode,
            Vector3 axis,
            float motionSpeed,
            float motionAmplitude,
            float phase = 0f,
            Renderer emissiveTarget = null,
            Color? emissiveColor = null,
            float minGlow = 0.72f,
            float maxGlow = 1.28f,
            float glowHz = 0.85f)
        {
            mode = motionMode;
            localAxis = axis.sqrMagnitude > 0.0001f ? axis.normalized : Vector3.up;
            speed = motionSpeed;
            amplitude = motionAmplitude;
            phaseOffset = phase;
            pulseRenderer = emissiveTarget;
            pulseColor = emissiveColor ?? Color.clear;
            pulseMin = minGlow;
            pulseMax = maxGlow;
            pulseHz = glowHz;
            restLocalPos = transform.localPosition;
            restLocalRot = transform.localRotation;
            restLocalScale = transform.localScale;
        }

        private void OnDisable()
        {
            ResetToRest();
        }

        private void Update()
        {
            if (ChapterSceneLink.ReducedMotion)
            {
                ResetToRest();
                return;
            }

            var clock = Shader.GetGlobalFloat(Clock);
            var t = (clock > 0.0001f ? clock : Time.time) + phaseOffset;
            var axis = localAxis.sqrMagnitude > 0.0001f ? localAxis.normalized : Vector3.up;

            switch (mode)
            {
                case MotionMode.Spin:
                {
                    var deg = Mathf.Repeat(speed * t, 360f);
                    transform.localRotation = restLocalRot * Quaternion.AngleAxis(deg, axis);
                    break;
                }
                case MotionMode.OscillateAngle:
                {
                    var deg = Mathf.Sin(t * speed) * amplitude;
                    transform.localRotation = restLocalRot * Quaternion.AngleAxis(deg, axis);
                    break;
                }
                case MotionMode.FloatBob:
                {
                    var wave = Mathf.Sin(t * speed);
                    transform.localPosition = restLocalPos + axis * (wave * amplitude);
                    transform.localRotation = restLocalRot * Quaternion.AngleAxis(Mathf.Repeat(t * 14f, 360f), Vector3.up);
                    break;
                }
                case MotionMode.PulseScale:
                {
                    var mul = 1f + Mathf.Sin(t * speed) * amplitude;
                    transform.localScale = restLocalScale * Mathf.Max(0.05f, mul);
                    break;
                }
            }

            if (pulseRenderer && pulseColor.maxColorComponent > 0.001f)
            {
                mpb ??= new MaterialPropertyBlock();
                var pulse = Mathf.Lerp(pulseMin, pulseMax, 0.5f + 0.5f * Mathf.Sin(t * pulseHz * Mathf.PI * 2f));
                pulseRenderer.GetPropertyBlock(mpb);
                mpb.SetColor(EmissionColorId, pulseColor * pulse);
                pulseRenderer.SetPropertyBlock(mpb);
            }
        }

        private void ResetToRest()
        {
            transform.localPosition = restLocalPos;
            transform.localRotation = restLocalRot;
            transform.localScale = restLocalScale;
            if (pulseRenderer && pulseColor.maxColorComponent > 0.001f)
            {
                mpb ??= new MaterialPropertyBlock();
                pulseRenderer.GetPropertyBlock(mpb);
                mpb.SetColor(EmissionColorId, pulseColor);
                pulseRenderer.SetPropertyBlock(mpb);
            }
        }
    }
}
