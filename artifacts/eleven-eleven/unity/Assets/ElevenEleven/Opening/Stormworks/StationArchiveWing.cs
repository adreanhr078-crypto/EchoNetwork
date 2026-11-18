using UnityEngine;

namespace ElevenEleven.Opening
{
    public sealed class StationArchiveWing : MonoBehaviour
    {
        internal const int CompleteMask = 7;
        private static readonly string[] Memories =
        {
            "Shizuka. A familiar presence in a memory that hasn't fully returned.",
            "Yuki. You recognize him, but the memory remains fragmented.",
            "EX-011. The identifier links this fragment to the experiment.",
        };
        private static readonly string[] ArabicMemories =
        {
            "‏ﺔﻠﻣﺎﻛ ﺎﻫﺪﻌﺘﺴﺗ ﻢﻟ ﺓﺮﻛﺍﺫ ﻲﻓ ﻪﻓﺮﻌﺗ ﺭﻮﻀﺣ .ﺎﻛﻮﺰﻴﺷ",
            "‏ﺔﻌﻄﻘﺘﻣ ﺖﻟﺍﺯ ﺎﻣ ﺓﺮﻛﺍﺬﻟﺍ ﻦﻜﻟ ،ﻪﻓﺮﻌﺗ .ﻲﻛﻮﻳ",
            "‏ﺔﺑﺮﺠﺘﻟﺎﺑ ﺔﻴﻈﺸﻟﺍ ﻂﺑﺮﻳ ﺰﻣﺮﻟﺍ .EX-011",
        };

        [SerializeField] private Transform entrance;
        [SerializeField] private Transform decoder;
        [SerializeField] private Transform exit;
        [SerializeField] private Transform[] anchors;
        [SerializeField] private Transform[] visual;
        [SerializeField] private Light coreLight;
        private Vector3 exitShut;
        private Vector3 entranceShut;
        private Quaternion[] shardRest;
        private float animationTime;
        internal int Fragments { get; private set; }
        internal int LastRecovered { get; private set; }
        internal Vector3 Checkpoint => transform.TransformPoint(new Vector3(-11.0f, 0.045f, 4.65f));
        internal Vector3 Landing => transform.TransformPoint(new Vector3(-11.0f, 0.045f, 14.60f));

        private void Awake()
        {
            exitShut = exit.localPosition;
            entranceShut = entrance.localPosition;
            shardRest = new Quaternion[visual.Length];
            for (var i = 0; i < visual.Length; i++) shardRest[i] = visual[i].localRotation;
        }

        internal void Restore(int fragments, bool accessed, bool decoded)
        {
            Fragments = fragments;
            RefreshVisuals();
            Doors(accessed, decoded, 1f);
        }

        internal void Tick(float dt, bool accessible, bool decoded)
        {
            var reduced = ChapterSceneLink.ReducedMotion;
            Doors(accessible, decoded, reduced ? 1f : 1f - Mathf.Exp(-6f * dt));
            if (!accessible || reduced) return;
            animationTime += dt;
            for (var index = 0; index < visual.Length; index++)
                if (visual[index].gameObject.activeSelf)
                    visual[index].localRotation = shardRest[index] * Quaternion.Euler(0f, 35f * animationTime, 0f);
        }

        internal string Action(Vector3 point, bool decoded)
        {
            if (decoded) return "";
            if (Nearest(point) >= 0) return EntryCopy.Arabic ? "‏ﺓﺮﻛﺍﺬﻟﺍ ﺔﻴﻈﺷ ﺬﺧ" : "Recover memory fragment  [E]";
            if (CanDecode(point)) return EntryCopy.Arabic ? "‏ﺓﺮﻛﺍﺬﻟﺍ ﻞﺠﺳ ﻚﻓ" : "Decode archive  [E]";
            return "";
        }

        internal string Objective(Vector3 point, bool decoded)
        {
            if (decoded) return EntryCopy.Arabic ? "‏ﺭﻮﺘﻛﺎﻔﻤﻟﺍ ﺔﺑﺍﻮﺑ ﺭﺒﻋﺍ" : "Cross the gate toward the reactor.";
            if (Fragments == CompleteMask)
                return EntryCopy.Arabic ? "‏ﺓﺮﻛﺍﺬﻟﺍ ﻞﺠﺳ ﻚﻓ ﻢﺛ ﺓﺍﻮﻨﻟﺍ ﻰﻟﺇ ﺪﻋ" : "Return to the core and decode the record.";
            var recovered = (Fragments & 1) + ((Fragments >> 1) & 1) + ((Fragments >> 2) & 1);
            return EntryCopy.Arabic ? $"{recovered}/3 ‏ﺓﺮﻛﺍﺬﻟﺍ ﺎﻳﺎﻈﺷ ﺪﻌﺘﺳﺍ" : $"Recover the memory fragments  {recovered}/3.";
        }

        internal bool CanDecode(Vector3 point) => Fragments == CompleteMask && Near(point, decoder);

        internal string Collect(Vector3 point)
        {
            var index = Nearest(point);
            if (index < 0) return "";
            LastRecovered = index;
            Fragments |= 1 << index;
            RefreshVisuals();
            return EntryCopy.Arabic ? ArabicMemories[index] : Memories[index];
        }

        internal bool Crossed(Vector3 point)
        {
            var local = transform.InverseTransformPoint(point);
            return local.z > 14.32f && local.z < 15.55f && Mathf.Abs(local.x + 11f) < 0.88f;
        }

        private void Doors(bool accessible, bool decoded, float blend)
        {
            entrance.localPosition = Vector3.Lerp(entrance.localPosition, entranceShut + Vector3.up * (accessible ? 3.7f : 0), blend);
            exit.localPosition = Vector3.Lerp(exit.localPosition, exitShut + Vector3.up * (decoded ? 3.45f : 0), blend);
        }

        private void RefreshVisuals()
        {
            for (var index = 0; index < visual.Length; index++)
                visual[index].gameObject.SetActive((Fragments & (1 << index)) == 0);
            coreLight.color = Fragments == CompleteMask ? new Color(0.10f, 0.92f, 1f) : new Color(0.65f, 0.22f, 1f);
        }

        private int Nearest(Vector3 point)
        {
            for (var index = 0; index < anchors.Length; index++)
                if ((Fragments & (1 << index)) == 0 && Near(point, anchors[index])) return index;
            return -1;
        }

        private static bool Near(Vector3 point, Transform anchor)
        {
            var distance = anchor.position - point;
            return Mathf.Abs(distance.y) < 1.2f && new Vector2(distance.x, distance.z).sqrMagnitude < 2.21f;
        }
    }
}

