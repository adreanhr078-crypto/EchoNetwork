using System;
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using Object = UnityEngine.Object;

namespace ElevenEleven.Editor
{
    internal static class OpeningRoomFidelity
    {
        private const string RoomPath = "Assets/ElevenEleven/Opening/Room01/";
        private const string GeneratedPath = RoomPath + "Fidelity/";
        private const float RoomWidth = 18f;
        private const float RoomLength = 25.4f;
        private const float RoomHeight = 7.2f;
        private const float RoomCenterZ = 5.5f;

        internal static void Build(Transform sectorRoot, Material wall, Material deck, Material gate)
        {
            var floor = sectorRoot.Find("Flooded deck");
            var door = sectorRoot.Find("Blast gate/Sliding door");
            if (floor == null || door == null || !Mathf.Approximately(door.localPosition.z, 18f) ||
                Vector3.Distance(floor.localPosition, new Vector3(0f, -0.2f, RoomCenterZ)) > 0.001f ||
                Vector3.Distance(floor.localScale, new Vector3(RoomWidth, 0.4f, RoomLength)) > 0.001f)
                throw new InvalidDataException("Sector 11 does not match the 18 by 25.4 metre Godot room and gate layout.");

            if (!AssetDatabase.IsValidFolder(GeneratedPath.TrimEnd('/')))
                AssetDatabase.CreateFolder(RoomPath.TrimEnd('/'), "Fidelity");
            var supplyCase = AssetDatabase.LoadAssetAtPath<GameObject>(RoomPath + "SupplyCase.glb");
            if (supplyCase == null) throw new FileNotFoundException("Import the original Sector 11 supply case.", RoomPath + "SupplyCase.glb");

            var root = new GameObject("Godot Room 01 architectural details").transform;
            root.SetParent(sectorRoot, false);
            var cube = PrimitiveMesh(PrimitiveType.Cube);
            var cylinder = PrimitiveMesh(PrimitiveType.Cylinder);

            var ribs = new List<CombineInstance>();
            var trusses = new List<CombineInstance>();
            var deckPanels = new List<CombineInstance>();
            var joints = new List<CombineInstance>();
            var rails = new List<CombineInstance>();
            var beacons = new List<CombineInstance>();
            var wallBands = new List<CombineInstance>();

            // Source grid and dimensions from sector11_visual_shell.gd, opening_only.
            for (var bay = 0; bay < 5; bay++)
            {
                var z = 5f - bay * 5f;
                foreach (var side in new[] { -1f, 1f })
                    Add(ribs, cube, new Vector3(side * 8.78f, 3.35f, z), new Vector3(0.42f, 6.7f, 0.55f));
                Add(ribs, cube, new Vector3(0f, RoomHeight - 0.6f, z), new Vector3(17.3f, 0.38f, 0.6f));
                Add(trusses, cube, new Vector3(0f, RoomHeight - 1.15f, z), new Vector3(16.2f, 0.12f, 0.26f));
            }

            for (var row = 0; row < 4; row++)
            {
                var z = 1f - row * 5f;
                Add(joints, cube, new Vector3(0f, 0.014f, z), new Vector3(RoomWidth, 0.018f, 0.045f));
                foreach (var side in new[] { -1f, 1f })
                {
                    var x = side * 6.3f;
                    Add(deckPanels, cube, new Vector3(x, 0.018f, z - 2.2f), new Vector3(2.6f, 0.028f, 1.15f));
                    Add(joints, cube, new Vector3(x + side * 1.18f, 0.036f, z - 2.2f), new Vector3(0.045f, 0.02f, 0.92f));
                }
            }

            foreach (var side in new[] { -1f, 1f })
            {
                Add(ribs, cylinder, new Vector3(side * 6.6f, RoomHeight - 1f, -RoomCenterZ),
                    new Vector3(0.24f, (RoomLength - 2f) * 0.5f, 0.24f), Quaternion.Euler(-90f, 0f, 0f));
                Add(rails, cube, new Vector3(side * 8.15f, 0.15f, -RoomCenterZ), new Vector3(0.1f, 0.08f, RoomLength - 1.5f));
                // opening_wall_finish.gdshader places the enamel guide at y = 1.30–1.53 m.
                Add(wallBands, cube, new Vector3(side * 8.59f, 1.415f, -RoomCenterZ), new Vector3(0.045f, 0.23f, RoomLength - 0.24f));
            }

            // Place the sign just inside the inner wall face so the text stays legible.
            Add(trusses, cube, new Vector3(8.53f, 6.4f, -8f), new Vector3(0.06f, 0.52f, 5.1f));
            Add(rails, cube, new Vector3(8.49f, 6.13f, -8f), new Vector3(0.025f, 0.025f, 5.05f));
            BuildSign(root, "SectorIdentification", "SECTOR 11  /  NEURAL CONTAINMENT", new Vector3(8.485f, 6.40f, 8f),
                90f, new Color(0.68f, 0.87f, 0.93f), 4.7f, 0.28f);

            // Use static emitters at the original beacon bays and retain the existing light budget.
            foreach (var z in new[] { 0.5f, -14.5f })
            {
                Add(trusses, cube, new Vector3(0f, 6.86f, z), new Vector3(0.52f, 0.12f, 0.24f));
                Add(beacons, cube, new Vector3(0f, 6.785f, z), new Vector3(0.34f, 0.035f, 0.12f));
            }

            var frame = CreateMaterial("MachinedContainmentFrame", gate, new Color(0.35f, 0.42f, 0.49f), 0.42f, 0.48f);
            AddBatch(root, "Containment ribs and coolant conduits", "ContainmentRibs", ribs, frame, true);
            AddBatch(root, "Service trusses and housings", "ServiceTrusses", trusses, gate, true);
            AddBatch(root, "Wall enamel guide bands", "WallEnamelGuideBands", wallBands,
                CreateMaterial("WallEnamelGuideBand", wall, new Color(0.17f, 0.35f, 0.41f), 0.22f, 0.40f), false);
            AddBatch(root, "Maintenance deck panels", "MaintenanceDeckPanels", deckPanels,
                CreateMaterial("MaintenanceDeckPanel", deck, new Color(0.18f, 0.22f, 0.27f), 0.22f, 0.45f), false);
            AddBatch(root, "Floor expansion joints", "FloorExpansionJoints", joints,
                CreateMaterial("FloorExpansionJoint", deck, new Color(0.05f, 0.065f, 0.087f), 0.3f, 0.48f), false);
            AddBatch(root, "Cyan signal rails", "CyanSignalRails", rails,
                CreateMaterial("CyanSignalRail", gate, new Color(0.025f, 0.22f, 0.26f), 0.3f, 0.58f,
                    new Color(0.015f, 0.38f, 0.50f)), false);
            AddBatch(root, "Amber containment practicals", "AmberContainmentPracticals", beacons,
                CreateMaterial("AmberContainmentPractical", gate, new Color(0.34f, 0.13f, 0.046f), 0.16f, 0.55f,
                    new Color(0.80f, 0.18f, 0.035f)), false);

            BuildSupplyCase(root, supplyCase, "SupplyCrate_A1", new Vector3(5f, 0f, -6f), 0f);
            BuildSupplyCase(root, supplyCase, "SupplyCrate_A2", new Vector3(-6f, 0f, 4f), -15f);
            BuildGateVisuals(root, door, cube, frame, gate);
            BuildWetDeck(floor, deck);
            ApplyLighting(sectorRoot, wall);
        }

