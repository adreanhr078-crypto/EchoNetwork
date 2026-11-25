#if ECHO_R10_PLAYER_PROBE
using System;
using System.Collections;
using System.IO;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.SceneManagement;
using Stopwatch = System.Diagnostics.Stopwatch;

namespace ElevenEleven.Opening
{
    internal sealed class ObservatoryWindowsProfile : MonoBehaviour
    {
        [Serializable]
        private sealed class ViewTiming
        {
            public string name;
            public int frames;
            public int cameraRenders;
            public double meanMs;
            public double p50Ms;
            public double p95Ms;
            public double p99Ms;
        }

        [Serializable]
        private sealed class Report
        {
            public string unity;
            public string graphicsDevice;
            public string graphicsApi;
            public string quality;
            public int width;
            public int height;
            public string method;
            public ViewTiming[] views;
        }

        private const int SampleCount = 300;
        private string reportPath;

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        private static void Begin()
        {
            var path = Environment.GetEnvironmentVariable("ECHO_OBSERVATORY_PROFILE");
            if (string.IsNullOrWhiteSpace(path)) return;
            if (string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("ECHO_R02_FIXTURE_DIRECTORY")))
            {
                Debug.LogError("Observatory profiling needs an isolated save directory.");
                Application.Quit(1);
                return;
            }

            var probe = new GameObject("Observatory Windows profile").AddComponent<ObservatoryWindowsProfile>();
            DontDestroyOnLoad(probe.gameObject);
            probe.reportPath = path;
            probe.StartCoroutine(probe.Run());
        }

        private IEnumerator Run()
        {
            Application.runInBackground = true;
            QualitySettings.vSyncCount = 0;
            Application.targetFrameRate = -1;
            ChapterSceneLink.ReducedMotion = false;
            ChapterSaveSession.SetRestore(new Room01Checkpoint
            {
                Wake = true, Clock = true, Photo = true, Memory = true, Terminal = true,
                Conduit = true, Ending = true, Frequency = 111, Phase = 45, Channel = 7,
                StationStage = StormworksRoute.LabRead
            });
            SceneManager.LoadScene("ChapterRoom01", LoadSceneMode.Single);
            yield return null;

            var observer = Camera.main;
            if (observer == null || SystemInfo.graphicsDeviceType == UnityEngine.Rendering.GraphicsDeviceType.Null ||
                FindFirstObjectByType<StationMemoryObservatory>() == null)
            {
                Debug.LogError("The observatory scene or its graphics device did not load in the Windows player.");
                Application.Quit(1);
                yield break;
            }
            var views = new (string name, Vector3 at, Vector3 look)[]
            {
                ("central", new Vector3(.68f,1.70f,42.7f), new Vector3(.40f,3.1f,65.7f)),
                ("east", new Vector3(15.34f,1.72f,43.7f), new Vector3(15f,2.70f,62f)),
                ("west", new Vector3(-15.24f,1.72f,41.7f), new Vector3(-15.7f,2.72f,56f)),
                ("security", new Vector3(15.1f,1.72f,81.45f), new Vector3(17.23f,1.91f,94.9f)),
                ("reactor", new Vector3(-34.6f,2.25f,148.6f), new Vector3(-35.5f,2.9f,172f))
            };
            var results = new ViewTiming[views.Length];
            var values = new double[SampleCount];
            const int width = 1280;
            const int height = 720;
            var target = RenderTexture.GetTemporary(width, height, 24, RenderTextureFormat.ARGB32);
            var readback = new Texture2D(1, 1, TextureFormat.RGBA32, false);
            var request = new UniversalRenderPipeline.SingleCameraRequest { destination = target };
            if (!RenderPipeline.SupportsRenderRequest(observer, request))
            {
                Debug.LogError("The Windows render pipeline does not support an offscreen camera request.");
                RenderTexture.ReleaseTemporary(target);
                Destroy(readback);
                Application.Quit(1);
                yield break;
            }

            try
            {
                for (var index = 0; index < views.Length; index++)
                {
                    var (name, at, look) = views[index];
                    var rotation = Quaternion.LookRotation(look - at);
                    for (var frame = 0; frame < 60; frame++)
                    {
                        yield return null;
                        observer.transform.SetPositionAndRotation(at, rotation);
                        Render(observer, request, readback);
                    }

                    double sum = 0;
                    for (var frame = 0; frame < values.Length; frame++)
                    {
                        yield return null;
                        observer.transform.SetPositionAndRotation(at, rotation);
                        var started = Stopwatch.GetTimestamp();
                        Render(observer, request, readback);
                        var milliseconds = (Stopwatch.GetTimestamp() - started) * 1000.0 / Stopwatch.Frequency;
                        values[frame] = milliseconds;
                        sum += milliseconds;
                    }
                    Array.Sort(values);
                    results[index] = new ViewTiming
                    {
                        name = name, frames = values.Length, cameraRenders = values.Length,
                        meanMs = sum / values.Length,
                        p50Ms = Percentile(values, .5), p95Ms = Percentile(values, .95), p99Ms = Percentile(values, .99)
                    };
                    R01WindowsSmoke.Capture(observer, Path.Combine(Path.GetDirectoryName(reportPath), $"Windows-{name}.png"));
                    Debug.Log($"ECHO_OBSERVATORY_PROFILE_VIEW {name} p50={results[index].p50Ms:F2} p95={results[index].p95Ms:F2}");
                }
            }
            finally
            {
                RenderTexture.ReleaseTemporary(target);
                Destroy(readback);
            }

            var report = new Report
            {
                unity = Application.unityVersion, graphicsDevice = SystemInfo.graphicsDeviceName,
                graphicsApi = SystemInfo.graphicsDeviceType.ToString(), quality = QualitySettings.names[QualitySettings.GetQualityLevel()],
                width = width, height = height, views = results,
                method = "URP offscreen camera render plus synchronous one-pixel GPU readback; 60 warm-up renders per view."
            };
            File.WriteAllText(reportPath, JsonUtility.ToJson(report, true));
            Application.Quit(0);
        }

        private static void Render(Camera camera, UniversalRenderPipeline.SingleCameraRequest request, Texture2D readback)
        {
            RenderPipeline.SubmitRenderRequest(camera, request);
            var active = RenderTexture.active;
            try
            {
                RenderTexture.active = request.destination;
                readback.ReadPixels(new Rect(0, 0, 1, 1), 0, 0, false);
            }
            finally
            {
                RenderTexture.active = active;
            }
        }

        private static double Percentile(double[] values, double fraction) =>
            values[(int)Math.Ceiling(values.Length * fraction) - 1];
    }
}
#endif
