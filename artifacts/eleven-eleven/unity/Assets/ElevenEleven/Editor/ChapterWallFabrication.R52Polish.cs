using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using ElevenEleven.Opening;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using static ElevenEleven.Editor.GodotRoomAssembly;

namespace ElevenEleven.Editor
{
    internal static partial class ChapterWallFabrication
    {
        private const string PolishMatFolder = "Assets/ElevenEleven/Opening/Stormworks/ChapterRoomPolish/";
        private const string PolishGradePath = PolishMatFolder + "Chapter photographic grade.asset";
        private const string HyperShaderPath = "Assets/ElevenEleven/Opening/Hospital/HyperAnimeCharacter.shader";
        private const string DetailGroupName = "R52 AAA Polish Details";

        [MenuItem("11.11/Apply R52 AAA Polish")]
        public static void ApplyR52AAAPolish()
        {
            var scene = EditorSceneManager.OpenScene(ScenePath);
            var content = scene.GetRootGameObjects().Single(root => root.name == "Room content").transform;
            var wasContentActive = content.gameObject.activeSelf;
            if (!wasContentActive) content.gameObject.SetActive(true);
            try
            {
            var station = content.Find("Echo Station");
            if (!station) throw new InvalidDataException("Missing Echo Station.");

            var authority = content.GetComponentsInChildren<Collider>(true)
                .ToDictionary(c => c, c => (EditorJsonUtility.ToJson(c), c.transform.localToWorldMatrix));

            var motionBefore = station.GetComponentsInChildren<RoomEnvironmentMotion>(true);
            if (motionBefore.Length != 16)
                throw new InvalidDataException($"Expected 16 RoomEnvironmentMotion components, found {motionBefore.Length}.");

            var secWing = station.GetComponentInChildren<StationSecurityWing>(true);
            var secState = secWing ? EditorJsonUtility.ToJson(secWing) : string.Empty;
            var route = content.GetComponentInChildren<StormworksRoute>(true);
            var routeState = route ? EditorJsonUtility.ToJson(route) : string.Empty;
            var coverEdges = station.Find("Security wing")?.GetComponentsInChildren<MeshRenderer>(true)
                .Where(r => r.bounds.size is { x: > 1.4f and < 1.56f, y: > 0.01f and < 0.06f, z: > 0.95f and < 1.11f })
                .ToArray() ?? Array.Empty<MeshRenderer>();

            EnsureUrpPipelineAndGrade(content);
            UpgradeRenderSettings(scene);
            var mats = BuildSharedPolishMaterials();
            UpgradeCharacterAndNpcMaterials(content, mats);
            int dedupCount = SuppressNonColliderCoincidentDuplicates(content, station);

            FixObservatoryAndHorizon(station, mats);
            FixSecurityWing(station, mats, coverEdges);
            FixSpecimenAndArchive(station, mats);
            FixReactorWing(station, mats);
            FixQuarantineWing(station, mats);
            FixSurveillanceWing(station, mats);
            FixExaminationObservationAndZero(station, mats);
            DockVanesAndRefineCrystals(station, mats);
            WireAmbientMotionDetails(station, mats);

            // Re-assert collider integrity, R40 cover plates, and 16 RoomEnvironmentMotion zones
            var after = content.GetComponentsInChildren<Collider>(true);
            if (after.Length != authority.Count || after.Any(c =>
                    !authority.TryGetValue(c, out var was) ||
                    was.Item1 != EditorJsonUtility.ToJson(c) ||
                    was.Item2 != c.transform.localToWorldMatrix))
            {
                throw new InvalidDataException($"Collider invariant broken (before={authority.Count} after={after.Length}).");
            }

            if (secWing && EditorJsonUtility.ToJson(secWing) != secState)
                throw new InvalidDataException("StationSecurityWing bindings changed unexpectedly.");
            if (route && EditorJsonUtility.ToJson(route) != routeState)
                throw new InvalidDataException("StormworksRoute bindings changed unexpectedly.");
            if (coverEdges.Length != 6 || coverEdges.Any(r => !r || !r.enabled))
                throw new InvalidDataException("R40 security cover plates must stay enabled (6 expected).");

            var motionAfter = station.GetComponentsInChildren<RoomEnvironmentMotion>(true);
            if (motionAfter.Length != 16 || motionAfter.Any(m => m.PieceCount < 23))
                throw new InvalidDataException("RoomEnvironmentMotion invariant violated.");

            if (!wasContentActive) content.gameObject.SetActive(false);
            EditorSceneManager.MarkSceneDirty(scene);
            AssetDatabase.SaveAssets();
            if (!EditorSceneManager.SaveScene(scene))
                throw new IOException("Failed to save ChapterRoom01 after R52 AAA Polish.");

            Debug.Log($"ECHO_R52_AAA_POLISH_SAVED colliders={after.Length} zones={motionAfter.Length} deduped={dedupCount}");
            }
            catch
            {
                if (!wasContentActive && content) content.gameObject.SetActive(false);
                throw;
            }
        }

        private sealed class PolishMaterials
        {
            public Shader HyperShader;
            public Material DarkSteel;
            public Material BrushedAlloy;
            public Material BulkheadMatte;
            public Material ScreenDarkCrt;
            public Material WetPuddle;
            public Material CrystalBlue;
            public Material CrystalViolet;
            public Material CyanGlow;
            public Material TurquoiseGlow;
            public Material AmberGlow;
            public Material VioletGlow;
        }

