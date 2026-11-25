using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace ElevenEleven.Opening
{
    public sealed class StationZeroEncounter : MonoBehaviour
    {
        private const float AltarReach = 2.8f;

        [SerializeField] private Transform altar;
        [SerializeField] private Transform stageMark;
        [SerializeField] private Transform shadowShot;
        [SerializeField] private Transform depthShot;
        [SerializeField] private Transform decisionShot;
        [SerializeField] private ArchiveVignettes vignettes;
        [SerializeField] private Transform sealShot;
        [SerializeField] private GameObject manifestation;
        [SerializeField] private Animation breathing;
        [SerializeField] private Light aura;
        [SerializeField] private AudioSource ambience;
        [SerializeField] private AudioSource cue;
        [SerializeField] private GameObject panel;
        [SerializeField] private Text speaker;
        [SerializeField] private Text line;
        [SerializeField] private Button advance;
        [SerializeField] private Button dismiss;
        [SerializeField] private Button[] questions;

        private int answer = -1;
        private Room01Player actor;
        private bool acceptedRecap;
        private bool IsQuestionList => Progress.Beat == ZeroBeat.Questions && answer < 0;
        private bool AtDecision => Progress.Beat == ZeroBeat.Decision;
        internal ZeroPactProgress Progress { get; private set; }
        internal bool IsReading => panel.activeSelf;
        internal Transform Shot => acceptedRecap ? sealShot : Progress.Beat switch
        {
            ZeroBeat.Depth or ZeroBeat.Silence => depthShot,
            ZeroBeat.Decision => decisionShot,
            _ => shadowShot,
        };

        private static readonly string[] QuestionText =
        {
            "What is the price?", "Why me?", "How can I trust you?"
        };
        private static readonly string[] QuestionArabic =
        {
            "؟ﻦﻤﺜﻟﺍ ﺎﻣ", "؟ﺎﻧﺃ ﺍﺫﺎﻤﻟ", "؟ﻚﺑ ﻖﺛﺃ ﻒﻴﻛ"
        };
        private static readonly string[] AnswerText =
        {
            "The price is that I remain with you… until the end.",
            "I took nothing from you. I am only… giving you what remains.",
            "I will not inhabit your body… unless you let me. If you weaken… I will finish the journey."
        };
        private static readonly string[] AnswerArabic =
        {
            ".ﺔﻳﺎﻬﻨﻟﺍ ﻰﻟﺇ …ﻚﻌﻣ ﻥﻮﻛﺃ ﻥﺃ ﻮﻫ ﻦﻤﺜﻟﺍ",
            ".ﻲﻘﺑ ﺎﻣ ﻚﻴﻄﻋﺃ …ﻂﻘﻓ ﺎﻧﺃ .ﺎﺌﻴﺷ ﻚﻨﻣ ﺬﺧﺁ ﻢﻟ ﺎﻧﺃ",
            ".ﻖﻳﺮﻄﻟﺍ ﺎﻧﺃ ﻞﻤﻛﺄﺳ …ﺖﻔﻌﺿ ﺍﺫﺇﻭ .ﻲﻨﺘﻛﺮﺗ ﺍﺫﺇ ﻻﺇ …ﻙﺪﺴﺟ ﻞﺘﺣﺃ ﻦﻟ"
        };

        private static string Copy(string english, string arabic) => EntryCopy.Arabic ? arabic : english;

        internal string Objective => Progress.Accepted
            ? Copy("The pact is sealed. Return to the theatre.", ".ﺔﺑﺮﺠﺘﻟﺍ ﺔﻋﺎﻗ ﻰﻟﺇ ﺪﻋ .ﺪﻘﻌﻟﺍ ﻢﺗ")
            : Copy("Follow the violet light to the altar.", ".ﺢﺑﺬﻤﻟﺍ ﻰﻟﺇ ﻲﺠﺴﻔﻨﺒﻟﺍ ﺀﻮﻀﻟﺍ ﻊﺒﺗﺍ");

        internal string Action(Vector3 position)
        {
            var delta = altar.position - position;
            if (Progress.Accepted || IsReading || Mathf.Abs(delta.y) > 0.9f ||
                new Vector2(delta.x, delta.z).sqrMagnitude > AltarReach * AltarReach)
                return "";
            return Progress.Deferred
                ? Copy("Return to Zero  [E]", "ﻭﺮﻳﺯ ﻰﻟﺇ ﺪﻋ")
                : Copy("Confront the presence  [E]", "ﺭﻮﻀﺤﻟﺍ ﻪﺟﺍﻭ");
        }

        internal void Restore(ZeroPactProgress progress)
        {
            Progress = progress;
            SetPresentation();
        }

        internal void Interact(Room01Player player)
        {
            if (Action(player.transform.position).Length == 0) return;
            actor = player;
            var newDepth = Progress.Beat == ZeroBeat.Unseen;
            if (!Commit(Progress.Open())) return;
            answer = -1;
            actor.ReturnToSafePoint(stageMark.position, "");
            actor.FaceRouteFocus(altar.position);
            panel.SetActive(true);
            actor.HoldForExamination(true);
            SetPresentation();
            if (newDepth) vignettes?.Show(5, true);
        }

        public void Advance()
        {
            if (!IsReading || Time.timeScale <= 0f) return;
            if (Progress.Beat == ZeroBeat.Depth && vignettes?.Active == true) vignettes.End();
            if (acceptedRecap)
            {
                Close();
                return;
            }
            if (AtDecision)
            {
                if (!Commit(Progress.Confirm())) return;
                acceptedRecap = true;
                actor.ApplyPactAppearance(true);
                if (!ChapterSceneLink.Muted) cue.Play();
                SetPresentation();
                return;
            }
            if (answer >= 0)
            {
                answer = -1;
            }
            else
            {
                var next = Progress.Advance();
                if (next.Equals(Progress) || !Commit(next)) return;
            }
            SetPresentation();
        }

        public void Ask(int index)
        {
            if (!IsReading || !IsQuestionList || index < 0 || index >= questions.Length || Time.timeScale <= 0f)
                return;
            if (!Commit(Progress.Ask(index))) return;
            answer = index;
            SetPresentation();
        }

        public void Dismiss()
        {
            if (!IsReading || Time.timeScale <= 0f) return;
            if (AtDecision && !Commit(Progress.Defer())) return;
            Close();
        }

        private bool Commit(ZeroPactProgress next)
        {
            if (next.Equals(Progress)) return true;
            if (!actor.TrySaveZero(Progress, next))
            {
                if (IsReading) line.text = Copy("Could not save. Try again.", ".ﺍﺩﺪﺠﻣ ﻝﻭﺎﺣ .ﻆﻔﺤﻟﺍ ﺭﺬﻌﺗ");
                return false;
            }
            Progress = next;
            return true;
        }

        private void Close()
        {
            vignettes?.End();
            panel.SetActive(false);
            acceptedRecap = false;
            answer = -1;
            SetPresentation();
            actor.HoldForExamination(false);
            actor.ReturnToSafePoint(stageMark.position, "");
            actor = null;
        }

        private void Update()
        {
            if (!IsReading) return;
            ambience.mute = cue.mute = ChapterSceneLink.Muted;
            var motion = manifestation.activeSelf && !ChapterSceneLink.ReducedMotion;
            if (motion && !breathing.isPlaying) breathing.Play();
            if (!motion && breathing.isPlaying) breathing.Stop();
        }

        private void OnDisable()
        {
            ambience.Stop();
            cue.Stop();
        }

        private void SetPresentation()
        {
            var showZero = IsReading && Progress.Beat >= ZeroBeat.Manifestation && !Progress.Accepted;
            manifestation.SetActive(showZero);
            aura.enabled = showZero || acceptedRecap;
            aura.color = acceptedRecap ? new Color(0.26f, 0.65f, 1f) : new Color(0.51f, 0.21f, 1f);
            if (!IsReading)
            {
                ambience.Stop();
                return;
            }

            ambience.mute = cue.mute = ChapterSceneLink.Muted;
            if (!ambience.isPlaying) ambience.Play();
            speaker.text = Progress.Beat switch
            {
                ZeroBeat.Depth => Copy("At the bottom", "ﻉﺎﻘﻟﺍ ﻲﻓ"),
                ZeroBeat.Accepted => "EX-011",
                _ => Copy("Zero", "ﻭﺮﻳﺯ"),
            };
            line.text = Progress.Beat switch
            {
                ZeroBeat.Depth => Copy("You are still here.", ".ﺎﻨﻫ ﺖﻟﺯ ﺎﻣ"),
                ZeroBeat.Silence => "…",
                ZeroBeat.Voice => Copy("You were trying to remain human.", ".ﺎﻧﺎﺴﻧﺇ ﻰﻘﺒﺗ ﻥﺃ ﻝﻭﺎﺤﺗ ﺖﻨﻛ ﺖﻧﺃ"),
                ZeroBeat.Manifestation => Copy("This is my true form. I am neither human… nor a memory.", ".ﻯﺮﻛﺫ ﻻﻭ …ﺎﻧﺎﺴﻧﺇ ﺖﺴﻟ ﺎﻧﺃ .ﻲﻘﻴﻘﺤﻟﺍ ﻲﻠﻜﺷ ﺍﺬﻫ"),
                ZeroBeat.Questions when answer >= 0 => Copy(AnswerText[answer], AnswerArabic[answer]),
                ZeroBeat.Questions => Copy("Ask before you choose.", ".ﺭﺎﺘﺨﺗ ﻥﺃ ﻞﺒﻗ ﻝﺄﺳﺍ"),
                ZeroBeat.Decision => Copy("I will not inhabit your body… unless you let me. The price is that I remain with you… until the end.", ".ﺔﻳﺎﻬﻨﻟﺍ ﻰﻟﺇ …ﻚﻌﻣ ﻥﻮﻛﺃ ﻥﺃ ﻮﻫ ﻦﻤﺜﻟﺍ .ﻲﻨﺘﻛﺮﺗ ﺍﺫﺇ ﻻﺇ …ﻙﺪﺴﺟ ﻞﺘﺣﺃ ﻦﻟ"),
                ZeroBeat.Accepted => Copy("The form vanished. The mark is still on the skin.", ".ﺪﻠﺠﻟﺍ ﻰﻠﻋ ﺔﻣﻼﻌﻟﺍ ﺖﻟﺍﺯ ﺎﻣ .ﻞﻜﺸﻟﺍ ﻰﻔﺘﺧﺍ"),
                _ => "",
            };
            for (var index = 0; index < questions.Length; index++)
            {
                var asked = (Progress.Questions & (1 << index)) != 0;
                SetButton(questions[index], IsQuestionList, (asked ? "• " : "") + Copy(QuestionText[index], QuestionArabic[index]));
            }
            SetButton(advance, !IsQuestionList || Progress.HeardAll, Progress.Beat switch
            {
                ZeroBeat.Decision => Copy("Give me what I need", "ﻪﺟﺎﺘﺣﺃ ﺎﻣ ﻲﻨﻄﻋﺃ"),
                ZeroBeat.Questions when IsQuestionList => Copy("Make the choice", "ﺭﺍﺮﻘﻟﺍ ﻰﻟﺇ"),
                ZeroBeat.Accepted => Copy("Return to the theatre", "ﺔﺑﺮﺠﺘﻟﺍ ﺔﻋﺎﻗ ﻰﻟﺇ ﺪﻋ"),
                _ => Copy("Continue", "ﻊﺑﺎﺗ"),
            });
            SetButton(dismiss, !acceptedRecap, AtDecision ? Copy("Not yet", "ﻥﻵﺍ ﺲﻴﻟ") : Copy("Step back", "ﻊﺟﺍﺮﺗ"));
            if (EventSystem.current != null)
            {
                var focus = AtDecision ? dismiss : IsQuestionList && !Progress.HeardAll ? questions[0] : advance;
                EventSystem.current.SetSelectedGameObject(focus.gameObject);
            }
        }

        private static void SetButton(Button button, bool visible, string text)
        {
            button.gameObject.SetActive(visible);
            button.GetComponentInChildren<Text>(true).text = text;
        }
    }
}
