using UnityEngine;

namespace ElevenEleven.Opening
{
    public sealed class StationReactorWing : MonoBehaviour
    {
        internal const int Both = 3;
        [SerializeField] private Transform bridge;
        [SerializeField] private Transform hatch;
        [SerializeField] private Transform entrance;
        [SerializeField] private Transform[] breakers;
        [SerializeField] private Bounds[] arcVolumes;
        [SerializeField] private Light[] arcs;
        private Vector3 bridgeDown;
        private Vector3 hatchShut;
        private Vector3 entranceShut;
        private float clock;
        private float grace;
        internal int Breakers { get; private set; }
        internal Vector3 Landing => transform.TransformPoint(new Vector3(0f, 0.045f, 44.65f));
        internal Vector3 EntryPoint => transform.TransformPoint(new Vector3(0f, -3.94f, 2.5f));

        private void Awake()
        {
            bridgeDown = bridge.localPosition;
            hatchShut = hatch.localPosition;
            entranceShut = entrance.localPosition;
        }

        internal void Restore(int breakersMask, bool accessible)
        {
            Breakers = breakersMask;
            MoveGates(accessible, 1f);
        }

        internal string Action(Vector3 feet)
        {
            var slot = ReadyBreaker(feet);
            if (slot < 0) return "";
            if (EntryCopy.Arabic)
                return slot == 0 ? "‏ﻲﺑﺮﻐﻟﺍ ﻊﻃﺎﻘﻟﺍ ﻞﻐﺷ" : "‏ﻲﻗﺮﺸﻟﺍ ﻊﻃﺎﻘﻟﺍ ﻞﻐﺷ";
            return slot == 0 ? "Switch west breaker  [E]" : "Switch east breaker  [E]";
        }

        internal bool Interact(Vector3 feet)
        {
            var slot = ReadyBreaker(feet);
            if (slot < 0) return false;
            Breakers |= 1 << slot;
            return true;
        }

        internal string Objective(Vector3 position)
        {
            if (Breakers == Both)
                return EntryCopy.Arabic ? "‏ﻲﻜﻴﻟﻭﺭﺪﻴﻬﻟﺍ ﺮﺴﺠﻟﺍ ﺭﺒﻋﺍ" : "Cross the hydraulic bridge when it is level.";
            if (!Inside(position))
                return EntryCopy.Arabic ? "‏ﻞﻋﺎﻔﻤﻟﺍ ﺡﺎﻨﺟ ﻞﺧﺩﺍ" : "Follow the reserve conduit into the reactor.";
            return EntryCopy.Arabic ? "‏ﻦﻴﻴﺋﺎﺑﺮﻬﻜﻟﺍ ﻦﻴﻌﻃﺎﻘﻟﺍ ﻞﻐﺷ" : "Activate both breakers. Cross when the discharge fades.";
        }

        internal bool Passed(Vector3 feet)
        {
            var position = transform.InverseTransformPoint(feet);
            return Breakers == Both && Mathf.Abs(position.x) < 0.84f && position.z > 44.25f && position.z < 45.6f;
        }

        internal void Tick(Room01Player player, bool accessible, float dt)
        {
            var motion = ChapterSceneLink.ReducedMotion ? 1f : 1f - Mathf.Exp(-5.5f * dt);
            MoveGates(accessible, motion);
            var point = player.transform.position;
            var present = accessible && Inside(point);
            var local = transform.InverseTransformPoint(point);
            if (present)
            {
                clock = Mathf.Repeat(clock + dt, 4.3f);
                grace = Mathf.Max(0f, grace - dt);
            }

            for (var i = 0; i < arcs.Length; i++)
            {
                var phase = Mathf.Repeat(clock + i * 2.15f, 4.3f);
                var warning = phase < 0.8f;
                var charged = phase >= 0.8f && phase < 1.8f;
                arcs[i].enabled = present;
                if (!present) continue;
                arcs[i].color = warning ? new Color(1f, 0.46f, 0.08f) : new Color(0.19f, 0.56f, 1f);
                arcs[i].intensity = charged ? 11.5f : warning ? 3.8f : 0.85f;
                if (dt > 0f && charged && grace <= 0f && arcVolumes[i].Contains(local))
                {
                    grace = 2.4f;
                    var anchor = local.z > 30f ? new Vector3(0, 0.04f, 41f)
                        : local.z > 14f ? new Vector3(-11f, -1.89f, 16f) : new Vector3(0, -3.94f, 2.5f);
                    player.TryHazardReturn(transform.TransformPoint(anchor), EntryCopy.Arabic
                        ? "‏ﻦﻣﻵﺍ ﻊﻗﻮﻤﻟﺍ ﻰﻟﺇ ﺕﺪﻋ" : "Discharge forced an emergency return.");
                }
            }
        }

        private void MoveGates(bool access, float blend)
        {
            var powered = Breakers == Both;
            entrance.localPosition = Vector3.Lerp(entrance.localPosition, entranceShut + Vector3.up * (access ? 3.7f : 0f), blend);
            bridge.localPosition = Vector3.Lerp(bridge.localPosition, bridgeDown + Vector3.up * (powered ? 3.5f : 0f), blend);
            hatch.localPosition = Vector3.Lerp(hatch.localPosition, hatchShut + Vector3.up * (powered ? 3.4f : 0f), blend);
        }

        private int ReadyBreaker(Vector3 feet)
        {
            for (var i = 0; i < breakers.Length; i++)
            {
                if ((Breakers & (1 << i)) != 0) continue;
                var delta = breakers[i].position - feet;
                if (Mathf.Abs(delta.y) < 1.2f && new Vector2(delta.x, delta.z).sqrMagnitude < 2.35f) return i;
            }
            return -1;
        }

        private bool Inside(Vector3 world)
        {
            var local = transform.InverseTransformPoint(world);
            return Mathf.Abs(local.x) <= 18.4f && local.z >= -0.15f && local.z <= 44.2f;
        }
    }
}
