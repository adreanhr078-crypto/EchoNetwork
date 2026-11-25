using UnityEngine;

namespace ElevenEleven.Opening
{
    [DisallowMultipleComponent]
    public sealed class SurveillanceScannerArc : MonoBehaviour
    {
        private const int Segments = 30;
        private const int BranchSegments = 8;
        private const float BaseWidth = .019f;
        [SerializeField] private LineRenderer core;
        [SerializeField] private LineRenderer halo;
        [SerializeField] private LineRenderer fork;
        [SerializeField] private Light reflectedLight;
        [SerializeField] private float seed;
        private readonly Vector3[] positions = new Vector3[Segments + 1];
        private readonly Vector3[] branch = new Vector3[BranchSegments + 1];

        private void OnEnable() => Draw(Time.time, ChapterSceneLink.ReducedMotion);

        private void LateUpdate() => Draw(Time.time, ChapterSceneLink.ReducedMotion);

        private void Draw(float time, bool reduced)
        {
            const float span = 2f * StationSurveillanceWing.ScannerHalfWidth;
            var phase = reduced ? 0f : time * 5.4f;
            for (var index = 0; index <= Segments; index++)
            {
                var along = index / (float)Segments;
                var envelope = Mathf.Sin(Mathf.PI * along);
                var vertical = Mathf.PerlinNoise(index * .71f + seed, phase) - .5f;
                var forward = Mathf.PerlinNoise(index * .58f + 13f, phase + seed) - .5f;
                var spread = reduced ? .066f : .126f;
                positions[index] = new Vector3(-span * .5f + span * along,
                    vertical * spread * envelope, forward * spread * envelope);
            }
            core.SetPositions(positions);
            halo.SetPositions(positions);
            var pulse = reduced ? .72f : .79f + .21f * Mathf.Sin(time * 5.5f + seed);
            core.widthMultiplier = BaseWidth * pulse;
            halo.widthMultiplier = .080f * pulse;
            reflectedLight.intensity = .52f + pulse * .67f;
            fork.enabled = !reduced;
            if (reduced) return;

            var begin = 7 + Mathf.FloorToInt(Mathf.Repeat(time * 1.35f + seed, 7f));
            for (var index = 0; index <= BranchSegments; index++)
            {
                var along = index / (float)BranchSegments;
                var separation = Mathf.Sin(Mathf.PI * along);
                var variation = Mathf.PerlinNoise(index * .94f + seed, phase * .41f) - .5f;
                branch[index] = positions[begin + index] + new Vector3(0f,
                    separation * (.108f + variation * .082f), separation * variation * .14f);
            }
            fork.SetPositions(branch);
            fork.widthMultiplier = .012f * pulse;
        }

        public static int CorePoints => Segments + 1;
        public static int ForkPoints => BranchSegments + 1;
    }
}
