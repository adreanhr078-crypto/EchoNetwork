using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace ElevenEleven.Opening
{
    public sealed class CoverTileInput : MonoBehaviour, IBeginDragHandler, IDragHandler, IEndDragHandler, IDropHandler
    {
        [SerializeField] private CoverRecoveryPresenter cover;
        [SerializeField, Range(0, CoverPuzzle.TileCount - 1)] private int position;
        private RawImage preview;

        public void Select() => cover.Select(position);

        public void OnBeginDrag(PointerEventData data)
        {
            if (!cover.AcceptsTiles || data.button != PointerEventData.InputButton.Left) return;
            var tile = GetComponent<RawImage>();
            var canvas = tile.canvas.rootCanvas;
            var ghost = new GameObject("Cover piece preview", typeof(RectTransform), typeof(CanvasRenderer), typeof(RawImage));
            ghost.transform.SetParent(canvas.transform, false);
            preview = ghost.GetComponent<RawImage>();
            preview.texture = tile.texture;
            preview.uvRect = tile.uvRect;
            preview.color = new Color(0.88f, 0.98f, 1f, 0.86f);
            preview.raycastTarget = false;
            preview.rectTransform.sizeDelta = tile.rectTransform.rect.size * 0.84f;
            OnDrag(data);
        }

        public void OnDrag(PointerEventData data)
        {
            if (preview == null) return;
            if (RectTransformUtility.ScreenPointToWorldPointInRectangle(
                (RectTransform)preview.transform.parent, data.position, data.pressEventCamera, out var point))
                preview.transform.position = point;

            var target = data.pointerCurrentRaycast.gameObject?.GetComponentInParent<CoverTileInput>();
            cover.SetDropTarget(target != null && target != this && target.cover == cover ? target.position : -1);
        }

        public void OnEndDrag(PointerEventData data) => ClearPreview();
        private void OnDisable() => ClearPreview();

        private void ClearPreview()
        {
            if (preview == null) return;
            preview.gameObject.SetActive(false);
            Destroy(preview.gameObject);
            preview = null;
            cover.SetDropTarget(-1);
        }

        public void OnDrop(PointerEventData data)
        {
            if (data.pointerDrag == null || !cover.AcceptsTiles) return;
            if (data.pointerDrag.TryGetComponent<CoverTileInput>(out var origin) && origin.cover == cover && origin.preview != null)
                cover.Swap(origin.position, position);
        }
    }
}
