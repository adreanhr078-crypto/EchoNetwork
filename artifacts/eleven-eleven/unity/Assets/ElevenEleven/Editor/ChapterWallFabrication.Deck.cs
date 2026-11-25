using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using static ElevenEleven.Editor.GodotRoomAssembly;
using Object = UnityEngine.Object;

namespace ElevenEleven.Editor
{
    internal static partial class ChapterWallFabrication
    {
        [MenuItem("11.11/Finish Surveillance Deck Plates")]
        public static void DetailSurveillanceDeck()
        {
            if (!Application.isBatchMode && !EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo()) return;
            var scene = EditorSceneManager.OpenScene(ScenePath);
            var content = scene.GetRootGameObjects().Single(root => root.name == "Room content").transform;
            var walk = content.Find("Echo Station/Surveillance and mirror/Surveillance scanner gallery/Graphite deck and recessed drainage");
            if (!walk) throw new InvalidDataException("Form the scanner gallery before the deck plates.");
            var colliders = content.GetComponentsInChildren<Collider>(true)
                .ToDictionary(collider => collider, collider => EditorJsonUtility.ToJson(collider));
            var steel = AssetDatabase.LoadAssetAtPath<Material>(Art + "StationFinishes/Chronostat oxide-filled steel.mat");
            var baseMap = ImportDeckMap("Base", TextureImporterType.Default, true);
            var normal = ImportDeckMap("Normal", TextureImporterType.NormalMap, false);
            var metalSmooth = ImportDeckMap("MetalSmooth", TextureImporterType.Default, false);
            var aisle = DeckMaterial("Surveillance aggregate grip steel", new Color(.60f,.535f,.45f), .53f, 1.27f);
            var lane = DeckMaterial("Surveillance worn graphite slabs", new Color(.68f,.603f,.51f), .71f, 1.13f);
            var drain = FinishAt(steel, "Surveillance recessed drain well", new Color(.18f,.166f,.143f), .28f);
            var edges = FinishAt(steel, "Surveillance polished slab bevel", new Color(.57f,.503f,.425f), .64f);
            var inset = FinishAt(steel, "Surveillance countersunk hardware", new Color(.28f,.259f,.226f), .35f);
            var steps = FinishAt(steel, "Surveillance grate and screw heads", new Color(.52f,.495f,.444f), .53f);

            var plates = new DeckPlates();
            int total = 0;
            float[] mainSeams = { .08f, 4.4f, 9.2f, 14.75f, 20.8f, 27.1f, 31.85f, 35.91f };
            float[] stagger = { .08f, 3.6f, 8.6f, 13.8f, 19.7f, 25.8f, 31.2f, 35.91f };
            foreach (var (left, right, slot, shift) in new[]
                     {
                         (-13.95f, -9.44f, 0, false), (-9.44f, -4.92f, 0, true),
                         (-4.51f, 0f, 1, false), (0f, 4.51f, 1, false),
                         (4.92f, 9.44f, 0, true), (9.44f, 13.95f, 0, false)
                     })
            {
                var seams = shift ? stagger : mainSeams;
                for (var i = 0; i + 1 < seams.Length; i++)
                {
                    plates.Slab(left + .011f, right - .011f, seams[i] + .013f, seams[i + 1] - .013f, slot);
                    total++;
                }
            }
            foreach (var x in new[] { -4.715f, 4.715f }) plates.Drain(x, .18f, 35.82f);
            const string meshName = "Surveillance zoned deck geometry";
            var rebuilt = plates.Build(meshName);
            var target = AssetDatabase.LoadAssetAtPath<Mesh>(Folder + meshName + ".asset");
            EditorUtility.CopySerialized(rebuilt, target);
            Object.DestroyImmediate(rebuilt);
            EditorUtility.SetDirty(target);
            walk.GetComponent<MeshRenderer>().sharedMaterials = new[] { aisle, lane, drain, edges, inset, steps };
            var afterwards = content.GetComponentsInChildren<Collider>(true);
            if (afterwards.Length != colliders.Count ||
                afterwards.Any(c => !colliders.TryGetValue(c, out var state) || state != EditorJsonUtility.ToJson(c)))
                throw new InvalidDataException("Deck plates changed gameplay collision.");
            AssetDatabase.SaveAssets();
            if (!EditorSceneManager.SaveScene(scene)) throw new IOException("Could not save the fitted deck plates.");
            Debug.Log($"ECHO_SURVEILLANCE_DECK_DETAIL plates={total} drain_runs=2 cased_bolts={total * 4} colliders={afterwards.Length}");

            Material DeckMaterial(string name, Color tint, float smoothness, float bump)
            {
                var result = FinishAt(steel, name, tint, smoothness);
                result.SetTexture("_BaseMap", baseMap);
                result.SetTexture("_BumpMap", normal);
                result.SetTexture("_MetallicGlossMap", metalSmooth);
                result.SetFloat("_BumpScale", bump);
                result.EnableKeyword("_METALLICSPECGLOSSMAP");
                result.EnableKeyword("_NORMALMAP");
                return result;
            }
        }

