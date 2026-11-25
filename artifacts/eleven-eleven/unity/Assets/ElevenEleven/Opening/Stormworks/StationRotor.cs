using UnityEngine;

namespace ElevenEleven.Opening
{
    public sealed class StationRotor : MonoBehaviour
    {
        [SerializeField] private float degreesPerSecond = 75f;
        private Quaternion rest;
        private static readonly int Clock = Shader.PropertyToID("_EchoSurfaceClock");

        private void Awake() => rest = transform.localRotation;

        private void Update()
        {
            if (ChapterSceneLink.ReducedMotion)
            {
                transform.localRotation = rest;
                return;
            }

            var t = Shader.GetGlobalFloat(Clock);
            var angle = Mathf.Repeat(degreesPerSecond * (0.84f * t + 0.16f / 1.4f * (1f - Mathf.Cos(t * 1.4f))), 360f);
            transform.localRotation = rest * Quaternion.AngleAxis(angle, Vector3.forward);
        }
    }
}

