using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using ElevenEleven.Opening;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using static ElevenEleven.Editor.GodotRoomAssembly;

namespace ElevenEleven.Editor
{
    internal static partial class ChapterWallFabrication
    {
        internal const string R48Log = "Laboratory memory log readout";

        public static void FinishLaboratoryInductors()
        {
            var scene = EditorSceneManager.OpenScene(ScenePath);
            var content = scene.GetRootGameObjects().Single(root => root.name == "Room content").transform;
            var station = content.Find("Echo Station");
            var route = station.GetComponent<StormworksRoute>();
            var routeJson = EditorJsonUtility.ToJson(route);
            var collisions = content.GetComponentsInChildren<Collider>(true).ToDictionary(c => c,
                c => (record: EditorJsonUtility.ToJson(c), matrix: c.transform.localToWorldMatrix));
            var bases = station.Cast<Transform>().Where(t => t.name == "Coil base").ToArray();
            var collars = station.Cast<Transform>().Where(t => t.name == "Coil insulator").ToArray();
            var cores = station.Cast<Transform>().Where(t => t.name == "Coil core").ToArray();
            if (bases.Length != 2 || collars.Length != 12 || cores.Length != 2)
                throw new InvalidDataException("The original twin coil assembly was not found.");

            var steel = AssetDatabase.LoadAssetAtPath<Material>(Folder + "Station worked manganese alloy.mat");
            var graphite = AssetDatabase.LoadAssetAtPath<Material>(Folder + "R47 sterile graphite housing.mat");
            var copper = AssetDatabase.LoadAssetAtPath<Material>(Art + "StationFinishes/Chronostat copper hardware.mat");
            var materials = new[] { graphite, steel, copper };
            var baseProfile = new (float radius, float height, int finish)[]
            {
                (0f, -1f, 0), (.462f, -1f, 0), (.501f, -.89f, 1), (.501f, -.66f, 1),
                (.459f, -.61f, 1), (.448f, -.4f, 0), (.448f, .20f, 0), (.481f, .29f, 0),
                (.481f, .49f, 1), (.447f, .56f, 1), (.438f, .70f, 0), (.343f, .70f, 0),
                (.303f, .83f, 1), (.225f, .83f, 2), (.204f, 1f, 2), (0f, 1f, 0)
            };
            var collarProfile = new (float radius, float height, int finish)[]
            {
                (.291f, -.71f, 0), (.453f, -.71f, 0), (.49f, -.60f, 1), (.498f, -.34f, 1),
                (.470f, -.18f, 1), (.473f, .19f, 0), (.498f, .35f, 2), (.486f, .59f, 2),
                (.451f, .69f, 1), (.291f, .69f, 1), (.291f, -.71f, 0)
            };
            var baseMesh = InductorLathe(baseProfile);
            var collarMesh = InductorLathe(collarProfile);
            var packedMesh = PackInductor(cores[0], bases, collars, baseMesh, collarMesh);
            UnityEngine.Object.DestroyImmediate(baseMesh);
            UnityEngine.Object.DestroyImmediate(collarMesh);
            foreach (var part in bases.Concat(collars))
                part.GetComponent<MeshRenderer>().enabled = false;

            var opticsSource = AssetDatabase.LoadAssetAtPath<Material>(Art + "Specimen laminated glass.mat");
            var coreMaterial = ArchiveOptics(opticsSource, "R48 memory inductor dielectric", 4f,
                new Color(.104f, .56f, .62f, .48f), 0f, 0f, 3002);
            var forge = ResetNamed(station, "Memory Laboratory inductor hardware");
            foreach (var core in cores)
            {
                var renderer = core.GetComponent<MeshRenderer>();
                renderer.sharedMaterial = coreMaterial;
                renderer.shadowCastingMode = ShadowCastingMode.Off;
                renderer.receiveShadows = false;
                var hardware = Node(forge, "Packed inductor hardware", core.localPosition);
                hardware.gameObject.AddComponent<MeshFilter>().sharedMesh = packedMesh;
                var housing = hardware.gameObject.AddComponent<MeshRenderer>();
                housing.sharedMaterials = materials;
                housing.shadowCastingMode = ShadowCastingMode.Off;
            }
            var existingScreen = station.Find("Log display").GetComponent<MeshRenderer>();
            FitLabLog(station, existingScreen, graphite, steel);

            var after = content.GetComponentsInChildren<Collider>(true);
            if (routeJson != EditorJsonUtility.ToJson(route) || after.Length != collisions.Count ||
                after.Any(c => !collisions.TryGetValue(c, out var prior) || prior.record != EditorJsonUtility.ToJson(c) ||
                    prior.matrix != c.transform.localToWorldMatrix))
                throw new InvalidDataException("Laboratory dressing must preserve collision and log progression.");
            AssetDatabase.SaveAssets();
            if (!EditorSceneManager.SaveScene(scene)) throw new IOException("Could not save the laboratory inductor finish.");
            Debug.Log($"ECHO_R48_LAB_SAVED coils=2 collars=12 original_clock=true colliders={collisions.Count}");
        }

