using System.Collections.Generic;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using static ElevenEleven.Editor.GodotRoomAssembly;

namespace ElevenEleven.Editor
{
    internal static class StationSurfaceDressing
    {
        private const string Folder = "Assets/ElevenEleven/Opening/Stormworks/";
        private static readonly string[] Treads = { "Deck trim", "Guide enamel", "Machine alloy" };
        private static Material[] materials;
        private static Mesh floorModule;
        private static Mesh ceilingModule;

        internal static void Examination(Transform theatre, Material deck)
        {
            var root = Node(theatre, "Examination platform deck", Vector3.zero);
            var (floor, _, palette) = LoadModules(deck);
            var examinationPalette = (Material[])palette.Clone();
            examinationPalette[0] = deck;
            for (var row = 0; row < 4; row++)
                for (var column = 0; column < 4; column++)
                {
                    var tile = new Vector3(-4.5f + column * 3f, 1.201f, 15.5f + row * 3f);
                    Fit(root, "Recessed examination floor cassette", floor, examinationPalette, tile,
                        Vector3.one, (column + row) % 2 * 180f);
                }
        }

        internal static void EchoStationBridge(Transform bridge, Material deck)
        {
            var standardDeck = AssetDatabase.LoadAssetAtPath<Material>(Folder + "Flooded plates.mat");
            var (floor, _, palette) = LoadModules(standardDeck);
            var bridgePalette = (Material[])palette.Clone();
            bridgePalette[0] = deck;
            const float span = 33.1f;
            const int rows = 11;
            for (var row = 0; row < rows; row++)
            {
                var z = 56.35f - span * 0.5f + (row + 0.5f) * span / rows;
                for (var column = 0; column < 2; column++)
                    Fit(bridge, "Drainage bridge floor cassette", floor, bridgePalette,
                        new Vector3((column - 0.5f) * 2.8f, 0.002f, z),
                        new Vector3(2.8f / 3f, 1f, span / rows / 3f), (row + column) % 2 * 180f);
            }
            foreach (Transform platform in bridge.parent)
            {
                if (platform.name != "Suspended service plate") continue;
                var dimensions = platform.localScale;
                var top = platform.localPosition + Vector3.up * (dimensions.y / 2f + 0.002f);
                Fit(bridge, "Suspended maintenance plate tread", floor, bridgePalette, top,
                    new Vector3(dimensions.x / 3f, 0.57f, dimensions.z / 3f), 0f);
            }
        }

        internal static void Opening(Transform room, Material deck)
        {
            var root = Node(room, "Containment floor engineering", Vector3.zero);
            var (floor, _, palette) = LoadModules(deck);
            for (var row = 0; row < 9; row++)
            {
                var z = -7.17f + (row + 0.5f) * 2.8f;
                for (var column = 0; column < 8; column++)
                {
                    var x = -10.5f + column * 3f;
                    Fit(root, "Pressure-rated deck cassette", floor, palette, new Vector3(x, 0f, z),
                        new Vector3(1f, 1f, 2.8f / 3f), (row + column) % 2 * 180f);
                }
            }
        }

        internal static void Specimen(Transform room, Material deck)
        {
            var root = Node(room, "Containment architectural cassettes", Vector3.zero);
            var (floor, ceiling, palette) = LoadModules(deck);
            for (var row = 0; row < 8; row++)
            {
                for (var column = 0; column < 10; column++)
                {
                    var x = -28.5f + column * 3f;
                    var z = -4.5f + row * 3f;
                    Fit(root, "Sealed floor cassette", floor, palette, new Vector3(x, 0, z),
                        new Vector3(1f, 1f, 1f), (row + column) % 2 * 180f);
                }
            }

            for (var bank = 0; bank < 5; bank++)
            {
                for (var row = 0; row < 4; row++)
                {
                    var at = new Vector3(-27f + bank * 6f, 7.22f, -3f + row * 6f);
                    Fit(root, "Ceiling air handling cassette", ceiling, palette, at, Vector3.one, (row % 2) * 180f);
                }
            }

            foreach (var x in new[] { -25.5f, -13f, -2.75f })
            {
                var light = Node(root, "Ceiling wash", new Vector3(x, 6.49f, 7.7f)).gameObject.AddComponent<Light>();
                light.type = LightType.Point;
                light.range = 11f;
                light.intensity = 5.2f;
                light.color = new Color(0.27f, 0.49f, 1f);
            }
        }

