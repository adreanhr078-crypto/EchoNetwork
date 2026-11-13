namespace ElevenEleven.Opening
{
    // Unity's legacy Text draws in visual order. The Arabic strings are pre-shaped
    // against the bundled Noto Sans Arabic font; the comments keep the source copy readable.
    internal static class EntryCopy
    {
        internal static bool Arabic { get; set; } = true;

        internal static string WakeTitle => Arabic ? "11:11  /  ﻡﺎﻈﻨﻟﺍ" : "11:11  /  SYSTEM";
        internal static string WakeMessage => Arabic ? ".ﺔﺑﺮﺠﺘﻟﺍ ﺖﺤﺠﻧ\n.ﻮﻜﻳﺇ ﺎﻳ ﻚﻴﻨﻴﻋ ﺢﺘﻓﺍ" : "Experiment complete.\nOpen your eyes, Echo.";
        internal static string Awaken => Arabic ? "ﻆﻘﻴﺘﺳﺍ" : "Awaken";

        internal static string Start => Arabic ? "ﺀﺪﺒﻠﻟ ﻂﻐﺿﺍ" : "Tap to Start"; // اضغط للبدء
        internal static string NewGame => Arabic ? "ﺓﺪﻳﺪﺟ ﺔﺒﻌﻟ" : "New game"; // لعبة جديدة
        internal static string Continue => Arabic ? "ﺔﻌﺑﺎﺘﻣ" : "Continue"; // متابعة
        internal static string Language => Arabic ? "English" : "ﺔﻴﺑﺮﻌﻟﺍ"; // English
        internal static string MotionOn => Arabic ? "ﺔﻠﻌﻔﻣ ﺔﻛﺮﺤﻟﺍ" : "Motion on"; // الحركة مفعلة
        internal static string MotionOff => Arabic ? "ﺔﻔﻗﻮﺘﻣ ﺔﻛﺮﺤﻟﺍ" : "Motion off"; // الحركة متوقفة
        internal static string SoundOn => Arabic ? "ﻞﻌﻔﻣ ﺕﻮﺼﻟﺍ" : "Sound on"; // الصوت مفعل
        internal static string SoundOff => Arabic ? "ﻡﻮﺘﻜﻣ ﺕﻮﺼﻟﺍ" : "Sound off"; // الصوت مكتوم
        internal static string CoverTitle => Arabic ? "ﺮﻛﺬﺘﺗ ﻥﺃ ﻞﺒﻗ\n…ﺙﺪﺣ ﺎﻣ" : "Before you remember\nwhat happened…"; // قبل أن تتذكر / ما حدث…
        internal static string CoverInstruction => Arabic ? "،ﻯﺮﺧﺃ ﻕﻮﻓ ﺎﻬﺘﻠﻓﺃﻭ ﺔﻌﻄﻗ ﺐﺤﺳﺍ\n.ﺎﻤﻬﻠﻳﺪﺒﺘﻟ ﻦﻴﺘﻌﻄﻗ ﺮﺘﺧﺍ ﻭﺃ" : "Drag a piece onto another,\nor select two to swap."; // اسحب قطعة وأفلتها فوق أخرى، / أو اختر قطعتين لتبديلهما.
        internal static string CoverWaiting => Arabic ? "ﻝﻭﻷﺍ ﺎﻬﻬﺟﻭ ﺓﺭﻮﺼﻠﻟ ﺪﻋﺃ" : "Restore the cover"; // أعد للصورة وجهها الأول
        internal static string CoverSelected => Arabic ? "ﺎﻬﻌﺿﻮﻣ ﺮﺘﺧﺍ .ﺓﺩﺪﺤﻣ ﺔﻌﻄﻗ" : "Choose a second piece"; // قطعة محددة. اختر موضعها
        internal static string CoverRestored => Arabic ? "…ﺓﺎﻨﻘﻟﺍ ﺢﺘﻔﻨﺗ .ﺓﺭﻮﺼﻟﺍ ﺖﻠﻤﺘﻛﺍ" : "Image restored. The channel opens…"; // اكتملت الصورة. تنفتح القناة…
        internal static string CoverReference => Arabic ? "ﺓﺭﻮﺼﻟﺍ ﺪﻫﺎﺷ" : "View reference"; // شاهد الصورة
        internal static string CoverBack => Arabic ? "ﻊﻄﻘﻟﺍ ﻰﻟﺇ ﺓﺩﻮﻌﻟﺍ" : "Return to pieces"; // العودة إلى القطع
        internal static string Undo => Arabic ? "ﻊﺟﺍﺮﺗ" : "Undo"; // تراجع
        internal static string Reset => Arabic ? "ﻂﻠﺨﻟﺍ ﺓﺩﺎﻋﺇ" : "Shuffle again"; // إعادة الخلط
        internal static string Pause => Arabic ? "ﺖﻗﺆﻣ ﻑﺎﻘﻳﺇ" : "Pause"; // إيقاف مؤقت
        internal static string Resume => Arabic ? "ﻑﺎﻨﺌﺘﺳﺍ" : "Resume"; // استئناف
        internal static string Skip => Arabic ? "ﺔﻄﻘﻠﻟﺍ ﻲﻄﺨﺗ" : "Skip shot"; // تخطي اللقطة
        internal static string Experiment => Arabic ? "؟ﺔﺑﺮﺠﺘﻟﺍ ﻩﺬﻫ ﺎﻣ" : "What is this experiment?"; // ما هذه التجربة؟
        internal static string Safety => Arabic ? "؟ﻥﺎﻣﻷﺍ ﻦﻋ ﺍﺫﺎﻣ" : "What about safety?"; // ماذا عن الأمان؟
        internal static string Ready => Arabic ? ".ﺪﻌﺘﺴﻣ ﺎﻧﺃ" : "I am ready."; // أنا مستعد.
        internal static string Questions => Arabic ? "ﺔﻠﺌﺳﻸﻟ ﺓﺩﻮﻌﻟﺍ" : "Back to questions"; // العودة للأسئلة
        internal static string EchoQuestion => Arabic ? "ﻮﻜﻳﺇ\n.ﺃﺪﺒﻧ ﻥﺃ ﻞﺒﻗ ﻝﺍﺆﺳ ﻱﺪﻟ" : "Echo\nI have a question before we begin."; // إيكو / لدي سؤال قبل أن نبدأ.
        internal static string FatherExperiment => Arabic ? "ﺏﻷﺍ\n.ﺎﺋﺩﺎﻫ ﻖﺑﺍ .ﺺﺤﻔﻟﺍ ﺀﺎﻨﺛﺃ ﺕﺍﺭﺎﺷﻹﺍ ﺐﻗﺍﺮﻨﺳ" : "Father\nWe will monitor the signals during the examination. Stay still."; // الأب / سنراقب الإشارات أثناء الفحص. ابق هادئا.
        internal static string FatherSafety => Arabic ? "ﺏﻷﺍ\n.ﺩﺎﺘﻌﻣ ﺮﻴﻏ ﺀﻲﺸﺑ ﺕﺮﻌﺷ ﻥﺇ ﺍﺭﻮﻓ ﻲﻧﺮﺒﺧﺃ" : "Father\nTell me immediately if anything feels unusual."; // الأب / أخبرني فورا إن شعرت بشيء غير معتاد.
    }
}