        private static Vector3 UnityPosition(Vector3 godot) => new Vector3(godot.x, godot.y, -godot.z);

        private static void Add(List<CombineInstance> batch, Mesh mesh, Vector3 godotPosition, Vector3 size,
            Quaternion? rotation = null)
        {
            batch.Add(new CombineInstance
            {
                mesh = mesh,
                transform = Matrix4x4.TRS(UnityPosition(godotPosition), rotation ?? Quaternion.identity, size),
            });
        }

        private static Mesh PrimitiveMesh(PrimitiveType type)
        {
            var primitive = GameObject.CreatePrimitive(type);
            var mesh = primitive.GetComponent<MeshFilter>().sharedMesh;
            Object.DestroyImmediate(primitive);
            return mesh;
        }

        private static void AddBatch(Transform root, string name, string assetName, List<CombineInstance> parts,
            Material material, bool castsShadows)
        {
            var mesh = new Mesh { name = assetName };
            mesh.CombineMeshes(parts.ToArray(), true, true, false);
            mesh.RecalculateBounds();
            var item = new GameObject(name, typeof(MeshFilter), typeof(MeshRenderer));
            item.transform.SetParent(root, false);
            item.GetComponent<MeshFilter>().sharedMesh = SaveMesh(assetName, mesh);
            var renderer = item.GetComponent<MeshRenderer>();
            renderer.sharedMaterial = material;
            renderer.shadowCastingMode = castsShadows ? ShadowCastingMode.On : ShadowCastingMode.Off;
            renderer.lightProbeUsage = LightProbeUsage.Off;
        }

