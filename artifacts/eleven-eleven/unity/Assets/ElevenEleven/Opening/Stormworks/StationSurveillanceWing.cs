using UnityEngine;

namespace ElevenEleven.Opening
{
    public sealed class StationSurveillanceWing : MonoBehaviour
    {
        internal const float Depth = 36f;
        private static readonly float[] ScannerLines = { 8f, 12f, 26f, 30f };
        public static System.ReadOnlySpan<float> ScannerDepths => ScannerLines;
        public const float ScannerHalfWidth = 3.7f;
        [SerializeField] private Transform mirror;
        [SerializeField] private Transform console;
        [SerializeField] private Transform gate;
        [SerializeField] private GameObject scannerGrid;
        [SerializeField] private Light mirrorSignal;
        [SerializeField] private Light consoleSignal;
        [SerializeField] private GameObject pathSafeCue;
        [SerializeField] private Renderer pathSafeLens;
        private Vector3 closed;
        private MaterialPropertyBlock pathSafeMpb;
        private static readonly int BaseColorId = Shader.PropertyToID("_BaseColor");
        private static readonly int EmissionColorId = Shader.PropertyToID("_EmissionColor");
        private static readonly Color Amber = new Color(1f, 0.32f, 0.06f);
        private static readonly Color Turquoise = new Color(0.08f, 1f, 0.69f);

        internal Vector3 ReflectionFocus => mirror.position;
        internal Vector3 Arrival => transform.TransformPoint(new Vector3(0f, 0.045f, 2.2f));
        internal Vector3 MirrorAnchor => transform.TransformPoint(new Vector3(6.7f, 0.045f, 10f));
        internal Vector3 DaisAnchor => transform.TransformPoint(new Vector3(-2.2f, 2.445f, 17.48f));
        internal Vector3 Exit => transform.TransformPoint(new Vector3(0f, 0.045f, 37.45f));

        private void Awake() => closed = gate.localPosition;

        internal string Objective(bool inspected, bool overridden)
        {
            if (inspected && overridden)
                return EntryCopy.Arabic ? "‏ﻲﻟﺎﻤﺸﻟﺍ ﺝﺮﺨﻤﻟﺍ ﺮﺒﻋﺍ" : "Leave surveillance through the north gate.";
            if (inspected)
                return EntryCopy.Arabic ? "‏ﺔﺒﻗﺍﺮﻤﻟﺍ ﺔﺼﻨﻣ ﻦﻣ ﻕﻼﻏﻹﺍ ﻊﻓﺭﺍ" : "Use a side ramp to reach the surveillance console.";
            return EntryCopy.Arabic ? "‏ﻲﻗﺮﺸﻟﺍ ﺭﺍﺪﺠﻟﺍ ﺓﺁﺮﻣ ﺺﺤﻓﺍ" : "Inspect the mirror on the east side.";
        }

        internal bool CanInspect(Vector3 player) => InReach(mirror, player, 0.2f, 1.25f);
        internal bool CanOverride(Vector3 player) => InReach(console, player, 2.24f, 1.7f);

        private bool InReach(Transform target, Vector3 player, float minimumHeight, float radius)
        {
            var feet = transform.InverseTransformPoint(player);
            if (feet.y < minimumHeight - 0.31f || feet.y > minimumHeight + 0.70f) return false;
            var delta = target.position - player;
            return new Vector2(delta.x, delta.z).sqrMagnitude <= radius * radius;
        }

        internal string Action(Vector3 position, bool inspected, bool overridden)
        {
            if (!inspected && CanInspect(position))
                return EntryCopy.Arabic ? "‏ﺓﺁﺮﻤﻟﺍ ﺺﺤﻓﺍ" : "Inspect the mirror  [E]";
            if (!overridden && CanOverride(position))
                return EntryCopy.Arabic ? "‏ﻕﻼﻏﻹﺍ ﻊﻓﺭﺍ" : "Lift surveillance lockdown  [E]";
            return "";
        }

        internal bool Crossed(Vector3 position)
        {
            var local = transform.InverseTransformPoint(position);
            return Mathf.Abs(local.x) < 0.87f && Mathf.Abs(local.y) < 0.35f && local.z > Depth + 0.48f &&
                local.z < Depth + 2.68f;
        }

        internal void Tick(Room01Player player, bool inspected, bool overridden, float dt, bool modal)
        {
            var blend = ChapterSceneLink.ReducedMotion ? 1f : 1f - Mathf.Exp(-6.5f * dt);
            Present(inspected, overridden, blend);
            if (modal || overridden) return;

            var local = transform.InverseTransformPoint(player.transform.position);
            if (Mathf.Abs(local.x) > ScannerHalfWidth || local.y < -0.12f || local.y > 1.23f) return;
            foreach (var z in ScannerDepths)
            {
                if (Mathf.Abs(local.z - z) > 0.31f) continue;
                var exit = z < 20f ? Arrival : transform.TransformPoint(new Vector3(-5.15f, 0.045f, 24f));
                player.TryHazardReturn(exit, EntryCopy.Arabic
                    ? "‏ﻲﺒﻧﺎﺠﻟﺍ ﺮﻤﻤﻟﺍ ﻚﻠﺳﺍ .ﺢﺴﻤﻟﺍ ﻚﻔﺸﺘﻛﺍ"
                    : "Scanner detected movement. Use the side aisle.");
                return;
            }
        }

        internal void Present(bool inspected, bool overridden, float blend)
        {
            gate.localPosition = Vector3.Lerp(gate.localPosition,
                closed + Vector3.up * (inspected && overridden ? 3.25f : 0f), blend);
            mirrorSignal.color = inspected ? Turquoise : Amber;
            consoleSignal.color = overridden ? Turquoise : Amber;
            scannerGrid.SetActive(!overridden);
            if (pathSafeCue && pathSafeCue.activeSelf != overridden) pathSafeCue.SetActive(overridden);
            if (pathSafeLens)
            {
                pathSafeMpb ??= new MaterialPropertyBlock();
                pathSafeLens.GetPropertyBlock(pathSafeMpb);
                pathSafeMpb.SetColor(BaseColorId, overridden ? new Color(0.14f, 0.96f, 0.72f, 1f) : new Color(0.32f, 0.14f, 0.08f, 1f));
                pathSafeMpb.SetColor(EmissionColorId, overridden ? new Color(0.16f, 1.55f, 1.05f, 1f) : new Color(0.28f, 0.09f, 0.02f, 1f));
                pathSafeLens.SetPropertyBlock(pathSafeMpb);
            }
        }
    }
}
