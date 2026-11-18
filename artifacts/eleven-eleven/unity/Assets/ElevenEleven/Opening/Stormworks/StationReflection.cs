using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace ElevenEleven.Opening
{
    public sealed class StationReflection : MonoBehaviour
    {
        [SerializeField] private MeshRenderer surface;
        private static readonly int ReflectionMap = Shader.PropertyToID("_ReflectionMap");
        private static readonly int ReflectionReady = Shader.PropertyToID("_ReflectionReady");
        private Camera observer;
        private Camera reflectionCamera;
        private RenderTexture reflection;
        private MaterialPropertyBlock properties;
        private float nextRefresh;

        private void LateUpdate()
        {
            if (GraphicsSettings.currentRenderPipeline is not UniversalRenderPipelineAsset ||
                SystemInfo.graphicsDeviceType == GraphicsDeviceType.Null) return;
            if (observer == null) observer = Camera.main;
            if (observer == null || observer.orthographic || Time.unscaledTime < nextRefresh) return;
            // The Quad is rotated around Y. Its visible side faces into the room.
            var normal = -transform.forward;
            var displacement = observer.transform.position - transform.position;
            var distance = Vector3.Dot(displacement, normal);
            if (distance < 0.16f || displacement.sqrMagnitude > 19f * 19f) return;
            var view = observer.WorldToViewportPoint(transform.position);
            if (view.z <= 0f || view.x < -0.32f || view.x > 1.32f || view.y < -0.32f || view.y > 1.32f) return;
            nextRefresh = Time.unscaledTime + (ChapterSceneLink.ReducedMotion ? 0.20f : 0.070f);

            EnsureCamera();
            var flippedForward = Vector3.Reflect(observer.transform.forward, normal);
            var flippedUp = Vector3.Reflect(observer.transform.up, normal);
            reflectionCamera.transform.SetPositionAndRotation(observer.transform.position - 2f * distance * normal,
                Quaternion.LookRotation(flippedForward, flippedUp));
            reflectionCamera.fieldOfView = observer.fieldOfView;
            reflectionCamera.aspect = observer.aspect;
            reflectionCamera.nearClipPlane = observer.nearClipPlane;
            reflectionCamera.farClipPlane = Mathf.Min(46f, observer.farClipPlane);
            reflectionCamera.cullingMask = observer.cullingMask;
            reflectionCamera.ResetWorldToCameraMatrix();
            reflectionCamera.ResetProjectionMatrix();

            // A proper reflected camera has horizontally reversed screen coordinates.
            // Clip from just inside the glass so that its backing cannot cover the reflected room.
            var point = reflectionCamera.worldToCameraMatrix.MultiplyPoint(transform.position + normal * 0.011f);
            var direction = reflectionCamera.worldToCameraMatrix.MultiplyVector(normal);
            var clip = new Vector4(direction.x, direction.y, direction.z, -Vector3.Dot(point, direction));
            reflectionCamera.projectionMatrix = reflectionCamera.CalculateObliqueMatrix(clip);
            var request = new UniversalRenderPipeline.SingleCameraRequest { destination = reflection };
            surface.forceRenderingOff = true;
            try
            {
                RenderPipeline.SubmitRenderRequest(reflectionCamera, request);
            }
            finally
            {
                surface.forceRenderingOff = false;
            }

            properties.SetTexture(ReflectionMap, reflection);
            properties.SetFloat(ReflectionReady, 1f);
            surface.SetPropertyBlock(properties);
        }

        private void EnsureCamera()
        {
            var height = Mathf.Clamp(Mathf.RoundToInt(672f / observer.aspect), 240, 512);
            if (reflection != null && reflection.height != height)
            {
                reflection.Release();
                Destroy(reflection);
                reflection = null;
            }

            if (reflection == null)
            {
                reflection = new RenderTexture(672, height, 24, RenderTextureFormat.DefaultHDR)
                {
                    name = "Surveillance Mirror",
                    filterMode = FilterMode.Bilinear,
                    wrapMode = TextureWrapMode.Clamp,
                };
                reflection.Create();
            }

            if (reflectionCamera != null) return;
            var capture = new GameObject("Surveillance Mirror Camera") { hideFlags = HideFlags.HideAndDontSave };
            reflectionCamera = capture.AddComponent<Camera>();
            reflectionCamera.enabled = false;
            reflectionCamera.clearFlags = CameraClearFlags.SolidColor;
            reflectionCamera.backgroundColor = new Color(0.025f, 0.043f, 0.11f);
            reflectionCamera.allowHDR = true;
            reflectionCamera.allowMSAA = false;
            reflectionCamera.useOcclusionCulling = false;
            var data = reflectionCamera.GetUniversalAdditionalCameraData();
            data.renderPostProcessing = false;
            data.renderShadows = false;
            properties = new MaterialPropertyBlock();
        }

        private void OnDisable()
        {
            if (reflectionCamera != null) Destroy(reflectionCamera.gameObject);
            if (reflection != null)
            {
                reflection.Release();
                Destroy(reflection);
            }
            if (surface != null) surface.SetPropertyBlock(null);
            reflectionCamera = null;
            reflection = null;
        }
    }
}
