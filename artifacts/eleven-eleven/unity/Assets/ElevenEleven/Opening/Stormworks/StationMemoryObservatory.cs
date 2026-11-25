using UnityEngine;

namespace ElevenEleven.Opening
{
    public sealed class StationMemoryObservatory : MonoBehaviour
    {
        [SerializeField] private Renderer sky;
        [SerializeField] private Transform[] driftingMemories;
        [SerializeField] private Transform clockRotor;
        [SerializeField] private Transform gyroRotor;
        [SerializeField] private Renderer clockReadout;

        private static readonly int SurfaceClock = Shader.PropertyToID("_EchoSurfaceClock");
        private Vector3[] positions;
        private Quaternion[] rotations;
        private static readonly Vector3 ClockAxle = new Vector3(.27f,.95f,.14f).normalized;
        private static readonly int DotIntensity = Shader.PropertyToID("_ClockDotIntensity");
        private MaterialPropertyBlock clockProperties;
        private Quaternion initialClock;
        private Quaternion initialGyro;
        private Vector3 clockCenter;
        private Camera observer;

        private void Awake()
        {
            positions = new Vector3[driftingMemories.Length];
            rotations = new Quaternion[driftingMemories.Length];
            for (var index = 0; index < driftingMemories.Length; index++)
            {
                positions[index] = driftingMemories[index].localPosition;
                rotations[index] = driftingMemories[index].localRotation;
            }
            sky.enabled = false;
            if (clockRotor == null || clockReadout == null) return;
            initialClock = clockRotor.localRotation;
            clockCenter = clockRotor.localPosition;
            if (gyroRotor != null) initialGyro = gyroRotor.localRotation;
            clockProperties = new MaterialPropertyBlock();
        }

        private void LateUpdate()
        {
            if (observer == null) observer = Camera.main;
            if (observer == null) return;
            var position = transform.InverseTransformPoint(observer.transform.position);
            sky.enabled = position.z > 32f && position.z < 85f && Mathf.Abs(position.x) < 28f;

            var motion = ChapterSceneLink.ReducedMotion ? 0f : 1f;
            var clock = Shader.GetGlobalFloat(SurfaceClock);
            if (clockProperties != null)
            {
                var angle = Mathf.Repeat(clock * 6f, 360f) * motion;
                clockRotor.localPosition = clockCenter + Vector3.up * (Mathf.Sin(clock * .38f) * .68f * motion);
                clockRotor.localRotation = initialClock * Quaternion.AngleAxis(angle,ClockAxle);
                if (gyroRotor != null)
                    gyroRotor.localRotation = initialGyro * Quaternion.AngleAxis(Mathf.Repeat(clock*13f,360f)*motion,Vector3.right);

                var wave = .5f + .5f * Mathf.Sin(clock * (2f * Mathf.PI / 2.6f));
                var upper = Mathf.Lerp(1f, Mathf.Lerp(.28f,1.27f,Mathf.SmoothStep(0f,1f,wave)),motion);
                var lower = Mathf.Lerp(1f, Mathf.Lerp(.28f,1.27f,Mathf.SmoothStep(0f,1f,1f-wave)),motion);
                clockReadout.GetPropertyBlock(clockProperties);
                clockProperties.SetVector(DotIntensity,new Vector4(upper,lower,0,0));
                clockReadout.SetPropertyBlock(clockProperties);
            }
            for (var i = 0; i < driftingMemories.Length; i++)
            {
                var phase = clock * (.25f + i * .031f) + i * 1.77f;
                var translation = new Vector3(Mathf.Sin(phase) * .87f, Mathf.Sin(phase * 1.13f) * .60f,
                    Mathf.Cos(phase) * .38f);
                var tilt = Quaternion.Euler(Mathf.Sin(phase) * 9f, Mathf.Cos(phase * .79f) * 12f, Mathf.Sin(phase) * 6f);
                driftingMemories[i].localPosition = positions[i] + translation * motion;
                driftingMemories[i].localRotation = rotations[i] * Quaternion.Slerp(Quaternion.identity, tilt, motion);
            }
        }
    }
}
