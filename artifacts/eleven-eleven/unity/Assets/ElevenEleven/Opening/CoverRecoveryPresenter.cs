using System.Collections;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.Events;
using UnityEngine.InputSystem;
using UnityEngine.UI;

namespace ElevenEleven.Opening
{
    public sealed class CoverRecoveryPresenter : MonoBehaviour
    {
        [SerializeField] private Texture2D cover;
        [SerializeField] private RawImage[] pieces;
        [SerializeField] private RawImage reference;
        [SerializeField] private Button undoButton;
        [SerializeField] private Button referenceButton;
        [SerializeField] private Button resetButton;
        [SerializeField] private Text stateLabel;
        [SerializeField] private Text heading;
        [SerializeField] private Text instruction;
        [SerializeField] private Button languageButton;
        [SerializeField] private Image[] edges;
        [SerializeField] private RectTransform board;
        [SerializeField] private CoverFracture fracture;
        [SerializeField] private CanvasGroup controls;
        [SerializeField] private UnityEvent restored = new UnityEvent();

        private readonly CoverPuzzle puzzle = new CoverPuzzle();
        private Coroutine settling;
        private int dropTarget = -1;
        private Button[] keyboardOrder;

        public UnityEvent Restored => restored;
        public bool IsSolved => puzzle.Solved;
        public bool AcceptsTiles => !puzzle.Solved && !puzzle.ReferenceOpen;

        private void OnEnable()
        {
            if (cover == null || reference == null || pieces == null || pieces.Length != CoverPuzzle.TileCount)
                throw new System.InvalidOperationException("The opening cover requires its source image and six tiles.");

            if (keyboardOrder == null)
            {
                keyboardOrder = new Button[pieces.Length + 4];
                for (var i = 0; i < pieces.Length; i++) keyboardOrder[i] = pieces[i].GetComponent<Button>();
                keyboardOrder[pieces.Length] = referenceButton;
                keyboardOrder[pieces.Length + 1] = undoButton;
                keyboardOrder[pieces.Length + 2] = resetButton;
                keyboardOrder[pieces.Length + 3] = languageButton;
            }
            reference.texture = cover;
            Refresh();
        }

        private void Update()
        {
            var keyboard = Keyboard.current;
            var events = EventSystem.current;
            if (keyboard == null || events == null || !keyboard.tabKey.wasPressedThisFrame) return;

            var reverse = keyboard.leftShiftKey.isPressed || keyboard.rightShiftKey.isPressed;
            var index = System.Array.FindIndex(keyboardOrder,
                button => button != null && button.gameObject == events.currentSelectedGameObject);
            if (index < 0) index = reverse ? 0 : keyboardOrder.Length - 1;
            var direction = reverse ? -1 : 1;
            for (var step = 0; step < keyboardOrder.Length; step++)
            {
                index = (index + direction + keyboardOrder.Length) % keyboardOrder.Length;
                var candidate = keyboardOrder[index];
                if (candidate == null || !candidate.isActiveAndEnabled || !candidate.IsInteractable()) continue;
                events.SetSelectedGameObject(candidate.gameObject);
                break;
            }
        }

        public void ToggleLanguage()
        {
            EntryCopy.Arabic = !EntryCopy.Arabic;
            Refresh();
        }

        internal void SetDropTarget(int position)
        {
            if (dropTarget == position) return;
            dropTarget = position;
            RefreshEdges();
        }

        public void Select(int position)
        {
            if (puzzle.Selected >= 0 && puzzle.Selected != position) Swap(puzzle.Selected, position);
            else Apply(() => puzzle.Select(position));
        }
        public void Swap(int first, int second)
        {
            if (puzzle.Solved || !puzzle.Swap(first, second)) return;
            StopSettling();
            dropTarget = -1;
            Refresh();
            if (puzzle.Solved) StartCoroutine(CompleteAfterInput());
            else if (!ChapterSceneLink.ReducedMotion) settling = StartCoroutine(Settle(first, second));
        }
        public void Undo() => Apply(() => puzzle.Undo());
        public void ResetCover() => Apply(puzzle.Reset);
        public void ToggleReference() => Apply(puzzle.ToggleReference);

