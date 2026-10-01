using UnityEngine;

namespace EchoNetwork.UnityG0
{
    /// <summary>
    /// Migration boundary for the current Godot G0 proof. It intentionally does
    /// not own account state, Canon, saves, rewards, or the web runtime.
    /// </summary>
    [DisallowMultipleComponent]
    public sealed class UnityG0Bootstrap : MonoBehaviour
    {
        [SerializeField] private GameObject roomAsset;
        [SerializeField] private GameObject echoAsset;
        [SerializeField] private Transform roomAnchor;
        [SerializeField] private Transform echoSpawn;
        [SerializeField] private bool allowProceduralFallback;

        public GameObject RoomAsset => roomAsset;
        public GameObject EchoAsset => echoAsset;

        private void Awake()
        {
            if (roomAsset != null && roomAnchor != null && roomAnchor.childCount == 0)
                Instantiate(roomAsset, roomAnchor);
            else if (roomAsset == null && !allowProceduralFallback)
                Debug.LogWarning("UNITY_G0_ROOM_ASSET_PENDING: assign the Unity-imported FBX prefab before production use.");

            if (echoAsset != null && echoSpawn != null && echoSpawn.childCount == 0)
            {
                var echo = Instantiate(echoAsset, echoSpawn);
                echo.name = "Echo_G0_MotionStudy_Instance";
            }
            else if (echoAsset == null)
            {
                Debug.LogWarning("UNITY_G0_ECHO_ASSET_PENDING: assign Echo_G0_MotionStudy.fbx after Unity import.");
            }

            Debug.Log("UNITY_G0_BOOTSTRAP_INITIALIZED_RUNTIME_PARITY_UNVERIFIED");
        }
    }
}
