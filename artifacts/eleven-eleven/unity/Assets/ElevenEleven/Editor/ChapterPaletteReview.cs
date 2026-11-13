using System;
using System.IO;
using System.Linq;
using ElevenEleven.Opening;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.UI;

namespace ElevenEleven.Editor
{
    internal static class ChapterPaletteReview
    {
        private const string Root = "Assets/ElevenEleven/Scenes/";
        private static readonly Color TitleTone = new Color(0.92f, 0.97f, 1f);
        private static readonly Vector3 CorridorPosition = new Vector3(-2.15f, 2.75f, 16.25f);
        private static readonly Color CorridorTone = new Color(0.96f, 0.68f, 0.40f);
        private const float CorridorIntensity = 5.4f;
        private const float CorridorRange = 7.1f;

        public static void Compare()
        {
            var tier = Environment.GetEnvironmentVariable("ECHO_R09_TIER");
            var output = Environment.GetEnvironmentVariable("ECHO_R09_CAPTURE_DIRECTORY");
            var quality = Array.IndexOf(QualitySettings.names, tier);
            if (!Application.isBatchMode || string.IsNullOrWhiteSpace(output) || Directory.Exists(output) ||
                quality < 0 || SystemInfo.graphicsDeviceType == GraphicsDeviceType.Null)
                throw new InvalidOperationException("An unused output folder and graphics quality tier are required.");
            Directory.CreateDirectory(output);
            QualitySettings.SetQualityLevel(quality, true);
            EditorApplication.delayCall += () => CaptureTier(tier, output);
        }

        private static void CaptureTier(string tier, string output)
        {
            try
            {
                var title = EditorSceneManager.OpenScene(Root + "ChapterTitle.unity");
                var canvas = title.GetRootGameObjects().Select(root => root.GetComponent<Canvas>()).Single(value => value != null);
                var poster = canvas.transform.Find("Title moon").GetComponent<RawImage>();
                var titleCamera = CreateCamera();
                titleCamera.cullingMask = 1 << canvas.gameObject.layer;
                canvas.renderMode = RenderMode.ScreenSpaceCamera;
                canvas.worldCamera = titleCamera;
                canvas.planeDistance = 1f;
                Canvas.ForceUpdateCanvases();
                Shot(titleCamera, output, "title-before");
                poster.color = TitleTone;
                Canvas.ForceUpdateCanvases();
                Shot(titleCamera, output, "title-after");

                var room = EditorSceneManager.OpenScene(Root + "ChapterRoom01.unity");
                var content = room.GetRootGameObjects().Single(root => root.name == "Room content");
                content.SetActive(true);
                var player = content.GetComponentInChildren<Room01Player>();
                var model = player.GetComponentInChildren<Animation>().gameObject;
                var idle = AssetDatabase.LoadAssetAtPath<AnimationClip>("Assets/ElevenEleven/Echo/Locomotion/SchoolIdle.anim");
                idle.SampleAnimation(model, 0.40f);
                var roomCamera = CreateCamera();
                roomCamera.farClipPlane = 42f;
                roomCamera.fieldOfView = 60f;
                var lights = content.GetComponentsInChildren<Light>();
                var bulkhead = lights.Single(value => value.name == "Bulkhead glow");
                var recovery = lights.Single(value => value.name == "Recovery glow");
                var candidateRecovery = (recovery.transform.position, recovery.color, recovery.intensity, recovery.range);
                recovery.transform.position = new Vector3(-2.5f, 3.8f, -3f);
                recovery.color = new Color(0.31f, 0.64f, 1f);
                recovery.intensity = 2.2f;
                recovery.range = 7f;
                FrameRoom(roomCamera, output, player.transform, "before");
                (recovery.transform.position, recovery.color, recovery.intensity, recovery.range) = candidateRecovery;
                ApplyCorridor(bulkhead);
                FrameRoom(roomCamera, output, player.transform, "after");
                Debug.Log($"R09_PALETTE_PASS tier={tier} pipeline={QualitySettings.renderPipeline.name} captures=6 device={SystemInfo.graphicsDeviceName}");
                EditorApplication.Exit(0);
            }
            catch (Exception error)
            {
                Debug.LogException(error);
                EditorApplication.Exit(1);
            }
        }

        public static void InstallAndTest()
        {
            if (!Application.isBatchMode) throw new InvalidOperationException("Use the isolated Unity batch project.");
            var title = EditorSceneManager.OpenScene(Root + "ChapterTitle.unity");
            var poster = title.GetRootGameObjects().Select(root => root.GetComponent<Canvas>()).Single(canvas => canvas != null)
                .transform.Find("Title moon").GetComponent<RawImage>();
            poster.color = TitleTone;
            EditorSceneManager.MarkSceneDirty(title);
            if (!EditorSceneManager.SaveScene(title)) throw new IOException("Unable to save title palette.");

            var room = EditorSceneManager.OpenScene(Root + "ChapterRoom01.unity");
            var content = room.GetRootGameObjects().Single(root => root.name == "Room content");
            ApplyCorridor(content.GetComponentsInChildren<Light>(true).Single(value => value.name == "Bulkhead glow"));
            EditorSceneManager.MarkSceneDirty(room);
            if (!EditorSceneManager.SaveScene(room)) throw new IOException("Unable to save room palette.");
            ChapterR01Smoke.Run();
        }

        private static void ApplyCorridor(Light light)
        {
            light.transform.position = CorridorPosition;
            light.color = CorridorTone;
            light.intensity = CorridorIntensity;
            light.range = CorridorRange;
        }

        private static void FrameRoom(Camera camera, string output, Transform player, string variant)
        {
            var focus = player.position + Vector3.up * 1.4f;
            var orbit = Quaternion.Euler(13f, 0, 0);
            camera.transform.SetPositionAndRotation(focus + orbit * Vector3.back * 3.6f, orbit);
            Shot(camera, output, $"wake-{variant}");
            camera.transform.position = new Vector3(1.35f, 1.88f, 10.0f);
            camera.transform.LookAt(new Vector3(0f, 2.0f, 18.7f));
            Shot(camera, output, $"corridor-{variant}");
        }

        private static Camera CreateCamera()
        {
            var camera = new GameObject("Palette capture camera").AddComponent<Camera>();
            camera.enabled = false;
            camera.clearFlags = CameraClearFlags.SolidColor;
            camera.backgroundColor = new Color(0.025f, 0.035f, 0.06f);
            return camera;
        }

        private static void Shot(Camera camera, string output, string name) =>
            R01DeviceCapture.Capture(camera, Path.Combine(output, name + ".png"));
    }
}
