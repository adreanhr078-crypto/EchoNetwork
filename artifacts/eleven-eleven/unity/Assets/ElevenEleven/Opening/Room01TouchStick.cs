using UnityEngine;
using UnityEngine.EventSystems;

namespace ElevenEleven.Opening
{
    public sealed class Room01TouchStick : MonoBehaviour, IPointerDownHandler, IDragHandler, IPointerUpHandler
    {
        [SerializeField] private RectTransform knob;
        private int? pointer;
        public Vector2 Value { get; private set; }

        public void OnPointerDown(PointerEventData data)
        {
            if (pointer.HasValue) return;
            pointer = data.pointerId;
            OnDrag(data);
        }

        public void OnDrag(PointerEventData data)
        {
            if (data.pointerId != pointer) return;
            var area = (RectTransform)transform;
            if (!RectTransformUtility.ScreenPointToLocalPointInRectangle(area, data.position, data.pressEventCamera, out var point))
                return;
            var radius = Mathf.Min(area.rect.width, area.rect.height) * 0.37f;
            if (radius <= 0f) return;
            Value = Vector2.ClampMagnitude((point - area.rect.center) / radius, 1f);
            knob.anchoredPosition = Value * radius;
        }

        public void OnPointerUp(PointerEventData data)
        {
            if (data.pointerId == pointer) ResetStick();
        }

        private void OnDisable() => ResetStick();

        private void ResetStick()
        {
            pointer = null;
            Value = Vector2.zero;
            if (knob != null) knob.anchoredPosition = Vector2.zero;
        }
    }
}
