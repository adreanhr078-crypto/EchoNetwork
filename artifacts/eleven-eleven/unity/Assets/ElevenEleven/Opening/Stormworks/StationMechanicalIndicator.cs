using UnityEngine;

namespace ElevenEleven.Opening
{
    [DisallowMultipleComponent]
    public sealed class StationMechanicalIndicator : MonoBehaviour
    {
        private static readonly int BaseColor = Shader.PropertyToID("_BaseColor");
        private static readonly int Emission = Shader.PropertyToID("_EmissionColor");
        [SerializeField] private StormworksRoute relay;
        [SerializeField] private Light memorySignal;
        [SerializeField] private Transform needle;
        [SerializeField] private Renderer lens;
        [SerializeField] private TextMesh label;
        [SerializeField] private Color inactiveColor;
        [SerializeField] private Color relayOnlineColor;
        [SerializeField] private float standbyAngle;
        [SerializeField] private float liveAngle;

        private MaterialPropertyBlock properties;
        private Color displayed;
        private bool shown;
        private bool energized;
        private float angle;

        private void OnEnable()
        {
            properties ??= new MaterialPropertyBlock();
            shown = false;
            Refresh(true);
        }

        private void LateUpdate() => Refresh(ChapterSceneLink.ReducedMotion);

        private void Refresh(bool snap)
        {
            var active = relay ? relay.Stage >= StormworksRoute.RelayRestored : memorySignal.enabled;
            var destination = active ? liveAngle : standbyAngle;
            var next = snap ? destination : Mathf.MoveTowards(angle, destination, 245f * Time.deltaTime);
            if (!shown || next != angle)
            {
                needle.localRotation = Quaternion.AngleAxis(next, Vector3.forward);
                angle = next;
            }

            var color = !active ? inactiveColor : relay ? relayOnlineColor : memorySignal.color;
            if (!shown || color != displayed)
            {
                displayed = color;
                lens.GetPropertyBlock(properties);
                properties.SetColor(BaseColor, color);
                properties.SetColor(Emission, color * 1.5f);
                lens.SetPropertyBlock(properties);
            }
            if (label && (!shown || active != energized))
            {
                label.text = active ? "FEED ONLINE" : "FEED OPEN";
                label.color = color;
            }
            energized = active;
            shown = true;
        }
    }
}
