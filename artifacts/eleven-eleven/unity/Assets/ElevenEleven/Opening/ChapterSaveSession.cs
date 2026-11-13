using System;
using System.IO;
using UnityEngine;

namespace ElevenEleven.Opening
{
    internal static class ChapterSaveSession
    {
        private const string CheckpointName = "system_opening_v1.json";
        private static readonly string[] GodotProjectNames = { "11.11 â€” Echo Network", "11.11 — Echo Network" };
        private static Room01Checkpoint pending;

        internal static string SavePath
        {
            get
            {
                var directory = Application.persistentDataPath;
#if UNITY_EDITOR || ECHO_R10_PLAYER_PROBE
                var fixture = Environment.GetEnvironmentVariable("ECHO_R02_FIXTURE_DIRECTORY");
                if (!string.IsNullOrWhiteSpace(fixture)) directory = fixture;
#endif
                return Path.Combine(directory, CheckpointName);
            }
        }

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
        private static void Reset() => pending = null;

        internal static Room01Checkpoint Read()
        {
            var path = SavePath;
            if (File.Exists(path) || File.Exists(path + ".bak")) return Woken(Room01Checkpoint.Load(path));
#if UNITY_EDITOR || ECHO_R10_PLAYER_PROBE
            var fixture = Environment.GetEnvironmentVariable("ECHO_R02_FIXTURE_DIRECTORY");
            if (!string.IsNullOrWhiteSpace(fixture))
                return Woken(Room01Checkpoint.Load(Path.Combine(fixture, "LegacyGodot", CheckpointName)));
#endif
            if (Application.platform != RuntimePlatform.WindowsEditor && Application.platform != RuntimePlatform.WindowsPlayer)
                return null;
            var root = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "Godot", "app_userdata");
            foreach (var name in GodotProjectNames)
            {
                var old = Woken(Room01Checkpoint.Load(Path.Combine(root, name, CheckpointName)));
                if (old != null) return old;
            }
            return null;
        }

        private static Room01Checkpoint Woken(Room01Checkpoint state) => state != null && state.Wake ? state : null;

        internal static void SetRestore(Room01Checkpoint state) => pending = state;

        internal static Room01Checkpoint TakeRestore()
        {
            var state = pending;
            pending = null;
            return state;
        }
    }
}
