using UnityEngine;
using UnityEngine.UI;

namespace ElevenEleven.Opening
{
    public sealed class StationSystemBanner : MonoBehaviour
    {
        [SerializeField] private CanvasGroup group;
        [SerializeField] private Text text;
        private float startAt = -100f;
        private const float Duration = 2.35f;

        internal void Show(string objective)
        {
            if (string.IsNullOrWhiteSpace(objective)) return;
            text.text = objective;
            startAt = Time.unscaledTime;
        }

        internal void Hide()
        {
            startAt = -100f;
            group.alpha = 0f;
        }

        private void Update()
        {
            var t = Time.unscaledTime - startAt;
            if (t > Duration)
            {
                if (group.alpha > 0f) group.alpha = 0f;
                return;
            }

            group.alpha = ChapterSceneLink.ReducedMotion ? 1f : Mathf.Min(
                Mathf.SmoothStep(0f, 1f, t / 0.17f), Mathf.SmoothStep(0f, 1f, (Duration - t) / 0.45f));
        }
    }
}
