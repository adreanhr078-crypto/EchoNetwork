using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace ElevenEleven.Opening
{
    public sealed class StationExaminationWing : MonoBehaviour
    {
        private enum Beat { Approach, Recognition, Memories, Shizuka, Yuki, Refusal, Resistance, Manifested }

        [SerializeField] private Transform console;
        [SerializeField] private Transform kinja;
        [SerializeField] private Transform shizuka;
        [SerializeField] private Transform yuki;
        [SerializeField] private Light shizukaSignal;
        [SerializeField] private Light yukiSignal;
        [SerializeField] private Light altarLight;
        [SerializeField] private GameObject shizukaPlate;
        [SerializeField] private GameObject yukiPlate;
        [SerializeField] private Transform examinationShot;
        [SerializeField] private Image scrim;
        [SerializeField] private GameObject panel;
        [SerializeField] private Text speaker;
        [SerializeField] private Text line;
        [SerializeField] private RawImage memory;
        [SerializeField] private AspectRatioFitter memoryAspect;
        [SerializeField] private Texture2D shizukaStill;
        [SerializeField] private Texture2D yukiStill;
        [SerializeField] private ArchiveVignettes fragments;
        [SerializeField] private Transform overloadRecord;
        [SerializeField] private Transform repeatRecord;
        [SerializeField] private Button advance;
        [SerializeField] private Button alternative;
        [SerializeField] private Button close;
        [SerializeField] private Button chooseShizuka;
        [SerializeField] private Button chooseYuki;
        [SerializeField] private GameObject countdown;
        [SerializeField] private RectTransform timer;

        private Beat beat;
        private int recognitionLine;
        private bool sawShizuka;
        private bool sawYuki;
        private Room01Player actor;
        private int visionTarget;
        private const float ChoiceTime = 13f;
        private float choiceRemaining;

        private void Update()
        {
            if (beat != Beat.Refusal || !IsReading || Time.timeScale <= 0f) return;
            choiceRemaining = Mathf.Max(0f, choiceRemaining - Time.unscaledDeltaTime);
            var anchor = timer.anchorMax;
            anchor.x = choiceRemaining / ChoiceTime;
            timer.anchorMax = anchor;
            if (choiceRemaining <= 0f) ResolveUltimatum(0);
        }

        private static readonly string[] Recognition =
        {
            "You… you knew?",
            "I recorded every tremor. You can watch them on the monitors.",
            "Can a human keep going after losing everything?",
            "Because I am your son?",
            "No… because you are the only one who has not broken yet."
        };

        private static readonly string[] RecognitionArabic =
        {
            "؟ﻑﺮﻌﺗ ﺖﻨﻛ …ﺖﻧﺃ",
            ".ﺕﺎﺷﺎﺸﻟﺍ ﻰﻠﻋ ﺎﻫﺪﻫﺎﺷ .ﺔﺸﻋﺭ ﻞﻛ ﺖﻠﺠﺳ",
            "؟ﺀﻲﺷ ﻞﻛ ﻥﺍﺪﻘﻓ ﺪﻌﺑ ﺭﺍﺮﻤﺘﺳﻻﺍ ﻥﺎﺴﻧﻹﺍ ﻊﻴﻄﺘﺴﻳ ﻞﻫ",
            "؟ﻚﻨﺑﺍ ﻲﻨﻧﻷ",
            ".ﺪﻌﺑ ﺮﻬﻨﻳ ﻢﻟ ﻱﺬﻟﺍ ﺪﻴﺣﻮﻟﺍ ﻚﻧﻷ …ﻻ"
        };

        private static readonly Color Unread = new Color(0.57f, 0.25f, 1f);
        private static readonly Color Read = new Color(0.20f, 0.73f, 0.81f);

        internal bool IsReading => panel.activeSelf;
        internal Transform Shot => beat == Beat.Recognition ? examinationShot : null;
        internal bool Confronted => beat == Beat.Manifested;
        internal Vector3 AfterTrial => transform.TransformPoint(new Vector3(2.2f, 0.045f, 30.5f));

        private static string Copy(string english, string arabic) => EntryCopy.Arabic ? arabic : english;

        internal void Restore(bool confronted) => SetBeat(confronted ? Beat.Manifested : Beat.Approach);

        internal string Objective()
        {
            if (Confronted)
                return Copy("The signal came from the altar. Follow the violet light.", ".ﻲﺠﺴﻔﻨﺒﻟﺍ ﺀﻮﻀﻟﺍ ﻊﺒﺗﺍ .ﺢﺑﺬﻤﻟﺍ ﻦﻣ ﺓﺭﺎﺷﻹﺍ ﺕﺀﺎﺟ");
            if (beat == Beat.Memories)
            {
                if (sawShizuka) return Copy("Examine Yuki’s memory beside the platform.", ".ﺔﺼﻨﻤﻟﺍ ﺏﺮﻗ ﻲﻛﻮﻳ ﻯﺮﻛﺫ ﺺﺤﻓﺍ");
                if (sawYuki) return Copy("Examine Shizuka’s memory beside the platform.", ".ﺔﺼﻨﻤﻟﺍ ﺏﺮﻗ ﺎﻛﻭﺰﻴﺷ ﻯﺮﻛﺫ ﺺﺤﻓﺍ");
                return Copy("Examine the two memories beside the platform.", ".ﺔﺼﻨﻤﻟﺍ ﺏﺮﻗ ﻦﻴﻳﺮﻛﺬﻟﺍ ﺺﺤﻓﺍ");
            }
            return Copy("Follow the ramp to the neural rig.", ".ﻲﺒﺼﻌﻟﺍ ﺺﺤﻔﻟﺍ ﺯﺎﻬﺟ ﻰﻟﺇ ﺭﺪﺤﻨﻤﻟﺍ ﺪﻌﺻﺍ");
        }

        internal string Action(Vector3 position)
        {
            if (beat == Beat.Approach && Near(console, position))
                return Copy("Inspect the neural rig  [E]", "ﻲﺒﺼﻌﻟﺍ ﺺﺤﻔﻟﺍ ﺯﺎﻬﺟ ﺺﺤﻓﺍ");
            if (beat == Beat.Memories && overloadRecord != null && Near(overloadRecord, position))
                return Copy("Replay the neural overload [E]", "ﺔﻴﺒﺼﻌﻟﺍ ﺔﻣﺪﺼﻟﺍ ﺪﻋﺃ");
            if (beat == Beat.Memories && repeatRecord != null && Near(repeatRecord, position))
                return Copy("Replay the repeated trial [E]", "ﺭﺮﻜﻤﻟﺍ ﺭﺎﺒﺘﺧﻻﺍ ﺪﻋﺃ");
            if (beat == Beat.Memories && !sawShizuka && Near(shizuka, position))
                return Copy("Remember Shizuka  [E]", "ﺎﻛﻭﺰﻴﺷ ﺮﻛﺬﺗ");
            if (beat == Beat.Memories && !sawYuki && Near(yuki, position))
                return Copy("Remember Yuki  [E]", "ﻲﻛﻮﻳ ﺮﻛﺬﺗ");
            return "";
        }

        private static bool Near(Transform target, Vector3 position)
        {
            var delta = target.position - position;
            return Mathf.Abs(delta.y) < 0.75f && new Vector2(delta.x, delta.z).sqrMagnitude < 1.65f * 1.65f;
        }

        internal void Interact(Room01Player player)
        {
            if (Action(player.transform.position).Length == 0) return;
            actor = player;
            switch (beat)
            {
                case Beat.Approach:
                    recognitionLine = 0;
                    player.FaceRouteFocus(kinja.position);
                    SetBeat(Beat.Recognition);
                    break;
                case Beat.Memories:
                    if (overloadRecord != null && Near(overloadRecord, player.transform.position))
                    {
                        fragments.Show(3);
                        return;
                    }
                    if (repeatRecord != null && Near(repeatRecord, player.transform.position))
                    {
                        fragments.Show(4);
                        return;
                    }
                    SetBeat(!sawShizuka && Near(shizuka, player.transform.position) ? Beat.Shizuka : Beat.Yuki);
                    break;
            }
        }

        public void Advance()
        {
            if (!IsReading || actor == null) return;
            switch (beat)
            {
                case Beat.Recognition:
                    if (++recognitionLine == Recognition.Length) SetBeat(Beat.Memories);
                    else Present();
                    break;
                case Beat.Shizuka:
                case Beat.Yuki:
                    if (beat == Beat.Shizuka) sawShizuka = true;
                    else sawYuki = true;
                    SetBeat(sawShizuka && sawYuki ? Beat.Refusal : Beat.Memories);
                    break;
                case Beat.Refusal:
                    ResolveUltimatum(0);
                    break;
                case Beat.Resistance:
                    if (!actor.TrySaveExamination())
                    {
                        line.text = Copy("Could not save the examination. Try again.", ".ﺍﺩﺪﺠﻣ ﻝﻭﺎﺣ .ﺺﺤﻔﻟﺍ ﻆﻔﺣ ﺭﺬﻌﺗ");
                        return;
                    }
                    fragments?.End();
                    SetBeat(Beat.Manifested);
                    actor.ReturnToSafePoint(AfterTrial,
                        Copy("A presence gathers near the altar.", ".ﺢﺑﺬﻤﻟﺍ ﺏﺮﻗ ﺭﻮﻀﺣ ﻞﻜﺸﺘﻳ"));
                    break;
            }
        }

        public void ResolveUltimatum(int target)
        {
            if (beat != Beat.Refusal || !IsReading || target < 0 || target > 2 || Time.timeScale <= 0f) return;
            visionTarget = target;
            SetBeat(Beat.Resistance);
            fragments?.Show(6, true);
        }

        internal void Cancel()
        {
            fragments?.End();
            if (!IsReading) return;
            sawShizuka = sawYuki = false;
            SetBeat(Beat.Approach);
        }

        public void CancelReading()
        {
            if (IsReading) actor.CancelExamination();
        }

        public void ReviewMemories()
        {
            if (beat != Beat.Refusal) return;
            sawShizuka = false;
            sawYuki = false;
            SetBeat(Beat.Memories);
        }

        private void SetBeat(Beat value)
        {
            beat = value;
            if (beat == Beat.Refusal) choiceRemaining = ChoiceTime;
            shizukaSignal.enabled = yukiSignal.enabled = value >= Beat.Memories && value < Beat.Manifested;
            shizukaSignal.color = sawShizuka ? Read : Unread;
            yukiSignal.color = sawYuki ? Read : Unread;
            shizukaPlate.SetActive(shizukaSignal.enabled && !sawShizuka);
            yukiPlate.SetActive(yukiSignal.enabled && !sawYuki);
            altarLight.enabled = Confronted;
            Present();
        }

        private void Present()
        {
            var reading = beat == Beat.Recognition || (beat >= Beat.Shizuka && beat <= Beat.Resistance);
            var wasReading = IsReading;
            if (wasReading != reading)
            {
                panel.SetActive(reading);
                actor?.HoldForExamination(reading);
                if (!reading && EventSystem.current != null) EventSystem.current.SetSelectedGameObject(null);
            }
            if (!reading) return;

            scrim.color = new Color(0.015f, 0.023f, 0.053f, beat == Beat.Recognition ? 0.08f : 0.22f);
            var primary = Copy("Continue", "ﻊﺑﺎﺗ");
            Texture2D still = null;
            switch (beat)
            {
                case Beat.Recognition:
                    speaker.text = recognitionLine == 0 || recognitionLine == 3 ? Copy("Echo", "ﻮﻜﻳﺇ") : Copy("Kinja", "ﺎﺠﻨﻴﻛ");
                    line.text = Copy(Recognition[recognitionLine], RecognitionArabic[recognitionLine]);
                    break;
                case Beat.Shizuka:
                    speaker.text = Copy("Shizuka", "ﺎﻛﻭﺰﻴﺷ");
                    line.text = Copy("Do not leave us.", ".ﺎﻨﻛﺮﺘﺗ ﻻ");
                    still = shizukaStill;
                    break;
                case Beat.Yuki:
                    speaker.text = Copy("Yuki", "ﻲﻛﻮﻳ");
                    line.text = Copy("Echo…", "…ﻮﻜﻳﺇ");
                    still = yukiStill;
                    break;
                case Beat.Refusal:
                    speaker.text = Copy("Kinja", "ﺎﺠﻨﻴﻛ");
                    line.text = Copy("Choose who dies. If you wait, I will take both.",
                        ".ﻦﻴﻨﺛﻻﺍ ﺬﺧﺂﺳ ،ﺕﺩﺩﺮﺗ ﺍﺫﺇ .ﺕﻮﻤﻳ ﻦﻣ ﺮﺘﺧﺍ");
                    primary = Copy("Refuse", "ﺾﻓﺭﺍ");
                    break;
                case Beat.Resistance:
                    speaker.text = Copy("At the bottom", "ﻉﺎﻘﻟﺍ ﻲﻓ");
                    line.text = visionTarget switch
                    {
                        1 => Copy("Shizuka…! I can still hear you under the water.", ".ﺀﺎﻤﻟﺍ ﺖﺤﺗ ﻚﻌﻤﺳﺃ ﻝﺍﺯﺃ ﺎﻣ !…ﺎﻛﻭﺰﻴﺷ"),
                        2 => Copy("Yuki…! Don't let the voice disappear.", ".ﻲﻔﺘﺨﻳ ﺕﻮﺼﻟﺍ ﻲﻋﺪﺗ ﻻ !…ﻲﻛﻮﻳ"),
                        _ => Copy("I heard both of them. Then the room went under.", ".ﺔﻓﺮﻐﻟﺍ ﺖﻗﺮﻏ ﻢﺛ .ﺎﻤﻬﻴﻠﻛ ﺖﻌﻤﺳ"),
                    };
                    primary = Copy("Try to reach the light", "ﺩﻮﻌﺼﻟﺍ ﻝﻭﺎﺣ");
                    break;
            }

            memory.texture = still;
            memory.gameObject.SetActive(still != null);
            if (still != null) memoryAspect.aspectRatio = (float)still.width / still.height;
            advance.GetComponentInChildren<Text>().text = primary;
            close.GetComponentInChildren<Text>().text = Copy("Leave trial", "ﺭﺎﺒﺘﺧﻻﺍ ﺭﺩﺎﻏ");
            var choosing = beat == Beat.Refusal;
            line.rectTransform.anchorMin = new Vector2(0.06f, choosing ? 0.54f : 0.33f);
            line.rectTransform.anchorMax = new Vector2(0.94f, choosing ? 0.75f : 0.70f);
            chooseShizuka.gameObject.SetActive(choosing);
            chooseYuki.gameObject.SetActive(choosing);
            chooseShizuka.GetComponentInChildren<Text>(true).text = Copy("Shizuka", "ﺎﻛﻭﺰﻴﺷ");
            chooseYuki.GetComponentInChildren<Text>(true).text = Copy("Yuki", "ﻲﻛﻮﻳ");
            countdown.SetActive(choosing);
            alternative.gameObject.SetActive(choosing);
            alternative.GetComponentInChildren<Text>(true).text = Copy("Look at them again", "ﻯﺮﺧﺃ ﺓﺮﻣ ﺎﻤﻬﻴﻟﺇ ﺮﻈﻧﺍ");
            if (EventSystem.current != null) EventSystem.current.SetSelectedGameObject(advance.gameObject);
        }
    }
}
