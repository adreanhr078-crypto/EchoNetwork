using System;
using System.IO;
using System.Linq;
using ElevenEleven.Opening;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using static ElevenEleven.Editor.GodotRoomAssembly;
using Object = UnityEngine.Object;

namespace ElevenEleven.Editor
{
    internal static partial class ChapterWallFabrication
    {
        private const string SignalLayer = "Signal aperture architecture";
        private const string ApertureLeafLayer = "Fitted phase leaves";

        public static void DirectSignalChamber()
        {
            var scene = EditorSceneManager.OpenScene(ScenePath);
            var content = scene.GetRootGameObjects().Single(root => root.name == "Room content").transform;
            var sector = content.Find("Sector 11");
            var station = content.Find("Echo Station");
            var door = sector.Find("Blast gate/Sliding door");
            var colliders = content.GetComponentsInChildren<Collider>(true)
                .ToDictionary(collider => collider, collider => EditorJsonUtility.ToJson(collider));
            var gate = door.parent.GetComponent<Room01Gate>();
            var gateState = EditorJsonUtility.ToJson(gate);

            var structure = ResetNamed(station, SignalLayer);
            var leaves = ResetNamed(door, ApertureLeafLayer);
            var steel = AssetDatabase.LoadAssetAtPath<Material>(Art + "StationFinishes/Chronostat oxide-filled steel.mat");
            var enamel = AssetDatabase.LoadAssetAtPath<Material>("Assets/ElevenEleven/Opening/Hospital/Finishes/Ward eggshell enamel.mat");
            var dark = FinishAt(steel, "Signal carbon steel", new Color(.30f,.275f,.240f), .43f);
            var machined = FinishAt(steel, "Signal machined sealing rails", new Color(.65f,.572f,.467f), .67f);
            var ceramic = FinishAt(enamel, "Signal aged porcelain pressure lining", new Color(.75f,.696f,.60f), .40f);
            var bronze = FinishAt(steel, "Signal blackened bronze locks", new Color(.57f,.406f,.261f), .53f);
            var filament = Emitter("Signal energized filament", new Color(1f, .49f, .16f), 2.8f);
            var practical = Emitter("Signal opal phosphor", new Color(1f, .83f, .63f), 1.8f);

            var prefabCube = GameObject.CreatePrimitive(PrimitiveType.Cube);
            var cube = prefabCube.GetComponent<MeshFilter>().sharedMesh;
            Object.DestroyImmediate(prefabCube);
            foreach (var part in door.Cast<Transform>().Where(part =>
                         part.name is "Gate armor" or "Measured hydraulic door facade"))
                foreach (var renderer in part.GetComponentsInChildren<MeshRenderer>(true))
                    renderer.enabled = false;
            door.Find("Gate panel").GetComponent<MeshRenderer>().sharedMaterial = dark;

            var ring = AssetDatabase.LoadAssetAtPath<Mesh>(Art + "ChapterRoomPolish/Pressure full-size rolled sections.asset");
            var seal = AssetDatabase.LoadAssetAtPath<Mesh>(Art + "ChapterRoomPolish/Pressure dual rolled finish bead.asset");
            if (!ring || !seal) throw new FileNotFoundException("The authored pressure ring meshes are missing.");
            var approach = door.position - station.forward * 1.04f;
            var frameAt = station.InverseTransformPoint(approach);
            frameAt.y = 3.10f;
            var frame = Node(structure, "Stationary clocked aperture", frameAt);
            Add(frame, "Cast elliptical gate return", ring, dark, Vector3.zero, new Vector3(1.08f,1.24f,1.55f));
            Add(frame, "Exposed sealing lip", seal, machined, Vector3.back * .31f, new Vector3(1.11f,1.24f,1f));
            Add(frame, "Opposed fixed guide shoes", seal, bronze, Vector3.back * .25f, new Vector3(1.17f,1.31f,1.2f));

            var leafMesh = PressureLeafMesh();
            var painted = new[] { dark, ceramic, machined };
            foreach (var side in new[] { -1f, 1f })
            {
                var face = Node(leaves, side < 0 ? "Port pressure platen" : "Starboard pressure platen",
                    new Vector3(side * 1.59f, .025f, -.326f));
                face.localRotation = Quaternion.Euler(0f, 180f, 0f);
                face.localScale = new Vector3(2.95f, 6.06f, 1f);
                face.gameObject.AddComponent<MeshFilter>().sharedMesh = leafMesh;
                face.gameObject.AddComponent<MeshRenderer>().sharedMaterials = painted;
                foreach (var y in new[] { -.99f, .99f })
                {
                    Add(leaves, "Registration stroke hood", cube, dark, new Vector3(side*.85f, y, -.410f),
                        new Vector3(.61f, .057f, .055f));
                    Add(leaves, "Recessed registration stroke", cube, filament, new Vector3(side*.85f, y, -.441f),
                        new Vector3(.54f, .018f, .014f));
                }
                Add(leaves, "Central platen guide", cube, machined, new Vector3(side * .101f, 0f, -.422f),
                    new Vector3(.045f, 5.55f, .12f));
            }
            Add(leaves, "Shielded standby filament", cube, filament, new Vector3(0f, -.03f, -.412f),
                new Vector3(.095f,5.46f,.055f));

            var practicals = sector.Cast<Transform>().Where(item => item.name == "CeilingTile").ToArray();
            foreach (var original in practicals)
            {
                foreach (var renderer in original.GetComponentsInChildren<MeshRenderer>(true))
                    renderer.enabled = false;
                var point = station.InverseTransformPoint(original.position);
                var assembly = Node(structure, $"Recessed ceiling practical {point.z:F1}", new Vector3(0f, 6.56f, point.z));
                Add(assembly, "Pressed black reflector housing", cube, dark, Vector3.zero, new Vector3(2.62f,.24f,.51f));
                Add(assembly, "Ceramic lamp liner", cube, machined, Vector3.down*.116f, new Vector3(2.38f,.044f,.256f));
                Add(assembly, "Recessed phosphor lens", cube, practical, Vector3.down*.145f, new Vector3(2.11f,.022f,.112f));
                foreach (var x in new[] { -1.13f, 1.13f })
                    Add(assembly, "Suspension pin", cube, bronze, new Vector3(x,.25f,0f), new Vector3(.12f,.46f,.14f));
                var spot = Node(assembly, "Warm reflected task light", Vector3.down*.172f).gameObject.AddComponent<Light>();
                spot.transform.localRotation = Quaternion.Euler(90f,0f,0f);
                spot.type = LightType.Spot;
                spot.color = new Color(1f,.81f,.64f);
                spot.intensity = 14f;
                spot.range = 10f;
                spot.spotAngle = 62f;
                spot.innerSpotAngle = 39f;
            }
            if (practicals.Length != 5) throw new InvalidDataException("The Signal light row lost a fixture.");

            var optical = structure.Find("Stationary clocked aperture");
            var head = Node(optical, "Aperture skimming key", new Vector3(0f,3.06f,-2.45f)).gameObject.AddComponent<Light>();
            head.transform.LookAt(optical.position + Vector3.down * 1.4f);
            head.type = LightType.Spot;
            head.color = new Color(1f,.82f,.62f);
            head.intensity = 31f;
            head.range = 12f;
            head.spotAngle = 62f;
            head.innerSpotAngle = 37f;
            GrazingKey(structure, "Viewport transmitted floor wash", new Vector3(-7.08f,2.92f,8.55f),
                new Vector3(-3.78f,.04f,9.2f), new Color(.38f,.83f,.78f), 11f, 7f);
            GrazingKey(structure, "Standby gate reflection on center channel", new Vector3(0f,2.6f,16.49f),
                new Vector3(.10f,.05f,10.9f), new Color(1f,.59f,.29f), 18f, 11f);

            var after = content.GetComponentsInChildren<Collider>(true);
            if (after.Length != colliders.Count || after.Any(c => !colliders.TryGetValue(c, out var before) ||
                  !string.Equals(before, EditorJsonUtility.ToJson(c), StringComparison.Ordinal)) ||
                  !string.Equals(gateState, EditorJsonUtility.ToJson(gate), StringComparison.Ordinal))
                throw new InvalidDataException("Signal architecture changed gameplay authority.");
            AssetDatabase.SaveAssets();
            if (!EditorSceneManager.SaveScene(scene)) throw new IOException("Could not save the Signal aperture.");
            Debug.Log($"ECHO_SIGNAL_ART_DIRECTION leaves=2 practicals={practicals.Length} colliders={after.Length} gate_authority=unchanged");
        }

