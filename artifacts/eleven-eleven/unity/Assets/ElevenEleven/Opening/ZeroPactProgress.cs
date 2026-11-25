using System;
using Newtonsoft.Json.Linq;

namespace ElevenEleven.Opening
{
    internal enum ZeroBeat { Unseen, Depth, Silence, Voice, Manifestation, Questions, Decision, Accepted }

    internal readonly struct ZeroPactProgress
    {
        private const int AllQuestions = 7;

        internal ZeroBeat Beat { get; }
        internal int Questions { get; }
        internal bool Deferred { get; }
        internal bool Accepted => Beat == ZeroBeat.Accepted;
        internal bool HeardAll => Questions == AllQuestions;

        private ZeroPactProgress(ZeroBeat beat, int questions, bool deferred)
        {
            Beat = beat;
            Questions = questions;
            Deferred = deferred;
        }

        internal ZeroPactProgress Open() => Beat == ZeroBeat.Unseen
            ? new ZeroPactProgress(ZeroBeat.Depth, 0, false)
            : new ZeroPactProgress(Beat, Questions, false);

        internal ZeroPactProgress Advance() =>
            Beat >= ZeroBeat.Depth && Beat <= ZeroBeat.Questions && (Beat < ZeroBeat.Questions || HeardAll)
                ? new ZeroPactProgress(Beat + 1, Questions, false)
                : this;

        internal ZeroPactProgress Ask(int index) => Beat == ZeroBeat.Questions && index >= 0 && index < 3
            ? new ZeroPactProgress(Beat, Questions | (1 << index), false)
            : this;

        internal ZeroPactProgress Defer() => Beat == ZeroBeat.Decision && !Deferred
            ? new ZeroPactProgress(Beat, Questions, true)
            : this;

        internal ZeroPactProgress Confirm() => Beat == ZeroBeat.Decision && !Deferred && HeardAll
            ? new ZeroPactProgress(ZeroBeat.Accepted, Questions, false)
            : this;

        internal bool IsValid(bool examined) =>
            Beat >= ZeroBeat.Unseen && Beat <= ZeroBeat.Accepted &&
            (examined || Beat == ZeroBeat.Unseen) &&
            Questions >= 0 && Questions <= AllQuestions &&
            (Beat >= ZeroBeat.Questions || Questions == 0) &&
            (Beat < ZeroBeat.Decision || HeardAll) &&
            (!Deferred || Beat == ZeroBeat.Decision);

        internal JObject ToJson() => new JObject
        {
            ["beat"] = (int)Beat,
            ["questions"] = Questions,
            ["deferred"] = Deferred,
        };

        internal static ZeroPactProgress Read(JObject milestones)
        {
            if (!milestones.TryGetValue("zero", out var token)) return default;
            if (!(token is JObject state) || state.Count != 3 ||
                state["beat"]?.Type != JTokenType.Integer || state["questions"]?.Type != JTokenType.Integer ||
                state["deferred"]?.Type != JTokenType.Boolean)
                throw new FormatException("Invalid Zero encounter checkpoint.");
            return new ZeroPactProgress((ZeroBeat)(int)state["beat"], (int)state["questions"], (bool)state["deferred"]);
        }
    }
}
