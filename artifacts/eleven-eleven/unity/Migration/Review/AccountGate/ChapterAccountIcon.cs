using UnityEngine;
using UnityEngine.UI;

namespace ElevenEleven.Opening
{
    public sealed class ChapterAccountIcon : MaskableGraphic
    {
        public enum Mark { Guest, Google, Facebook }

        [SerializeField] private Mark mark;

        public void SetMark(Mark value)
        {
            mark = value;
            SetVerticesDirty();
        }

        protected override void OnPopulateMesh(VertexHelper mesh)
        {
            mesh.Clear();
            var rect = GetPixelAdjustedRect();
            var size = Mathf.Min(rect.width, rect.height);
            if (size <= 0f) return;

            switch (mark)
            {
                case Mark.Guest:
                    Arc(mesh, rect.center, size, new Vector2(0f, .15f), .06f, .16f, 0, 360, new Color32(127, 232, 239, 255));
                    Arc(mesh, rect.center, size, new Vector2(0f, -.27f), .21f, .29f, 7, 173, new Color32(103, 200, 246, 255));
                    break;
                case Mark.Google:
                    Arc(mesh, rect.center, size, Vector2.zero, .23f, .37f, 39, 147, new Color32(234, 67, 53, 255));
                    Arc(mesh, rect.center, size, Vector2.zero, .23f, .37f, 147, 220, new Color32(251, 188, 5, 255));
                    Arc(mesh, rect.center, size, Vector2.zero, .23f, .37f, 220, 318, new Color32(52, 168, 83, 255));
                    var blue = new Color32(66, 133, 244, 255);
                    Arc(mesh, rect.center, size, Vector2.zero, .23f, .37f, 318, 367, blue);
                    Quad(mesh, rect.center, size, .015f, -.066f, .37f, .064f, blue);
                    break;
                default:
                    var facebook = new Color32(76, 153, 255, 255);
                    Arc(mesh, rect.center, size, new Vector2(.12f, .19f), .11f, .25f, 40, 180, facebook);
                    Quad(mesh, rect.center, size, -.13f, -.38f, .01f, .20f, facebook);
                    Quad(mesh, rect.center, size, -.26f, -.09f, .22f, .035f, facebook);
                    break;
            }
        }

        private static void Arc(VertexHelper mesh, Vector2 center, float size, Vector2 offset,
            float inner, float outer, float from, float to, Color32 color)
        {
            var count = Mathf.Max(3, Mathf.CeilToInt((to - from) / 12f));
            var first = mesh.currentVertCount;
            for (var index = 0; index <= count; index++)
            {
                var angle = Mathf.Lerp(from, to, (float)index / count) * Mathf.Deg2Rad;
                var direction = new Vector2(Mathf.Cos(angle), Mathf.Sin(angle));
                mesh.AddVert(center + (offset + inner * direction) * size, color, Vector2.zero);
                mesh.AddVert(center + (offset + outer * direction) * size, color, Vector2.zero);
                if (index == 0) continue;
                var edge = first + index * 2;
                mesh.AddTriangle(edge - 2, edge - 1, edge + 1);
                mesh.AddTriangle(edge - 2, edge + 1, edge);
            }
        }

        private static void Quad(VertexHelper mesh, Vector2 center, float size, float x0, float y0, float x1, float y1, Color32 color)
        {
            var first = mesh.currentVertCount;
            mesh.AddVert(center + new Vector2(x0, y0) * size, color, Vector2.zero);
            mesh.AddVert(center + new Vector2(x0, y1) * size, color, Vector2.zero);
            mesh.AddVert(center + new Vector2(x1, y1) * size, color, Vector2.zero);
            mesh.AddVert(center + new Vector2(x1, y0) * size, color, Vector2.zero);
            mesh.AddTriangle(first, first + 1, first + 2);
            mesh.AddTriangle(first, first + 2, first + 3);
        }
    }
}
