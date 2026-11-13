namespace ElevenEleven.Opening
{
    internal static class AccountGateCopy
    {
        internal static string English(ChapterAccountGate.Copy value) => value switch
        {
            ChapterAccountGate.Copy.NoService => "Guest play is available.\nOnline sign-in requires a configured account service.",
            ChapterAccountGate.Copy.GoogleAvailable => "Play as a guest or link your account on the website.\nFacebook is unavailable.",
            ChapterAccountGate.Copy.BrowserInstructions => "Finish the cover puzzle on the website.\nCopy the connection code and paste it here.",
            ChapterAccountGate.Copy.InvalidCode => "Copy the 43-character connection code from the website.",
            ChapterAccountGate.Copy.Connecting => "Checking the connection code…",
            ChapterAccountGate.Copy.Rejected => "The connection could not be confirmed.\nCreate a new connection if the code expired or was used.",
            _ => "",
        };

        // uGUI uses visual-order text. Keep each fixed Arabic line in visual glyph order.
        internal static string Arabic(ChapterAccountGate.Copy value) => value switch
        {
            ChapterAccountGate.Copy.NoService => ".ﻒﻴﻀﻛ ﺐﻌﻠﻟﺍ ﻚﻨﻜﻤﻳ\n.ﺔﻣﺪﺨﻟﺍ ﺩﺍﺪﻋﺇ ﺝﺎﺘﺤﻳ ﺏﺎﺴﺤﻟﺍ ﻂﺑﺭ",
            ChapterAccountGate.Copy.GoogleAvailable => ".ﻊﻗﻮﻤﻟﺍ ﺮﺒﻋ ﻚﺑﺎﺴﺣ ﻂﺑﺭﺍ ﻭﺃ ﻒﻴﻀﻛ ﺐﻌﻟﺍ\n.ﺡﺎﺘﻣ ﺮﻴﻏ ﻙﻮﺒﺴﻴﻓ",
            ChapterAccountGate.Copy.BrowserInstructions => ".ﻊﻗﻮﻤﻟﺍ ﻲﻓ ﻑﻼﻐﻟﺍ ﺰﻐﻟ ﻞﻤﻛﺃ\n.ﺎﻨﻫ ﻪﻘﺼﻟﺍﻭ ﻂﺑﺮﻟﺍ ﺰﻣﺭ ﺦﺴﻧﺍ",
            ChapterAccountGate.Copy.InvalidCode => ".ﻊﻗﻮﻤﻟﺍ ﻦﻣ ﻼﻣﺎﻛ ﻂﺑﺮﻟﺍ ﺰﻣﺭ ﺦﺴﻧﺍ",
            ChapterAccountGate.Copy.Connecting => "…ﻂﺑﺮﻟﺍ ﺰﻣﺭ ﻦﻣ ﻖﻘﺤﺘﻟﺍ ﺭﺎﺟ",
            ChapterAccountGate.Copy.Rejected => ".ﻂﺑﺮﻟﺍ ﺪﻴﻛﺄﺗ ﺭﺬﻌﺗ\n.ﺰﻣﺮﻟﺍ ﺔﻴﺣﻼﺻ ﺖﻬﺘﻧﺍ ﺍﺫﺇ ﺍﺪﻳﺪﺟ ﻻﺎﺼﺗﺍ ﺊﺸﻧﺃ",
            _ => "",
        };

        internal static string Label(string name) => name switch
        {
            "Account heading" => "ﻝﻮﺧﺪﻟﺍ ﻞﻴﺠﺴﺗ",
            "Guest caption" => "ﻒﻴﺿ",
            "Paste caption" => "ﺰﻣﺮﻟﺍ ﻖﺼﻟ",
            "Renew caption" => "ﺪﻳﺪﺟ ﻝﺎﺼﺗﺍ",
            _ => null,
        };
    }
}
