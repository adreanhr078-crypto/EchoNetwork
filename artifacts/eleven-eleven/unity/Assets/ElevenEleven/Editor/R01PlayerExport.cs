using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEngine;
using UnityEngine.Rendering;

namespace ElevenEleven.Editor
{
    internal static class R01PlayerExport
    {
        public static void Run()
        {
            var output = Environment.GetEnvironmentVariable("ECHO_R01_EXPORT_PATH");
            if (!Application.isBatchMode || string.IsNullOrWhiteSpace(output) || !Path.IsPathRooted(output))
                throw new InvalidOperationException("An isolated batch build requires a full output path.");

            ChapterSceneBuilder.OpenRegisteredTitle();
            PlayerSettings.productName = "11.11";
            PlayerSettings.defaultScreenWidth = 1280;
            PlayerSettings.defaultScreenHeight = 720;
            PlayerSettings.fullScreenMode = FullScreenMode.Windowed;
            PlayerSettings.SetUseDefaultGraphicsAPIs(BuildTarget.StandaloneWindows64, false);
            PlayerSettings.SetGraphicsAPIs(BuildTarget.StandaloneWindows64, new[] { GraphicsDeviceType.Direct3D11 });
            var timing = Environment.GetEnvironmentVariable("ECHO_R03_BUILD") == "1";
            var r10 = Environment.GetEnvironmentVariable("ECHO_R10_BUILD");
            var defines = r10 switch
            {
                "verify" => new[] { "ECHO_R10_PLAYER_PROBE", "ECHO_R01_VERIFY_EXPORTED_PLAYER" },
                "clean" => Array.Empty<string>(),
                _ => new[] { timing ? "ECHO_R03_PLAYER_PROBE" : "ECHO_R01_VERIFY_EXPORTED_PLAYER" },
            };
            Directory.CreateDirectory(Path.GetDirectoryName(output));
            var report = BuildPipeline.BuildPlayer(new BuildPlayerOptions
            {
                scenes = EditorBuildSettings.scenes.Where(scene => scene.enabled).Select(scene => scene.path).ToArray(),
                locationPathName = output,
                target = BuildTarget.StandaloneWindows64,
                options = BuildOptions.StrictMode | BuildOptions.CompressWithLz4,
                extraScriptingDefines = defines,
            });
            var summary = report.summary;
            if (summary.result != BuildResult.Succeeded || summary.totalErrors != 0 || !File.Exists(output))
                throw new InvalidOperationException($"R01 Windows export failed: {summary.result}, {summary.totalErrors} errors.");

            Debug.Log($"{(r10 != null ? "R10" : timing ? "R03" : "R01")}_WINDOWS_EXPORT_PASS bytes={summary.totalSize} warnings={summary.totalWarnings}");
            EditorApplication.Exit(0);
        }
    }
}
