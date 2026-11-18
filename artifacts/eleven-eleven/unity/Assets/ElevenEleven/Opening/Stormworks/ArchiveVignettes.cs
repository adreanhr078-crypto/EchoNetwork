using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.UI;
using UnityEngine.Video;

namespace ElevenEleven.Opening
{
    public sealed class ArchiveVignettes : MonoBehaviour
    {
        [SerializeField] private RawImage image;
        [SerializeField] private VideoPlayer player;
        [SerializeField] private VideoClip[] clips;
        [SerializeField] private Texture2D[] stills;
        [SerializeField] private AudioSource ambience;
        private RenderTexture target;
        private float remaining;
        private int current;
        private bool decoderStarted;
        private bool waitingForFrame;
        private float prepareRemaining;
        internal bool Active => remaining > 0f;

        internal void Show(int index)
        {
            if (index < 0 || index >= clips.Length) return;
            End();
            current = index;
            remaining = ChapterSceneLink.ReducedMotion ? 2.5f : 3.8f;
            image.texture = stills[current];
            image.gameObject.SetActive(true);
            if (!ChapterSceneLink.Muted && SystemInfo.graphicsDeviceType != GraphicsDeviceType.Null) ambience.Play();
            if (ChapterSceneLink.ReducedMotion || SystemInfo.graphicsDeviceType == GraphicsDeviceType.Null) return;
            if (target == null)
            {
                // Memories occupy the center of the HUD. Decode at its presentation size.
                target = new RenderTexture(768, 432, 0, RenderTextureFormat.ARGB32) { name = "Archive memory frame" };
                target.Create();
            }

            waitingForFrame = true;
            prepareRemaining = 5f;
            player.targetTexture = target;
            player.clip = clips[index];
            player.Prepare();
        }

        internal void Advance(float dt)
        {
            if (!Active) return;
            ambience.mute = ChapterSceneLink.Muted;
            if (ChapterSceneLink.ReducedMotion)
            {
                if (waitingForFrame || decoderStarted)
                {
                    player.Stop();
                    waitingForFrame = false;
                    decoderStarted = false;
                    remaining = Mathf.Min(remaining, 2.5f);
                }

                image.texture = stills[current];
            }
            else if (waitingForFrame)
            {
                if (!decoderStarted && player.isPrepared)
                {
                    player.Play();
                    decoderStarted = true;
                }

                if (decoderStarted && player.frame >= 1)
                {
                    image.texture = target;
                    waitingForFrame = false;
                }
                else
                {
                    prepareRemaining -= dt;
                    if (prepareRemaining > 0f) return;
                    player.Stop();
                    waitingForFrame = false;
                    decoderStarted = false;
                    remaining = 1.65f;
                }
            }

            remaining -= dt;
            if (remaining <= 0f) End();
        }

        internal void End()
        {
            remaining = 0f;
            waitingForFrame = false;
            decoderStarted = false;
            if (player != null) player.Stop();
            if (ambience != null) ambience.Stop();
            if (image != null) image.gameObject.SetActive(false);
        }

        private void OnDisable()
        {
            End();
            if (player != null) player.targetTexture = null;
            if (target == null) return;
            target.Release();
            Destroy(target);
            target = null;
        }
    }
}

