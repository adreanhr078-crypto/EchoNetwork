using System;
using Newtonsoft.Json.Linq;

namespace ElevenEleven.Opening
{
    public sealed class Room01Checkpoint
    {
        public const string Schema = "echo-opening-local-v1";

        public bool Wake { get; set; }
        public bool Clock { get; set; }
        public bool Photo { get; set; }
        public bool Memory { get; set; }
        public bool Terminal { get; set; }
        public bool Conduit { get; set; }
        public bool Ending { get; set; }
        public int StationStage { get; set; }
        public int ArchiveFragments { get; set; }
        public int ReactorBreakers { get; set; }
        public double Frequency { get; set; } = 80;
        public double Phase { get; set; }
        public double Channel { get; set; } = 1;

        public static Room01Checkpoint Load(string path) =>
            Parse(CheckpointFile.Read(path, Validate) ?? CheckpointFile.Read(path + ".bak", Validate));

        public bool Save(string path) => IsValid() && CheckpointFile.Save(path, ToJson(), Validate);

        private static bool Validate(JObject json) => Parse(json) != null;

        private static Room01Checkpoint Parse(JObject json)
        {
            if (json == null || json["schema"]?.Type != JTokenType.String || (string)json["schema"] != Schema ||
                !(json["milestones"] is JObject flags) || !(json["terminal"] is JObject terminal))
                return null;
            var state = new Room01Checkpoint
            {
                Wake = ReadBool(flags, "wake"),
                Clock = ReadBool(flags, "clock"),
                Photo = ReadBool(flags, "photo"),
                Memory = ReadBool(flags, "memory"),
                Terminal = ReadBool(flags, "terminal"),
                Conduit = ReadBool(flags, "conduit"),
                Ending = ReadBool(flags, "ending"),
                StationStage = flags.TryGetValue("station", out var station)
                    ? station.Type == JTokenType.Integer ? (int)station : throw new FormatException("station")
                    : 0,
                ArchiveFragments = flags.TryGetValue("archive_fragments", out var fragments)
                    && fragments.Type == JTokenType.Integer ? (int)fragments : flags.ContainsKey("archive_fragments") ? -1 : 0,
                ReactorBreakers = flags.TryGetValue("reactor_breakers", out var breakers)
                    && breakers.Type == JTokenType.Integer ? (int)breakers : flags.ContainsKey("reactor_breakers") ? -1 : 0,
                Frequency = ReadNumber(terminal, "frequency"),
                Phase = ReadNumber(terminal, "phase"),
                Channel = ReadNumber(terminal, "harmonic"),
            };
            return state.IsValid() ? state : null;
        }

        private bool IsValid() =>
            (!Clock || Wake) && (!Photo || Clock) && (!Memory || Photo) &&
            (!(Terminal || Conduit) || Memory) && (!Ending || (Terminal && Conduit)) &&
            StationStage >= 0 && StationStage <= StormworksRoute.SurveillancePassed && (StationStage == 0 || Ending) &&
            ArchiveFragments >= 0 && ArchiveFragments <= StationArchiveWing.CompleteMask &&
            (StationStage >= StormworksRoute.SpecimenPassed || ArchiveFragments == 0) &&
            (StationStage < StormworksRoute.ArchiveDecoded || ArchiveFragments == StationArchiveWing.CompleteMask) &&
            ReactorBreakers >= 0 && ReactorBreakers <= StationReactorWing.Both &&
            (StationStage >= StormworksRoute.ArchivePassed || ReactorBreakers == 0) &&
            (StationStage < StormworksRoute.ReactorPassed || ReactorBreakers == StationReactorWing.Both) &&
            InRange(Frequency, 50, 150) && InRange(Phase, 0, 180) && InRange(Channel, 1, 10);

        private static bool InRange(double value, double minimum, double maximum) => value >= minimum && value <= maximum;

        private static bool ReadBool(JObject source, string name) =>
            source[name]?.Type == JTokenType.Boolean ? (bool)source[name] : throw new FormatException(name);

        private static double ReadNumber(JObject source, string name)
        {
            var type = source[name]?.Type;
            return type == JTokenType.Float || type == JTokenType.Integer ? (double)source[name] : throw new FormatException(name);
        }

        private JObject ToJson() => new JObject
        {
            ["schema"] = Schema,
            ["milestones"] = new JObject
            {
                ["wake"] = Wake, ["clock"] = Clock, ["photo"] = Photo, ["memory"] = Memory,
                ["terminal"] = Terminal, ["conduit"] = Conduit, ["ending"] = Ending, ["station"] = StationStage, ["archive_fragments"] = ArchiveFragments,
                ["reactor_breakers"] = ReactorBreakers,
            },
            ["terminal"] = new JObject { ["frequency"] = Frequency, ["phase"] = Phase, ["harmonic"] = Channel },
        };
    }
}