        private void Apply(System.Action action)
        {
            if (puzzle.Solved) return;

            StopSettling();
            action();
            Refresh();
            if (puzzle.Solved) StartCoroutine(CompleteAfterInput());
        }

        private void StopSettling()
        {
            if (settling != null) StopCoroutine(settling);
            settling = null;
        }

        private void OnDisable()
        {
            StopSettling();
            dropTarget = -1;
        }

        private IEnumerator CompleteAfterInput()
        {
            if (EventSystem.current != null) EventSystem.current.SetSelectedGameObject(null);
            yield return null;
            if (fracture != null && board != null && !ChapterSceneLink.ReducedMotion &&
                SystemInfo.graphicsDeviceType != UnityEngine.Rendering.GraphicsDeviceType.Null)
            {
                if (controls != null) controls.interactable = false;
                reference.gameObject.SetActive(true);
                yield return new WaitForSecondsRealtime(0.23f);
                Canvas.ForceUpdateCanvases();
                fracture.Begin(cover, board);
                board.gameObject.SetActive(false);
                var began = Time.unscaledTime;
                const float fractureSeconds = 1.05f;
                while (Time.unscaledTime - began < fractureSeconds)
                {
                    var progress = (Time.unscaledTime - began) / fractureSeconds;
                    fracture.Draw(progress);
                    if (controls != null) controls.alpha = 1f - Mathf.SmoothStep(0f, 1f, progress);
                    yield return null;
                }
                fracture.Draw(1f);
            }
            restored.Invoke();
        }

        private IEnumerator Settle(int first, int second)
        {
            var start = Time.unscaledTime;
            while (!puzzle.Solved && Time.unscaledTime - start < 0.14f)
            {
                var value = Mathf.SmoothStep(0.58f, 1f, (Time.unscaledTime - start) / 0.14f);
                if (puzzle.Selected != first) pieces[first].color = Color.white * value;
                if (puzzle.Selected != second) pieces[second].color = Color.white * value;
                yield return null;
            }
            settling = null;
            if (!puzzle.Solved) Refresh();
        }

        private static void SetControl(Button button, string label, bool enabled)
        {
            if (button == null) return;
            button.interactable = enabled;
            button.GetComponentInChildren<Text>().text = label;
        }

        private void RefreshEdges()
        {
            if (edges == null) return;
            for (var index = 0; index < edges.Length; index++)
            {
                edges[index].color = index == dropTarget ? new Color(0.48f, 1f, 0.92f) :
                    index == puzzle.Selected ? new Color(0.65f, 0.77f, 1f) : new Color(0.22f, 0.27f, 0.52f);
                edges[index].enabled = !puzzle.Solved;
            }
        }

        private void Refresh()
        {
            var width = 1f / CoverPuzzle.Columns;
            var height = 1f / CoverPuzzle.Rows;
            for (var position = 0; position < pieces.Length; position++)
            {
                var piece = puzzle.PieceAt(position);
                var image = pieces[position];
                image.texture = cover;
                image.uvRect = new Rect((piece % CoverPuzzle.Columns) * width,
                    1f - (piece / CoverPuzzle.Columns + 1) * height, width, height);
                image.color = position == puzzle.Selected ? new Color(0.74f, 0.91f, 1f) : Color.white;
            }

            reference.gameObject.SetActive(puzzle.ReferenceOpen);
            foreach (var piece in pieces) piece.GetComponent<Button>().interactable = AcceptsTiles;
            SetControl(undoButton, EntryCopy.Undo, puzzle.CanUndo && !puzzle.ReferenceOpen);
            SetControl(referenceButton, puzzle.ReferenceOpen ? EntryCopy.CoverBack : EntryCopy.CoverReference, !puzzle.Solved);
            SetControl(resetButton, EntryCopy.Reset, !puzzle.Solved);
            SetControl(languageButton, EntryCopy.Language, !puzzle.Solved);
            if (heading != null) heading.text = EntryCopy.CoverTitle;
            if (instruction != null) instruction.text = EntryCopy.CoverInstruction;
            if (stateLabel != null)
                stateLabel.text = puzzle.Solved ? EntryCopy.CoverRestored : puzzle.Selected >= 0 ? EntryCopy.CoverSelected : EntryCopy.CoverWaiting;
            RefreshEdges();
        }
    }
}
