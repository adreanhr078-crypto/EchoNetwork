using UnityEngine;

namespace EchoNetwork.UnityG0
{
    /// <summary>Editor/batch smoke probe for the migrated scene only.</summary>
    public sealed class G0SmokeProbe : MonoBehaviour
    {
        private void Start()
        {
            var bootstrap = GetComponent<UnityG0Bootstrap>();
            var camera = Camera.main;
            var player = FindFirstObjectByType<ThirdPersonController>();
            var interactables = FindObjectsByType<G0Interactable>(FindObjectsSortMode.None);
            var colliders = FindObjectsByType<BoxCollider>(FindObjectsSortMode.None);

            if (bootstrap == null || camera == null || player == null || interactables.Length < 3 || colliders.Length < 4)
            {
                Debug.LogError(
                    $"UNITY_G0_SMOKE_FAIL bootstrap={bootstrap != null} camera={camera != null} " +
                    $"player={player != null} interactables={interactables.Length} colliders={colliders.Length}");
                if (Application.isBatchMode) Application.Quit(1);
                return;
            }

            // Component presence alone cannot establish a working migration.
            Debug.LogWarning("UNITY_G0_COMPONENTS_PRESENT_RUNTIME_PARITY_UNVERIFIED");
            if (Application.isBatchMode)
                Application.Quit(2);
        }
    }
}
