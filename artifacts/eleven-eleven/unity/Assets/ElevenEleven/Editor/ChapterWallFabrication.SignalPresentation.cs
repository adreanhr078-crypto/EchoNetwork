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
        internal const string SignalPresentationLayer = "Signal console and overhead indicators";
        private const string SignalRepeaterMesh = "Signal console repeater bezel";
        private const string SignalCeilingMesh = "Signal recessed ceiling indicator housing";

        public static void FitSignalPresentation()
        {
            var scene = EditorSceneManager.OpenScene(ScenePath);
            var content = scene.GetRootGameObjects().Single(root => root.name == "Room content").transform;
            var station = content.Find("Echo Station");
            var sector = content.Find("Sector 11");
            var player = content.GetComponentInChildren<Room01Player>(true);
            var gate = sector.Find("Blast gate").GetComponent<Room01Gate>();
            var donor = station.Find("Flow R37 fitted architecture/Signal tuning console");
            var lights = station.Find(SignalLayer).Cast<Transform>()
                .Where(node => node.name.StartsWith("Recessed ceiling practical ", StringComparison.Ordinal))
                .OrderBy(node => node.localPosition.z).ToArray();
            var serializedPlayer = new SerializedObject(player);
            var anchor = serializedPlayer.FindProperty("terminal").objectReferenceValue as Transform;
            if (!donor || !anchor || !gate || lights.Length != 5 || Vector3.Distance(anchor.position, donor.position) > .8f)
                throw new InvalidDataException("The original signal console, collider or ceiling row changed.");

            var attached = donor.GetComponentsInChildren<MeshRenderer>(true).Where(item => item.enabled).ToArray();
            if (attached.Length == 0) throw new InvalidDataException("The original console has no visible mesh.");
            var bounds = attached.Select(item => item.bounds).Aggregate((first, next) =>
            {
                first.Encapsulate(next);
                return first;
            });
            if (bounds.size.y < .97f || bounds.size.y > 1.55f || bounds.size.x > 1.45f || bounds.size.z > 1.66f)
                throw new InvalidDataException($"Signal console bounds no longer match the fitted instrument: {bounds}.");

            var colliders = content.GetComponentsInChildren<Collider>(true).ToDictionary(item => item,
                item => (data: EditorJsonUtility.ToJson(item), matrix: item.transform.localToWorldMatrix));
            var playerState = EditorJsonUtility.ToJson(player);
            var gateState = EditorJsonUtility.ToJson(gate);
            var iron = RequireSignalMaterial("Signal carbon steel", true);
            var enamel = RequireSignalMaterial("Signal aged porcelain pressure lining", true);
            var steel = RequireSignalMaterial("Signal machined sealing rails", true);
            var glass = RequireSignalMaterial("R47 recorder dark glass", false);
            var filament = RequireSignalMaterial("Signal energized filament", false);
            var cubeSource = GameObject.CreatePrimitive(PrimitiveType.Cube);
            var cube = cubeSource.GetComponent<MeshFilter>().sharedMesh;
            Object.DestroyImmediate(cubeSource);

            var layer = ResetNamed(station, SignalPresentationLayer);
            var facing = Vector3.ProjectOnPlane(donor.forward, Vector3.up).normalized;
            var depth = Vector3.Dot(new Vector3(Mathf.Abs(facing.x), 0f, Mathf.Abs(facing.z)), bounds.extents);
            var center = new Vector3(bounds.center.x, bounds.max.y + .162f, bounds.center.z);
            var face = Node(layer, "Inset signal and feed readout", Vector3.zero);
            face.SetPositionAndRotation(center + facing * (depth * .39f),
                Quaternion.LookRotation((facing + Vector3.up * .17f).normalized, Vector3.up));

            // The riser is a sibling of the nonuniform Tripo fit. Explicit dimensions preserve the new rigid pivots.
            var saddle = Node(layer, "Console saddle with paired risers", Vector3.zero);
            saddle.SetPositionAndRotation(center - Vector3.up * .113f + facing * (depth * .19f),
                Quaternion.LookRotation(facing, Vector3.up));
            foreach (var side in new[] { -1f, 1f })
            {
                Add(saddle, "Preloaded steel bracket", cube, steel, new Vector3(side * .418f, -.025f, -.038f),
                    new Vector3(.095f, .173f, .15f));
                Add(saddle, "Bolted mounting shoe", cube, iron, new Vector3(side * .418f, -.095f, -.042f),
                    new Vector3(.169f, .045f, .215f));
            }
            Add(saddle, "Backplate and insulated cable chase", cube, iron, new Vector3(0f, .095f, -.055f),
                new Vector3(1.19f, .236f, .151f));

            var faceMesh = new Plates(4);
            faceMesh.Raised(0f, 0f, 1.35f, .398f, .054f, .022f, .014f, 0);
            faceMesh.Raised(-.226f, .023f, .704f, .196f, .026f, .043f, .011f, 2);
            faceMesh.Raised(-.226f, .023f, .649f, .151f, .014f, .054f, .007f, 3);
            faceMesh.Raised(.354f, .019f, .489f, .225f, .035f, .045f, .009f, 2);
            faceMesh.Raised(.354f, .019f, .447f, .190f, .026f, .057f, .008f, 3);
            faceMesh.Raised(-.358f, -.127f, .301f, .066f, .022f, .049f, .007f, 2);
            faceMesh.Raised(-.358f, -.127f, .269f, .040f, .015f, .060f, .004f, 3);
            faceMesh.Raised(.155f, -.139f, .808f, .040f, .014f, .047f, .006f, 3);
            foreach (var x in new[] { -.619f, .619f })
            foreach (var y in new[] { -.139f, .147f })
                faceMesh.Bolt(x, y, .018f, .023f, .047f);
            for (var index = 0; index < 7; index++)
                faceMesh.Raised(-.49f + index * .091f, .020f, .0025f, .115f, .0007f, .056f, .0006f, 0);
            SetPanel(face, SignalRepeaterMesh, faceMesh, new[] { iron, enamel, steel, glass });

            var quiet = new Color(.70f, .80f, .79f);
            AddLegend(face, "PHASE RECEIVER", new Vector3(-.226f, .135f, .050f), .0084f, quiet);
            AlignLegend(face, "SIGNAL", new Vector3(.148f, .064f, .072f), .0062f, quiet, TextAnchor.MiddleRight);
            AlignLegend(face, "FEED", new Vector3(.148f, -.021f, .072f), .0062f, quiet, TextAnchor.MiddleRight);
            AlignLegend(face, "DOOR INTERLOCK", new Vector3(-.190f, -.139f, .054f), .0060f, quiet, TextAnchor.MiddleRight);
            var alignment = SignalReadout(face, "Signal state", new Vector3(.538f, .064f, .073f), .0064f, "SEARCH");
            var feed = SignalReadout(face, "Feed state", new Vector3(.538f, -.021f, .073f), .0064f, "FAULT");
            var interlock = SignalReadout(face, "Interlock state", new Vector3(.538f, -.139f, .056f), .0062f, "HELD");

            Add(face, "Protected feed indicator", cube, filament, new Vector3(.568f, -.022f, .074f),
                new Vector3(.025f, .042f, .009f));
            var relay = Node(face, "Rigid feed relay flag", new Vector3(-.425f, -.127f, .075f));
            Add(relay, "White ceramic relay flag", cube, enamel, Vector3.zero, new Vector3(.057f, .025f, .008f));
            var trace = Node(face, "Signal trace", Vector3.zero).gameObject.AddComponent<LineRenderer>();
            trace.sharedMaterial = filament;
            trace.useWorldSpace = false;
            trace.widthMultiplier = .010f;
            trace.positionCount = 2;
            trace.SetPositions(new[] { new Vector3(-.514f, .012f, .073f), new Vector3(.058f, .012f, .073f) });
            trace.shadowCastingMode = ShadowCastingMode.Off;

            var guides = lights.Select(node => FitSignalCeilingIndicator(layer, node, cube, iron, steel, filament)).ToArray();
            layer.gameObject.AddComponent<SignalConsolePresentation>().Configure(player, gate, alignment, feed, interlock,
                face.Find("Protected feed indicator").GetComponent<MeshRenderer>(), guides, relay, trace);

            if (content.GetComponentsInChildren<Collider>(true).Length != colliders.Count || colliders.Any(item =>
                    !item.Key || item.Value.data != EditorJsonUtility.ToJson(item.Key) ||
                    item.Value.matrix != item.Key.transform.localToWorldMatrix) ||
                playerState != EditorJsonUtility.ToJson(player) || gateState != EditorJsonUtility.ToJson(gate))
                throw new InvalidDataException("Signal presentation attempted to change collision or puzzle authority.");

            AssetDatabase.SaveAssets();
            if (!EditorSceneManager.SaveScene(scene)) throw new IOException("Failed to save Signal console presentation.");
            Debug.Log($"ECHO_SIGNAL_CONSOLE_SAVED colliders={colliders.Count} bound_ceiling_practicals={guides.Length} visual_donor_meshes={attached.Length}");
        }

        private static Material RequireSignalMaterial(string name, bool pbr)
        {
            var material = AssetDatabase.LoadAssetAtPath<Material>(Folder + name + ".mat");
            if (!material || (pbr && (!material.GetTexture("_BaseMap") || !material.GetTexture("_BumpMap"))))
                throw new FileNotFoundException($"Missing cached Signal material: {name}.");
            return material;
        }

        private static void AlignLegend(Transform face, string name, Vector3 offset, float size, Color color, TextAnchor anchor)
        {
            AddLegend(face, name, offset, size, color);
            var text = face.Find(name).GetComponent<TextMesh>();
            text.anchor = anchor;
            text.alignment = anchor == TextAnchor.MiddleRight ? TextAlignment.Right :
                anchor == TextAnchor.MiddleLeft ? TextAlignment.Left : TextAlignment.Center;
        }

        private static TextMesh SignalReadout(Transform face, string name, Vector3 offset, float size, string initial)
        {
            AlignLegend(face, name, offset, size, new Color(.67f, .51f, 1f), TextAnchor.MiddleLeft);
            var readout = face.Find(name).GetComponent<TextMesh>();
            readout.text = initial;
            return readout;
        }

        private static Renderer FitSignalCeilingIndicator(Transform layer, Transform practical, Mesh cube,
            Material iron, Material steel, Material filament)
        {
            var mount = Node(layer, "Practical route index " + practical.localPosition.z.ToString("0.0",
                System.Globalization.CultureInfo.InvariantCulture), Vector3.zero);
            mount.SetPositionAndRotation(practical.TransformPoint(new Vector3(-.724f, -.176f, -.164f)),
                practical.rotation * Quaternion.Euler(90f, 0f, 0f));
            var housing = new Plates(2);
            housing.Raised(0f, 0f, .682f, .104f, .028f, .019f, .007f, 0);
            housing.Raised(0f, 0f, .599f, .074f, .021f, .031f, .004f, 1);
            SetPanel(mount, SignalCeilingMesh, housing, new[] { iron, steel });
            Add(mount, "Protected guide phosphor", cube, filament, new Vector3(0f, 0f, .036f),
                new Vector3(.526f, .036f, .008f));
            return mount.Find("Protected guide phosphor").GetComponent<MeshRenderer>();
        }
    }
}