        private static Mesh SaveMesh(string name, Mesh generated)
        {
            var path = GeneratedPath + name + ".asset";
            var asset = AssetDatabase.LoadAssetAtPath<Mesh>(path);
            if (asset == null)
            {
                AssetDatabase.CreateAsset(generated, path);
                return generated;
            }
            EditorUtility.CopySerialized(generated, asset);
            Object.DestroyImmediate(generated);
            EditorUtility.SetDirty(asset);
            AssetDatabase.SaveAssetIfDirty(asset);
            return asset;
        }

        private static Material CreateMaterial(string name, Material basis, Color color, float metallic, float smoothness,
            Color? emission = null)
        {
            var path = GeneratedPath + name + ".mat";
            var material = AssetDatabase.LoadAssetAtPath<Material>(path);
            if (material == null)
            {
                material = new Material(basis);
                AssetDatabase.CreateAsset(material, path);
            }
            material.SetColor("_BaseColor", color);
            material.SetFloat("_Metallic", metallic);
            material.SetFloat("_Smoothness", smoothness);
            if (emission.HasValue)
            {
                material.SetColor("_EmissionColor", emission.Value);
                material.EnableKeyword("_EMISSION");
            }
            EditorUtility.SetDirty(material);
            AssetDatabase.SaveAssetIfDirty(material);
            return material;
        }

        private static void BuildGateVisuals(Transform root, Transform door, Mesh cube, Material frame, Material gate)
        {
            var frameParts = new List<CombineInstance>();
            foreach (var side in new[] { -1f, 1f })
                Add(frameParts, cube, new Vector3(side * 4.2f, 3.5f, -18f), new Vector3(1.2f, 7f, 1.6f));
            Add(frameParts, cube, new Vector3(0f, 6.8f, -18f), new Vector3(9.2f, 1.4f, 1.8f));
            AddBatch(root, "Primary blast gate frame", "PrimaryBlastGateFrame", frameParts, frame, true);

            var armor = CreateMaterial("PrimaryGateArmor", gate, new Color(0.36f, 0.43f, 0.52f), 0.48f, 0.62f);
            foreach (Transform child in door)
                if (child.name == "Gate armor") child.GetComponent<MeshRenderer>().sharedMaterial = armor;
            door.Find("Gate panel").GetComponent<MeshRenderer>().sharedMaterial =
                CreateMaterial("PrimaryGateDoor", gate, new Color(0.22f, 0.28f, 0.36f), 0.43f, 0.44f);

            var seals = new List<CombineInstance>();
            foreach (var side in new[] { -1f, 1f })
                Add(seals, cube, new Vector3(side * 3.35f, 0f, 0.32f), new Vector3(0.07f, 6f, 0.035f));
            Add(seals, cube, new Vector3(0f, 0f, 0.4f), new Vector3(0.12f, 5.6f, 0.08f));
            AddBatch(door, "Amber seals", "PrimaryGateSeals", seals,
                CreateMaterial("PrimaryGateSeal", gate, new Color(0.24f, 0.071f, 0.035f), 0.19f, 0.54f,
                    new Color(0.68f, 0.14f, 0.035f)), false);
            BuildSign(door, "GateStatusLabel", "SECTOR 11  //  SEALED", new Vector3(0f, 2.15f, -0.46f), 0f,
                new Color(1f, 0.68f, 0.35f), 4.2f, 0.26f);
        }

        private static void ApplyLighting(Transform sectorRoot, Material wall)
        {
            var finish = CreateMaterial("ContainmentWallFinish", wall, new Color(0.26f, 0.30f, 0.37f), 0.22f, 0.42f);
            foreach (var name in new[] { "West wall", "East wall", "Rear wall", "Ceiling", "West threshold wall", "East threshold wall", "Threshold ceiling" })
                sectorRoot.Find(name).GetComponent<MeshRenderer>().sharedMaterial = finish;

            // URP's existing PC and Mobile tiers use coloured ambient bounce and the existing light budget.
            RenderSettings.ambientMode = AmbientMode.Trilight;
            RenderSettings.ambientSkyColor = new Color(0.49f, 0.57f, 0.70f);
            RenderSettings.ambientEquatorColor = new Color(0.39f, 0.43f, 0.57f);
            RenderSettings.ambientGroundColor = new Color(0.26f, 0.25f, 0.42f);
            RenderSettings.ambientIntensity = 1f;

            var sceneRoots = sectorRoot.gameObject.scene.GetRootGameObjects();
            var fill = Array.Find(sceneRoots, item => item.name == "Cool overhead fill").GetComponent<Light>();
            fill.color = new Color(0.85f, 0.92f, 1f);
            fill.intensity = 0.95f;
            var recovery = Array.Find(sceneRoots, item => item.name == "Recovery glow").GetComponent<Light>();
            recovery.color = new Color(0.86f, 0.93f, 1f);
            recovery.intensity = 1.95f;
            var evidence = Array.Find(sceneRoots, item => item.name == "Evidence wash").GetComponent<Light>();
            evidence.color = new Color(0.44f, 0.81f, 1f);
            evidence.intensity = 2.4f;
        }

