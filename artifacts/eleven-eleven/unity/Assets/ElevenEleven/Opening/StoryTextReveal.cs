using System;
using UnityEngine;
using UnityEngine.UI;

namespace ElevenEleven.Opening
{
    [RequireComponent(typeof(Text))]
    public sealed class StoryTextReveal : BaseMeshEffect
    {
        private Text label;
        private string last;
        private float began;
        private int[] order = Array.Empty<int>();
        private Vector2[] glyphCenters = Array.Empty<Vector2>();
        private float Progress => ChapterSceneLink.ReducedMotion ? 1f :
            Mathf.Clamp01((Time.unscaledTime - began) / Mathf.Clamp(0.25f + (last?.Length ?? 0) * 0.018f, 0.35f, 1.65f));

        protected override void OnEnable()
        {
            base.OnEnable();
            label = GetComponent<Text>();
            last = label.text;
            began = Time.unscaledTime;
            label.SetVerticesDirty();
        }

        private void LateUpdate()
        {
            if (label.text != last)
            {
                last = label.text;
                began = Time.unscaledTime;
                label.SetVerticesDirty();
            }
            else if (Progress < 1f || Time.unscaledTime - began < 1.75f)
                label.SetVerticesDirty();
        }

        public override void ModifyMesh(VertexHelper mesh)
        {
            if (!IsActive() || label == null) return;
            var amount = Progress;
            var glyphs = mesh.currentVertCount / 4;
            if (glyphs == 0 || amount >= 1f) return;
            if (order.Length != glyphs)
            {
                order = new int[glyphs];
                glyphCenters = new Vector2[glyphs];
            }
            var vertex = new UIVertex();
            for (var i = 0; i < glyphs; i++)
            {
                mesh.PopulateUIVertex(ref vertex, i * 4);
                var corner = vertex.position;
                mesh.PopulateUIVertex(ref vertex, i * 4 + 2);
                glyphCenters[i] = (corner + vertex.position) * 0.5f;
                order[i] = i;
            }
            if (EntryCopy.Arabic)
            {
                var row = Mathf.Max(4f, label.fontSize * 0.52f);
                Array.Sort(order, (left, right) =>
                {
                    var leftRow = Mathf.RoundToInt(glyphCenters[left].y / row);
                    var rightRow = Mathf.RoundToInt(glyphCenters[right].y / row);
                    return leftRow != rightRow ? rightRow.CompareTo(leftRow) :
                        glyphCenters[right].x.CompareTo(glyphCenters[left].x);
                });
            }

            var until = amount * (glyphs + 2f);
            for (var index = 0; index < glyphs; index++)
            {
                var ink = Mathf.Clamp01(until - index);
                for (var corner = 0; corner < 4; corner++)
                {
                    var at = order[index] * 4 + corner;
                    mesh.PopulateUIVertex(ref vertex, at);
                    var color = vertex.color;
                    color.a = (byte)Mathf.RoundToInt(color.a * ink);
                    vertex.color = color;
                    mesh.SetUIVertex(vertex, at);
                }
            }
        }
    }
}
