using System;
using System.Collections;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace ElevenEleven.Opening
{
    public sealed class ChapterRoomStage : MonoBehaviour
    {
        [SerializeField] private GameObject content;
        [SerializeField] private Room01Player player;
        [SerializeField] private Camera gameplayCamera;
        [SerializeField] private AudioListener listener;
        [SerializeField] private GameObject hud;
        [SerializeField] private GameObject events;
        public bool IsReady { get; private set; }
        public bool IsFailed { get; private set; }
        public bool RenderWarmupCompleted { get; private set; }

        private void Awake()
        {
            if (!PreparedChapterRoom.Holds(gameObject.scene)) Activate();
        }

        internal void Activate()
        {
            if (!content.activeSelf)
            {
                content.SetActive(true);
                return;
            }

            gameplayCamera.enabled = true;
            listener.enabled = true;
            hud.SetActive(true);
            events.SetActive(true);
            player.ReleaseFromStaging();
        }

        internal void StartWarmup()
        {
            if (content.activeSelf) return;
            player.HoldForStaging();
            gameplayCamera.enabled = false;
            listener.enabled = false;
            hud.SetActive(false);
            events.SetActive(false);
            content.SetActive(true);
            StartCoroutine(Warm());
        }

        private IEnumerator Warm()
        {
            var deadline = Time.realtimeSinceStartupAsDouble + 2.0;
            while (!player.HasGroundContact && Time.realtimeSinceStartupAsDouble < deadline)
                yield return null;
            if (!player.HasGroundContact)
            {
                IsFailed = true;
                yield break;
            }

            if (SystemInfo.graphicsDeviceType == GraphicsDeviceType.Null)
            {
                IsReady = true;
                yield break;
            }

            RenderTexture target = null;
            try
            {
                target = RenderTexture.GetTemporary(320, 180, 24, RenderTextureFormat.ARGB32);
                var request = new UniversalRenderPipeline.SingleCameraRequest { destination = target };
                if (!RenderPipeline.SupportsRenderRequest(gameplayCamera, request))
                {
                    IsFailed = true;
                }
                else
                {
                    RenderPipeline.SubmitRenderRequest(gameplayCamera, request);
                    RenderWarmupCompleted = true;
                    IsReady = true;
                }
            }
            catch (Exception error)
            {
                IsFailed = true;
                Debug.LogException(error, this);
            }
            finally
            {
                if (target != null) RenderTexture.ReleaseTemporary(target);
            }
        }
    }
}