        private static void FitLabLog(Transform station, MeshRenderer existing, Material graphite, Material steel)
        {
            var phosphor = AssetDatabase.LoadAssetAtPath<Material>(Folder + "R47 specimen status phosphor.mat");
            var amber = AssetDatabase.LoadAssetAtPath<Material>(Folder + "R47 ochre service markers.mat");
            var glass = AssetDatabase.LoadAssetAtPath<Material>(Folder + "R47 recorder dark glass.mat");
            var face = ResetNamed(station, R48Log);
            face.localPosition = existing.transform.localPosition + new Vector3(0f, .002f, -.038f);
            face.localRotation = Quaternion.LookRotation(Vector3.back, Vector3.up);
            existing.sharedMaterial = graphite;
            var panel = new Plates(5);
            panel.Raised(0f, 0f, 1.25f, .315f, .023f, .013f, .009f, 0);
            panel.Raised(.011f, .031f, 1.15f, .176f, .016f, .027f, .006f, 1);
            panel.Raised(.011f, .031f, 1.104f, .146f, .012f, .031f, .005f, 4);
            panel.Raised(0f, .122f, 1.033f, .005f, .001f, .033f, .001f, 2);
            for (var index = 0; index < 14; index++)
                panel.Raised(-.509f + index * .078f, -.095f, .057f, .013f, .002f, .032f, .002f, index % 5 == 0 ? 3 : 2);
            const float ruleZ = .036f;
            SetPanel(face, "R48 recessed lab memory readout", panel, new[] { graphite, steel, phosphor, amber, glass });
            AddLegend(face, "MEMORY LOG", new Vector3(-.335f, .030f, ruleZ), .0077f, new Color(.69f, .94f, .91f));
            AddLegend(face, "SECTOR 11", new Vector3(.334f, .030f, ruleZ), .0074f, new Color(.55f, .78f, .80f));
        }

