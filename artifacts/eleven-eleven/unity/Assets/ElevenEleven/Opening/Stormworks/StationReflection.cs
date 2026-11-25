using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace ElevenEleven.Opening
{
    public sealed class StationReflection : MonoBehaviour
    {
        [SerializeField] private MeshRenderer surface;
        [SerializeField] private int horizontalPixels = 672;
        [SerializeField] private Transform liveAvatar;
        [SerializeField] private GameObject alternateAvatar;

        private Renderer[] liveRenderers;
        private Renderer[] alternateRenderers;
        private bool[] previousVisibility;
        private float mirageClock = float.PositiveInfinity;
        private Transform mirrorHead;
        private Transform wingRoot;
        private Quaternion headRest;
        private Quaternion wingRest;
        private const float RevealAt = 1.35f;
        private const float ReturnAt = 4.6f;
        private const float SceneEnd = 5.7f;
        internal float MirageElapsed => mirageClock;
        internal bool MirageSequenceActive => alternateAvatar != null && MirageElapsed < SceneEnd;
        internal bool MirageActive => MirageSequenceActive && MirageElapsed >= RevealAt && MirageElapsed < ReturnAt;
        private static readonly int Fracture = Shader.PropertyToID("_Fracture");

        private void Awake()
        {
            if (alternateAvatar == null || liveAvatar == null) return;
            liveRenderers = liveAvatar.GetComponentsInChildren<Renderer>(true);
            alternateRenderers = alternateAvatar.GetComponentsInChildren<Renderer>(true);
            previousVisibility = new bool[liveRenderers.Length];
            foreach (var mesh in alternateRenderers) mesh.forceRenderingOff = true;
            foreach (var joint in alternateAvatar.GetComponentsInChildren<Transform>())
            {
                if (joint.name.EndsWith(":Head", System.StringComparison.Ordinal)) mirrorHead = joint;
                if (wingRoot == null && joint.name.StartsWith("Wing", System.StringComparison.Ordinal) &&
                    joint.name.EndsWith("Left", System.StringComparison.Ordinal)) wingRoot = joint;
            }
            if (mirrorHead != null) headRest = mirrorHead.localRotation;
            if (wingRoot != null) wingRest = wingRoot.localRotation;
        }

        internal void RevealMirage()
        {
            if (alternateRenderers == null) return;
            mirageClock = 0f;
            nextRefresh = 0f;
        }

        internal void AdvanceMirage(float dt)
        {
            if (MirageSequenceActive) mirageClock += Mathf.Min(0.08f, dt);
        }

        internal void LookAway()
        {
            mirageClock = float.PositiveInfinity;
            nextRefresh = 0f;
        }
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
            var displayMirage = MirageActive && alternateRenderers != null;
            if (displayMirage)
            {
                alternateAvatar.transform.SetPositionAndRotation(liveAvatar.position, liveAvatar.rotation);
                if (!ChapterSceneLink.ReducedMotion)
                {
                    var t = MirageElapsed - RevealAt;
                    if (mirrorHead != null) mirrorHead.localRotation = headRest *
                        Quaternion.Euler(-5f * Mathf.SmoothStep(0f, 1f, t / 0.9f), -3.3f, 1.3f);
                    if (wingRoot != null) wingRoot.localRotation = wingRest *
                        Quaternion.Euler(0f, (1f - Mathf.SmoothStep(0f, 1f, t / 0.8f)) * 18f, 0f);
                }
                ReplaceReflectionAvatar(true);
            }
            surface.forceRenderingOff = true;
            try
            {
                RenderPipeline.SubmitRenderRequest(reflectionCamera, request);
            }
            finally
            {
                surface.forceRenderingOff = false;
                if (displayMirage) ReplaceReflectionAvatar(false);
            }

            properties.SetTexture(ReflectionMap, reflection);
            properties.SetFloat(ReflectionReady, 1f);
            var time = MirageElapsed;
            var distort = MirageSequenceActive && !ChapterSceneLink.ReducedMotion ?
                Mathf.Max(0f, 1f - Mathf.Abs(time - RevealAt) * 1.65f,
                    1f - Mathf.Abs(time - ReturnAt) * 2.7f) : 0f;
            properties.SetFloat(Fracture, distort);
            surface.SetPropertyBlock(properties);
        }

        private void ReplaceReflectionAvatar(bool replace)
        {
            for (var index = 0; index < liveRenderers.Length; index++)
            {
                if (replace) previousVisibility[index] = liveRenderers[index].forceRenderingOff;
                liveRenderers[index].forceRenderingOff = replace || previousVisibility[index];
            }
            foreach (var mesh in alternateRenderers) mesh.forceRenderingOff = !replace;
        }

        private void EnsureCamera()
        {
            var width = Mathf.Clamp(horizontalPixels, 512, 1280);
            var height = Mathf.Clamp(Mathf.RoundToInt(width / observer.aspect), 240, 850);
            if (reflection != null && (reflection.width != width || reflection.height != height))
            {
                reflection.Release();
                Destroy(reflection);
                reflection = null;
            }

            if (reflection == null)
            {
                reflection = new RenderTexture(width, height, 24, RenderTextureFormat.DefaultHDR)
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
            data.renderShadows = alternateAvatar != null;
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
