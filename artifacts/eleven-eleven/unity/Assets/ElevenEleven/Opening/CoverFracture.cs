using UnityEngine;
using UnityEngine.UI;

namespace ElevenEleven.Opening
{
    [RequireComponent(typeof(CanvasRenderer))]
    public sealed class CoverFracture : MaskableGraphic
    {
        [SerializeField] private AudioClip crack;

        private Rect bounds;
        private Texture source;
        private float progress;
        private ScreenFractureVeins veins;
        public override Texture mainTexture => source != null ? source : base.mainTexture;

        public void Begin(Texture texture, RectTransform board)
        {
            source = texture;
            var corners = new Vector3[4];
            board.GetWorldCorners(corners);
            var first = rectTransform.InverseTransformPoint(corners[0]);
            var last = rectTransform.InverseTransformPoint(corners[2]);
            bounds = Rect.MinMaxRect(first.x, first.y, last.x, last.y);
            raycastTarget = false;
            gameObject.SetActive(true);
            if (crack != null && !ChapterSceneLink.Muted)
            {
                var audio = GetComponent<AudioSource>() ?? gameObject.AddComponent<AudioSource>();
                audio.playOnAwake = false;
                audio.spatialBlend = 0f;
                audio.PlayOneShot(crack);
            }
            if (veins == null)
            {
                var overlay = new GameObject("Screen fracture veins", typeof(RectTransform));
                var rect = (RectTransform)overlay.transform;
                rect.SetParent(rectTransform, false);
                rect.anchorMin = Vector2.zero;
                rect.anchorMax = Vector2.one;
                rect.offsetMin = Vector2.zero;
                rect.offsetMax = Vector2.zero;
                veins = overlay.AddComponent<ScreenFractureVeins>();
                veins.raycastTarget = false;
            }
            veins.Begin(Rect.PointToNormalized(rectTransform.rect, bounds.center));
            Draw(0);
            SetMaterialDirty();
        }

        public void Draw(float value)
        {
            progress = Mathf.Clamp01(value);
            if (veins != null) veins.Draw(progress);
            SetVerticesDirty();
        }

        protected override void OnPopulateMesh(VertexHelper mesh)
        {
            mesh.Clear();
            if (source == null || bounds.width <= 0) return;
            for (var row = 0; row < 4; row++)
            for (var column = 0; column < 4; column++)
            {
                var a = new Vector2(column, row) * 0.25f;
                var b = a + new Vector2(0.25f, 0);
                var c = a + new Vector2(0, 0.25f);
                var d = a + new Vector2(0.25f, 0.25f);
                AddShard(mesh, a, b, c, column, row, 0);
                AddShard(mesh, b, d, c, column, row, 1);
            }
        }

        private void AddShard(VertexHelper mesh, Vector2 a, Vector2 b, Vector2 c, int column, int row, int half)
        {
            var center = (a + b + c) / 3f;
            var motion = progress * progress * progress;
            var travel = new Vector2((column - 1.5f) * 0.65f, (row - 1.5f) * 0.60f - 0.20f);
            var index = (row * 4 + column) * 2 + half;
            var angle = (index % 5 - 2) * 0.16f * progress;
            var sine = Mathf.Sin(angle);
            var cosine = Mathf.Cos(angle);
            var tint = new Color(1f, 1f, 1f, 1f - Mathf.SmoothStep(0f, 1f, (progress - 0.10f) / 0.90f));
            var origin = bounds.min + Vector2.Scale(center + travel * motion, bounds.size);
            var start = mesh.currentVertCount;
            AddPoint(mesh, a, center, origin, sine, cosine, tint);
            AddPoint(mesh, b, center, origin, sine, cosine, tint);
            AddPoint(mesh, c, center, origin, sine, cosine, tint);
            mesh.AddTriangle(start, start + 1, start + 2);
        }

        private void AddPoint(VertexHelper mesh, Vector2 uv, Vector2 center, Vector2 origin, float sine, float cosine, Color tint)
        {
            var offset = Vector2.Scale(uv - center, bounds.size);
            var rotated = new Vector2(cosine * offset.x - sine * offset.y, sine * offset.x + cosine * offset.y);
            mesh.AddVert(origin + rotated, tint, uv);
        }
    }
}
