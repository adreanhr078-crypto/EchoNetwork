using System;
using UnityEngine;

namespace ElevenEleven.Opening
{
    [DisallowMultipleComponent]
    public sealed class RoomUtilityEffects : MonoBehaviour
    {
        public enum Role { ConduitFault, ViewportRunoff, PurgePilot, PressureReturn }

        private static readonly int Phase = Shader.PropertyToID("_UtilityPhase");
        private static readonly int Load = Shader.PropertyToID("_UtilityLoad");
        private static readonly int Drip = Shader.PropertyToID("_UtilityDrip");
        private static readonly int Footstep = Shader.PropertyToID("_UtilityFootstep");
        private static readonly Color FaultColor = new Color(.34f, .61f, 1f);
        private static readonly Color PoweredColor = new Color(.14f, .86f, .63f);

        [SerializeField] private Role role;
        [SerializeField] private Room01Player observer;
        [SerializeField] private StormworksRoute route;
        [SerializeField] private float radius = 16f;
        [SerializeField] private Renderer[] surfaces = Array.Empty<Renderer>();
        [SerializeField] private ParticleSystem particles;
        [SerializeField] private Light spill;
        [SerializeField] private LineRenderer arc;
        [SerializeField] private LineRenderer halo;
        [SerializeField] private Vector3 arcSpan;
        [SerializeField] private Transform dripOutlet;
        [SerializeField] private Transform dripImpact;
        [SerializeField] private Vector2 wetHalfExtents;

        private readonly Vector3[] arcPoints = new Vector3[11];
        private MaterialPropertyBlock properties;
        private float elapsed;
        private float nextEvent = .55f;
        private float arcUntil;
        private float pressureLoad;
        private float paintedPhase = float.NaN;
        private float paintedLoad = float.NaN;
        private Vector3 previousPosition;
        private Vector3 lastFootprint;
        private Vector4 drip = new Vector4(0f, 0f, -10f, 0f);
        private Vector4 pendingDrip;
        private Vector4 footstep = new Vector4(0f, 0f, -10f, 0f);
        private bool effectsActive;
        private bool wasNearby;

        private void Awake()
        {
            properties = new MaterialPropertyBlock();
            previousPosition = observer ? observer.transform.position : transform.position;
            lastFootprint = previousPosition;
            pressureLoad = DesiredPressureLoad();
            SetArcs(false);
        }

        private void LateUpdate()
        {
            if (!observer) return;
            var position = observer.transform.position;
            var nearby = (position - transform.position).sqrMagnitude < radius * radius;
            var animate = nearby && !ChapterSceneLink.ReducedMotion;
            var paused = Time.timeScale <= 0f || observer.UtilityMotionPaused;
            var delta = paused ? 0f : Time.deltaTime;
            if (animate && effectsActive)
            {
                if (paused && particles.isPlaying) particles.Pause();
                else if (!paused && particles.isPaused) particles.Play();
            }
            if (animate && delta > 0f)
            {
                elapsed += delta;
                pressureLoad = Mathf.MoveTowards(pressureLoad, DesiredPressureLoad(), delta * 2.4f);
            }
            else if (!animate)
            {
                pressureLoad = DesiredPressureLoad();
            }

            switch (role)
            {
                case Role.ConduitFault:
                    PresentConduit(nearby, animate && delta > 0f, delta);
                    break;
                case Role.ViewportRunoff:
                case Role.PressureReturn:
                    PresentWater(position, animate, delta);
                    break;
                case Role.PurgePilot:
                    PresentPilot(nearby, animate, delta);
                    break;
            }

            wasNearby = nearby;
            previousPosition = position;
        }

        private float DesiredPressureLoad() => route && route.PressureIsSafe ? .22f : 1f;

        private void PresentConduit(bool nearby, bool advance, float delta)
        {
            var powered = observer.ConduitPowered;
            if (!nearby || powered || ChapterSceneLink.ReducedMotion)
            {
                SetArcs(false);
                StopParticles();
                arcUntil = 0f;
                nextEvent = elapsed + .55f;
                spill.enabled = nearby;
                spill.color = powered ? PoweredColor : FaultColor;
                spill.intensity = powered ? .7f : .32f;
                return;
            }

            if (!advance) return;
            if (elapsed >= nextEvent)
            {
                var interval = Mathf.PerlinNoise(elapsed * .52f, 3.21f);
                nextEvent = elapsed + Mathf.Lerp(1.05f, 2.6f, interval);
                arcUntil = elapsed + Mathf.Lerp(.15f, .36f, interval);
                if (!particles.isPlaying) particles.Play();
                particles.Emit(14 + Mathf.RoundToInt(interval * 10f));
                effectsActive = true;
            }

            var discharging = elapsed < arcUntil;
            SetArcs(discharging);
            if (discharging) DrawArc();
            var target = discharging ? Mathf.Lerp(1.6f, 3.8f, Mathf.PerlinNoise(elapsed * 41f, 7.5f)) : .32f;
            spill.enabled = true;
            spill.color = FaultColor;
            spill.intensity = Mathf.MoveTowards(spill.intensity, target, delta * 24f);
        }

