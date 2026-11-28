using UnityEngine;

namespace ElevenEleven.Opening
{
    [DisallowMultipleComponent]
    public sealed class StationReactorDeckSignals : MonoBehaviour
    {
        private static readonly int BaseColor = Shader.PropertyToID("_BaseColor");
        private static readonly int Emission = Shader.PropertyToID("_EmissionColor");
        private static readonly Color Unpowered = new Color(.58f, .23f, .075f);
        private static readonly Color WestPower = new Color(.91f, .44f, .12f);
        private static readonly Color EastPower = new Color(.18f, .71f, .60f);
        private static readonly Color ServiceReady = new Color(.51f, .85f, .72f);

        [SerializeField] private StormworksRoute route;
        [SerializeField] private Renderer[] west;
        [SerializeField] private Renderer[] east;
        [SerializeField] private Renderer service;

        private MaterialPropertyBlock block;
        private int previousMask = -1;
        private bool previousReduced;

        private void OnEnable() => previousMask = -1;

        private void LateUpdate()
        {
            if (!route) return;
            var mask = route.PoweredBreakers;
            var reduced = ChapterSceneLink.ReducedMotion;
            if (mask == previousMask && reduced == previousReduced && (reduced || mask == 0)) return;
            block ??= new MaterialPropertyBlock();
            var time = Time.time;
            ApplyCircuit(west, (mask & 1) != 0, WestPower, time, reduced);
            ApplyCircuit(east, (mask & 2) != 0, EastPower, time, reduced);
            if (mask != previousMask || reduced != previousReduced)
                Paint(service, mask == 3 ? ServiceReady : Unpowered, mask == 3 ? .87f : .10f);
            previousMask = mask;
            previousReduced = reduced;
        }

        private void ApplyCircuit(Renderer[] lamps, bool powered, Color color, float time, bool reduced)
        {
            for (var i = 0; i < lamps.Length; i++)
            {
                var intensity = !powered ? .12f : reduced ? .85f :
                    .61f + .42f * Mathf.Pow(.5f + .5f * Mathf.Cos(time * 3.2f - i * .90f), 3f);
                Paint(lamps[i], powered ? color : Unpowered, intensity);
            }
        }

        private void Paint(Renderer surface, Color color, float intensity)
        {
            surface.GetPropertyBlock(block);
            block.SetColor(BaseColor, color * (.35f + intensity * .32f));
            block.SetColor(Emission, color * intensity);
            surface.SetPropertyBlock(block);
        }
    }
}