        private static void EnsureUrpPipelineAndGrade(Transform content)
        {
            var pcRp = AssetDatabase.LoadAssetAtPath<UniversalRenderPipelineAsset>("Assets/Settings/PC_RPAsset.asset");
            if (pcRp)
            {
                pcRp.msaaSampleCount = 4;
                pcRp.supportsHDR = true;
                EditorUtility.SetDirty(pcRp);
            }

            var profile = AssetDatabase.LoadAssetAtPath<VolumeProfile>(PolishGradePath);
            if (!profile)
            {
                profile = ScriptableObject.CreateInstance<VolumeProfile>();
                AssetDatabase.CreateAsset(profile, PolishGradePath);
            }

            if (!profile.TryGet<Tonemapping>(out var tone))
                tone = profile.Add<Tonemapping>(true);
            tone.active = true;
            tone.mode.overrideState = true;
            tone.mode.value = TonemappingMode.ACES;

            if (!profile.TryGet<Bloom>(out var bloom))
                bloom = profile.Add<Bloom>(true);
            bloom.active = true;
            bloom.threshold.overrideState = true;
            bloom.threshold.value = 1.04f;
            bloom.intensity.overrideState = true;
            bloom.intensity.value = 0.42f;
            bloom.scatter.overrideState = true;
            bloom.scatter.value = 0.68f;
            bloom.clamp.overrideState = true;
            bloom.clamp.value = 5.5f;
            bloom.highQualityFiltering.overrideState = true;
            bloom.highQualityFiltering.value = true;

            if (!profile.TryGet<ColorAdjustments>(out var color))
                color = profile.Add<ColorAdjustments>(true);
            color.active = true;
            color.postExposure.overrideState = true;
            color.postExposure.value = 0.14f;
            color.contrast.overrideState = true;
            color.contrast.value = 20f;
            color.saturation.overrideState = true;
            color.saturation.value = 16f;

            if (!profile.TryGet<ShadowsMidtonesHighlights>(out var smh))
                smh = profile.Add<ShadowsMidtonesHighlights>(true);
            smh.active = true;
            smh.shadows.overrideState = true;
            smh.shadows.value = new Vector4(0.955f, 0.992f, 1.038f, -0.020f);
            smh.midtones.overrideState = true;
            smh.midtones.value = new Vector4(1.004f, 1.000f, 0.996f, 0.000f);
            smh.highlights.overrideState = true;
            smh.highlights.value = new Vector4(1.045f, 1.012f, 0.965f, 0.025f);

            if (!profile.TryGet<Vignette>(out var vig))
                vig = profile.Add<Vignette>(true);
            vig.active = true;
            vig.color.overrideState = true;
            vig.color.value = new Color(0.03f, 0.05f, 0.09f, 1f);
            vig.intensity.overrideState = true;
            vig.intensity.value = 0.21f;
            vig.smoothness.overrideState = true;
            vig.smoothness.value = 0.48f;

            EditorUtility.SetDirty(profile);

            var cam = content.GetComponentsInChildren<Camera>(true).FirstOrDefault(c => c.name == "Room 01 camera");
            if (cam)
            {
                cam.allowMSAA = true;
                cam.allowHDR = true;
                var uacd = cam.GetUniversalAdditionalCameraData();
                if (uacd)
                {
                    uacd.renderPostProcessing = true;
                    uacd.antialiasing = AntialiasingMode.SubpixelMorphologicalAntiAliasing;
                    uacd.antialiasingQuality = AntialiasingQuality.High;
                    EditorUtility.SetDirty(uacd);
                }
                EditorUtility.SetDirty(cam);
            }
        }

        private static void UpgradeRenderSettings(UnityEngine.SceneManagement.Scene scene)
        {
            RenderSettings.ambientMode = AmbientMode.Trilight;
            RenderSettings.ambientSkyColor = new Color(0.45f, 0.53f, 0.67f, 1f);
            RenderSettings.ambientEquatorColor = new Color(0.31f, 0.36f, 0.43f, 1f);
            RenderSettings.ambientGroundColor = new Color(0.16f, 0.19f, 0.24f, 1f);
            RenderSettings.ambientIntensity = 1.08f;
            RenderSettings.fog = true;
            RenderSettings.fogMode = FogMode.ExponentialSquared;
            RenderSettings.fogColor = new Color(0.055f, 0.072f, 0.095f, 1f);
            RenderSettings.fogDensity = 0.0080f;
        }

        private static PolishMaterials BuildSharedPolishMaterials()
        {
            var urpLit = Shader.Find("Universal Render Pipeline/Lit");
            var hyper = AssetDatabase.LoadAssetAtPath<Shader>(HyperShaderPath) ?? Shader.Find("ElevenEleven/Hyper Anime Character");
            if (!urpLit) throw new InvalidDataException("Missing URP/Lit shader.");
            if (!hyper) throw new InvalidDataException("Missing HyperAnimeCharacter shader.");

            var m = new PolishMaterials
            {
                HyperShader = hyper,
                DarkSteel = EnsureUrpLitMat("R52DarkSteel", urpLit, new Color(0.16f, 0.18f, 0.22f, 1f), 0.72f, 0.56f),
                BrushedAlloy = EnsureUrpLitMat("R52BrushedAlloy", urpLit, new Color(0.34f, 0.38f, 0.44f, 1f), 0.78f, 0.62f),
                BulkheadMatte = EnsureUrpLitMat("R52HorizonBulkhead", urpLit, new Color(0.09f, 0.11f, 0.14f, 1f), 0.18f, 0.24f),
                ScreenDarkCrt = EnsureUrpLitMat("R52DiagnosticScreen", urpLit, new Color(0.03f, 0.07f, 0.10f, 1f), 0.12f, 0.90f,
                    new Color(0.06f, 0.44f, 0.52f, 1f)),
                WetPuddle = EnsureTransparentMat("R52DeconWetPuddle", urpLit, new Color(0.05f, 0.15f, 0.20f, 0.40f), 0.26f, 0.94f,
                    new Color(0.02f, 0.08f, 0.11f, 1f)),
                CrystalBlue = EnsureTransparentMat("R52CrystalBlue", urpLit, new Color(0.24f, 0.78f, 0.98f, 0.44f), 0.15f, 0.92f,
                    new Color(0.14f, 0.65f, 1.05f, 1f)),
                CrystalViolet = EnsureTransparentMat("R52CrystalViolet", urpLit, new Color(0.66f, 0.36f, 0.98f, 0.46f), 0.15f, 0.92f,
                    new Color(0.55f, 0.24f, 1.05f, 1f)),
                CyanGlow = EnsureUrpLitMat("R52CyanGlow", urpLit, new Color(0.22f, 0.85f, 0.98f, 1f), 0.1f, 0.85f,
                    new Color(0.20f, 0.95f, 1.35f, 1f)),
                TurquoiseGlow = EnsureUrpLitMat("R52TurquoiseGlow", urpLit, new Color(0.14f, 0.95f, 0.72f, 1f), 0.1f, 0.85f,
                    new Color(0.18f, 1.45f, 0.96f, 1f)),
                AmberGlow = EnsureUrpLitMat("R52AmberGlow", urpLit, new Color(0.95f, 0.48f, 0.14f, 1f), 0.1f, 0.85f,
                    new Color(1.25f, 0.46f, 0.12f, 1f)),
                VioletGlow = EnsureUrpLitMat("R52VioletGlow", urpLit, new Color(0.68f, 0.35f, 0.98f, 1f), 0.1f, 0.85f,
                    new Color(0.75f, 0.32f, 1.35f, 1f)),
            };
            return m;
        }