        private static Texture2D ImportDeckMap(string label, TextureImporterType type, bool srgb)
        {
            var path = Folder + "SurveillanceDeck-" + label + ".png";
            var imp = AssetImporter.GetAtPath(path) as TextureImporter ??
                throw new FileNotFoundException("The authored deck surface map is missing.", path);
            if (imp.textureType != type || imp.sRGBTexture != srgb || imp.anisoLevel != 8 ||
                imp.wrapMode != TextureWrapMode.Repeat || !imp.mipmapEnabled || imp.maxTextureSize != 1024)
            {
                imp.textureType = type;
                imp.sRGBTexture = srgb;
                imp.anisoLevel = 8;
                imp.wrapMode = TextureWrapMode.Repeat;
                imp.mipmapEnabled = true;
                imp.maxTextureSize = 1024;
                imp.SaveAndReimport();
            }
            return AssetDatabase.LoadAssetAtPath<Texture2D>(path);
        }

        private sealed class DeckPlates
        {
            private readonly List<Vector3> vertices = new();
            private readonly List<Vector2> uv = new();
            private readonly List<int>[] faces = Enumerable.Range(0, 6).Select(_ => new List<int>()).ToArray();
            private const float Top = .010f;

            internal void Slab(float x0, float x1, float z0, float z1, int slot)
            {
                var outside = Outline(x0, x1, z0, z1, .057f, -.004f);
                var inside = Outline(x0 + .013f, x1 - .013f, z0 + .013f, z1 - .013f, .047f, Top);
                var variation = new Vector2(Mathf.Repeat(x0 * .177f, 1f), Mathf.Repeat(z0 * .211f, 1f));
                Fan(inside, slot, variation);
                for (var i = 0; i < outside.Length; i++)
                {
                    var next = (i + 1) % outside.Length;
                    Face(3, outside[i], outside[next], inside[next], inside[i]);
                }
                foreach (var x in new[] { x0 + .134f, x1 - .134f })
                foreach (var z in new[] { z0 + .148f, z1 - .148f })
                {
                    Disk(x, z, .029f, Top + .0008f, 10, 4);
                    Disk(x, z, .017f, Top + .0021f, 6, 5);
                }
            }

            internal void Drain(float x, float z0, float z1)
            {
                Face(2, new Vector3(x - .207f, -.0047f, z0), new Vector3(x - .207f, -.0047f, z1),
                    new Vector3(x + .207f, -.0047f, z1), new Vector3(x + .207f, -.0047f, z0));
                for (var z = z0 + .07f; z < z1 - .07f; z += .152f)
                {
                    Face(5, new Vector3(x - .177f, .003f, z), new Vector3(x - .177f, .003f, z + .035f),
                        new Vector3(x + .177f, .003f, z + .035f), new Vector3(x + .177f, .003f, z));
                }
            }

            private static Vector3[] Outline(float x0, float x1, float z0, float z1, float c, float y)
                => new[]
                {
                    new Vector3(x0+c,y,z0), new Vector3(x0,y,z0+c), new Vector3(x0,y,z1-c), new Vector3(x0+c,y,z1),
                    new Vector3(x1-c,y,z1), new Vector3(x1,y,z1-c), new Vector3(x1,y,z0+c), new Vector3(x1-c,y,z0)
                };

            private void Disk(float x, float z, float radius, float y, int segments, int slot)
            {
                var points = new Vector3[segments];
                for (var i = 0; i < segments; i++)
                {
                    var angle = -(Mathf.PI * 2f * i / segments);
                    points[i] = new Vector3(x + radius * Mathf.Cos(angle), y, z + radius * Mathf.Sin(angle));
                }
                Fan(points, slot, Vector2.zero);
            }

            private void Fan(Vector3[] shape, int slot, Vector2 variation)
            {
                var first = vertices.Count;
                Vertex(shape.Aggregate(Vector3.zero, (sum, vertex) => sum + vertex) / shape.Length, variation);
                foreach (var point in shape) Vertex(point, variation);
                for (var i = 0; i < shape.Length; i++)
                    faces[slot].AddRange(new[] { first, first + i + 1, first + ((i + 1) % shape.Length) + 1 });
            }

            private void Face(int slot, Vector3 a, Vector3 b, Vector3 c, Vector3 d)
            {
                var start = vertices.Count;
                foreach (var point in new[] { a, b, c, d }) Vertex(point, Vector2.zero);
                faces[slot].AddRange(new[] { start, start + 1, start + 2, start, start + 2, start + 3 });
            }

            private void Vertex(Vector3 point, Vector2 variation)
            {
                vertices.Add(point);
                uv.Add(new Vector2(point.x * .47f, point.z * .47f) + variation);
            }

            internal Mesh Build(string name)
            {
                var mesh = new Mesh { name = name, subMeshCount = faces.Length };
                mesh.SetVertices(vertices);
                mesh.SetUVs(0, uv);
                for (var slot = 0; slot < faces.Length; slot++) mesh.SetTriangles(faces[slot], slot);
                mesh.RecalculateNormals();
                mesh.RecalculateTangents();
                mesh.RecalculateBounds();
                return mesh;
            }
        }
    }
}