        private void DrawArc()
        {
            var sample = Mathf.Floor(elapsed * 26f);
            for (var i = 0; i < arcPoints.Length; i++)
            {
                var fraction = i / (float)(arcPoints.Length - 1);
                var amplitude = Mathf.Sin(fraction * Mathf.PI) * .099f;
                var displacement = new Vector3(0f, Mathf.Sin(i * 14.37f + sample * 2.33f),
                    Mathf.Cos(i * 19.73f - sample * 2.67f));
                arcPoints[i] = arcSpan * fraction + displacement * amplitude;
            }

            arc.SetPositions(arcPoints);
            halo.SetPositions(arcPoints);
        }

        private void SetArcs(bool visible)
        {
            if (arc) arc.enabled = visible;
            if (halo) halo.enabled = visible;
        }

        private void PresentWater(Vector3 position, bool animate, float delta)
        {
            if (!animate)
            {
                StopParticles();
                drip.w = 0f;
                pendingDrip.w = 0f;
                footstep.w = 0f;
                nextEvent = elapsed + .34f;
            }
            else if (delta > 0f)
            {
                // Keep the last impact visible while the next drop is airborne.
                if (pendingDrip.w > 0f && elapsed >= pendingDrip.z)
                {
                    drip = pendingDrip;
                    pendingDrip.w = 0f;
                }

                var interval = role == Role.PressureReturn ? Mathf.Lerp(.68f, 1.12f, pressureLoad) : .72f;
                if (elapsed >= nextEvent)
                {
                    nextEvent = elapsed + interval;
                    var outlet = dripOutlet.position;
                    var impact = dripImpact.position;
                    var dropHeight = outlet.y - impact.y;
                    var fallTime = Mathf.Sqrt(Mathf.Max(.01f, 2f * dropHeight / Physics.gravity.magnitude));
                    var strength = role == Role.PressureReturn ? Mathf.Lerp(.9f, .45f, pressureLoad) : .7f;
                    pendingDrip = new Vector4(impact.x, impact.z, elapsed + fallTime, strength);
                    if (!particles.isPlaying) particles.Play();
                    particles.Emit(role == Role.PressureReturn && pressureLoad < .5f ? 4 : 2);
                    effectsActive = true;
                }

                var local = transform.InverseTransformPoint(position);
                var movement = position - previousPosition;
                var planarStep = new Vector2(movement.x, movement.z).sqrMagnitude;
                if (wasNearby && observer.HasGroundContact && Mathf.Abs(local.y) < .20f &&
                    Mathf.Abs(local.x) < wetHalfExtents.x && Mathf.Abs(local.z) < wetHalfExtents.y &&
                    planarStep > .04f * delta * delta && planarStep < .36f &&
                    elapsed - footstep.z >= .30f && (position - lastFootprint).sqrMagnitude > .10f)
                {
                    lastFootprint = position;
                    footstep = new Vector4(position.x, position.z, elapsed, 1f);
                }
            }

            PresentSurfaces(animate ? elapsed : 0f, pressureLoad);
        }

        private void PresentPilot(bool nearby, bool animate, float delta)
        {
            var flameLoad = Mathf.Lerp(.5f, 1f, pressureLoad);
            if (animate && !effectsActive && delta > 0f)
            {
                particles.Play();
                effectsActive = true;
            }
            else if (!animate) StopParticles();

            var flicker = animate ? Mathf.PerlinNoise(elapsed * 5.4f, .85f) : .55f;
            spill.enabled = nearby;
            spill.intensity = flameLoad * (.95f + .7f * flicker);
            PresentSurfaces(animate ? elapsed : 0f, nearby ? flameLoad : 0f);
        }

        private void PresentSurfaces(float phase, float load)
        {
            if (surfaces.Length == 0 || (paintedPhase == phase && paintedLoad == load)) return;
            paintedPhase = phase;
            paintedLoad = load;
            properties.SetFloat(Phase, phase);
            properties.SetFloat(Load, load);
            properties.SetVector(Drip, drip);
            properties.SetVector(Footstep, footstep);
            foreach (var surface in surfaces)
            {
                surface.enabled = load > 0f;
                surface.SetPropertyBlock(properties);
            }
        }

        private void StopParticles()
        {
            if (!effectsActive) return;
            particles.Stop(true, ParticleSystemStopBehavior.StopEmittingAndClear);
            effectsActive = false;
        }

        private void OnDisable()
        {
            SetArcs(false);
            StopParticles();
            if (spill) spill.enabled = false;
        }

#if UNITY_EDITOR
        public void Configure(Role effectRole, Room01Player player, StormworksRoute stationRoute,
            float activeRadius, Renderer[] effectSurfaces, ParticleSystem effectParticles, Light bounce = null,
            LineRenderer core = null, LineRenderer glow = null, Vector3 contactGap = default, Transform outlet = null,
            Transform impact = null, Vector2 wetBounds = default)
        {
            role = effectRole;
            observer = player;
            route = stationRoute;
            radius = activeRadius;
            surfaces = effectSurfaces;
            particles = effectParticles;
            spill = bounce;
            arc = core;
            halo = glow;
            arcSpan = contactGap;
            dripOutlet = outlet;
            dripImpact = impact;
            wetHalfExtents = wetBounds;
        }
#endif
    }
}