        private static Material EnsureUrpLitMat(string name, Shader shader, Color baseCol, float metallic, float smoothness, Color? emission = null)
        {
            var path = PolishMatFolder + name + ".mat";
            var mat = AssetDatabase.LoadAssetAtPath<Material>(path);
            if (!mat)
            {
                mat = new Material(shader) { name = name };
                AssetDatabase.CreateAsset(mat, path);
            }
            else
            {
                mat.shader = shader;
                mat.name = name;
            }
            mat.SetFloat("_Surface", 0f);
            mat.SetFloat("_ZWrite", 1f);
            mat.SetColor("_BaseColor", baseCol);
            mat.SetFloat("_Metallic", metallic);
            mat.SetFloat("_Smoothness", smoothness);
            if (emission.HasValue)
            {
                mat.EnableKeyword("_EMISSION");
                mat.SetColor("_EmissionColor", emission.Value);
            }
            else
            {
                mat.DisableKeyword("_EMISSION");
                mat.SetColor("_EmissionColor", Color.black);
            }
            mat.renderQueue = 2000;
            EditorUtility.SetDirty(mat);
            return mat;
        }

        private static Material EnsureTransparentMat(string name, Shader shader, Color baseCol, float metallic, float smoothness, Color emission)
        {
            var path = PolishMatFolder + name + ".mat";
            var mat = AssetDatabase.LoadAssetAtPath<Material>(path);
            if (!mat)
            {
                mat = new Material(shader) { name = name };
                AssetDatabase.CreateAsset(mat, path);
            }
            else
            {
                mat.shader = shader;
                mat.name = name;
            }
            mat.SetFloat("_Surface", 1f);
            mat.SetFloat("_Blend", 0f);
            mat.SetFloat("_SrcBlend", (float)BlendMode.SrcAlpha);
            mat.SetFloat("_DstBlend", (float)BlendMode.OneMinusSrcAlpha);
            mat.SetFloat("_ZWrite", 0f);
            mat.SetColor("_BaseColor", baseCol);
            mat.SetFloat("_Metallic", metallic);
            mat.SetFloat("_Smoothness", smoothness);
            mat.EnableKeyword("_SURFACE_TYPE_TRANSPARENT");
            mat.EnableKeyword("_EMISSION");
            mat.SetColor("_EmissionColor", emission);
            mat.renderQueue = 3000;
            EditorUtility.SetDirty(mat);
            return mat;
        }

        private static void UpgradeCharacterAndNpcMaterials(Transform content, PolishMaterials mats)
        {
            var renderers = content.GetComponentsInChildren<Renderer>(true);
            foreach (var r in renderers)
            {
                var path = AnimationUtility.CalculateTransformPath(r.transform, content);
                if (path.Contains("School65 facing") && path.Contains("tripo_"))
                    ApplyHyperToonToRenderer(r, "R52School65Hyper", mats.HyperShader,
                        Color.white, new Color(0.68f, 0.72f, 0.84f, 1f), 0.14f, 0.09f, 0.34f, 0.08f, 0.16f);
                else if ((path.Contains("Pact72 facing") || path.Contains("Mirror-only Pact72")) && path.Contains("tripo_"))
                    ApplyHyperToonToRenderer(r, "R52Pact72Hyper", mats.HyperShader,
                        Color.white, new Color(0.62f, 0.66f, 0.82f, 1f), 0.14f, 0.09f, 0.40f, 0.08f, 0.18f);
                else if (path.EndsWith("KinjaPreservedScientistSurface", StringComparison.Ordinal))
                    ApplyHyperToonToRenderer(r, "R52KinjaHyper", mats.HyperShader,
                        new Color(0.95f, 0.96f, 0.98f, 1f), new Color(0.58f, 0.64f, 0.76f, 1f), 0.15f, 0.10f, 0.30f, 0.06f, 0.16f);
                else if (path.Contains("Zero manifestation/Armature/tripo_"))
                {
                    var mat = BuildHyperAnimeMaterial("R52ZeroHyper", r.sharedMaterial, mats.HyperShader,
                        new Color(0.92f, 0.86f, 1.00f, 1f), new Color(0.42f, 0.32f, 0.65f, 1f), 0.16f, 0.12f, 0.52f, 0.10f, 0.22f);
                    mat.SetColor("_RimColor", new Color(0.76f, 0.50f, 1.00f, 1f));
                    EditorUtility.SetDirty(mat);
                    AssignSingleMatToAllSlots(r, mat);
                }
            }
        }

        private static void ApplyHyperToonToRenderer(Renderer r, string matPrefix, Shader shader,
            Color baseCol, Color shadowCol, float shadowOffset, float shadowFeather, float rimStrength, float hairSheen, float inkDarken)
        {
            var srcMats = r.sharedMaterials;
            if (srcMats == null || srcMats.Length == 0) return;
            var replaced = new Material[srcMats.Length];
            for (var i = 0; i < srcMats.Length; i++)
            {
                var src = srcMats[i];
                var suffix = srcMats.Length == 1 ? "" : "_" + i;
                // Preserve existing R52 toon material texture if already upgraded once
                var existing = AssetDatabase.LoadAssetAtPath<Material>(PolishMatFolder + matPrefix + suffix + ".mat");
                var texSource = src ? src : existing;
                replaced[i] = BuildHyperAnimeMaterial(matPrefix + suffix, texSource, shader,
                    baseCol, shadowCol, shadowOffset, shadowFeather, rimStrength, hairSheen, inkDarken);
            }
            r.sharedMaterials = replaced;
            EditorUtility.SetDirty(r);
        }

        private static void AssignSingleMatToAllSlots(Renderer r, Material mat)
        {
            var count = Math.Max(1, r.sharedMaterials.Length);
            var arr = new Material[count];
            for (var i = 0; i < count; i++) arr[i] = mat;
            r.sharedMaterials = arr;
            EditorUtility.SetDirty(r);
        }

