using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEngine;

namespace ElevenEleven.Editor
{
    internal static class EntryWindowsBuild
    {
        public static void Run()
        {
            var output = Environment.GetEnvironmentVariable("ECHO_ENTRY_EXPORT_PATH");
            if (!Application.isBatchMode || !Path.IsPathRooted(output))
                throw new InvalidOperationException("Use batch mode and supply the absolute build path.");

            if (Environment.GetEnvironmentVariable("ECHO_ENTRY_ROOM") == "1")
                ChapterSceneBuilder.RebuildRoom();
            if (Environment.GetEnvironmentVariable("ECHO_ENTRY_REBUILD") == "1") ChapterSceneBuilder.RebuildEntry();
            else ChapterSceneBuilder.OpenRegisteredTitle();
            var verify = Environment.GetEnvironmentVariable("ECHO_ENTRY_VERIFY") == "1";
            var report = BuildPipeline.BuildPlayer(new BuildPlayerOptions
            {
                scenes = EditorBuildSettings.scenes.Where(scene => scene.enabled).Select(scene => scene.path).ToArray(),
                locationPathName = output,
                target = BuildTarget.StandaloneWindows64,
                options = BuildOptions.StrictMode | BuildOptions.CompressWithLz4,
                extraScriptingDefines = verify ? new[] { "ECHO_R10_PLAYER_PROBE", "ECHO_R01_VERIFY_EXPORTED_PLAYER" } : Array.Empty<string>(),
            });
            var summary = report.summary;
            if (summary.result != BuildResult.Succeeded || summary.totalErrors != 0 || !File.Exists(output))
                throw new InvalidOperationException($"Windows export failed: {summary.result}, {summary.totalErrors} errors.");

            Debug.Log($"ENTRY_WINDOWS_BUILD_PASS bytes={summary.totalSize} warnings={summary.totalWarnings} verification={verify}");
            EditorApplication.Exit(0);
        }
    }
}
