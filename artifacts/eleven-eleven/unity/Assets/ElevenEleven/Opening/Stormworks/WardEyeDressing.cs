using UnityEngine;

namespace ElevenEleven.Opening
{
    public sealed class WardEyeDressing : MonoBehaviour
    {
        private static readonly int TraceColor = Shader.PropertyToID("_TraceColor");
        [SerializeField] private Transform packet;
        [SerializeField] private GameObject wornCompress;
        [SerializeField] private Renderer flare;
        [SerializeField] private Light pulseLight;
        [SerializeField] private Transform wakeShot;
        [SerializeField] private SkinnedMeshRenderer wardBody;
        [SerializeField] private Mesh originalBody;
        [SerializeField] private Mesh fittedBody;
        [SerializeField] private Material originalMaterial;
        [SerializeField] private Material schoolAnimeMaterial;
        [SerializeField] private Material postPactHeadMaterial;
        [SerializeField] private GameObject postPactHead;

        private float glowRemaining;
        private MaterialPropertyBlock paint;

        internal Transform WakeShot => glowRemaining > .14f && !ChapterSceneLink.ReducedMotion ? wakeShot : null;

        internal bool InReach(Vector3 feet) => packet && Vector3.Distance(feet + Vector3.up * .70f, packet.position) <= 1.06f;

        internal void Present(bool awake, bool equipped, bool flash)
        {
            if (wardBody && originalBody && fittedBody)
            {
                wardBody.sharedMesh = awake ? fittedBody : originalBody;
                var suitMat = schoolAnimeMaterial ? schoolAnimeMaterial : originalMaterial;
                if (suitMat)
                {
                    wardBody.sharedMaterials = awake && fittedBody.subMeshCount > 1 && postPactHeadMaterial
                        ? new[] { suitMat, postPactHeadMaterial }
                        : new[] { originalMaterial ? originalMaterial : suitMat };
                }
            }
            if (postPactHead) postPactHead.SetActive(awake);
            if (packet) packet.gameObject.SetActive(awake && !equipped);
            if (wornCompress) wornCompress.SetActive(awake && equipped);
            glowRemaining = awake && !equipped && flash ? 1.85f : 0f;
            if (flare) flare.gameObject.SetActive(glowRemaining > 0f);
            Paint(glowRemaining > 0f ? 1f : 0f);
        }

        private void OnDisable()
        {
            glowRemaining = 0f;
            if (flare) flare.gameObject.SetActive(false);
            if (pulseLight) pulseLight.enabled = false;
            Paint(0f);
        }

        private void LateUpdate()
        {
            if (!flare || !flare.gameObject.activeSelf) return;
            glowRemaining = Mathf.Max(0f, glowRemaining - Time.unscaledDeltaTime);
            var level = ChapterSceneLink.ReducedMotion ? .28f : Mathf.Sin(Mathf.Clamp01(glowRemaining / 1.85f) * Mathf.PI);
            if (glowRemaining <= 0f)
            {
                flare.gameObject.SetActive(false);
                Paint(0f);
                return;
            }
            Paint(level);
        }

        private void Paint(float level)
        {
            if (pulseLight)
            {
                var showLight = level > .01f && !ChapterSceneLink.ReducedMotion;
                pulseLight.enabled = showLight;
                if (showLight) pulseLight.intensity = level * .24f;
            }
            if (!flare) return;
            paint ??= new MaterialPropertyBlock();
            flare.GetPropertyBlock(paint);
            paint.SetColor(TraceColor, new Color(2.2f, .50f, 3.2f, 1f) * level);
            flare.SetPropertyBlock(paint);
        }
    }
}