        private static int SuppressNonColliderCoincidentDuplicates(Transform content, Transform station)
        {
            var protectedRenderers = new HashSet<Renderer>();
            foreach (var mb in content.GetComponentsInChildren<MonoBehaviour>(true))
            {
                if (!mb) continue;
                var so = new SerializedObject(mb);
                var prop = so.GetIterator();
                while (prop.NextVisible(true))
                {
                    if (prop.propertyType != SerializedPropertyType.ObjectReference) continue;
                    var obj = prop.objectReferenceValue;
                    if (obj is Renderer rr) protectedRenderers.Add(rr);
                    else if (obj is Component c) foreach (var r in c.GetComponentsInChildren<Renderer>(true)) protectedRenderers.Add(r);
                    else if (obj is GameObject g) foreach (var r in g.GetComponentsInChildren<Renderer>(true)) protectedRenderers.Add(r);
                }
            }

            var renderers = station.GetComponentsInChildren<MeshRenderer>(true);
            var seen = new Dictionary<string, Bounds>(StringComparer.Ordinal);
            var suppressed = 0;
            foreach (var r in renderers)
            {
                if (!r.enabled || protectedRenderers.Contains(r)) continue;
                if (r.GetComponent<Collider>() != null) continue;
                var name = r.gameObject.name;
                if (name.StartsWith("Fracture chip", StringComparison.Ordinal) ||
                    name.StartsWith("Instrument vane", StringComparison.Ordinal) ||
                    name.Contains("CoverEdge") ||
                    name.Contains("_MeshInstance3D_9") ||
                    name.Contains("_MeshInstance3D_10") ||
                    name.Contains("_MeshInstance3D_11") ||
                    name.Contains("_MeshInstance3D_12"))
                    continue;

                var mf = r.GetComponent<MeshFilter>();
                if (!mf || !mf.sharedMesh) continue;
                var b = r.bounds;
                var key = $"{mf.sharedMesh.GetInstanceID()}_{Mathf.RoundToInt(b.center.x * 200f)}_{Mathf.RoundToInt(b.center.y * 200f)}_{Mathf.RoundToInt(b.center.z * 200f)}_{Mathf.RoundToInt(b.size.x * 200f)}_{Mathf.RoundToInt(b.size.y * 200f)}_{Mathf.RoundToInt(b.size.z * 200f)}";
                if (seen.TryGetValue(key, out _))
                {
                    r.enabled = false;
                    EditorUtility.SetDirty(r);
                    suppressed++;
                }
                else
                {
                    seen[key] = b;
                }
            }
            return suppressed;
        }

        private static Transform ResetPolishGroup(Transform parent)
        {
            var old = parent.Find(DetailGroupName);
            if (old) UnityEngine.Object.DestroyImmediate(old.gameObject);
            var go = new GameObject(DetailGroupName);
            go.transform.SetParent(parent, false);
            return go.transform;
        }

        private static GameObject AddBox(Transform parent, string name, Vector3 worldPos, Vector3 worldScale, Material mat, Quaternion? worldRot = null)
        {
            var go = GameObject.CreatePrimitive(PrimitiveType.Cube);
            go.name = name;
            UnityEngine.Object.DestroyImmediate(go.GetComponent<Collider>());
            go.transform.SetParent(parent, true);
            go.transform.position = worldPos;
            go.transform.rotation = worldRot ?? Quaternion.identity;
            go.transform.localScale = worldScale;
            var r = go.GetComponent<Renderer>();
            r.sharedMaterial = mat;
            return go;
        }

        private static GameObject AddCylinder(Transform parent, string name, Vector3 worldPos, Vector3 worldScale, Material mat, Quaternion? worldRot = null)
        {
            var go = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
            go.name = name;
            UnityEngine.Object.DestroyImmediate(go.GetComponent<Collider>());
            go.transform.SetParent(parent, true);
            go.transform.position = worldPos;
            go.transform.rotation = worldRot ?? Quaternion.identity;
            go.transform.localScale = worldScale;
            var r = go.GetComponent<Renderer>();
            r.sharedMaterial = mat;
            return go;
        }

        private static void FixObservatoryAndHorizon(Transform station, PolishMaterials mats)
        {
            var obs = station.Find("Memory Observatory");
            if (!obs) return;
            var details = ResetPolishGroup(obs);

            // Replace bright purple 'Service plate pier' columns under Echo Station with brushed dark alloy + foot shoes
            foreach (var r in station.GetComponentsInChildren<MeshRenderer>(true))
            {
                if (r.gameObject.name == "Service plate pier")
                {
                    r.sharedMaterial = mats.BrushedAlloy;
                    EditorUtility.SetDirty(r);
                    var b = r.bounds;
                    AddBox(details, "PierFootShoe", new Vector3(b.center.x, b.min.y + 0.08f, b.center.z),
                        new Vector3(b.size.x + 0.16f, 0.16f, b.size.z + 0.16f), mats.DarkSteel);
                    AddBox(details, "PierTopCap", new Vector3(b.center.x, b.max.y - 0.06f, b.center.z),
                        new Vector3(b.size.x + 0.12f, 0.12f, b.size.z + 0.12f), mats.DarkSteel);
                }
            }

            // Ground Chronostat reference iris on right Observatory bridge deck
            var iris = obs.Find("Chapter room environment art/High orbit glacial shards/Fitted room mechanisms/Chronostat reference iris");
            if (iris)
            {
                var lp = iris.position;
                if (lp.y > 0.65f)
                {
                    AddBox(details, "ChronostatIrisPedestal", new Vector3(lp.x, 0.44f, lp.z), new Vector3(0.24f, 0.86f, 0.20f), mats.DarkSteel);
                    AddBox(details, "ChronostatIrisBaseFlange", new Vector3(lp.x, 0.06f, lp.z), new Vector3(0.46f, 0.08f, 0.38f), mats.BrushedAlloy);
                    AddBox(details, "ChronostatIrisCyanStrip", new Vector3(lp.x, 0.72f, lp.z - 0.105f), new Vector3(0.18f, 0.03f, 0.02f), mats.CyanGlow);
                }
            }

            // Seal sky gap below outer Observatory perimeter walls (z = 76..95, well clear of center walkway)
            AddBox(details, "HorizonBulkheadWest", new Vector3(-22.5f, -5.6f, 84.5f), new Vector3(26f, 11.4f, 22f), mats.BulkheadMatte);
            AddBox(details, "HorizonBulkheadEast", new Vector3(22.5f, -5.6f, 84.5f), new Vector3(26f, 11.4f, 22f), mats.BulkheadMatte);
            AddBox(details, "HorizonSubApron", new Vector3(0f, -3.5f, 86.5f), new Vector3(56f, 7.8f, 18f), mats.BulkheadMatte);
            AddBox(details, "HorizonCrossGirder", new Vector3(0f, -6.4f, 89.0f), new Vector3(22f, 2.2f, 12f), mats.DarkSteel);
            AddBox(details, "HorizonBeaconWest", new Vector3(-11.2f, -0.35f, 82.0f), new Vector3(0.32f, 0.08f, 11.5f), mats.CyanGlow);
            AddBox(details, "HorizonBeaconEast", new Vector3(11.2f, -0.35f, 82.0f), new Vector3(0.32f, 0.08f, 11.5f), mats.CyanGlow);
        }

