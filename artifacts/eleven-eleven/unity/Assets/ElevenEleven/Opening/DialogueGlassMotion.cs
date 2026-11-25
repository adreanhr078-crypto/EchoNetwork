using UnityEngine;
using UnityEngine.UI;

namespace ElevenEleven.Opening
{
    [DisallowMultipleComponent]
    public sealed class DialogueGlassMotion : MonoBehaviour
    {
        private Material material;
        private CanvasGroup group;
        private float appearedAt;
        private static readonly int Drift = Shader.PropertyToID("_Drift");

        private void Awake()
        {
            var graphic = GetComponent<Image>();
            material = new Material(graphic.material);
            graphic.material = material;
            group = GetComponent<CanvasGroup>();
        }

        private void OnEnable()
        {
            appearedAt = Time.unscaledTime;
            Present();
        }

        private void Update() => Present();

        private void Present()
        {
            var reduced = ChapterSceneLink.ReducedMotion;
            material.SetFloat(Drift, reduced ? 0f : 1f);
            var elapsed = Mathf.Clamp01((Time.unscaledTime - appearedAt) / 0.19f);
            group.alpha = reduced ? 1f : Mathf.SmoothStep(0.4f, 1f, elapsed);
        }

        private void OnDestroy()
        {
            if (material != null) Destroy(material);
        }
    }
}
