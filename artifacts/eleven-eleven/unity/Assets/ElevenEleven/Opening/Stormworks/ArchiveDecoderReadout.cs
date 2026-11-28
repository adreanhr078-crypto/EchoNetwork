using UnityEngine;

namespace ElevenEleven.Opening
{
    [DisallowMultipleComponent]
    public sealed class ArchiveDecoderReadout : MonoBehaviour
    {
        private static readonly Color Waiting = new Color(.93f, .62f, .33f);
        private static readonly Color Ready = new Color(.48f, .90f, .90f);
        private static readonly Color Complete = new Color(.48f, .93f, .69f);

        [SerializeField] private StormworksRoute route;
        [SerializeField] private TextMesh count;
        [SerializeField] private TextMesh state;
        [SerializeField] private Renderer[] fragmentLamps;

        private int previousMask = -1;
        private bool previousDecoded;

        private void OnEnable()
        {
            previousMask = -1;
            Refresh();
        }

        private void LateUpdate() => Refresh();

        private void Refresh()
        {
            var mask = route.MemoryFragments & StationArchiveWing.CompleteMask;
            var decoded = route.Stage >= StormworksRoute.ArchiveDecoded;
            if (mask == previousMask && decoded == previousDecoded) return;

            var collected = 0;
            for (var index = 0; index < fragmentLamps.Length; index++)
            {
                var recovered = (mask & (1 << index)) != 0;
                fragmentLamps[index].enabled = recovered;
                if (recovered) collected++;
            }
            var ready = mask == StationArchiveWing.CompleteMask;
            count.text = $"{collected} / {fragmentLamps.Length}";
            count.color = state.color = decoded ? Complete : ready ? Ready : Waiting;
            state.text = decoded ? "DECODED" : ready ? "READY" : "AWAITING FRAGMENTS";
            previousMask = mask;
            previousDecoded = decoded;
        }
    }
}
