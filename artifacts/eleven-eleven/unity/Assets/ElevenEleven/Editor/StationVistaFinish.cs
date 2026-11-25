using System;
using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using static ElevenEleven.Editor.GodotRoomAssembly;

namespace ElevenEleven.Editor
{
    internal static class StationVistaFinish
    {
        private const string Scene = "Assets/ElevenEleven/Scenes/ChapterRoom01.unity";
        private const string Folder = "Assets/ElevenEleven/Opening/Stormworks/";
        private const string FinishRoot = "Echo Station architectural finish";

        [MenuItem("11.11/Apply Echo Station Finish")]
        public static void Upgrade()
        {
            if (!Application.isBatchMode && !EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo()) return;
            var scene = EditorSceneManager.OpenScene(Scene);
            var station = scene.GetRootGameObjects().Single(root => root.name == "Room content").transform.Find("Echo Station");
            Dress(station);
            if (!EditorSceneManager.SaveScene(scene)) throw new InvalidOperationException("Could not save the Echo Station finish.");
            Debug.Log("ECHO_STATION_FINISH_SAVED");
        }

        public static void UpgradeAndReview()
        {
            Upgrade();
            StormworksSmoke.Run();
        }

        internal static void Dress(Transform station)
        {
            var previous = station.Find(FinishRoot);
            if (previous != null) UnityEngine.Object.DestroyImmediate(previous.gameObject);
            var finish = Node(station, FinishRoot, Vector3.zero);
            var hull = Finish("Echo Station mineral enamel", new Color(0.092f, 0.14f, 0.16f), 0.18f, 0.31f);
            var steel = Finish("Echo Station brushed frame", new Color(0.28f, 0.34f, 0.33f), 0.50f, 0.46f);
            ApplyBrushedSteel(steel);
            var zinc = Finish("Echo Station safety enamel", new Color(0.49f, 0.33f, 0.17f), 0.16f, 0.40f);
            var amber = Finish("Echo Station amber lens", new Color(0.97f, 0.52f, 0.18f), 0.0f, 0.43f, 1.0f);
            var aqua = Finish("Echo Station aqua lens", new Color(0.35f, 0.82f, 0.77f), 0.0f, 0.42f, 0.72f);

            var basin = StormworksConstruction.PersistentMaterial("Echo Station basin", "StormworksSurface.shader");
            basin.SetColor("_BaseColor", new Color(0.047f, 0.095f, 0.119f));
            basin.SetColor("_ShadowTone", new Color(0.10f, 0.23f, 0.33f));
            basin.SetFloat("_Wetness", 0.83f);
            basin.SetFloat("_WaterBody", 1f);
            basin.SetFloat("_WaterShimmer", 0.48f);
            basin.SetFloat("_PanelScale", 0.55f);
            Save(basin);
            station.Find("Water below").GetComponent<MeshRenderer>().sharedMaterial = basin;

            var tread = StormworksConstruction.PersistentMaterial("Echo Station bridge deck", "StormworksSurface.shader");
            tread.SetColor("_BaseColor", new Color(0.22f, 0.26f, 0.285f));
            tread.SetColor("_ShadowTone", new Color(0.16f, 0.20f, 0.25f));
            tread.SetFloat("_Wetness", 0.51f);
            tread.SetFloat("_PanelScale", 0.65f);
            Save(tread);
            StationSurfaceDressing.EchoStationBridge(finish, tread);
            BuildBridge(finish, hull, steel, aqua);
            BuildRelay(finish, hull, steel, zinc, amber);
            station.Find("Relay sign backplate").localPosition = new Vector3(-15f, 3.24f, 54.59f);
            station.Find("Relay").localPosition = new Vector3(-15f, 3.24f, 54.495f);
            BuildEastThreshold(finish, hull, steel, aqua);
            DressClockPier(finish, hull, steel, aqua);

            var structure = station.Find("Stormworks structural modules");
            RetunePool(structure, "Intake spill left", new Color(0.54f, 0.79f, 0.73f), 6.4f);
            RetunePool(structure, "Observation spill right", new Color(0.44f, 0.55f, 0.88f), 5.4f);
            RetunePool(structure, "Clock apparatus glow", new Color(0.48f, 0.79f, 0.81f), 12.0f);
            RetunePool(structure, "Tailwater magenta", new Color(0.33f, 0.44f, 0.73f), 4.8f);
            RetunePool(structure, "Tailwater blue", new Color(0.27f, 0.56f, 0.81f), 5.1f);
            RetunePool(station, "Reflector wash", new Color(0.42f, 0.61f, 0.75f), 3.4f);
            RetunePool(station, "East lab wash", new Color(0.45f, 0.72f, 0.72f), 4.7f);
            SetSpot(station.Find("Relay pool light").GetComponent<Light>(), new Vector3(-14.0f, 4.55f, 54.01f),
                new Vector3(-15.03f, 0.96f, 55.8f), new Color(1.0f, 0.78f, 0.48f), 15f, 8.5f, 72f, true);
            var bridgeKey = Node(finish, "Cold span light", Vector3.zero).gameObject.AddComponent<Light>();
            SetSpot(bridgeKey, new Vector3(-2.08f, 5.17f, 44.3f), new Vector3(-0.34f, 0.01f, 51.3f),
                new Color(0.71f, 0.87f, 1f), 23f, 16f, 51f, false);
        }

