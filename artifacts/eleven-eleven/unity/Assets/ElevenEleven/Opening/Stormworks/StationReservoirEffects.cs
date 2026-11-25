using UnityEngine;

namespace ElevenEleven.Opening
{
    public sealed class StationReservoirEffects : MonoBehaviour
    {
        [SerializeField] private ParticleSystem[] drift;
        [SerializeField] private ParticleSystem[] powered;
        [SerializeField] private ParticleSystem burst;
        [SerializeField] private Transform[] windMarkers;

        private static readonly int SurfaceClock = Shader.PropertyToID("_EchoSurfaceClock");
        private StormworksRoute route;
        private bool running;
        private int lastStage;

        private void Start()
        {
            route = GetComponentInParent<StormworksRoute>();
            lastStage = route.Stage;
        }

        private void Update()
        {
            var stage = route.Stage;
            if (ChapterSceneLink.ReducedMotion)
            {
                if (running) SetRunning(false);
                lastStage = stage;
                return;
            }
            if (Time.timeScale <= 0f) return;
            if (!running) SetRunning(true);

            var phase = Shader.GetGlobalFloat(SurfaceClock);
            var gust = Mathf.Sin(phase * 1.47f) + 0.30f * Mathf.Sin(phase * 3.19f);
            foreach (var marker in windMarkers)
                marker.localRotation = Quaternion.Euler(0f, 0f, 10f + gust * 12f);
            foreach (var system in drift)
            {
                var velocity = system.velocityOverLifetime;
                velocity.x = 0.22f + gust * 0.19f;
            }
            foreach (var system in powered)
            {
                var emission = system.emission;
                emission.enabled = stage >= 2;
            }
            if (lastStage == 1 && stage >= 2) burst.Emit(10);
            lastStage = stage;
        }

        private void SetRunning(bool enabled)
        {
            running = enabled;
            Apply(drift, enabled);
            Apply(powered, enabled);
            if (enabled) burst.Play();
            else
            {
                burst.Stop(false, ParticleSystemStopBehavior.StopEmittingAndClear);
                foreach (var marker in windMarkers) marker.localRotation = Quaternion.identity;
            }
        }

        private static void Apply(ParticleSystem[] systems, bool enabled)
        {
            foreach (var system in systems)
            {
                if (enabled) system.Play();
                else system.Stop(false, ParticleSystemStopBehavior.StopEmittingAndClear);
            }
        }
    }
}
