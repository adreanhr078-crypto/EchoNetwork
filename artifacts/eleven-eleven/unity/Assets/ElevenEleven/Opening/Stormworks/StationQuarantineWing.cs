using UnityEngine;

namespace ElevenEleven.Opening
{
    public sealed class StationQuarantineWing : MonoBehaviour
    {
        public const float Depth = 32f;
        [SerializeField] private Transform gate;
        [SerializeField] private Transform console;
        [SerializeField] private GameObject mist;
        [SerializeField] private Light status;
        [SerializeField] private AudioSource extraction;
        private Vector3 closed;
        private static readonly Color Violet = new Color(0.46f, 0.17f, 1f);
        private static readonly Color Clear = new Color(0.1f, 1f, 0.64f);

        internal Vector3 Catwalk => transform.TransformPoint(new Vector3(-1.4f, 3.25f, 16.06f));

        private void Awake() => closed = gate.localPosition;

        internal string Objective(bool overridden) => overridden
            ? EntryCopy.Arabic ? "‏ﻲﻟﺎﻤﺸﻟﺍ ﺝﺮﺨﻤﻟﺍ ﻰﻟﺇ ﻝﺰﻧﺍ" : "Descend to the north blast gate."
            : EntryCopy.Arabic ? "‏ﻱﻮﻠﻌﻟﺍ ﺮﻤﻤﻟﺍ ﻦﻣ ﺮﺠﺤﻟﺍ ﺢﺘﻓﺍ" : "Take the west ramp to the quarantine override.";

        internal string Action(Vector3 player, bool overridden) => !overridden && CanOverride(player)
            ? EntryCopy.Arabic ? "‏ﺮﺠﺤﻟﺍ ﺢﺘﻓﺍ" : "Clear quarantine  [E]"
            : "";

        internal bool CanOverride(Vector3 player)
        {
            var feet = transform.InverseTransformPoint(player);
            return feet.y >= 2.96f && feet.y < 4.5f && (player - console.position).sqrMagnitude < 2.9f;
        }

        internal void Present(bool overridden, float blend)
        {
            gate.localPosition = Vector3.Lerp(gate.localPosition, closed + Vector3.up * (overridden ? 3.18f : 0f), blend);
            mist.SetActive(!overridden);
            status.color = overridden ? Clear : Violet;
        }

        internal void Tick(Vector3 position, bool overridden, bool modal, float dt)
        {
            Present(overridden, ChapterSceneLink.ReducedMotion ? 1f : 1f - Mathf.Exp(-6.5f * dt));
            var local = transform.InverseTransformPoint(position);
            var active = !overridden && !modal && !ChapterSceneLink.Muted &&
                local.z > -1f && local.z < Depth && Mathf.Abs(local.x) < 12f;
            if (active && !extraction.isPlaying) extraction.Play();
            if (!active && extraction.isPlaying) extraction.Stop();
        }
    }
}
