using UnityEngine;

namespace ElevenEleven.Opening
{
    public sealed class Room01Gate : MonoBehaviour
    {
        [SerializeField] private Transform door;
        [SerializeField] private Light doorSignal;
        [SerializeField] private Transform threshold;
        private const float SlideDistance = 6.5f;
        private const float SlideDuration = 2.4f;
        private static readonly Color OpenColor = new Color(0.18f, 0.92f, 1f);

        public bool IsOpen { get; private set; }
        internal Vector3 ResumePosition => threshold.position + Vector3.forward * 0.25f + Vector3.up * 0.04f;

        private Vector3 closedPosition;
        private float elapsed;
        private bool opening;

        private void Awake() => closedPosition = door.localPosition;

        public void Open()
        {
            if (opening || IsOpen) return;
            if (ChapterSceneLink.ReducedMotion) FinishOpening();
            else opening = true;
        }

        public bool HasCrossed(Vector3 player) =>
            IsOpen && player.z >= threshold.position.z && Mathf.Abs(player.x - threshold.position.x) < 3.55f;

        internal void RestoreOpen()
        {
            closedPosition = door.localPosition;
            FinishOpening();
        }

        private void Update()
        {
            if (!opening) return;
            elapsed += Time.deltaTime;
            var t = Mathf.Clamp01(elapsed / SlideDuration);
            door.localPosition = closedPosition + Vector3.up * (SlideDistance * (1f - (1f - t) * (1f - t)));
            if (t >= 1f) FinishOpening();
        }

        private void FinishOpening()
        {
            door.localPosition = closedPosition + Vector3.up * SlideDistance;
            doorSignal.color = OpenColor;
            opening = false;
            IsOpen = true;
        }
    }
}