        private static Transform ResetNamed(Transform parent, string name)
        {
            var earlier = parent.Find(name);
            if (earlier) Object.DestroyImmediate(earlier.gameObject);
            return Node(parent, name, Vector3.zero);
        }

        private static void Add(Transform parent, string name, Mesh mesh, Material material, Vector3 offset, Vector3 scale)
        {
            var node = Node(parent, name, offset);
            node.localScale = scale;
            node.gameObject.AddComponent<MeshFilter>().sharedMesh = mesh;
            var renderer = node.gameObject.AddComponent<MeshRenderer>();
            renderer.sharedMaterial = material;
            renderer.shadowCastingMode = ShadowCastingMode.Off;
        }

        private static Material Emitter(string name, Color color, float strength)
        {
            var path = Folder + name + ".mat";
            var mat = AssetDatabase.LoadAssetAtPath<Material>(path);
            if (!mat)
            {
                mat = new Material(Shader.Find("Universal Render Pipeline/Lit")) { name = name };
                AssetDatabase.CreateAsset(mat, path);
            }
            mat.SetColor("_BaseColor", color);
            mat.SetColor("_EmissionColor", color * strength);
            mat.EnableKeyword("_EMISSION");
            EditorUtility.SetDirty(mat);
            return mat;
        }

        private static Mesh PressureLeafMesh()
        {
            const string name = "Signal folded pressure platen";
            var path = Folder + name + ".asset";
            var mesh = AssetDatabase.LoadAssetAtPath<Mesh>(path);
            if (mesh) return mesh;
            var plates = new Plates();
            plates.Raised(0f, 0f, 1f,.992f,.091f,.031f,.014f,0);
            plates.Raised(0f, 0f,.946f,.949f,.083f,.065f,.017f,2);
            plates.Raised(0f, 0f,.890f,.900f,.075f,.078f,.011f,1);
            foreach (var x in new[] { -.283f, .283f })
            foreach (var y in new[] { -.357f, .357f })
                plates.Bolt(x,y,.008f,.076f,.092f);
            mesh = plates.Build(name);
            AssetDatabase.CreateAsset(mesh, path);
            return mesh;
        }
    }
}
