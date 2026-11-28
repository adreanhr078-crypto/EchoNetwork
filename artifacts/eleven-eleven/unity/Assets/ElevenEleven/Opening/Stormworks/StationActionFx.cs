using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace ElevenEleven.Opening
{
    /// <summary>
    /// Synthesizes procedural SFX_ONLY action audio and renders pooled combat slashes,
    /// dodge trails, and landing/mantle particle bursts while respecting Muted and ReducedMotion.
    /// </summary>
    [DisallowMultipleComponent]
    public sealed class StationActionFx : MonoBehaviour
    {
        private AudioSource audioSource;
        private AudioClip rollSfx;
        private AudioClip dashSfx;
        private AudioClip mantleSfx;
        private AudioClip evadeSfx;
        private AudioClip[] slashSfx;
        private AudioClip impactSfx;
        private AudioClip finisherImpactSfx;

        private Material particleMat;
        private Material slashMat;
        private Texture2D radialTex;
        private Texture2D ribbonTex;
        private readonly ParticleSystem[] burstPool = new ParticleSystem[6];
        private int burstCursor;

        private LineRenderer slashArc;
        private float slashTimer;
        private float slashDuration = 0.24f;
        private int slashVariant;
        private Transform slashOrigin;

        private Animation hitStopAnim;
        private string hitStopClip;
        private float hitStopTimer;

        private static readonly Color VioletCore = new Color(0.86f, 0.56f, 1.45f, 1f);
        private static readonly Color CyanEdge = new Color(0.24f, 1.10f, 1.45f, 1f);
        private static readonly Color DustTint = new Color(0.72f, 0.80f, 0.88f, 0.55f);

        private void Awake()
        {
            audioSource = gameObject.AddComponent<AudioSource>();
            audioSource.playOnAwake = false;
            audioSource.spatialBlend = 0f;
            audioSource.dopplerLevel = 0f;
            audioSource.volume = 0.72f;

            SynthesizeAudioClips();
            BuildVisualPools();
        }

        private void OnDestroy()
        {
            DestroyClip(rollSfx);
            DestroyClip(dashSfx);
            DestroyClip(mantleSfx);
            DestroyClip(evadeSfx);
            DestroyClip(impactSfx);
            DestroyClip(finisherImpactSfx);
            if (slashSfx != null)
                foreach (var c in slashSfx) DestroyClip(c);
            if (particleMat) Destroy(particleMat);
            if (slashMat) Destroy(slashMat);
            if (radialTex) Destroy(radialTex);
            if (ribbonTex) Destroy(ribbonTex);
        }

        private static void DestroyClip(AudioClip clip)
        {
            if (clip) Destroy(clip);
        }

        private void Update()
        {
            if (hitStopTimer > 0f)
            {
                hitStopTimer = Mathf.Max(0f, hitStopTimer - Time.unscaledDeltaTime);
                if (hitStopTimer <= 0f && hitStopAnim && !string.IsNullOrEmpty(hitStopClip) && hitStopAnim[hitStopClip] != null)
                    hitStopAnim[hitStopClip].speed = 1f;
            }

            if (slashTimer > 0f && slashArc != null)
            {
                slashTimer = Mathf.Max(0f, slashTimer - Time.deltaTime);
                if (slashTimer <= 0f || ChapterSceneLink.ReducedMotion)
                {
                    slashArc.enabled = false;
                }
                else
                {
                    UpdateSlashArc(1f - slashTimer / Mathf.Max(0.01f, slashDuration));
                }
            }
        }

        internal void PlayRoll(Vector3 worldPos)
        {
            PlaySfx(rollSfx, 0.62f);
            SpawnBurst(worldPos + Vector3.up * 0.25f, DustTint, 10, 1.4f, 0.28f);
        }

        internal void PlayShadowDash(Vector3 worldPos)
        {
            PlaySfx(dashSfx, 0.76f);
            SpawnBurst(worldPos + Vector3.up * 0.85f, VioletCore, 18, 2.8f, 0.34f);
        }

        internal void PlayMantle(Vector3 worldPos)
        {
            PlaySfx(mantleSfx, 0.65f);
            SpawnBurst(worldPos + Vector3.up * 0.6f, DustTint, 9, 1.3f, 0.25f);
        }

        internal void PlayEvade(Vector3 worldPos)
        {
            PlaySfx(evadeSfx, 0.75f);
            SpawnBurst(worldPos + Vector3.up * 0.9f, CyanEdge, 22, 3.4f, 0.35f);
        }

        internal void PlaySlash(Transform avatar, int comboIndex, Animation anim, string clipName)
        {
            slashVariant = Mathf.Clamp(comboIndex, 0, 2);
            if (slashSfx != null && slashSfx.Length > 0)
                PlaySfx(slashSfx[slashVariant % slashSfx.Length], 0.78f);

            if (!ChapterSceneLink.ReducedMotion && slashArc != null && avatar != null)
            {
                slashOrigin = avatar;
                slashDuration = slashVariant == 2 ? 0.28f : 0.22f;
                slashTimer = slashDuration;
                slashArc.enabled = true;
                UpdateSlashArc(0.05f);
            }

            hitStopAnim = anim;
            hitStopClip = clipName;
        }

        internal void PlayImpact(Vector3 worldPos, bool finisher)
        {
            PlaySfx(finisher ? finisherImpactSfx : impactSfx, finisher ? 0.88f : 0.72f);
            SpawnBurst(worldPos, finisher ? VioletCore : CyanEdge, finisher ? 30 : 18, finisher ? 4.6f : 3.0f, 0.40f);
            if (!ChapterSceneLink.ReducedMotion && hitStopAnim && !string.IsNullOrEmpty(hitStopClip) && hitStopAnim[hitStopClip] != null)
            {
                hitStopAnim[hitStopClip].speed = 0.08f;
                hitStopTimer = finisher ? 0.060f : 0.042f;
            }
        }

        private void PlaySfx(AudioClip clip, float volume)
        {
            if (ChapterSceneLink.Muted || !audioSource || !clip) return;
            audioSource.mute = false;
            audioSource.PlayOneShot(clip, volume);
        }

        private void SpawnBurst(Vector3 pos, Color color, int count, float speed, float lifetime)
        {
            if (ChapterSceneLink.ReducedMotion) return;
            var ps = burstPool[burstCursor];
            burstCursor = (burstCursor + 1) % burstPool.Length;
            if (!ps) return;
            ps.transform.position = pos;
            var main = ps.main;
            main.startColor = color;
            main.startSpeed = speed;
            main.startLifetime = lifetime;
            ps.Emit(count);
        }

        private void UpdateSlashArc(float progress)
        {
            if (!slashOrigin || !slashArc) return;
            const int pts = 18;
            slashArc.positionCount = pts;
            var fwd = slashOrigin.forward;
            var right = slashOrigin.right;
            var center = slashOrigin.position + Vector3.up * (slashVariant == 2 ? 1.25f : 1.08f) + fwd * 0.55f;
            var sweepStart = slashVariant == 0 ? -48f : slashVariant == 1 ? -82f : -65f;
            var sweepSpan = slashVariant == 0 ? 115f : slashVariant == 1 ? 168f : 145f;
            var headAngle = Mathf.Lerp(sweepStart, sweepStart + sweepSpan, Mathf.SmoothStep(0f, 1f, progress));
            var tailAngle = headAngle - Mathf.Lerp(45f, 88f, progress);

            var tilt = slashVariant switch
            {
                0 => Quaternion.AngleAxis(18f, fwd),
                1 => Quaternion.AngleAxis(-6f, fwd),
                _ => Quaternion.AngleAxis(82f, fwd)
            };

            var radius = slashVariant == 2 ? 1.38f : 1.18f;
            for (var i = 0; i < pts; i++)
            {
                var u = i / (float)(pts - 1);
                var ang = Mathf.Lerp(tailAngle, headAngle, u) * Mathf.Deg2Rad;
                var local = new Vector3(Mathf.Sin(ang) * radius, 0f, Mathf.Cos(ang) * radius);
                var rotated = tilt * local;
                slashArc.SetPosition(i, center + right * rotated.x + Vector3.up * rotated.y + fwd * (rotated.z * 0.65f));
            }
            var alpha = Mathf.Sin(progress * Mathf.PI);
            slashArc.startColor = Color.Lerp(VioletCore, CyanEdge, 0.35f) * alpha;
            slashArc.endColor = VioletCore * (alpha * 1.15f);
        }

        private void BuildVisualPools()
        {
            radialTex = CreateRadialGlowTexture(64);
            ribbonTex = CreateSlashRibbonTexture(64, 16);
            var shader = Shader.Find("Universal Render Pipeline/Particles/Unlit") ?? Shader.Find("Sprites/Default");
            particleMat = BuildAdditiveParticleMat(shader, radialTex);
            slashMat = BuildAdditiveParticleMat(shader, ribbonTex);

            for (var i = 0; i < burstPool.Length; i++)
            {
                var go = new GameObject("ActionBurst_" + i);
                go.transform.SetParent(transform, false);
                var ps = go.AddComponent<ParticleSystem>();
                ps.Stop(true, ParticleSystemStopBehavior.StopEmittingAndClear);
                var main = ps.main;
                main.playOnAwake = false;
                main.loop = false;
                main.startSize = new ParticleSystem.MinMaxCurve(0.08f, 0.19f);
                main.gravityModifier = 0.08f;
                main.simulationSpace = ParticleSystemSimulationSpace.World;
                var emission = ps.emission;
                emission.enabled = false;
                var shape = ps.shape;
                shape.shapeType = ParticleSystemShapeType.Sphere;
                shape.radius = 0.25f;
                var colOverLifetime = ps.colorOverLifetime;
                colOverLifetime.enabled = true;
                var grad = new Gradient();
                grad.SetKeys(
                    new[] { new GradientColorKey(Color.white, 0f), new GradientColorKey(new Color(0.65f, 0.72f, 1f), 1f) },
                    new[] { new GradientAlphaKey(0f, 0f), new GradientAlphaKey(1f, 0.15f), new GradientAlphaKey(0f, 1f) });
                colOverLifetime.color = grad;
                var r = go.GetComponent<ParticleSystemRenderer>();
                r.sharedMaterial = particleMat;
                r.shadowCastingMode = ShadowCastingMode.Off;
                burstPool[i] = ps;
            }

            var arcGo = new GameObject("PactSlashArc");
            arcGo.transform.SetParent(transform, false);
            slashArc = arcGo.AddComponent<LineRenderer>();
            slashArc.enabled = false;
            slashArc.useWorldSpace = true;
            slashArc.widthCurve = new AnimationCurve(
                new Keyframe(0f, 0.08f),
                new Keyframe(0.55f, 1f),
                new Keyframe(0.88f, 0.72f),
                new Keyframe(1f, 0.04f));
            slashArc.widthMultiplier = 0.30f;
            slashArc.numCapVertices = 4;
            slashArc.shadowCastingMode = ShadowCastingMode.Off;
            slashArc.sharedMaterial = slashMat;
        }

        private static Material BuildAdditiveParticleMat(Shader shader, Texture2D tex)
        {
            var mat = new Material(shader) { color = Color.white, mainTexture = tex };
            mat.SetFloat("_Surface", 1f);
            mat.SetFloat("_Blend", 2f);
            mat.SetFloat("_SrcBlend", (float)BlendMode.SrcAlpha);
            mat.SetFloat("_DstBlend", (float)BlendMode.One);
            mat.SetFloat("_ZWrite", 0f);
            mat.EnableKeyword("_SURFACE_TYPE_TRANSPARENT");
            mat.EnableKeyword("_BLENDMODE_ADD");
            mat.renderQueue = 3000;
            return mat;
        }

        private static Texture2D CreateRadialGlowTexture(int size)
        {
            var tex = new Texture2D(size, size, TextureFormat.RGBA32, false) { wrapMode = TextureWrapMode.Clamp };
            var half = (size - 1) * 0.5f;
            for (var y = 0; y < size; y++)
            for (var x = 0; x < size; x++)
            {
                var dx = (x - half) / half;
                var dy = (y - half) / half;
                var r = Mathf.Sqrt(dx * dx + dy * dy);
                var a = Mathf.Clamp01(1f - r);
                a = a * a * (0.4f + 0.6f * a);
                tex.SetPixel(x, y, new Color(1f, 1f, 1f, a));
            }
            tex.Apply(false, false);
            return tex;
        }

        private static Texture2D CreateSlashRibbonTexture(int w, int h)
        {
            var tex = new Texture2D(w, h, TextureFormat.RGBA32, false) { wrapMode = TextureWrapMode.Clamp };
            for (var y = 0; y < h; y++)
            {
                var v = Mathf.Abs((y / (float)(h - 1)) * 2f - 1f);
                var cross = Mathf.Pow(Mathf.Clamp01(1f - v), 1.8f);
                for (var x = 0; x < w; x++)
                {
                    var u = x / (float)(w - 1);
                    var lengthwise = Mathf.Sin(u * Mathf.PI);
                    var a = Mathf.Clamp01(cross * Mathf.Pow(lengthwise, 0.6f));
                    tex.SetPixel(x, y, new Color(1f, 1f, 1f, a));
                }
            }
            tex.Apply(false, false);
            return tex;
        }

        private void SynthesizeAudioClips()
        {
            rollSfx = MakeNoiseWhoosh("SFX_Roll", 0.28f, 340f, 140f, 0.35f);
            dashSfx = MakeNoiseWhoosh("SFX_ShadowDash", 0.26f, 920f, 260f, 0.50f);
            mantleSfx = MakeNoiseWhoosh("SFX_Mantle", 0.22f, 240f, 480f, 0.42f);
            evadeSfx = MakeHarmonic("SFX_Evade", 0.24f, 660f, 990f, 0.40f);
            slashSfx = new[]
            {
                MakeNoiseWhoosh("SFX_Slash_0", 0.19f, 1180f, 420f, 0.55f),
                MakeNoiseWhoosh("SFX_Slash_1", 0.22f, 1420f, 310f, 0.62f),
                MakeNoiseWhoosh("SFX_Slash_2", 0.28f, 1650f, 190f, 0.72f),
            };
            impactSfx = MakeHarmonic("SFX_Impact", 0.22f, 185f, 72f, 0.65f);
            finisherImpactSfx = MakeHarmonic("SFX_Finisher", 0.34f, 220f, 55f, 0.80f);
        }

        private static AudioClip MakeNoiseWhoosh(string name, float dur, float fStart, float fEnd, float gain)
        {
            const int sr = 22050;
            var n = Mathf.Max(256, Mathf.RoundToInt(sr * dur));
            var data = new float[n];
            var phase = 0f;
            uint rng = (uint)name.GetHashCode() | 1u;
            for (var i = 0; i < n; i++)
            {
                var u = i / (float)(n - 1);
                var env = Mathf.Sin(u * Mathf.PI) * (1f - u * 0.45f);
                var freq = Mathf.Lerp(fStart, fEnd, u);
                phase += 2f * Mathf.PI * freq / sr;
                rng ^= rng << 13; rng ^= rng >> 17; rng ^= rng << 5;
                var noise = ((rng & 0xFFFF) / 32768f - 1f);
                data[i] = Mathf.Clamp((Mathf.Sin(phase) * 0.42f + noise * 0.58f) * env * gain, -0.95f, 0.95f);
            }
            var clip = AudioClip.Create(name, n, 1, sr, false);
            clip.SetData(data, 0);
            return clip;
        }

        private static AudioClip MakeHarmonic(string name, float dur, float fStart, float fEnd, float gain)
        {
            const int sr = 22050;
            var n = Mathf.Max(256, Mathf.RoundToInt(sr * dur));
            var data = new float[n];
            var phase = 0f;
            for (var i = 0; i < n; i++)
            {
                var u = i / (float)(n - 1);
                var env = Mathf.Exp(-5.5f * u) * Mathf.Min(1f, u * 18f);
                var freq = Mathf.Lerp(fStart, fEnd, Mathf.Sqrt(u));
                phase += 2f * Mathf.PI * freq / sr;
                var sample = (Mathf.Sin(phase) + 0.4f * Mathf.Sin(phase * 2.02f)) * env * gain;
                data[i] = Mathf.Clamp(sample, -0.95f, 0.95f);
            }
            var clip = AudioClip.Create(name, n, 1, sr, false);
            clip.SetData(data, 0);
            return clip;
        }
    }
}
