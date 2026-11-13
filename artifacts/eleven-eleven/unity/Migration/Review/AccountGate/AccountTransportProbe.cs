using System;
using ElevenEleven.Opening;

internal static class AccountTransportProbe
{
    private static int count;

    public static void Main()
    {
        Check(ChapterAccountGate.ParseOrigin("https://account.example.org")?.Host == "account.example.org");
        Check(ChapterAccountGate.ParseOrigin("https://account.example.org:443/") != null);
        foreach (var invalid in new[] { "", "http://account.example.org", "https://me@account.example.org", "https://account.example.org/path",
            "https://account.example.org?x=1", "https://account.example.org#x", "https://account.example.org\\other" })
            Check(ChapterAccountGate.ParseOrigin(invalid) == null);

        var code = "Ab0_-" + new string('z', 38);
        Check(ChapterAccountGate.CleanCode(code) == code);
        Check(ChapterAccountGate.CleanCode(" \u2066" + code + "\u2069\n") == code);
        Check(ChapterAccountGate.CleanCode(code + "+") == null);
        Check(ChapterAccountGate.CleanCode(code.Substring(1)) == null);
        Check(ChapterAccountGate.CleanCode(code.Substring(0, 42) + "/") == null);
        Check(ChapterAccountGate.CleanCode(null) == null);

        const string receipt = "{\"scope\":\"native-chapter-entry\",\"entryConfirmed\":true,\"coverReceiptId\":\"local-test-fixture\"}";
        Check(ChapterAccountGate.IsConfirmed(receipt));
        Check(!ChapterAccountGate.IsConfirmed(receipt.Replace("true", "\"true\"")));
        Check(!ChapterAccountGate.IsConfirmed(receipt.Replace("true", "false")));
        Check(!ChapterAccountGate.IsConfirmed(receipt.Replace("native-chapter-entry", "other")));
        Check(!ChapterAccountGate.IsConfirmed(receipt.Replace("\"local-test-fixture\"", "42")));
        Check(!ChapterAccountGate.IsConfirmed(receipt.Replace("local-test-fixture", "")));
        Check(!ChapterAccountGate.IsConfirmed(receipt.Replace("true", "true,\"entryConfirmed\":true")));
        Check(!ChapterAccountGate.IsConfirmed("{}"));
        Check(!ChapterAccountGate.IsConfirmed("{broken"));
        Check(!ChapterAccountGate.IsConfirmed(null));
        Console.WriteLine("Account transport checks passed: " + count);
    }

    private static void Check(bool value)
    {
        if (!value) throw new InvalidOperationException("Failed account check " + (count + 1));
        count++;
    }
}
