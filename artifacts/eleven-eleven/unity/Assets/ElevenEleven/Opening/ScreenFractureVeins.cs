using UnityEngine;
using UnityEngine.UI;

namespace ElevenEleven.Opening
{
    [RequireComponent(typeof(CanvasRenderer))]
    public sealed class ScreenFractureVeins : MaskableGraphic
    {
        private static readonly Vector2[] Tips =
        {
            new Vector2(0f, 0.19f), new Vector2(0f, 0.74f),
            new Vector2(0.17f, 1f), new Vector2(0.47f, 1f),
            new Vector2(0.91f, 1f), new Vector2(1f, 0.70f),
            new Vector2(1f, 0.28f), new Vector2(0.68f, 0f),
            new Vector2(0.27f, 0f),
        };

        private Vector2 impact;
        private float progress;

        public void Begin(Vector2 normalizedImpact)
        {
            impact = normalizedImpact;
            Draw(0f);
        }

        public void Draw(float value)
        {
            progress = Mathf.Clamp01(value);
            SetVerticesDirty();
        }

        protected override void OnPopulateMesh(VertexHelper mesh)
        {
            mesh.Clear();
            var rect = rectTransform.rect;
            var extension = Mathf.SmoothStep(0f, 1f, progress / 0.33f);
            var opacity = Mathf.SmoothStep(0f, 1f, progress / 0.06f) *
                (1f - Mathf.SmoothStep(0f, 1f, (progress - 0.43f) / 0.57f));
            if (opacity <= 0f) return;

            var center = Rect.NormalizedToPoint(rect, impact);
            for (var i = 0; i < Tips.Length; i++)
            {
                var end = Rect.NormalizedToPoint(rect, Tips[i]);
                var delta = end - center;
                var bend = Vector2.Perpendicular(delta) * (i % 2 == 0 ? 0.055f : -0.08f);
                var near = center + delta * 0.28f + bend;
                var fork = center + delta * 0.62f - bend * 0.6f;
                var branch = fork + delta * 0.27f + bend * 1.65f;
                AddSegment(mesh, center, Vector2.Lerp(center, near, extension), 1.5f, opacity);
                AddSegment(mesh, near, Vector2.Lerp(near, fork, Mathf.Clamp01((extension - 0.25f) / 0.50f)), 1.1f, opacity);
                var last = Mathf.Clamp01((extension - 0.58f) / 0.42f);
                AddSegment(mesh, fork, Vector2.Lerp(fork, end, last), 0.7f, opacity * 0.85f);
                AddSegment(mesh, fork, Vector2.Lerp(fork, branch, last), 0.65f, opacity * 0.63f);
            }
        }

        private static void AddSegment(VertexHelper mesh, Vector2 from, Vector2 to, float width, float opacity)
        {
            var delta = to - from;
            if (delta.sqrMagnitude < 0.001f) return;
            var normal = Vector2.Perpendicular(delta).normalized;
            Quad(mesh, from, to, normal * (width * 3.6f), new Color(0.18f, 0.51f, 1f, 0.18f * opacity));
            Quad(mesh, from, to, normal * width, new Color(0.65f, 0.91f, 1f, 0.76f * opacity));
        }

        private static void Quad(VertexHelper mesh, Vector2 from, Vector2 to, Vector2 offset, Color tint)
        {
            var start = mesh.currentVertCount;
            mesh.AddVert(from - offset, tint, Vector2.zero);
            mesh.AddVert(from + offset, tint, Vector2.zero);
            mesh.AddVert(to + offset, tint, Vector2.zero);
            mesh.AddVert(to - offset, tint, Vector2.zero);
            mesh.AddTriangle(start, start + 1, start + 2);
            mesh.AddTriangle(start, start + 2, start + 3);
        }
    }
}