        private static void BuildSign(Transform root, string name, string label, Vector3 position, float yaw, Color color,
            float width, float height)
        {
            var sign = new GameObject(name, typeof(TextMesh));
            sign.transform.SetParent(root, false);
            sign.transform.SetLocalPositionAndRotation(position, Quaternion.Euler(0f, yaw, 0f));
            var text = sign.GetComponent<TextMesh>();
            text.font = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
            text.anchor = TextAnchor.MiddleCenter;
            text.alignment = TextAlignment.Center;
            text.fontSize = 48;
            text.characterSize = 0.12f;
            text.color = color;
            text.text = label;
            var renderer = sign.GetComponent<MeshRenderer>();
            renderer.sharedMaterial = text.font.material;
            renderer.shadowCastingMode = ShadowCastingMode.Off;
            renderer.receiveShadows = false;
            var bounds = renderer.bounds.size;
            var horizontal = Mathf.Max(bounds.x, bounds.z);
            if (horizontal > 0.01f && bounds.y > 0.01f)
                sign.transform.localScale *= Mathf.Min(width / horizontal, height / bounds.y);
        }

        private static void BuildSupplyCase(Transform root, GameObject source, string name, Vector3 godotPosition, float godotYaw)
        {
            var instance = Object.Instantiate(source, root, false);
            instance.name = name;
            // glTFast mirrors the local mesh in X. The native room mirrors world Z.
            instance.transform.SetLocalPositionAndRotation(UnityPosition(godotPosition), Quaternion.Euler(0f, 180f - godotYaw, 0f));
            var collider = instance.AddComponent<BoxCollider>();
            collider.center = new Vector3(0f, 0.45f, 0f);
            collider.size = Vector3.one * 0.9f;
        }

        private static void BuildWetDeck(Transform floor, Material basis)
        {
            var filter = floor.GetComponent<MeshFilter>();
            var mesh = Object.Instantiate(filter.sharedMesh);
            mesh.name = "WetCeramicDeckUV";
            mesh.hideFlags = HideFlags.None;
            var uv = mesh.uv;
            var vertices = mesh.vertices;
            var normals = mesh.normals;
            for (var i = 0; i < vertices.Length; i++)
                if (normals[i].y > 0.9f) uv[i] = new Vector2(vertices[i].x + 0.5f, vertices[i].z + 0.5f);
            mesh.uv = uv;
            filter.sharedMesh = SaveMesh(mesh.name, mesh);

            const string albedoPath = GeneratedPath + "WetCeramicDeckAlbedo.png";
            const string smoothnessPath = GeneratedPath + "WetCeramicDeckMetalSmooth.png";
            if (AssetDatabase.LoadAssetAtPath<Texture2D>(albedoPath) == null ||
                AssetDatabase.LoadAssetAtPath<Texture2D>(smoothnessPath) == null)
                BakeDeckMaps(albedoPath, smoothnessPath);

            var material = CreateMaterial("WetCeramicDeck", basis, Color.white, 0.1f, 1f);
            material.SetTexture("_BaseMap", AssetDatabase.LoadAssetAtPath<Texture2D>(albedoPath));
            material.SetTexture("_MetallicGlossMap", AssetDatabase.LoadAssetAtPath<Texture2D>(smoothnessPath));
            material.SetFloat("_SmoothnessTextureChannel", 0f);
            material.EnableKeyword("_METALLICSPECGLOSSMAP");
            EditorUtility.SetDirty(material);
            AssetDatabase.SaveAssetIfDirty(material);
            floor.GetComponent<MeshRenderer>().sharedMaterial = material;
        }