        private static void BuildBridge(Transform finish, Material hull, Material steel, Material guide)
        {
            foreach (var side in new[] { -1f, 1f })
            {
                Beam(finish, "Deck longitudinal box girder", hull, new Vector3(side * 2.61f, -0.61f, 56.42f),
                    new Vector3(0.29f, 0.36f, 32.9f));
                foreach (var z in new[] { 44.5f, 52.4f, 60.5f, 68.6f })
                {
                    Beam(finish, "Truss base", steel, new Vector3(side * 2.24f, -2.50f, z), new Vector3(0.48f, 3.88f, 0.60f));
                    Brace(finish, "Triangulated deck brace", hull, new Vector3(side * 2.24f, -2.7f, z),
                        new Vector3(side * 2.57f, -0.62f, z + 2.45f), 0.22f);
                    Beam(finish, "Pier shroud", hull, new Vector3(side * 2.24f, -3.84f, z), new Vector3(0.75f, 0.74f, 0.85f));
                }
                foreach (var z in new[] { 44.0f, 49.4f, 54.8f, 60.2f, 65.6f, 71.0f })
                {
                    Beam(finish, "Bridge edge reflector seat", steel, new Vector3(side * 2.70f, 0.008f, z),
                        new Vector3(0.20f, 0.017f, 0.65f));
                    Beam(finish, "Bridge inset glass guide", guide, new Vector3(side * 2.70f, 0.021f, z),
                        new Vector3(0.072f, 0.013f, 0.41f));
                }
            }
        }

        private static void BuildRelay(Transform finish, Material hull, Material steel, Material zinc, Material amber)
        {
            foreach (var x in new[] { -16.43f, -13.56f })
            {
                Beam(finish, "Relay entry post", hull, new Vector3(x, 1.99f, 54.92f),
                    new Vector3(0.23f, 2.19f, 0.33f), true);
                Beam(finish, "Post impact foot", steel, new Vector3(x, 1.15f, 54.91f), new Vector3(0.34f, 0.31f, 0.42f));
                Beam(finish, "Relay lane lens", amber, new Vector3(x, 2.24f, 54.737f), new Vector3(0.073f, 0.57f, 0.037f));
            }
            Beam(finish, "Relay entry lintel", hull, new Vector3(-15f, 3.11f, 54.92f), new Vector3(3.10f, 0.22f, 0.52f), true);
            Beam(finish, "Relay lintel lens", amber, new Vector3(-15f, 3.01f, 54.761f), new Vector3(1.52f, 0.046f, 0.15f));
            foreach (var x in new[] { -16.17f, -13.82f })
                for (var step = 0; step < 6; step++)
                {
                    var mark = Beam(finish, "Stair approach warning inlay", zinc, new Vector3(x, (step + 1) * 0.183f + 0.007f, 50.97f + step * .62f),
                        new Vector3(0.10f, 0.009f, 0.29f));
                    mark.localRotation = Quaternion.Euler(0f, x < -15f ? -28f : 28f, 0f);
                }
        }

        private static void BuildEastThreshold(Transform finish, Material hull, Material steel, Material guide)
        {
            foreach (var x in new[] { 13.55f, 16.45f })
            {
                Beam(finish, "Memory lab shutter jamb skin", hull, new Vector3(x, 1.91f, 62.71f), new Vector3(0.23f, 3.82f, 0.20f));
                Beam(finish, "Shutter inset guide", guide, new Vector3(x, 1.83f, 62.597f), new Vector3(0.077f, 2.64f, 0.033f));
                Beam(finish, "Shutter threshold toe plate", steel, new Vector3(x, 0.012f, 62.32f), new Vector3(0.34f, 0.021f, 0.54f));
            }
            Beam(finish, "Memory lab fascia trim", steel, new Vector3(15f, 4.51f, 62.735f), new Vector3(3.52f, 0.13f, 0.22f));
        }