        private static void FixSecurityWing(Transform station, PolishMaterials mats, MeshRenderer[] coverEdges)
        {
            var sec = station.Find("Security wing");
            if (!sec) return;
            var details = ResetPolishGroup(sec);
            var native = sec.Find("Native Godot security geometry");
            if (!native) return;

            // Hide floating/clipping DivertStation mesh & protruding readout plate next to left wall cabinet
            var divertMesh = native.Find("DivertStation/_MeshInstance3D_163");
            if (divertMesh)
            {
                foreach (var mr in divertMesh.GetComponentsInChildren<MeshRenderer>(true))
                {
                    if (mr.GetComponent<Collider>() == null) mr.enabled = false;
                }
            }

            // Support the 6 kept R40 CoverEdge metal tops with sleek grounded tactical barricade bodies
            foreach (var ce in coverEdges)
            {
                var b = ce.bounds;
                var h = Mathf.Max(0.4f, b.min.y - 0.04f);
                AddBox(details, "CoverBarricadeBody", new Vector3(b.center.x, 0.04f + h * 0.5f, b.center.z),
                    new Vector3(b.size.x * 0.94f, h, b.size.z * 0.88f), mats.DarkSteel);
                AddBox(details, "CoverBarricadePlinth", new Vector3(b.center.x, 0.07f, b.center.z),
                    new Vector3(b.size.x * 0.98f, 0.06f, b.size.z * 0.95f), mats.BrushedAlloy);
                AddBox(details, "CoverBarricadeTrim", new Vector3(b.center.x, b.min.y - 0.08f, b.min.z + 0.04f),
                    new Vector3(b.size.x * 0.82f, 0.035f, 0.04f), mats.CyanGlow);
            }

            // Ladder rails on ServiceClimb & pillars under DescentPlatform
            var climb = native.Find("ServiceClimb");
            if (climb)
            {
                var p = climb.position;
                AddBox(details, "ClimbRailLeft", new Vector3(p.x - 0.36f, p.y + 0.45f, p.z + 0.25f), new Vector3(0.06f, 2.75f, 0.08f), mats.BrushedAlloy);
                AddBox(details, "ClimbRailRight", new Vector3(p.x + 0.36f, p.y + 0.45f, p.z + 0.25f), new Vector3(0.06f, 2.75f, 0.08f), mats.BrushedAlloy);
            }

            var descent = native.Find("DescentPlatform/_MeshInstance3D_155")?.GetComponent<MeshRenderer>();
            if (descent)
            {
                var db = descent.bounds;
                var legH = Mathf.Max(0.3f, db.min.y - 0.04f);
                foreach (var sx in new[] { db.min.x + 0.12f, db.max.x - 0.12f })
                foreach (var sz in new[] { db.min.z + 0.12f, db.max.z - 0.12f })
                    AddBox(details, "DescentLeg", new Vector3(sx, 0.04f + legH * 0.5f, sz), new Vector3(0.11f, legH, 0.11f), mats.DarkSteel);
            }

            // Hide floating 1x1x1 block GateStation/FittedStationCasing4; move floating readout to west pier
            var gateCasing4 = native.Find("GateStation/FittedStationCasing3/FittedStationCasing4")?.GetComponent<MeshRenderer>();
            if (gateCasing4 && gateCasing4.GetComponent<Collider>() == null) gateCasing4.enabled = false;
            var gateReadoutHost = native.Find("GateStation/_MeshInstance3D_166");
            if (gateReadoutHost && gateReadoutHost.GetComponentsInChildren<Collider>(true).Length == 0)
            {
                gateReadoutHost.position = new Vector3(13.18f, 1.35f, 94.75f);
                PrefabUtility.RecordPrefabInstancePropertyModifications(gateReadoutHost);
            }

            // Connect ceiling Scanner turret to a real overhead ceiling mount & animate gentle sweep
            var scanner = native.Find("Scanner");
            if (scanner)
            {
                var head = scanner.Find("CompactNativeScannerHousing/CompactNativeScannerHousing2");
                if (head)
                {
                    var hp = head.position;
                    AddCylinder(details, "ScannerSuspensionStem", new Vector3(hp.x, hp.y + 0.95f, hp.z - 0.12f),
                        new Vector3(0.09f, 0.92f, 0.09f), mats.DarkSteel);
                    AddCylinder(details, "ScannerCeilingFlange", new Vector3(hp.x, hp.y + 1.84f, hp.z - 0.12f),
                        new Vector3(0.34f, 0.06f, 0.34f), mats.BrushedAlloy);
                    var kd = head.gameObject.GetComponent<StationKineticDetail>() ?? head.gameObject.AddComponent<StationKineticDetail>();
                    kd.Configure(StationKineticDetail.MotionMode.OscillateAngle, Vector3.up, 0.95f, 24f);
                }
            }

            // Spin security fans smoothly
            foreach (var r in native.GetComponentsInChildren<Transform>(true))
            {
                if (r.name.StartsWith("FanPBRRotorPivot", StringComparison.Ordinal))
                {
                    var rotor = r.gameObject.GetComponent<StationRotor>() ?? r.gameObject.AddComponent<StationRotor>();
                    EditorUtility.SetDirty(rotor);
                }
            }
        }

        private static void FixSpecimenAndArchive(Transform station, PolishMaterials mats)
        {
            var spec = station.Find("Specimen containment");
            if (spec)
            {
                var details = ResetPolishGroup(spec);
                var scannerHead = spec.Find("Native Godot specimen geometry/ScannerHead/MeasuredMechanicalScanner/MeasuredMechanicalScanner2");
                if (scannerHead)
                {
                    foreach (var mr in scannerHead.GetComponentsInChildren<MeshRenderer>(true))
                        mr.sharedMaterial = mats.DarkSteel;
                    var sp = scannerHead.position;
                    AddCylinder(details, "SpecimenScannerStem", new Vector3(sp.x, sp.y + 0.42f, sp.z - 0.10f),
                        new Vector3(0.11f, 0.45f, 0.11f), mats.BrushedAlloy);
                    AddBox(details, "SpecimenCeilingTrack", new Vector3(sp.x, sp.y + 0.82f, sp.z - 0.10f),
                        new Vector3(1.8f, 0.12f, 0.24f), mats.DarkSteel);
                    var optic = spec.Find("Native Godot specimen geometry/ScannerHead/NativeScannerOptic")?.GetComponent<Renderer>();
                    var kd = scannerHead.gameObject.GetComponent<StationKineticDetail>() ?? scannerHead.gameObject.AddComponent<StationKineticDetail>();
                    kd.Configure(StationKineticDetail.MotionMode.OscillateAngle, Vector3.up, 0.72f, 22f, 0.5f,
                        optic, new Color(0.18f, 1.35f, 0.95f, 1f), 0.7f, 1.4f, 1.1f);
                }
                foreach (var t in spec.GetComponentsInChildren<Transform>(true))
                {
                    if (t.name.StartsWith("FanPBRRotorPivot", StringComparison.Ordinal))
                        if (!t.GetComponent<StationRotor>()) t.gameObject.AddComponent<StationRotor>();
                }
            }

            var arch = station.Find("Memory archive wing");
            if (arch)
            {
                var details = ResetPolishGroup(arch);
                var ring = AddCylinder(details, "ArchiveMemoryHalo", new Vector3(-35.35f, 2.85f, 111.10f),
                    new Vector3(1.15f, 0.018f, 1.15f), mats.CrystalViolet, Quaternion.Euler(90f, 0f, 0f));
                ring.AddComponent<StationKineticDetail>().Configure(StationKineticDetail.MotionMode.Spin, Vector3.up, 18f, 0f);
            }
        }

