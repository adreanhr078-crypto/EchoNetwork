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
        internal const string R47Record = "EX-011 containment recorder";
        internal const string R47Cladding = "Containment shield service cladding";
        internal const string R47OrbitMaterial = "R47 Archive optical conductor";
        internal const string R47BeamMaterial = "R47 Archive memory projection";

        public static void FitRecordApproaches()
        {
            var scene = EditorSceneManager.OpenScene(ScenePath);
            var content = scene.GetRootGameObjects().Single(root => root.name == "Room content").transform;
            var station = content.Find("Echo Station");
            var colliders = content.GetComponentsInChildren<Collider>(true).ToDictionary(c => c,
                c => (serialized: EditorJsonUtility.ToJson(c), matrix: c.transform.localToWorldMatrix));
            var route = content.GetComponentInChildren<StormworksRoute>(true);
            var wing = station.Find("Specimen containment").GetComponent<StationSpecimenWing>();
            var archive = station.Find("Memory archive wing").GetComponent<StationArchiveWing>();
            var authority = new Component[] { route, wing, archive };
            var snapshot = authority.Select(c => EditorJsonUtility.ToJson(c)).ToArray();

            FitSpecimenRecorder(wing.transform);
            FitArchiveProjection(archive.transform);

            var after = content.GetComponentsInChildren<Collider>(true);
            if (after.Length != colliders.Count ||
                after.Any(c => !colliders.TryGetValue(c, out var prior) || prior.serialized != EditorJsonUtility.ToJson(c) ||
                    prior.matrix != c.transform.localToWorldMatrix) ||
                !snapshot.SequenceEqual(authority.Select(c => EditorJsonUtility.ToJson(c))))
                throw new InvalidDataException("The record approach changed a collision shape or route authority.");

            AssetDatabase.SaveAssets();
            if (!EditorSceneManager.SaveScene(scene)) throw new IOException("Could not save the record approaches.");
            Debug.Log($"ECHO_R47_RECORDS_SAVED colliders={colliders.Count} authority={authority.Length} archive_camera_unchanged=true");
        }

        private static void FitSpecimenRecorder(Transform room)
        {
            var art = room.Find("Native Godot specimen geometry");
            var monitor = art.Find("SpecimenLogTerminal/_MeshInstance3D_241");
            var blankBezel = monitor.Find("MachinedTerminalBezel/MachinedTerminalBezel2").GetComponent<MeshRenderer>();
            var blankScreen = monitor.Find("NativeReadoutSurface").GetComponent<MeshRenderer>();
            var shield = art.Find("TerminalShieldPlinth/_MeshInstance3D_235").GetComponent<MeshRenderer>();
            var template = AssetDatabase.LoadAssetAtPath<Material>(Art + "StationFinishes/Chronostat oxide-filled steel.mat");
            var dark = FinishAt(template, "R47 sterile graphite housing", new Color(.21f, .25f, .27f), .32f);
            var enamel = FinishAt(template, "R47 blue-grey sterile enamel", new Color(.42f, .51f, .54f), .45f);
            var rail = AssetDatabase.LoadAssetAtPath<Material>(Folder + "Station worked manganese alloy.mat");
            var amber = Emitter("R47 ochre service markers", new Color(.78f, .32f, .095f), .7f);
            var aqua = Emitter("R47 specimen status phosphor", new Color(.12f, .57f, .59f), .62f);
            var display = Emitter("R47 recorder dark glass", new Color(.024f, .055f, .072f), .53f);
            var materials = new[] { dark, enamel, rail, amber, aqua, display };

            blankBezel.enabled = false;
            blankScreen.enabled = false;
            var panel = ResetNamed(room, R47Record);
            var monitorCenter = room.InverseTransformPoint(monitor.GetComponent<MeshRenderer>().bounds.center);
            var collision = room.Find("Authored Godot collision/SpecimenLogTerminal").GetComponent<BoxCollider>();
            var cubeSource = GameObject.CreatePrimitive(PrimitiveType.Cube);
            var cube = cubeSource.GetComponent<MeshFilter>().sharedMesh;
            Object.DestroyImmediate(cubeSource);
            var mount = Node(panel, "Load-bearing recorder mount", panel.InverseTransformPoint(collision.bounds.center));
            Add(mount, "Anchored sole plate", cube, rail, new Vector3(0f, -.559f, -.024f), new Vector3(.83f, .082f, .64f));
            Add(mount, "Cast graphite pedestal", cube, dark, new Vector3(0f, -.036f, -.045f), new Vector3(.42f, 1.03f, .39f));
            Add(mount, "Machined monitor saddle", cube, rail, new Vector3(0f, .506f, -.088f), new Vector3(.56f, .16f, .39f));
            var face = Node(panel, "Tilted terminal face", monitorCenter + new Vector3(0f, .006f, -.135f));
            face.localRotation = Quaternion.LookRotation(new Vector3(0f, .24f, -1f), Vector3.up);
            var bezel = new Plates(materials.Length);
            bezel.Raised(0f, 0f, .916f, .52f, .044f, .023f, .011f, 0);
            bezel.Raised(0f, .028f, .823f, .368f, .034f, .037f, .009f, 2);
            bezel.Raised(0f, .028f, .747f, .311f, .019f, .043f, .008f, 5);
            bezel.Raised(0f, .166f, .634f, .005f, .002f, .045f, .001f, 4);
            bezel.Raised(-.257f, -.038f, .088f, .006f, .002f, .045f, .001f, 4);
            for (var i = 0; i < 5; i++)
            {
                bezel.Raised(-.192f + i * .066f, -.113f, .048f, .012f, .003f, .046f, .002f, i == 4 ? 3 : 4);
                bezel.Raised(-.152f + i * .076f, -.198f, .053f, .028f, .004f, .042f, .003f, i == 4 ? 3 : 1);
            }
            foreach (var x in new[] { -.414f, .414f })
            foreach (var y in new[] { -.189f, .201f })
                bezel.Bolt(x, y, .013f, .027f, .048f);
            SetPanel(face, "R47 machined EX-011 recorder", bezel, materials);
            AddLegend(face, "EX-011", new Vector3(0f, .077f, .051f), .0136f, new Color(.69f, .94f, .93f));
            AddLegend(face, "CONTAINMENT RECORD", new Vector3(0f, -.034f, .051f), .0047f, new Color(.52f, .78f, .80f));

            var cladding = ResetNamed(room, R47Cladding);
            shield.sharedMaterial = dark;
            var bounds = shield.bounds;
            foreach (var normal in new[] { Vector3.left, Vector3.right, Vector3.back, Vector3.forward })
            {
                var broad = Mathf.Abs(normal.x) > .5f;
                var position = bounds.center + normal * (Vector3.Dot(bounds.extents, new Vector3(Mathf.Abs(normal.x), 0f, Mathf.Abs(normal.z))) + .005f);
                var side = Node(cladding, broad ? "Service access panel" : "End cap", cladding.InverseTransformPoint(position));
                side.rotation = Quaternion.LookRotation(normal, Vector3.up);
                var shell = new Plates(materials.Length);
                var width = (broad ? bounds.size.z : bounds.size.x) - .018f;
                shell.Raised(0f, 0f, width, 2.98f, .048f, .017f, .007f, 0);
                shell.Raised(0f, 1.382f, width - .061f, .102f, .022f, .037f, .012f, 2);
                shell.Raised(0f, -1.365f, width - .072f, .146f, .021f, .042f, .008f, 2);
                if (broad) DressServiceCladding(shell, width);
                else
                {
                    shell.Raised(0f, .03f, width - .076f, 2.55f, .035f, .035f, .009f, 1);
                    shell.Raised(0f, 1.18f, width - .125f, .044f, .008f, .043f, .004f, 3);
                }
                var orientation = normal.x < 0f ? "west" : normal.x > 0f ? "east" : normal.z < 0f ? "south" : "north";
                SetPanel(side, "R47 containment shield " + orientation, shell, materials);
            }
        }

        private static void DressServiceCladding(Plates shell, float width)
        {
            var bay = width / 3f;
            for (var index = 0; index < 3; index++)
            {
                var x = (index - 1) * bay;
                shell.Raised(x, .18f, bay - .058f, 2.31f, .065f, .040f, .026f, 1);
                shell.Raised(x, -.825f, bay - .118f, .369f, .033f, .048f, .014f, 0);
                for (var row = 0; row < 4; row++)
                    shell.Raised(x, -.705f - row * .077f, bay - .211f, .023f, .007f, .061f, .004f, 2);
                foreach (var edge in new[] { -.39f, .39f })
                foreach (var height in new[] { -1.13f, .766f })
                    shell.Bolt(x + bay * edge, height, .026f, .041f, .065f);
            }
            shell.Raised(0f, 1.036f, .672f, .196f, .018f, .048f, .007f, 0);
            shell.Raised(0f, .905f, .668f, .025f, .006f, .049f, .004f, 3);
            for (var i = 0; i < 5; i++)
                shell.Raised(-.22f + i * .11f, 1.036f, .078f, .052f, .006f, .054f, .006f, i == 0 ? 3 : 2);
        }

        private static void AddLegend(Transform face, string legend, Vector3 position, float scale, Color color)
        {
            var node = Node(face, legend, position);
            node.localRotation = Quaternion.Euler(0f, 180f, 0f);
            var type = node.gameObject.AddComponent<TextMesh>();
            type.font = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
            type.GetComponent<MeshRenderer>().sharedMaterial = type.font.material;
            type.GetComponent<MeshRenderer>().shadowCastingMode = ShadowCastingMode.Off;
            type.fontSize = 64;
            type.characterSize = scale;
            type.anchor = TextAnchor.MiddleCenter;
            type.alignment = TextAlignment.Center;
            type.color = color;
            type.text = legend;
        }

        private static void SetPanel(Transform face, string name, Plates plates, Material[] materials)
        {
            var path = Folder + name + ".asset";
            var shape = plates.Build(name);
            var saved = AssetDatabase.LoadAssetAtPath<Mesh>(path);
            if (saved)
            {
                EditorUtility.CopySerialized(shape, saved);
                Object.DestroyImmediate(shape);
            }
            else
            {
                AssetDatabase.CreateAsset(shape, path);
                saved = shape;
            }
            face.gameObject.AddComponent<MeshFilter>().sharedMesh = saved;
            var renderer = face.gameObject.AddComponent<MeshRenderer>();
            renderer.sharedMaterials = materials;
            renderer.shadowCastingMode = ShadowCastingMode.Off;
        }

        private static void FitArchiveProjection(Transform room)
        {
            var art = room.Find("Native Godot archive geometry");
            var beam = art.Find("CoreBeamPillar").GetComponent<MeshRenderer>();
            var source = AssetDatabase.LoadAssetAtPath<Material>(Art + "Archive memory projection.mat");
            beam.sharedMaterial = ArchiveOptics(source, R47BeamMaterial, 2f, new Color(.55f, .25f, 1.6f, .77f), .77f, 2.04f, 3003);
            var conductor = ArchiveOptics(source, R47OrbitMaterial, 3f, new Color(.23f, .69f, 1.02f, .68f), 2.08f, 4.25f, 3004);
            var rings = art.GetComponentsInChildren<MeshRenderer>(true)
                .Where(r => r.transform.parent == art && r.name.StartsWith("ArchiveOrbit_")).ToArray();
            if (rings.Length < 2) throw new InvalidDataException("The Archive's original animated orbit meshes are missing.");
            foreach (var ring in rings)
            {
                ring.sharedMaterial = conductor;
                ring.shadowCastingMode = ShadowCastingMode.Off;
                ring.receiveShadows = false;
            }
            Debug.Log($"ECHO_R47_ARCHIVE_OPTOUT visual_orbits={rings.Length} projection=distance_fade original_transforms=true");
        }

        private static Material ArchiveOptics(Material source, string name, float mode, Color tint, float near, float full, int queue)
        {
            var path = Folder + name + ".mat";
            var material = AssetDatabase.LoadAssetAtPath<Material>(path);
            if (!material)
            {
                material = new Material(source) { name = name };
                AssetDatabase.CreateAsset(material, path);
            }
            material.SetColor("_Tint", tint);
            material.SetFloat("_Mode", mode);
            material.SetVector("_ProjectionViewFade", new Vector4(near, full, 0f, 0f));
            material.renderQueue = queue;
            EditorUtility.SetDirty(material);
            return material;
        }
    }
}