        private static void DressClockPier(Transform finish, Material hull, Material steel, Material guide)
        {
            var ring = new Vector3(0, 13.70f, 81.22f);
            for (var index = 0; index < 16; index++)
            {
                var angle = (index + 0.5f) * 2f * Mathf.PI / 16f;
                var direction = new Vector3(Mathf.Sin(angle), Mathf.Cos(angle), 0f);
                var brace = Beam(finish, "Chronostat segmented rim", steel, ring + direction * 10.41f,
                    new Vector3(3.46f, 0.10f, 0.11f));
                brace.localRotation = Quaternion.Euler(0f, 0f, -angle * Mathf.Rad2Deg);
            }
            foreach (var side in new[] { -1f, 1f })
            {
                var x = side * 8.4f;
                Beam(finish, "Chronostat buttress", hull, new Vector3(x, 2.37f, 81.41f), new Vector3(1.47f, 5.7f, 1.24f));
                Beam(finish, "Chronostat buttress plated face", steel, new Vector3(x, 2.56f, 80.75f), new Vector3(0.67f, 4.9f, 0.13f));
                Beam(finish, "Chronostat vertical locator", guide, new Vector3(x, 3.43f, 80.669f), new Vector3(0.12f, 1.44f, 0.044f));
                Brace(finish, "Chronostat return bracing", hull, new Vector3(side * 8.4f, 1.33f, 81.4f),
                    new Vector3(side * 5.3f, 6.20f, 83.1f), 0.38f);
            }
        }

        private static void RetunePool(Transform root, string name, Color color, float intensity)
        {
            var light = root.Find(name).GetComponent<Light>();
            light.color = color;
            light.intensity = intensity;
        }

        private static void SetSpot(Light light, Vector3 at, Vector3 target, Color color, float intensity, float range, float outer, bool casts)
        {
            light.transform.localPosition = at;
            light.transform.localRotation = Quaternion.LookRotation(target - at);
            light.type = LightType.Spot;
            light.color = color;
            light.intensity = intensity;
            light.range = range;
            light.spotAngle = outer;
            light.innerSpotAngle = outer * 0.70f;
            light.shadows = casts ? LightShadows.Soft : LightShadows.None;
            light.shadowStrength = 0.79f;
            light.shadowNormalBias = 0.31f;
        }

        private static void Brace(Transform parent, string name, Material material, Vector3 a, Vector3 b, float thickness)
        {
            var span = b - a;
            var brace = Beam(parent, name, material, (a + b) * 0.5f, new Vector3(thickness, thickness, span.magnitude));
            brace.localRotation = Quaternion.LookRotation(span);
        }

        private static Transform Beam(Transform parent, string name, Material material, Vector3 at, Vector3 size, bool casts = false)
        {
            var piece = GameObject.CreatePrimitive(PrimitiveType.Cube);
            piece.name = name;
            piece.transform.SetParent(parent, false);
            piece.transform.localPosition = at;
            piece.transform.localScale = size;
            var renderer = piece.GetComponent<MeshRenderer>();
            renderer.sharedMaterial = material;
            renderer.shadowCastingMode = casts ? ShadowCastingMode.On : ShadowCastingMode.Off;
            UnityEngine.Object.DestroyImmediate(piece.GetComponent<Collider>());
            return piece.transform;
        }

        private static Material Finish(string name, Color tint, float metallic, float smoothness, float glow = 0f)
        {
            var path = Folder + name + ".mat";
            var material = AssetDatabase.LoadAssetAtPath<Material>(path);
            if (material == null)
            {
                material = new Material(Shader.Find("Universal Render Pipeline/Lit"));
                AssetDatabase.CreateAsset(material, path);
            }
            material.color = tint;
            material.SetFloat("_Metallic", metallic);
            material.SetFloat("_Smoothness", smoothness);
            if (glow > 0f)
            {
                material.SetColor("_EmissionColor", tint * glow);
                material.EnableKeyword("_EMISSION");
            }
            Save(material);
            return material;
        }

        private static void ApplyBrushedSteel(Material steel)
        {
            const string source = Folder + "StationFinishes/Station-BrushedSteel-";
            var normal = (TextureImporter)AssetImporter.GetAtPath(source + "Normal.png");
            if (normal.textureType != TextureImporterType.NormalMap)
            {
                normal.textureType = TextureImporterType.NormalMap;
                normal.SaveAndReimport();
            }
            var mask = (TextureImporter)AssetImporter.GetAtPath(source + "MetalSmooth.png");
            if (mask.sRGBTexture)
            {
                mask.sRGBTexture = false;
                mask.SaveAndReimport();
            }
            steel.SetTexture("_BaseMap", AssetDatabase.LoadAssetAtPath<Texture2D>(source + "Base.png"));
            steel.SetTexture("_BumpMap", AssetDatabase.LoadAssetAtPath<Texture2D>(source + "Normal.png"));
            steel.SetTexture("_MetallicGlossMap", AssetDatabase.LoadAssetAtPath<Texture2D>(source + "MetalSmooth.png"));
            steel.SetFloat("_BumpScale", 0.84f);
            steel.SetFloat("_Smoothness", 0.81f);
            steel.EnableKeyword("_NORMALMAP");
            steel.EnableKeyword("_METALLICSPECGLOSSMAP");
            Save(steel);
        }

        private static void Save(Material material)
        {
            EditorUtility.SetDirty(material);
            AssetDatabase.SaveAssetIfDirty(material);
        }
    }
}
