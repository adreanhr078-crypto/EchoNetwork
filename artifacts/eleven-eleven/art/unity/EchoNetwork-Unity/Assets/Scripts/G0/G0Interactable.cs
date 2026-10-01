using UnityEngine;

namespace EchoNetwork.UnityG0
{
    /// <summary>Small, local-only interaction contract for the migrated G0 room.</summary>
    [DisallowMultipleComponent]
    public sealed class G0Interactable : MonoBehaviour
    {
        public enum InteractionKind
        {
            SignalNode,
            MemoryClue,
            ExitDoor,
        }

        [SerializeField] private InteractionKind kind = InteractionKind.SignalNode;
        [SerializeField] private string prompt = "Interact";
        [SerializeField] private bool oneShot;

        private bool consumed;

        public InteractionKind Kind => kind;
        public string Prompt => prompt;

        public void Interact()
        {
            if (oneShot && consumed)
                return;

            consumed = true;
            Debug.Log($"G0_INTERACTION kind={kind} object={name}");
            if (kind == InteractionKind.ExitDoor)
                Debug.Log("G0_EXIT_DOOR_SIGNAL_READY");
            else if (kind == InteractionKind.MemoryClue)
                Debug.Log("G0_MEMORY_CLUE_SIGNAL_READY");
            else
                Debug.Log("G0_SIGNAL_NODE_SIGNAL_READY");
        }
    }
}