        private static void BakeDeckMaps(string albedoPath, string smoothnessPath)
        {
            const int size = 1024;
            var albedo = new Color32[size * size];
            var smoothness = new Color32[size * size];
            var ceramic = new Color(0.32f, 0.37f, 0.43f);
            var seamColor = new Color(0.09f, 0.115f, 0.145f);
            var coolant = new Color(0.035f, 0.15f, 0.19f);
            for (var row = 0; row < size; row++)
            {
                var z = RoomCenterZ + ((row + 0.5f) / size - 0.5f) * RoomLength;
                for (var column = 0; column < size; column++)
                {
                    var x = ((column + 0.5f) / size - 0.5f) * RoomWidth;
                    var tileX = x / 1.5f;
                    var tileZ = -z / 2.4f;
                    var seamDistance = Mathf.Min(EdgeDistance(tileX) * 1.5f, EdgeDistance(tileZ) * 2.4f);
                    var tileTone = Hash(Mathf.FloorToInt(tileX), Mathf.FloorToInt(tileZ));
                    var wear = Noise(x * 3.5f, z * 3.5f);
                    var baseColor = ceramic * (0.88f + tileTone * 0.20f + (wear - 0.5f) * 0.08f);
                    baseColor = Color.Lerp(baseColor, seamColor, (1f - Smooth(0.004f, 0.029f, seamDistance)) * 0.46f);
                    var leakDistance = new Vector2((x + 2.5f) * 0.9f, (z + 2.8f) * 1.2f).magnitude;
                    var dripDistance = new Vector2(x - 6.6f, z - 5.5f).magnitude;
                    var leak = 1f - Smooth(1.2f, 4.8f, leakDistance);
                    var drip = 1f - Smooth(0.35f, 2.2f, dripDistance);
                    var puddle = 0.7f * Noise(x * 0.85f, z * 0.85f) + 0.3f * Noise(x * 2.1f, z * 2.1f);
                    var wet = Smooth(0.44f, 0.60f, puddle) * Mathf.Max(leak, drip * 0.7f);
                    var damp = Smooth(0.32f, 0.56f, puddle) * leak;
                    var wetColor = Color.Lerp(baseColor * 0.7f, coolant, 0.35f);
                    var color = Color.Lerp(baseColor, wetColor, (wet + damp) * 0.5f);
                    color.a = 1f;
                    var i = row * size + column;
                    albedo[i] = color;
                    smoothness[i] = new Color(0.10f, 0f, 0f, Mathf.Lerp(0.45f + (wear - 0.5f) * 0.12f, 0.86f, wet));
                }
            }
            SaveTexture(albedoPath, albedo, size, false);
            SaveTexture(smoothnessPath, smoothness, size, true);
        }

        private static float EdgeDistance(float value)
        {
            var fraction = value - Mathf.Floor(value);
            return Mathf.Min(fraction, 1f - fraction);
        }

        private static float Smooth(float min, float max, float value)
        {
            var t = Mathf.InverseLerp(min, max, value);
            return t * t * (3f - 2f * t);
        }

        private static float Noise(float x, float z)
        {
            var ix = Mathf.FloorToInt(x);
            var iz = Mathf.FloorToInt(z);
            var fx = Smooth(0f, 1f, x - ix);
            var fz = Smooth(0f, 1f, z - iz);
            return Mathf.Lerp(Mathf.Lerp(Hash(ix, iz), Hash(ix + 1, iz), fx),
                Mathf.Lerp(Hash(ix, iz + 1), Hash(ix + 1, iz + 1), fx), fz);
        }

        private static float Hash(int x, int z)
        {
            unchecked
            {
                var hash = (uint)x * 0x9e3779b9u ^ (uint)z * 0x85ebca6bu;
                hash ^= hash >> 16;
                hash *= 0x7feb352du;
                hash ^= hash >> 15;
                return (hash & 0xffffu) / 65535f;
            }
        }

        private static void SaveTexture(string path, Color32[] pixels, int size, bool linear)
        {
            var image = new Texture2D(size, size, linear ? TextureFormat.RGBA32 : TextureFormat.RGB24, false, linear);
            image.SetPixels32(pixels);
            image.Apply();
            var absolute = Path.Combine(Application.dataPath, path.Substring("Assets/".Length));
            File.WriteAllBytes(absolute, image.EncodeToPNG());
            Object.DestroyImmediate(image);
            AssetDatabase.ImportAsset(path, ImportAssetOptions.ForceSynchronousImport);
            var importer = (TextureImporter)AssetImporter.GetAtPath(path);
            importer.sRGBTexture = !linear;
            importer.alphaSource = linear ? TextureImporterAlphaSource.FromInput : TextureImporterAlphaSource.None;
            importer.wrapMode = TextureWrapMode.Clamp;
            importer.mipmapEnabled = true;
            importer.anisoLevel = 4;
            importer.textureCompression = TextureImporterCompression.Compressed;
            importer.SaveAndReimport();
        }
    }
}