        private static void FixReactorWing(Transform station, PolishMaterials mats)
        {
            var reactor = station.Find("Reserve reactor wing");
            if (!reactor) return;
            var details = ResetPolishGroup(reactor);

            foreach (var t in reactor.GetComponentsInChildren<Transform>(true))
            {
                if (!t.name.StartsWith("Reactor walkway protected power bus", StringComparison.Ordinal)) continue;
                var bus = t.Find("ReactorSideBus");
                if (!bus) continue;
                var mr = bus.GetComponent<MeshRenderer>();
                if (!mr || bus.GetComponent<Collider>() != null || t.GetComponentsInChildren<Collider>(true).Length > 0) continue;
                // Anchor power bus cleanly flush under/along outer catwalk rail (local +/-3.45 instead of +/-5.48 sticking into lockers)
                var lp = t.localPosition;
                var sign = Mathf.Sign(lp.x);
                if (Mathf.Abs(lp.x) > 3.9f)
                {
                    t.localPosition = new Vector3(sign * 3.42f, -0.78f, lp.z);
                    t.localScale = new Vector3(1.25f, 1.35f, t.localScale.z);
                    PrefabUtility.RecordPrefabInstancePropertyModifications(t);
                }
                bus.localPosition = new Vector3(0f, 0f, 0f);
                bus.localScale = new Vector3(0.24f, 0.42f, 1.65f);
                mr.sharedMaterial = mats.DarkSteel;
                PrefabUtility.RecordPrefabInstancePropertyModifications(bus);
            }

            // Cooling core halo rings over reactor bay & dock regulator hub cleanly to East wall
            var hotMech = reactor.Find("Chapter room environment art/Hot debris and regulator plates/Fitted room mechanisms");
            if (hotMech && hotMech.GetComponentsInChildren<Collider>(true).Length == 0)
            {
                hotMech.position = new Vector3(-25.10f, 3.85f, 166.0f);
                EditorUtility.SetDirty(hotMech);
            }
            var coreRing = AddCylinder(details, "ReactorCoolantHalo", new Vector3(-35.5f, 6.45f, 164.0f),
                new Vector3(2.4f, 0.04f, 2.4f), mats.CrystalBlue);
            coreRing.AddComponent<StationKineticDetail>().Configure(StationKineticDetail.MotionMode.Spin, Vector3.up, 26f, 0f);
        }

        private static void FixQuarantineWing(Transform station, PolishMaterials mats)
        {
            var decon = station.Find("Decontamination and quarantine");
            if (!decon) return;
            ResetPolishGroup(decon);
            foreach (var mr in decon.GetComponentsInChildren<MeshRenderer>(true))
            {
                if (mr.gameObject.name.StartsWith("CondensationPuddle_", StringComparison.Ordinal))
                {
                    mr.sharedMaterial = mats.WetPuddle;
                    mr.transform.position = new Vector3(mr.transform.position.x, 4.010f, mr.transform.position.z);
                    mr.transform.localScale = new Vector3(0.82f, 1f, 0.82f);
                    EditorUtility.SetDirty(mr);
                    var kd = mr.gameObject.GetComponent<StationKineticDetail>() ?? mr.gameObject.AddComponent<StationKineticDetail>();
                    kd.Configure(StationKineticDetail.MotionMode.PulseScale, Vector3.up, 0.7f, 0.03f, mr.bounds.center.x);
                }
                else if (mr.gameObject.name.StartsWith("FanPBRRotorPivot", StringComparison.Ordinal))
                {
                    if (!mr.GetComponent<StationRotor>()) mr.gameObject.AddComponent<StationRotor>();
                }
            }
        }

        private static void FixSurveillanceWing(Transform station, PolishMaterials mats)
        {
            var surv = station.Find("Surveillance and mirror");
            if (!surv) return;
            var details = ResetPolishGroup(surv);

            // Disable pitch-black floating rectangle left of mirror
            var recordMount = surv.Find("Godot surveillance architecture/mirror_chamber_room/SurveillancePresentation/RecordMount");
            if (recordMount)
            {
                foreach (var mr in recordMount.GetComponentsInChildren<MeshRenderer>(true))
                {
                    if (mr.GetComponent<Collider>() == null) mr.enabled = false;
                }
            }

            foreach (var t in surv.GetComponentsInChildren<Transform>(true))
            {
                if (t.name.StartsWith("FanPBRRotorPivot", StringComparison.Ordinal))
                    if (!t.GetComponent<StationRotor>()) t.gameObject.AddComponent<StationRotor>();
            }

            // Build & wire illuminated PATH SAFE north gate indicator on StationSurveillanceWing
            var wing = surv.GetComponent<StationSurveillanceWing>();
            var panelBack = AddBox(details, "PathSafeHousing", new Vector3(-35.5f, 7.62f, 277.35f),
                new Vector3(2.35f, 0.42f, 0.14f), mats.DarkSteel);
            var lensObj = AddBox(details, "PathSafeLens", new Vector3(-35.5f, 7.62f, 277.26f),
                new Vector3(2.15f, 0.28f, 0.04f), mats.ScreenDarkCrt);
            var cueHolder = new GameObject("PathSafeCueLabel");
            cueHolder.transform.SetParent(details, true);
            cueHolder.transform.position = new Vector3(-35.5f, 7.62f, 277.21f);
            cueHolder.transform.rotation = Quaternion.identity;
            var tm = cueHolder.AddComponent<TextMesh>();
            var font = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
            tm.font = font;
            var tmRenderer = tm.GetComponent<MeshRenderer>();
            if (font && tmRenderer) tmRenderer.sharedMaterial = font.material;
            if (tmRenderer) tmRenderer.shadowCastingMode = ShadowCastingMode.Off;
            tm.text = "PATH SAFE";
            tm.fontSize = 64;
            tm.characterSize = 0.036f;
            tm.fontStyle = FontStyle.Bold;
            tm.anchor = TextAnchor.MiddleCenter;
            tm.alignment = TextAlignment.Center;
            tm.color = new Color(0.02f, 0.08f, 0.10f, 1f);
            cueHolder.SetActive(false);

            if (wing)
            {
                var so = new SerializedObject(wing);
                so.FindProperty("pathSafeCue").objectReferenceValue = cueHolder;
                so.FindProperty("pathSafeLens").objectReferenceValue = lensObj.GetComponent<Renderer>();
                so.ApplyModifiedPropertiesWithoutUndo();
                EditorUtility.SetDirty(wing);
            }
            _ = panelBack;
        }