        internal static void Archive(Transform room, Material deck)
        {
            var root = Node(room, "Archive cooling infrastructure", Vector3.zero);
            var (floor, ceiling, palette) = LoadModules(deck);
            for (var row = 0; row < 9; row++)
            {
                foreach (var x in new[] { -20.2f, -17.2f, -14.2f, -11.2f, -8.2f, -5.2f, -2.2f })
                    Fit(root, "Archive floor cassette", floor, palette, new Vector3(x, 0.001f, -12f + row * 3f),
                        Vector3.one, (row % 2) * 180f);
            }

            for (var row = 0; row < 4; row++)
            {
                foreach (var x in new[] { -19.0f, -3.0f })
                    Fit(root, "Overhead memory conduits", ceiling, palette, new Vector3(x, 8.52f, -9f + row * 6f),
                        Vector3.one, x > -10f ? 180f : 0f);
            }
        }

        private static (Mesh floor, Mesh ceiling, Material[] palette) LoadModules(Material deck)
        {
            materials ??= new[]
            {
                deck,
                Metal(Treads[0], new Color(0.13f, 0.19f, 0.25f), 0.5f, 0.34f),
                Metal(Treads[1], new Color(0.07f, 0.42f, 0.48f), 0.32f, 0.55f, new Color(0.02f, 0.57f, 0.55f)),
                Metal(Treads[2], new Color(0.16f, 0.12f, 0.23f), 0.74f, 0.72f),
            };
            if (floorModule == null || ceilingModule == null)
            {
                var cube = PrimitiveMesh(PrimitiveType.Cube);
                var cylinder = PrimitiveMesh(PrimitiveType.Cylinder);
                floorModule = Floor(cube, cylinder);
                ceilingModule = Ceiling(cube, cylinder);
            }
            return (floorModule, ceilingModule, materials);
        }

        private static Mesh Floor(Mesh cube, Mesh cylinder)
        {
            var builder = new Module(cube, cylinder);
            builder.Box(0, new Vector3(0, 0.009f, 0), new Vector3(2.932f, 0.023f, 2.932f));
            foreach (var side in new[] { -1f, 1f })
            {
                builder.Box(1, new Vector3(side * 1.438f, 0.029f, 0), new Vector3(0.075f, 0.017f, 2.93f));
                builder.Box(3, new Vector3(0, 0.023f, side * 1.443f), new Vector3(2.828f, 0.016f, 0.065f));
                builder.Box(3, new Vector3(side * 1.239f, 0.027f, 0),
                    new Vector3(0.21f, 0.014f, 1.17f));
                for (var index = 0; index < 7; index++)
                {
                    var z = -0.47f + index * 0.157f;
                    builder.Box(1, new Vector3(side * 1.239f, 0.040f, z), new Vector3(0.16f, 0.009f, 0.034f));
                }
                foreach (var z in new[] { -1.27f, 1.27f })
                {
                    builder.Cylinder(1, new Vector3(side * 1.28f, 0.025f, z), new Vector3(0.062f, 0.008f, 0.062f));
                    builder.Cylinder(3, new Vector3(side * 1.28f, 0.036f, z), new Vector3(0.025f, 0.006f, 0.025f));
                }
                builder.Box(2, new Vector3(side * 1.418f, 0.045f, -0.91f), new Vector3(0.024f, 0.006f, 0.28f));
            }
            return builder.Save("Gasketed deck cassette");
        }

        private static Mesh Ceiling(Mesh cube, Mesh cylinder)
        {
            var builder = new Module(cube, cylinder);
            builder.Box(0, new Vector3(0, -0.10f, 0), new Vector3(5.76f, 0.28f, 5.76f));
            builder.Box(1, new Vector3(0, -0.243f, 0), new Vector3(4.28f, 0.1f, 3.84f));
            foreach (var side in new[] { -1f, 1f })
            {
                builder.Box(1, new Vector3(side * 2.67f, -0.274f, 0), new Vector3(0.31f, 0.35f, 5.94f));
                builder.Box(1, new Vector3(0, -0.274f, side * 2.67f), new Vector3(5.12f, 0.35f, 0.27f));
                builder.Box(3, new Vector3(side * 1.25f, -0.42f, 0), new Vector3(1.42f, 0.25f, 3.10f));
                builder.Box(2, new Vector3(side * 2.46f, -0.345f, 0), new Vector3(0.043f, 0.064f, 4.43f));
                for (var vent = 0; vent < 11; vent++)
                    builder.Box(1, new Vector3(side * 1.25f, -0.602f, (vent - 5) * 0.255f),
                        new Vector3(1.27f, 0.125f, 0.1f), Quaternion.Euler(22f, 0f, 0f));
                for (var i = 0; i < 2; i++)
                {
                    var x = side * (0.19f + i * 0.21f);
                    builder.Cylinder(1, new Vector3(x, -0.42f, 0), new Vector3(0.131f, 2.58f, 0.131f),
                        Quaternion.Euler(90f, 0f, 0f));
                    foreach (var z in new[] { -1.55f, 0f, 1.55f })
                        builder.Cylinder(3, new Vector3(x, -0.42f, z), new Vector3(0.207f, 0.105f, 0.207f),
                            Quaternion.Euler(90f, 0f, 0f));
                }

                foreach (var z in new[] { -2.67f, 2.67f })
                    builder.Cylinder(1, new Vector3(side * 2.68f, -0.49f, z), new Vector3(0.20f, 0.059f, 0.20f));
            }

            builder.Box(3, new Vector3(0, -0.445f, 0), new Vector3(1.39f, 0.22f, 0.59f));
            builder.Box(2, new Vector3(0, -0.566f, 0), new Vector3(0.86f, 0.04f, 0.31f));
            return builder.Save("Air handling cassette");
        }

