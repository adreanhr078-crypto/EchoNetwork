using UnityEngine;

namespace ElevenEleven.Opening
{
    public sealed class StationSecurityWing : MonoBehaviour
    {
        public const float EntranceZ = 79.5f;
        public const float CenterX = 17f;
        private const float ExitZ = EntranceZ + 17.65f;

        [SerializeField] private Transform scanner;
        [SerializeField] private Light sweep;
        [SerializeField] private Transform diversion;
        [SerializeField] private Transform gatePanel;
        [SerializeField] private Transform gate;
        [SerializeField] private Transform entry;
        [SerializeField] private AudioSource mechanism;
        private Vector3 gateClosed;
        private Vector3 entryClosed;
        private float elapsed;
        private float diversionRemaining;
        private float retryCooldown;
        private float warning;
        private bool gateOpen;
        internal bool Entered(Vector3 point) => point.z >= EntranceZ && InLane(point);
        internal bool Passed(Vector3 point) => gateOpen && point.z >= ExitZ && Mathf.Abs(point.x - CenterX) < 0.83f;
        internal static Vector3 ExitRecovery => new Vector3(CenterX, 0.045f, ExitZ + 0.07f);

        private void Awake()
        {
            gateClosed = gate.localPosition;
            entryClosed = entry.localPosition;
        }

        internal void Restore(bool unlocked, bool passed)
        {
            gateOpen = passed;
            if (unlocked) entry.localPosition = entryClosed + Vector3.up * 3.3f;
            if (passed) gate.localPosition = gateClosed + Vector3.up * 3.35f;
        }

        internal string Action(Vector3 point)
        {
            if (!Entered(point) || point.z > ExitZ) return "";
            if (Touching(point, diversion) && diversionRemaining <= 0)
                return EntryCopy.Arabic ? "‏ﺢﺳﺎﻤﻟﺍ ﺭﺎﺴﻣ ﺮﻴّﻏ" : "Divert scanner  [E]";
            if (!gateOpen && Touching(point, gatePanel))
                return EntryCopy.Arabic ? "‏ﻦﻣﻷﺍ ﺔﺑﺍﻮﺑ ﺢﺘﻓﺍ" : "Release security gate  [E]";
            return "";
        }

        internal string Objective(Vector3 point)
        {
            if (!Entered(point)) return EntryCopy.Arabic ? "‏ﺀﺎﻨﻔﻟﺍ ﻦﻣ ﻦﻣﻷﺍ ﺡﺎﻨﺟ ﺭﺒﻋﺍ" : "Enter the security wing from the perimeter.";
            if (warning >= 0.40f) return EntryCopy.Arabic ? "‏ﺀﺎﻄﻏ ﻒﻠﺧ ﺊﺒﺘﺧﺍ" : "Scanner tracking. Move behind cover.";
            if (gateOpen) return EntryCopy.Arabic ? "‏ﻦﻣﻷﺍ ﺔﺑﺍﻮﺑ ﺭﺒﻋﺍ" : "Cross the security gate.";
            return EntryCopy.Arabic ? "‏ﺢﺳﺎﻤﻟﺍ ﺭﺎﺴﻣ ﺮﻴّﻏ ﻭﺃ ﺀﺎﻄﻐﻟﺍ ﻦﻣ ﺪﻔﺘﺳﺍ" : "Use cover or divert the scanner, then release the gate.";
        }

        internal bool Interact(Vector3 point)
        {
            if (Action(point).Length == 0) return false;
            if (Touching(point, diversion) && diversionRemaining <= 0)
            {
                diversionRemaining = 8f;
                warning = 0f;
            }
            else gateOpen = true;
            if (!ChapterSceneLink.Muted) mechanism.Play();
            return true;
        }

        internal void Tick(Room01Player player, float dt, bool unlocked, bool passed, bool modal)
        {
            var reduced = ChapterSceneLink.ReducedMotion;
            var blend = reduced ? 1f : 1f - Mathf.Exp(-6.5f * dt);
            entry.localPosition = Vector3.Lerp(entry.localPosition, entryClosed + Vector3.up * (unlocked ? 3.3f : 0f), blend);
            gate.localPosition = Vector3.Lerp(gate.localPosition, gateClosed + Vector3.up * (gateOpen ? 3.35f : 0f), blend);
            sweep.enabled = unlocked;
            mechanism.mute = ChapterSceneLink.Muted;
            if (!unlocked || modal || !Entered(player.transform.position) || passed || player.transform.position.z > ExitZ) return;

            elapsed += dt;
            retryCooldown = Mathf.Max(0f, retryCooldown - dt);
            diversionRemaining = Mathf.Max(0f, diversionRemaining - dt);
            scanner.localRotation = Quaternion.Euler(5.8f, 180f + Mathf.Sin(elapsed * 0.55f) * 44.7f, 0);
            var diverted = diversionRemaining > 0f;
            sweep.color = diverted ? new Color(0.19f, 0.85f, 1f) : new Color(1f, 0.37f, 0.075f);
            sweep.intensity = diverted ? 0.9f : 5.1f + warning * 2.5f;
            var seen = !diverted && retryCooldown <= 0f && Sees(player.transform.position);
            warning = Mathf.MoveTowards(warning, seen ? 1f : 0f, (seen ? 0.6f : 1.2f) * dt);
            if (warning < 1f) return;

            warning = 0f;
            retryCooldown = 2f;
            player.TryHazardReturn(new Vector3(CenterX - 2.6f, 0.045f, EntranceZ + 1.4f),
                EntryCopy.Arabic ? "‏ﻦﻣﻵﺍ ﻊﻗﻮﻤﻟﺍ ﻰﻟﺇ ﺕﺪﻋ" : "Scanner locked on. Returned to cover.");
        }

        private bool Sees(Vector3 feet)
        {
            var delta = feet + Vector3.up * 0.95f - scanner.position;
            var distance = delta.magnitude;
            if (distance < 0.15f || distance > 13f) return false;
            var direction = delta / distance;
            return Vector3.Dot(scanner.forward, direction) >= 0.97815f &&
                !Physics.Raycast(scanner.position, direction, distance, ~(1 << 2), QueryTriggerInteraction.Ignore);
        }

        private static bool InLane(Vector3 point) => Mathf.Abs(point.x - CenterX) < 4.45f;
        private static bool Touching(Vector3 point, Transform target)
        {
            var delta = target.position - point;
            return Mathf.Abs(delta.y) <= 1.12f && new Vector2(delta.x, delta.z).sqrMagnitude <= 1.95f;
        }
    }
}