        private static void FixExaminationObservationAndZero(Transform station, PolishMaterials mats)
        {
            var exam = station.Find("Surveillance and mirror/Kinja examination theatre");
            if (!exam) return;
            var details = ResetPolishGroup(exam);

            // 1. Separate clashing carts on raised dais from Neural overload & Repeat trial pedestals and ground pedestals cleanly
            var labArch = exam.Find("Godot examination architecture/PactRevengePresentation/ClinicalLabArchitecture");
            if (labArch)
            {
                var cart6Node = labArch.Find("_Node3D_701");
                if (cart6Node && cart6Node.GetComponent<Collider>() == null)
                {
                    cart6Node.position = new Vector3(-42.55f, cart6Node.position.y, 296.55f);
                    PrefabUtility.RecordPrefabInstancePropertyModifications(cart6Node);
                }
                var cart12Node = labArch.Find("_Node3D_715");
                if (cart12Node && cart12Node.GetComponent<Collider>() == null)
                {
                    cart12Node.position = new Vector3(-28.45f, cart12Node.position.y, 296.55f);
                    PrefabUtility.RecordPrefabInstancePropertyModifications(cart12Node);
                }

                // Hide unstyled thin orange floor strips & reskin 704 sill
                foreach (var stripName in new[] { "_MeshInstance3D_706", "_MeshInstance3D_707", "_MeshInstance3D_723", "_MeshInstance3D_724" })
                {
                    var s = labArch.Find(stripName)?.GetComponent<MeshRenderer>();
                    if (s && s.GetComponent<Collider>() == null) s.enabled = false;
                }
                var sill = labArch.Find("_MeshInstance3D_704")?.GetComponent<MeshRenderer>();
                if (sill) sill.sharedMaterial = mats.DarkSteel;

                // Overlay crisp dark cyan CRT displays centered accurately inside the monitor bezel (b.max.y - 0.32f, X or Z aligned)
                foreach (var mr in labArch.GetComponentsInChildren<MeshRenderer>(true))
                {
                    if (!mr.enabled || !mr.gameObject.name.StartsWith("diagnostic_cart", StringComparison.Ordinal)) continue;
                    var b = mr.bounds;
                    var zFacing = b.size.x > b.size.z;
                    var screenSize = zFacing ? new Vector3(0.56f, 0.34f, 0.14f) : new Vector3(0.14f, 0.34f, 0.56f);
                    var screen = AddBox(details, mr.gameObject.name + "_GlassScreen",
                        new Vector3(b.center.x, b.max.y - 0.31f, b.center.z),
                        screenSize, mats.ScreenDarkCrt);
                    var kd = screen.AddComponent<StationKineticDetail>();
                    kd.Configure(StationKineticDetail.MotionMode.PulseScale, Vector3.up, 0.9f, 0.015f, b.center.z,
                        screen.GetComponent<Renderer>(), new Color(0.08f, 0.48f, 0.56f, 1f), 0.78f, 1.32f, 0.95f);
                }
            }

            // Pedestals under Neural overload & Repeat trial record kiosks (reaching dais top y=5.20)
            foreach (var recName in new[] { "Neural overload record", "Repeat trial record" })
            {
                var rec = exam.Find(recName);
                if (!rec) continue;
                var p = rec.position;
                AddBox(details, recName + "_Pedestal", new Vector3(p.x, 5.58f, p.z), new Vector3(0.32f, 0.76f, 0.22f), mats.DarkSteel);
                AddBox(details, recName + "_Base", new Vector3(p.x, 5.23f, p.z), new Vector3(0.58f, 0.07f, 0.42f), mats.BrushedAlloy);
            }

            // 2. Dock floating wall scrubbers & optical assembly flush onto inner East/West Examination walls (never hanging in midair!)
            var scrubber = exam.Find("Kinja confrontation/Chapter room environment art/Observation bay scrubber");
            if (scrubber && scrubber.GetComponentsInChildren<Collider>(true).Length == 0)
            {
                scrubber.position = new Vector3(-50.62f, 7.65f, 300.68f);
                EditorUtility.SetDirty(scrubber);
            }
            var airFilter = exam.Find("Chapter room environment art/Examination air filter");
            if (airFilter && airFilter.GetComponentsInChildren<Collider>(true).Length == 0)
            {
                airFilter.position = new Vector3(-50.62f, 8.20f, 305.55f);
                EditorUtility.SetDirty(airFilter);
            }
            var optAssembly = exam.Find("Chapter room environment art/Examination optical assembly");
            if (optAssembly && optAssembly.GetComponentsInChildren<Collider>(true).Length == 0)
            {
                optAssembly.position = new Vector3(-20.38f, 8.35f, 302.68f);
                EditorUtility.SetDirty(optAssembly);
            }
            var telSweep = exam.Find("Kinja confrontation/Chapter room environment art/Observation alcove afterimages/Fitted room mechanisms/Observation telemetry sweep");
            if (telSweep && telSweep.GetComponentsInChildren<Collider>(true).Length == 0)
            {
                telSweep.position = new Vector3(-50.62f, 7.45f, 298.85f);
                EditorUtility.SetDirty(telSweep);
            }
            var examFins = exam.Find("Chapter room environment art/Examination filtration fins and air/Fitted room mechanisms");
            if (examFins && examFins.GetComponentsInChildren<Collider>(true).Length == 0)
            {
                examFins.position = new Vector3(-20.42f, 8.65f, 300.17f);
                EditorUtility.SetDirty(examFins);
            }

            // 3. Ground Examination wall utility posts & foot guards all the way down to lower floor y=4.00
            var archFinish = exam.Find("Examination architectural finish");
            if (archFinish)
            {
                foreach (Transform child in archFinish)
                {
                    if (child.GetComponentsInChildren<Collider>(true).Length > 0) continue;
                    if (child.name == "Utility foot guard" && child.position.y > 4.6f)
                    {
                        child.position = new Vector3(child.position.x, 4.36f, child.position.z);
                        EditorUtility.SetDirty(child);
                    }
                    else if (child.name == "Wall utility post" && child.position.y > 8.5f)
                    {
                        var ls = child.localScale;
                        child.position = new Vector3(child.position.x, 8.55f, child.position.z);
                        child.localScale = new Vector3(ls.x, 9.10f, ls.z);
                        EditorUtility.SetDirty(child);
                    }
                }
            }

            // 4. Zero arena: uncover carved basalt ring filigree by replacing floor disc with hovering orbiting amethyst prisms
            foreach (var discName in new[] { "Zero encounter/Chapter room environment art/Violet fractured laminate", "Zero encounter/Chapter room environment art/Examination violet indicator" })
            {
                var disc = exam.Find(discName);
                if (disc && disc.GetComponentsInChildren<Collider>(true).Length == 0)
                {
                    var ls = disc.localScale;
                    if (ls.x > 0.85f) disc.localScale = new Vector3(ls.x * 0.78f, ls.y, ls.z * 0.78f);
                    EditorUtility.SetDirty(disc);
                }
            }

            var altarHaloOrbit = new GameObject("ZeroAltarCrystalOrbit");
            altarHaloOrbit.transform.SetParent(details, true);
            altarHaloOrbit.transform.position = new Vector3(-35.5f, 5.55f, 313.03f);
            for (var i = 0; i < 6; i++)
            {
                var a = (Mathf.PI * 2f * i) / 6f;
                var shard = AddBox(altarHaloOrbit.transform, "ZeroAltarPrism_" + i,
                    altarHaloOrbit.transform.position + new Vector3(Mathf.Cos(a) * 1.45f, Mathf.Sin(a * 2f) * 0.14f, Mathf.Sin(a) * 1.45f),
                    new Vector3(0.055f, 0.22f, 0.055f), mats.CrystalViolet, Quaternion.Euler(14f, i * 60f, 12f));
                shard.AddComponent<StationKineticDetail>().Configure(StationKineticDetail.MotionMode.FloatBob, Vector3.up, 1.3f, 0.06f, i * 0.8f);
            }
            altarHaloOrbit.AddComponent<StationKineticDetail>().Configure(StationKineticDetail.MotionMode.Spin, Vector3.up, 18f, 0f);
        }

