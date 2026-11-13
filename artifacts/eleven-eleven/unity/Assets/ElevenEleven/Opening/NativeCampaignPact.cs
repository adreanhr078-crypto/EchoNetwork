using System;
using System.Linq;
using Newtonsoft.Json.Linq;

namespace ElevenEleven.Opening
{
    public sealed class NativeCampaignPact
    {
        public const string Schema = "echo-sector11-campaign-v1";
        private static readonly string[] Events = { "specimen", "archive", "reactor", "decon", "mirror", "lab", "hospital" };
        private static readonly string[][] FlagNames =
        {
            new[] { "terminal_read" },
            new[] { "shard_shizuka", "shard_yuki", "shard_sector11", "archive_decoded" },
            new[] { "breaker_a_done", "breaker_b_done" },
            new[] { "override_done" },
            new[] { "mirror_inspected", "override_done" },
            new[] { "confrontation_done", "contract_done", "revenge_done", "wish_done" },
            new[] { "bed_awakened", "mark_revealed" },
        };

        private readonly string path;
        private JObject current;

        private NativeCampaignPact(string path, JObject current)
        {
            this.path = path;
            this.current = current;
        }

        public bool HasEarnedPact => Earned(current);
        public bool AwaitsConsent => Pending(current);

        public static NativeCampaignPact Load(string path)
        {
            var state = CheckpointFile.Read(path, IsValid) ?? CheckpointFile.Read(path + ".bak", IsValid);
            return new NativeCampaignPact(path, state ?? new JObject
            {
                ["schema"] = Schema, ["completed"] = new JArray(), ["flags"] = new JObject(),
            });
        }

        public bool Confirm()
        {
            return Apply(state =>
            {
                if (!Pending(state)) return null;
                var next = (JObject)state.DeepClone();
                next["flags"]["lab"]["contract_done"] = true;
                var cursor = Cursor(next);
                cursor["step"] = 6;
                cursor["answer"] = -1;
                cursor["deferred"] = false;
                next["presentation"]["beat"] = "accepted";
                next["presentation"]["elapsed"] = 0;
                return next;
            });
        }

        public bool Defer() => SetDeferred(true, Pending);

        public bool Reopen() => SetDeferred(false, state => !Earned(state) && Flag(Cursor(state), "deferred"));

        private bool SetDeferred(bool value, Func<JObject, bool> allowed)
        {
            return Apply(state =>
            {
                if (!allowed(state)) return null;
                var next = (JObject)state.DeepClone();
                Cursor(next)["deferred"] = value;
                return next;
            });
        }

        private bool Apply(Func<JObject, JObject> transition)
        {
            lock (CheckpointFile.WriteLock)
            {
                var state = CheckpointFile.Read(path, IsValid) ?? CheckpointFile.Read(path + ".bak", IsValid);
                if (state == null) return false;
                current = state;
                var next = transition(state);
                if (next == null || !CheckpointFile.Save(path, next, IsValid)) return false;
                current = next;
                return true;
            }
        }

        private static JObject Cursor(JObject state) => state["presentation"]?["encounter"] as JObject;
        private static bool Earned(JObject state) => Flag(state["flags"]["lab"], "contract_done");
        private static bool Pending(JObject state) => !Earned(state) && Cursor(state) is JObject cursor &&
            Whole(cursor["step"], 5, 5) && !Flag(cursor, "deferred");

        internal static bool IsValid(JObject json)
        {
            if (json["schema"]?.Type != JTokenType.String || (string)json["schema"] != Schema ||
                !(json["completed"] is JArray completed) || completed.Count > Events.Length ||
                !(json["flags"] is JObject flags) || (json.Count != 3 && (json.Count != 4 || json["presentation"] == null)))
                return false;
            for (var index = 0; index < completed.Count; index++)
            {
                if (completed[index].Type != JTokenType.String || (string)completed[index] != Events[index] ||
                    !FlagNames[index].All(name => Flag(flags[Events[index]], name)))
                    return false;
            }
            foreach (var room in flags.Properties())
            {
                var index = Array.IndexOf(Events, room.Name);
                if (index < 0 || index > completed.Count || !(room.Value is JObject states) ||
                    states.Properties().Any(flag => !FlagNames[index].Contains(flag.Name) || flag.Value.Type != JTokenType.Boolean))
                    return false;
            }
            var archive = flags["archive"];
            var lab = flags["lab"];
            var hospital = flags["hospital"];
            if ((Flag(archive, "archive_decoded") && !FlagNames[1].All(name => Flag(archive, name))) ||
                (Flag(hospital, "mark_revealed") && !Flag(hospital, "bed_awakened")))
                return false;
            for (var index = 1; index < FlagNames[5].Length; index++)
                if (Flag(lab, FlagNames[5][index]) && !Flag(lab, FlagNames[5][index - 1])) return false;

            if (json["presentation"] == null) return true;
            if (!(json["presentation"] is JObject presentation) || completed.Count != 5 ||
                (presentation.Count != 2 && (presentation.Count != 3 || presentation["encounter"] == null)) ||
                !Number(presentation["elapsed"], 0, 90) || !Flag(lab, "confrontation_done") || Flag(lab, "wish_done"))
                return false;
            if (presentation["beat"]?.Type != JTokenType.String) return false;
            var beat = (string)presentation["beat"];
            var accepted = Flag(lab, "contract_done");
            if (presentation["encounter"] != null &&
                ((beat != "pact" && beat != "accepted") || !ValidateCursor(presentation["encounter"], accepted)))
                return false;
            return beat switch
            {
                "pact" => !accepted,
                "accepted" or "revenge" => accepted && !Flag(lab, "revenge_done"),
                "wish" => Flag(lab, "revenge_done"),
                _ => false,
            };
        }

        private static bool ValidateCursor(JToken token, bool accepted)
        {
            if (!(token is JObject cursor) || (cursor.Count != 4 && (cursor.Count != 5 || cursor["answer"] == null)) ||
                !Whole(cursor["step"], 0, 8) || !Whole(cursor["questions"], 0, 7) ||
                cursor["deferred"]?.Type != JTokenType.Boolean || !(cursor["look"] is JArray look) ||
                look.Count != 2 || !Number(look[0], -0.5, 0.5) || !Number(look[1], -0.3, 0.3))
                return false;
            var step = (int)cursor["step"];
            var questions = (int)cursor["questions"];
            if (accepted != (step >= 6) || (step < 4 && questions != 0) || (step >= 5 && questions != 7))
                return false;
            if (cursor["answer"] != null)
            {
                if (!Whole(cursor["answer"], -1, 2)) return false;
                var answer = (int)cursor["answer"];
                if (answer >= 0 && (step != 4 || (questions & (1 << answer)) == 0)) return false;
            }
            return !Flag(cursor, "deferred") || (step == 5 && !accepted);
        }

        private static bool Flag(JToken source, string key) =>
            source is JObject value && value[key]?.Type == JTokenType.Boolean && (bool)value[key];

        private static bool Number(JToken value, double min, double max) =>
            (value?.Type == JTokenType.Integer || value?.Type == JTokenType.Float) &&
            (double)value >= min && (double)value <= max;

        private static bool Whole(JToken value, int min, int max) =>
            Number(value, min, max) && (double)value == Math.Floor((double)value);
    }
}
