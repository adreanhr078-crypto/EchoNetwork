using UnityEngine;

namespace ElevenEleven.Opening
{
    public sealed class StationSpecimenWing : MonoBehaviour
    {
        private static readonly string[] SampleIds = { "005", "007", "008", "009", "010", "011" };
        internal const string Record = "EX-011 · Awoke before memory suppression. Baseline intact. Kinja ordered containment.";
        [SerializeField] private Transform shutter;
        [SerializeField] private Transform shortcut;
        [SerializeField] private Transform exit;
        [SerializeField] private Transform terminal;
        [SerializeField] private Transform scanner;
        [SerializeField] private Light beam;
        [SerializeField] private Transform[] tanks;
        private Vector3 closed;
        private Vector3 shutterClosed;
        private Vector3 shortcutClosed;
        private float scan;
        private float caution;
        private float grace;
        internal Vector3 Checkpoint => transform.TransformPoint(new Vector3(-24f, 0.04f, 12f));
        internal Vector3 ExitCheckpoint => transform.TransformPoint(new Vector3(-30.6f, 0.04f, 12f));

        private void Awake()
        {
            closed = exit.localPosition;
            shutterClosed = shutter.localPosition;
            shortcutClosed = shortcut.localPosition;
        }

        internal string Action(Vector3 position, bool logged)
        {
            if (!Inside(position)) return "";
            if (!logged && Near(position, terminal)) return EntryCopy.Arabic
                ? "‏ﺔﻨﻴﻌﻟﺍ ﻞﺠﺳ ﺃﺮﻗﺍ" : "Read specimen record  [E]";
            return NearestTank(position) >= 0
                ? EntryCopy.Arabic ? "‏ﺔﻨﻴﻌﻟﺍ ﺺﺤﻓﺍ" : "Inspect sample  [E]"
                : "";
        }

        internal bool ReadTerminal(Vector3 position) => Inside(position) && Near(position, terminal);

        internal string TankResult(Vector3 position)
        {
            var index = NearestTank(position);
            if (index < 0) return "";
            return EntryCopy.Arabic ? $"‏ﺀﺍﻮﺘﺣﻻﺍ ﺖﺤﺗ EX-{SampleIds[index]}" : $"EX-{SampleIds[index]} · In containment";
        }

        internal bool Crossed(Vector3 position)
        {
            var local = transform.InverseTransformPoint(position);
            return local.x < -30.25f && local.x >= -32f && Mathf.Abs(local.z - 12f) < 0.9f;
        }

        internal string Objective(Vector3 position, bool logged)
        {
            if (logged) return EntryCopy.Arabic ? "‏ﺔﻴﺑﺮﻐﻟﺍ ﺔﺑﺍﻮﺒﻟﺍ ﺭﺒﻋﺍ" : "Cross the west blast gate.";
            if (caution > 0.3f) return EntryCopy.Arabic ? "‏ﺀﺎﻄﻏ ﻒﻠﺧ ﺊﺒﺘﺧﺍ" : "Move behind cover.";
            if (!Inside(position)) return EntryCopy.Arabic ? "‏ﺕﺎﻨﻴﻌﻟﺍ ﺡﺎﻨﺟ ﻞﺧﺩﺍ" : "Enter the specimen wing.";
            return EntryCopy.Arabic ? "‏ﻲﺑﺮﻐﻟﺍ ﻞﺠﺴﻟﺍ ﺃﺮﻗﺍ" : "Read the containment record in the west alcove.";
        }

        internal void Tick(Room01Player player, bool access, bool logged, bool passed, float time, bool paused)
        {
            var blend = ChapterSceneLink.ReducedMotion ? 1f : 1f - Mathf.Exp(-6.4f * time);
            shutter.localPosition = Vector3.Lerp(shutter.localPosition, shutterClosed + Vector3.up * (access ? 3.55f : 0f), blend);
            exit.localPosition = Vector3.Lerp(exit.localPosition, closed + Vector3.up * (logged ? 3.4f : 0f), blend);
            shortcut.localPosition = Vector3.Lerp(shortcut.localPosition, shortcutClosed + Vector3.up * (passed ? 3.4f : 0f), blend);
            var feet = player.transform.position;
            beam.enabled = access && Inside(feet);
            if (!beam.enabled || paused || logged) return;

            scan += time * 0.41f;
            grace = Mathf.Max(0f, grace - time);
            scanner.localRotation = Quaternion.Euler(33f, -90f + Mathf.Sin(scan) * 42.97f, 0);
            var delta = feet + Vector3.up * 0.9f - scanner.position;
            var distance = delta.magnitude;
            var visible = grace <= 0f && distance > 0.1f && distance <= 22f &&
                Vector3.Dot(scanner.forward, delta / distance) >= 0.70f &&
                !Physics.Raycast(scanner.position, delta / distance, distance, ~(1 << 2), QueryTriggerInteraction.Ignore);
            caution = Mathf.MoveTowards(caution, visible ? 1f : 0f, time * (visible ? 1f : 2.5f));
            beam.color = caution > 0f ? new Color(1f, 0.53f, 0.06f) : new Color(0.02f, 0.85f, 0.92f);
            if (caution < 1f) return;

            caution = 0f;
            grace = 2.5f;
            var local = transform.InverseTransformPoint(feet);
            var anchor = local.x > -14f ? new Vector3(-2.5f, 0.05f, -2f)
                : local.z < 8f ? new Vector3(-26f, 0.05f, -3f) : new Vector3(-24f, 0.05f, 12f);
            player.ReturnToSafePoint(transform.TransformPoint(anchor), EntryCopy.Arabic
                ? "‏ﻦﻣﻵﺍ ﻊﻗﻮﻤﻟﺍ ﻰﻟﺇ ﺕﺪﻋ" : "Containment scan detected Echo. Returned to cover.");
        }

        internal void Restore(bool access, bool logged, bool passed)
        {
            if (passed) shortcut.localPosition = shortcutClosed + Vector3.up * 3.4f;
            if (access) shutter.localPosition = shutterClosed + Vector3.up * 3.55f;
            if (logged) exit.localPosition = closed + Vector3.up * 3.4f;
        }

        private int NearestTank(Vector3 point)
        {
            for (var index = 0; index < tanks.Length; index++)
                if (Near(point, tanks[index])) return index;
            return -1;
        }

        private bool Inside(Vector3 point)
        {
            var local = transform.InverseTransformPoint(point);
            return local.x >= -30.1f && local.x <= 0.1f && local.z >= -6.1f && local.z <= 18.1f;
        }

        private static bool Near(Vector3 point, Transform target)
        {
            var contact = target.position - point;
            return Mathf.Abs(contact.y) < 1.2f && new Vector2(contact.x, contact.z).sqrMagnitude < 2.6f;
        }
    }
}