        private static Mesh PackInductor(Transform sampleCore, Transform[] bases, Transform[] collars, Mesh baseMesh, Mesh collarMesh)
        {
            var parts = new[] { new List<CombineInstance>(), new List<CombineInstance>(), new List<CombineInstance>() };
            var center = sampleCore.localPosition;
            foreach (var part in bases.Concat(collars).Where(t => Mathf.Abs(t.localPosition.x - center.x) < .01f))
            {
                var mesh = part.name == "Coil base" ? baseMesh : collarMesh;
                var matrix = Matrix4x4.TRS(part.localPosition - center, part.localRotation, part.localScale);
                for (var finish = 0; finish < parts.Length; finish++)
                    parts[finish].Add(new CombineInstance { mesh = mesh, subMeshIndex = finish, transform = matrix });
            }
            var cylinder = sampleCore.GetComponent<MeshFilter>().sharedMesh;
            void AddPart(int finish, Vector3 position, Vector3 scale)
            {
                parts[finish].Add(new CombineInstance { mesh = cylinder, transform = Matrix4x4.TRS(position, Quaternion.identity, scale) });
            }
            AddPart(0, Vector3.zero, new Vector3(.253f, 1.32f, .253f));
            foreach (var phase in new[] { 24f, 144f, 264f })
            {
                var aim = Quaternion.Euler(0f, phase, 0f) * Vector3.forward;
                AddPart(2, aim * .155f, new Vector3(.083f, 1.22f, .083f));
                AddPart(1, aim * .375f, new Vector3(.045f, 1.24f, .045f));
            }
            AddPart(2, Vector3.up * 1.283f, new Vector3(.30f, .091f, .30f));
            AddPart(1, Vector3.up * 1.409f, new Vector3(.159f, .039f, .159f));
            var submeshes = new Mesh[parts.Length];
            for (var index = 0; index < parts.Length; index++)
            {
                submeshes[index] = new Mesh();
                submeshes[index].CombineMeshes(parts[index].ToArray(), true, true);
            }
            var packed = new Mesh();
            packed.CombineMeshes(submeshes.Select(mesh => new CombineInstance { mesh = mesh }).ToArray(), false, false);
            foreach (var transient in submeshes) UnityEngine.Object.DestroyImmediate(transient);
            return SaveInductorMesh("R48 paired memory inductor hardware", packed);
        }

        private static Mesh SaveInductorMesh(string name, Mesh mesh)
        {
            mesh.name = name;
            var path = Folder + name + ".asset";
            var saved = AssetDatabase.LoadAssetAtPath<Mesh>(path);
            if (!saved)
            {
                AssetDatabase.CreateAsset(mesh, path);
                return mesh;
            }
            EditorUtility.CopySerialized(mesh, saved);
            UnityEngine.Object.DestroyImmediate(mesh);
            return saved;
        }

        private static Mesh InductorLathe((float radius, float height, int finish)[] profile)
        {
            const int sides = 40;
            var vertices = new List<Vector3>();
            var normals = new List<Vector3>();
            var uv = new List<Vector2>();
            var submeshes = new[] { new List<int>(), new List<int>(), new List<int>() };
            for (var section = 1; section < profile.Length; section++)
            {
                var lower = profile[section - 1];
                var upper = profile[section];
                var outward = new Vector2(upper.height - lower.height, lower.radius - upper.radius).normalized;
                var start = vertices.Count;
                for (var side = 0; side <= sides; side++)
                {
                    var u = side / (float)sides;
                    var angle = u * Mathf.PI * 2f;
                    var x = Mathf.Cos(angle);
                    var z = Mathf.Sin(angle);
                    var normal = new Vector3(x * outward.x, outward.y, z * outward.x);
                    vertices.Add(new Vector3(x * lower.radius, lower.height, z * lower.radius));
                    vertices.Add(new Vector3(x * upper.radius, upper.height, z * upper.radius));
                    normals.Add(normal);
                    normals.Add(normal);
                    uv.Add(new Vector2(u * 3f, lower.height));
                    uv.Add(new Vector2(u * 3f, upper.height));
                    if (side == 0) continue;
                    var at = start + side * 2;
                    submeshes[lower.finish].AddRange(new[] { at - 2, at - 1, at, at, at - 1, at + 1 });
                }
            }
            var result = new Mesh { subMeshCount = submeshes.Length };
            result.SetVertices(vertices);
            result.SetNormals(normals);
            result.SetUVs(0, uv);
            for (var index = 0; index < submeshes.Length; index++)
                result.SetTriangles(submeshes[index], index);
            result.RecalculateTangents();
            result.RecalculateBounds();
            return result;
        }
    }
}
