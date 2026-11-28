using System.Collections;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace ElevenEleven.Opening
{
    internal sealed class OpeningWakeAudio : MonoBehaviour
    {
        private const float RoomTailDuration = 2.1f;
        private const float BedVolume = 0.82f;
        private AudioSource source;

        internal static OpeningWakeAudio Begin(Scene owner, AudioClip ambience, AudioClip foley, bool muted, bool paused)
        {
            var emitter = new GameObject("Opening wake audio");
            if (emitter.scene != owner) SceneManager.MoveGameObjectToScene(emitter, owner);
            var wake = emitter.AddComponent<OpeningWakeAudio>();
            wake.source = emitter.AddComponent<AudioSource>();
            wake.source.playOnAwake = false;
            wake.source.loop = true;
            wake.source.clip = ambience;
            wake.source.volume = BedVolume;
            wake.source.mute = muted;
            wake.source.dopplerLevel = 0f;
            wake.source.rolloffMode = AudioRolloffMode.Linear;
            wake.source.minDistance = 1.4f;
            wake.source.maxDistance = 7f;
            wake.source.Play();
            if (foley != null) wake.source.PlayOneShot(foley);
            wake.SetPaused(paused);
            return wake;
        }

        internal void SetMuted(bool muted) => source.mute = muted;

        internal void SetPaused(bool paused)
        {
            if (paused) source.Pause();
            else source.UnPause();
        }

        internal void EnterRoom(Scene scene, Vector3 entryPosition)
        {
            SceneManager.MoveGameObjectToScene(gameObject, scene);
            transform.position = entryPosition + Vector3.up;
            StartCoroutine(FadeRoomTail());
        }

        private IEnumerator FadeRoomTail()
        {
            var start = Time.unscaledTime;
            while (Time.unscaledTime - start < RoomTailDuration)
            {
                var progress = (Time.unscaledTime - start) / RoomTailDuration;
                source.mute = ChapterSceneLink.Muted;
                source.spatialBlend = Mathf.SmoothStep(0f, 1f, progress);
                source.volume = Mathf.SmoothStep(BedVolume, 0f, progress);
                yield return null;
            }
            Stop();
        }

        internal void Stop()
        {
            source.Stop();
            Destroy(gameObject);
        }
    }
}