        private static void DockVanesAndRefineCrystals(Transform station, PolishMaterials mats)
        {
            var zones = station.GetComponentsInChildren<RoomEnvironmentMotion>(true);
            foreach (var z in zones)
            {
                var isWardDust = z.gameObject.name.Contains("Dust drifting");
                var isSignalWindow = z.gameObject.name.Contains("Window chips");
                var mech = z.transform.Find("Fitted room mechanisms");
                var anchor = mech ? mech.position : z.transform.position;

                var vanes = new List<Transform>();
                var chips = new List<Transform>();
                for (var i = 0; i < z.transform.childCount; i++)
                {
                    var c = z.transform.GetChild(i);
                    if (c.name.StartsWith("Instrument vane", StringComparison.Ordinal)) vanes.Add(c);
                    else if (c.name.StartsWith("Fracture chip", StringComparison.Ordinal)) chips.Add(c);
                }

                // Dock every Instrument vane cleanly into a tight radial impeller collar right on Fitted room mechanisms
                for (var i = 0; i < vanes.Count; i++)
                {
                    var v = vanes[i];
                    var angle = (Mathf.PI * 2f * i) / Mathf.Max(1, vanes.Count);
                    var offset = new Vector3(0f, Mathf.Sin(angle) * 0.24f, Mathf.Cos(angle) * 0.24f);
                    v.position = anchor + offset;
                    v.localScale = Vector3.Min(v.localScale, new Vector3(0.18f, 0.12f, 0.20f));
                    EditorUtility.SetDirty(v);
                }

                // Convert coarse opaque fracture slabs into glowing translucent crystal motes tucked cleanly out of middle sightlines
                var isViolet = z.gameObject.name.Contains("violet") || z.gameObject.name.Contains("Decoder");
                var crystalMat = isViolet ? mats.CrystalViolet : mats.CrystalBlue;
                for (var i = 0; i < chips.Count; i++)
                {
                    var c = chips[i];
                    var mr = c.GetComponent<MeshRenderer>();
                    if (mr && !isWardDust && !isSignalWindow)
                    {
                        mr.sharedMaterial = crystalMat;
                        EditorUtility.SetDirty(mr);
                    }
                    if (isWardDust || isSignalWindow) continue;

                    var maxDim = c.gameObject.name.Contains("High orbit") ? 0.22f : 0.11f;
                    var ls = c.localScale;
                    var peak = Mathf.Max(ls.x, Mathf.Max(ls.y, ls.z));
                    if (peak > maxDim && peak > 0.001f)
                        c.localScale = ls * (maxDim / peak);

                    var orbitPos = c.position;
                    if ((orbitPos - anchor).magnitude > 2.2f || orbitPos.y < 1.8f)
                    {
                        var a = i * 2.39996f;
                        var rad = 0.45f + (i % 4) * 0.22f;
                        c.position = anchor + new Vector3(Mathf.Cos(a) * 0.25f, 0.45f + Mathf.Sin(a) * rad * 0.55f, Mathf.Cos(a * 0.7f) * rad);
                    }
                    EditorUtility.SetDirty(c);
                }
            }
        }

        private static void WireAmbientMotionDetails(Transform station, PolishMaterials mats)
        {
            // Animate Chronostat segmented rim & iris mechanisms softly across Observatory
            var obs = station.Find("Memory Observatory");
            if (obs)
            {
                var iris = obs.Find("Chapter room environment art/High orbit glacial shards/Fitted room mechanisms/Chronostat reference iris");
                if (iris)
                {
                    for (var i = 0; i < iris.childCount; i++)
                    {
                        var c = iris.GetChild(i);
                        if (c.name.StartsWith("Aperture leaf", StringComparison.Ordinal))
                        {
                            var kd = c.gameObject.GetComponent<StationKineticDetail>() ?? c.gameObject.AddComponent<StationKineticDetail>();
                            kd.Configure(StationKineticDetail.MotionMode.OscillateAngle, Vector3.forward, 0.8f, 12f, i * 0.6f);
                        }
                    }
                }
            }

            // Animate aperture leaves inside every Fitted room mechanisms hub across the whole station
            foreach (var z in station.GetComponentsInChildren<RoomEnvironmentMotion>(true))
            {
                var mech = z.transform.Find("Fitted room mechanisms");
                if (!mech) continue;
                var idx = 0;
                foreach (var t in mech.GetComponentsInChildren<Transform>(true))
                {
                    if (t.name.StartsWith("Aperture leaf", StringComparison.Ordinal) ||
                        t.name.StartsWith("Memory resonance", StringComparison.Ordinal))
                    {
                        var kd = t.gameObject.GetComponent<StationKineticDetail>() ?? t.gameObject.AddComponent<StationKineticDetail>();
                        kd.Configure(StationKineticDetail.MotionMode.FloatBob, Vector3.up, 1.05f, 0.025f, idx++ * 0.45f);
                    }
                }
            }
            _ = mats;
        }
    }
}