        private static Mesh PrimitiveMesh(PrimitiveType type)
        {
            var sample = GameObject.CreatePrimitive(type);
            var mesh = sample.GetComponent<MeshFilter>().sharedMesh;
            UnityEngine.Object.DestroyImmediate(sample);
            return mesh;
        }

        private static Material Metal(string name, Color color, float metallic, float smoothness, Color glow = default)
        {
            var path = Folder + name + ".mat";
            var material = AssetDatabase.LoadAssetAtPath<Material>(path);
            if (material == null)
            {
                material = new Material(Shader.Find("Universal Render Pipeline/Lit"));
                AssetDatabase.CreateAsset(material, path);
            }
            material.SetColor("_BaseColor", color);
            material.SetFloat("_Metallic", metallic);
            material.SetFloat("_Smoothness", smoothness);
            material.SetColor("_EmissionColor", glow);
            if (glow.maxColorComponent > 0f) material.EnableKeyword("_EMISSION");
            EditorUtility.SetDirty(material);
            AssetDatabase.SaveAssetIfDirty(material);
            return material;
        }

        private static void Fit(Transform owner, string name, Mesh mesh, Material[] palette, Vector3 at,
            Vector3 scale, float yaw)
        {
            var item = Node(owner, name, at);
            item.localScale = scale;
            item.localRotation = Quaternion.Euler(0f, yaw, 0f);
            item.gameObject.AddComponent<MeshFilter>().sharedMesh = mesh;
            var renderer = item.gameObject.AddComponent<MeshRenderer>();
            renderer.sharedMaterials = palette;
            renderer.shadowCastingMode = ShadowCastingMode.Off;
        }

        private sealed class Module
        {
            private readonly List<CombineInstance>[] submeshes = new List<CombineInstance>[4];
            private readonly Mesh cube;
            private readonly Mesh cylinder;

            internal Module(Mesh cube, Mesh cylinder)
            {
                this.cube = cube;
                this.cylinder = cylinder;
                for (var i = 0; i < submeshes.Length; i++) submeshes[i] = new List<CombineInstance>();
            }

            internal void Box(int material, Vector3 center, Vector3 size, Quaternion? rotation = null) =>
                Append(material, cube, center, size, rotation ?? Quaternion.identity);

            internal void Cylinder(int material, Vector3 center, Vector3 size, Quaternion? rotation = null) =>
                Append(material, cylinder, center, size, rotation ?? Quaternion.identity);

            private void Append(int material, Mesh primitive, Vector3 center, Vector3 size, Quaternion rotation) =>
                submeshes[material].Add(new CombineInstance { mesh = primitive, transform = Matrix4x4.TRS(center, rotation, size) });

            internal Mesh Save(string name)
            {
                var combined = new CombineInstance[submeshes.Length];
                for (var i = 0; i < combined.Length; i++)
                {
                    var segment = new Mesh();
                    segment.CombineMeshes(submeshes[i].ToArray());
                    combined[i] = new CombineInstance { mesh = segment, transform = Matrix4x4.identity };
                }
                var asset = new Mesh { name = name };
                asset.CombineMeshes(combined, false);
                asset.RecalculateBounds();
                var path = Folder + name + ".asset";
                var previous = AssetDatabase.LoadAssetAtPath<Mesh>(path);
                if (previous == null) AssetDatabase.CreateAsset(asset, path);
                else
                {
                    EditorUtility.CopySerialized(asset, previous);
                    UnityEngine.Object.DestroyImmediate(asset);
                    asset = previous;
                    EditorUtility.SetDirty(asset);
                }
                AssetDatabase.SaveAssetIfDirty(asset);
                foreach (var segment in combined) UnityEngine.Object.DestroyImmediate(segment.mesh);
                return asset;
            }
        }
    }
}
