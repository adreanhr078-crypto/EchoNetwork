using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace ElevenEleven.Opening
{
    internal enum KinjaBeat { Return, FirstContact, SecondContact, Staggered, Released, WishConfirmed }

    public sealed class StationKinjaConfrontation : MonoBehaviour
    {
        [SerializeField] private Transform target;
        [SerializeField] private Transform reaction;
        [SerializeField] private Transform approach;
        [SerializeField] private Transform shot;
        [SerializeField] private Light key;
        [SerializeField] private AudioSource contactSound;
        [SerializeField] private AudioClip[] contacts;
        [SerializeField] private GameObject panel;
        [SerializeField] private Text speaker;
        [SerializeField] private Text line;
        [SerializeField] private Button choice;
        [SerializeField] private Button back;
        [SerializeField] private Button strike;

        private Room01Player actor;
        private float impactTime;
        private float pulseCooldown = 3.8f;
        private float pulseWindup;
        private float recoveryTime;
        private float recoil;
        private bool available;
        internal KinjaBeat Beat { get; private set; }
        internal bool IsReading => panel.activeSelf;
        internal Transform Shot => shot;
        internal Vector3 ReturnPoint => approach.position;
        private bool CanFight => available && Beat < KinjaBeat.Staggered;

        private static string Copy(string english, string arabic) => EntryCopy.Arabic ? arabic : english;

        internal string Objective => Beat switch
        {
            KinjaBeat.Staggered => Copy("Approach Kinja and confront him.", ".ﻪﻬﺟﺍﻭﻭ ﺎﺠﻨﻴﻛ ﻦﻣ ﺏﺮﺘﻗﺍ"),
            KinjaBeat.Released => Copy("Return to Kinja and answer Zero’s offer.", ".ﻭﺮﻳﺯ ﺽﺮﻋ ﻦﻋ ﺐﺟﺃﻭ ﺎﺠﻨﻴﻛ ﻰﻟﺇ ﺪﻋ"),
            KinjaBeat.WishConfirmed => Copy("The System registered your wish.", ".ﻚﺘﻴﻨﻣﺃ ﻡﺎﻈﻨﻟﺍ ﻞﺠﺳ"),
            _ => Copy("Return to the theatre. Strike within reach [F / RB].", "[F / RB] ﻪﻨﻣ ﺏﺮﻘﻟﺍ ﺪﻨﻋ ﺏﺮﺿﺍﻭ ﺎﺠﻨﻴﻛ ﻰﻟﺇ ﺪﻋ"),
        };

        private bool Within(Room01Player player, float reach) => Within(player.transform.position, reach);

        private bool Within(Vector3 position, float reach)
        {
            var offset = target.position - position;
            return Mathf.Abs(offset.y) < 0.8f && new Vector2(offset.x, offset.z).sqrMagnitude <= reach * reach;
        }

        internal void Unlock()
        {
            if (available) return;
            available = true;
            Refresh();
        }

        internal void Restore(bool unlocked, KinjaBeat beat)
        {
            Beat = beat;
            available = unlocked;
            Refresh();
        }

        internal string Action(Vector3 position)
        {
            if (!available || !Within(position, 2.15f)) return "";
            return Beat switch
            {
                KinjaBeat.Staggered when recoveryTime <= 0f => Copy("Confront Kinja [E]", "ﺎﺠﻨﻴﻛ ﻪﺟﺍﻭ"),
                KinjaBeat.Released => Copy("Hear Zero’s offer [E]", "ﻭﺮﻳﺯ ﺽﺮﻌﻟ ﻊﻤﺘﺳﺍ"),
                _ => "",
            };
        }

        internal void Interact(Room01Player player)
        {
            if (Action(player.transform.position).Length == 0) return;
            actor = player;
            actor.ShowRouteNote("");
            actor.FaceRouteFocus(target.position);
            panel.SetActive(true);
            actor.HoldForExamination(true);
            PresentDecision();
            Refresh();
        }

        internal void RequestStrike(Room01Player player)
        {
            if (!CanFight || IsReading || recoveryTime > 0f || !Within(player, 2.25f) ||
                !player.TryPlayPactStrike(target.position, out var duration)) return;
            impactTime = 0.24f;
            recoveryTime = Mathf.Clamp(duration * 0.85f, 0.42f, 0.72f);
        }

        internal void Tick(Room01Player player, float dt, bool held)
        {
            if (!available) return;
            strike.gameObject.SetActive(CanFight && !held && Within(player, 2.25f) &&
                (UnityEngine.InputSystem.Touchscreen.current != null || Application.isMobilePlatform));
            if (held || dt <= 0f) return;

            recoveryTime = Mathf.Max(0f, recoveryTime - dt);
            if (impactTime > 0f)
            {
                impactTime -= dt;
                if (impactTime <= 0f && CanFight && Within(player, 2.40f))
                    ResolveContact(player);
            }

            if (CanFight && !IsReading)
            {
                if (pulseWindup > 0f)
                {
                    pulseWindup -= dt;
                    if (key) key.color = new Color(1f, 0.24f, 0.18f);
                    if (pulseWindup <= 0f)
                    {
                        pulseCooldown = 4.4f;
                        if (Within(player, 2.05f))
                        {
                            player.TryHazardReturn(transform.position + Vector3.back * 2.6f,
                                Copy("Kinja's defensive pulse pushed you back!", "دفعك نبض كينجا الدفاعي للخلف!"));
                        }
                        Refresh();
                    }
                }
                else
                {
                    pulseCooldown -= dt;
                    if (pulseCooldown <= 0f && Within(player, 4.8f))
                    {
                        pulseWindup = 1.25f;
                        player.ShowRouteNote(Copy("Kinja channels a pulse — Dodge [Ctrl] or Counter [F]!",
                            "كينجا يجمع نبضة — تفادَ [Ctrl] أو اضرب مضاداً [F]!"));
                    }
                }
            }

            recoil = Mathf.MoveTowards(recoil, 0f, dt * 2.8f);
            var tremor = pulseWindup > 0f && !ChapterSceneLink.ReducedMotion ? Mathf.Sin(Time.time * 42f) * 2.5f : 0f;
            reaction.localRotation = Quaternion.Euler(0f, 0f,
                (ChapterSceneLink.ReducedMotion ? 0f : (Beat == KinjaBeat.Staggered ? -12f : 0f) - recoil * 14f) + tremor);
        }

        private void ResolveContact(Room01Player player)
        {
            var countered = pulseWindup > 0f;
            pulseWindup = 0f;
            pulseCooldown = 4.2f;
            if (!Commit(player, Beat + 1)) return;
            recoil = countered ? 1.35f : 1f;
            var finisher = Beat == KinjaBeat.Staggered || countered;
            if (!ChapterSceneLink.Muted) contactSound.PlayOneShot(contacts[Mathf.Clamp((int)Beat - 1, 0, contacts.Length - 1)]);
            player.OnCombatImpact(target.position + Vector3.up * 1.15f, finisher);
            player.ShowRouteNote(Beat == KinjaBeat.Staggered
                ? Copy("Kinja is staggered!", ".ﺎﺠﻨﻴﻛ ﺡﺮﻨﺗ")
                : countered
                    ? Copy($"Counter Break! {(int)Beat} / 3", $"كسر مضاد! {(int)Beat} / 3")
                    : Copy($"Contact {(int)Beat} / 3", $"{(int)Beat} / 3"));
        }

        public void Confirm()
        {
            if (!IsReading || actor == null || Time.timeScale <= 0f) return;
            if (!Commit(actor, Beat + 1))
            {
                line.text = Copy("Could not save. Try again.", ".ﺍﺪﺪﺠﻣ ﻝﻭﺎﺣ .ﻆﻔﺤﻟﺍ ﺭﺬﻌﺗ");
                return;
            }
            if (Beat == KinjaBeat.Released) PresentDecision();
            else Close();
        }

        public void Close()
        {
            if (!IsReading) return;
            panel.SetActive(false);
            actor.HoldForExamination(false);
            actor = null;
            if (EventSystem.current != null) EventSystem.current.SetSelectedGameObject(null);
            Refresh();
        }

        private bool Commit(Room01Player player, KinjaBeat next)
        {
            if (!player.TrySaveKinjaBeat(Beat, next)) return false;
            Beat = next;
            Refresh();
            return true;
        }

        private void Refresh()
        {
            key.enabled = available && Beat < KinjaBeat.WishConfirmed;
            strike.GetComponentInChildren<Text>(true).text = Copy("Strike", "ﺔﺑﺮﺿ");
            key.color = Beat >= KinjaBeat.Released ? new Color(0.41f, 0.35f, 1f) : new Color(1f, 0.60f, 0.38f);
        }

        private void PresentDecision()
        {
            var wish = Beat == KinjaBeat.Released;
            speaker.text = wish ? "EX-011" : Copy("Echo", "ﻮﻜﻳﺇ");
            line.text = wish
                ? Copy("What is your wish?\nEscape… and take revenge on everyone connected to the System, whatever the cost.\nDo you accept?",
                    "؟ﻚﺘﻴﻨﻣﺃ ﻲﻫ ﺎﻣ\n.ﻦﻤﺜﻟﺍ ﻥﺎﻛ ﺎﻤﻬﻣ ،ﻡﺎﻈﻨﻟﺎﺑ ﻪﻟ ﺔﻗﻼﻋ ﻪﻟ ﻦﻣ ﻞﻛ ﻦﻣ ﻡﺎﻘﺘﻧﻻﺍﻭ …ﺝﻭﺮﺨﻟﺍ\n؟ﻞﺒﻘﺗ ﻞﻫ")
                : Copy("Now you want to talk? After everything?", "؟ﺀﻲﺷ ﻞﻛ ﺪﻌﺑ ؟ﻡﻼﻜﻟﺍ ﺪﻳﺮﺗ ﻥﻵﺍ");
            choice.GetComponentInChildren<Text>().text = wish ? Copy("Yes, I accept.", ".ﻞﺒﻗﺃ ،ﻢﻌﻧ") :
                Copy("I remember everything.", ".ﺀﻲﺷ ﻞﻛ ﺮﻛﺬﺗﺃ ﺎﻧﺃ");
            back.GetComponentInChildren<Text>().text = Copy("Step back", "ﻊﺟﺍﺮﺗ");
            if (EventSystem.current != null) EventSystem.current.SetSelectedGameObject(back.gameObject);
        }
    }
}
