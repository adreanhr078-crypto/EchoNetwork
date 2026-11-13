using System;
using System.IO;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace ElevenEleven.Editor
{
    internal static class R01DeviceCapture
    {
        public static void CaptureIfRequested(Transform player, Camera camera)
        {
            var directory = Environment.GetEnvironmentVariable("ECHO_R01_CAPTURE_DIRECTORY");
            if (string.IsNullOrEmpty(directory) || File.Exists(Path.Combine(directory, "room01-gameplay.png"))) return;
            if (SystemInfo.graphicsDeviceType == GraphicsDeviceType.Null)
                throw new InvalidOperationException("The R01 capture requires a graphics device.");
            Directory.CreateDirectory(directory);
            Capture(camera, Path.Combine(directory, "room01-gameplay.png"));
            var reviewObject = new GameObject("R01 identity evidence camera");
            try
            {
                var review = reviewObject.AddComponent<Camera>();
                review.CopyFrom(camera);
                review.enabled = false;
                review.transform.position = player.position + Vector3.up * 1.38f + player.forward * 1.9f;
                review.transform.LookAt(player.position + Vector3.up * 1.17f);
                review.fieldOfView = 43f;
                Capture(review, Path.Combine(directory, "room01-school-front.png"));
            }
            finally
            {
                UnityEngine.Object.DestroyImmediate(reviewObject);
            }
            Debug.Log($"R01_RENDERED_NORMAL_ENTRY device={SystemInfo.graphicsDeviceName} api={SystemInfo.graphicsDeviceType}");
        }

        internal static void Capture(Camera camera, string path)
        {
            const int width = 640;
            const int height = 360;
            var target = new RenderTexture(width, height, 24, RenderTextureFormat.ARGB32);
            var pixels = new Texture2D(width, height, TextureFormat.RGB24, false);
            var active = RenderTexture.active;
            try
            {
                target.Create();
                var request = new UniversalRenderPipeline.SingleCameraRequest { destination = target };
                if (!RenderPipeline.SupportsRenderRequest(camera, request))
                    throw new InvalidOperationException("The active render pipeline cannot capture this camera.");
                RenderPipeline.SubmitRenderRequest(camera, request);
                RenderTexture.active = target;
                pixels.ReadPixels(new Rect(0, 0, width, height), 0, 0);
                pixels.Apply();
                File.WriteAllBytes(path, pixels.EncodeToPNG());
            }
            finally
            {
                RenderTexture.active = active;
                target.Release();
                UnityEngine.Object.DestroyImmediate(target);
                UnityEngine.Object.DestroyImmediate(pixels);
            }
        }
    }
}
