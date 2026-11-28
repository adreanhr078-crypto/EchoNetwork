using UnityEngine;

namespace ElevenEleven.Opening
{
    [DisallowMultipleComponent]
    public sealed class SignalConsolePresentation : MonoBehaviour
    {
        private static readonly int BaseColor = Shader.PropertyToID("_BaseColor");
        private static readonly int EmissionColor = Shader.PropertyToID("_EmissionColor");
        private static readonly Color FeedFault = new Color(1f, .30f, .085f);
        private static readonly Color ScanViolet = new Color(.56f, .47f, 1f);
        private static readonly Color OnlineMint = new Color(.19f, .94f, .69f);
        private static readonly Color RouteWarm = new Color(.80f, .53f, .27f);

        [SerializeField] private Room01Player player;
        [SerializeField] private Room01Gate gate;
        [SerializeField] private TextMesh alignmentReadout;
        [SerializeField] private TextMesh feedReadout;
        [SerializeField] private TextMesh interlockReadout;
        [SerializeField] private Renderer feedLamp;
        [SerializeField] private Renderer[] ceilingIndicators;
        [SerializeField] private Transform relay;
        [SerializeField] private LineRenderer trace;

        private readonly Vector3[] points = new Vector3[48];
        private MaterialPropertyBlock lightProperties;
        private Vector3 relayHome;
        private float elapsed;
        private int previous = -1;
        private bool wasMoving;

        private void Awake()
        {
            lightProperties = new MaterialPropertyBlock();
            relayHome = relay.localPosition;
            trace.positionCount = points.Length;
        }

        private void LateUpdate()
        {
            var powered = player.ConduitPowered;
            var aligned = player.SignalAligned;
            var open = gate.IsOpen;
            var state = (powered ? 1 : 0) | (aligned ? 2 : 0) | (open ? 4 : 0);
            var stateChanged = state != previous;
            var nearby = (player.transform.position - transform.position).sqrMagnitude < 18f * 18f;
            var moving = nearby && !ChapterSceneLink.ReducedMotion;
            var advance = moving && !player.UtilityMotionPaused && Time.deltaTime > 0f;
            var showCurrent = stateChanged || moving != wasMoving;

            if (showCurrent)
            {
                alignmentReadout.text = aligned ? "ALIGNED" : "SEARCH";
                alignmentReadout.color = aligned ? OnlineMint : ScanViolet;
                feedReadout.text = powered ? "ONLINE" : "FAULT";
                feedReadout.color = powered ? OnlineMint : FeedFault;
                interlockReadout.text = open ? "OPEN" : powered && aligned ? "RELEASING" : "HELD";
                interlockReadout.color = open ? OnlineMint : RouteWarm;
            }

            var relayTarget = relayHome + Vector3.right * (powered ? .109f : 0f);
            if (!moving) relay.localPosition = relayTarget;
            else if (advance) relay.localPosition = Vector3.MoveTowards(relay.localPosition, relayTarget, Time.deltaTime * .48f);

            if (advance) elapsed += Time.deltaTime;
            if (showCurrent || (advance && (!powered || !aligned || !open)))
            {
                DrawTrace(aligned, powered, moving ? elapsed : 0f);
                var faultPulse = advance ? .93f + .12f * Mathf.Sin(elapsed * 3.2f) : 1f;
                Paint(feedLamp, powered ? OnlineMint : FeedFault, powered ? 1.65f : faultPulse);
                for (var i = 0; i < ceilingIndicators.Length; i++)
                {
                    var direction = advance && powered && aligned && !open
                        ? Mathf.Repeat(elapsed * 2.7f - i * .25f, 1f) : 0f;
                    var peak = Mathf.Max(0f, 1f - Mathf.Abs(direction - .52f) * 4.3f);
                    var color = powered && aligned ? OnlineMint : RouteWarm;
                    Paint(ceilingIndicators[i], color, .68f + peak * 1.21f);
                }
            }

            previous = state;
            wasMoving = moving;
        }

        private void DrawTrace(bool aligned, bool powered, float time)
        {
            for (var i = 0; i < points.Length; i++)
            {
                var fraction = i / (float)(points.Length - 1);
                var radians = fraction * Mathf.PI * 4f;
                var phase = aligned ? radians : radians * 1.22f - time * 3f;
                var amplitude = aligned ? .040f : powered ? .032f : .023f;
                var distortion = aligned ? 0f : Mathf.Sin(radians * 2.2f + time * 5f) * .012f;
                points[i] = new Vector3(-.514f + fraction * .572f,
                    .012f + Mathf.Sin(phase) * amplitude + distortion, .073f);
            }

            trace.SetPositions(points);
            Paint(trace, aligned ? OnlineMint : ScanViolet, aligned ? 1.75f : 1.15f);
        }

        private void Paint(Renderer target, Color color, float intensity)
        {
            target.GetPropertyBlock(lightProperties);
            lightProperties.SetColor(BaseColor, color);
            lightProperties.SetColor(EmissionColor, color * intensity);
            target.SetPropertyBlock(lightProperties);
        }

#if UNITY_EDITOR
        public void Configure(Room01Player actor, Room01Gate blastGate, TextMesh alignment, TextMesh power,
            TextMesh interlock, Renderer faultLamp, Renderer[] corridorIndicators, Transform powerRelay,
            LineRenderer signalTrace)
        {
            player = actor;
            gate = blastGate;
            alignmentReadout = alignment;
            feedReadout = power;
            interlockReadout = interlock;
            feedLamp = faultLamp;
            ceilingIndicators = corridorIndicators;
            relay = powerRelay;
            trace = signalTrace;
        }
#endif
    }
}
