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
        internal const string R51Relay = "West relay current instrument";
        internal const string R51Observation = "Observation vitrine seal fittings";

        public static void FitRelayAndObservation()
        {
            var scene = EditorSceneManager.OpenScene(ScenePath);
            var content = scene.GetRootGameObjects().Single(root => root.name == "Room content").transform;
            var station = content.Find("Echo Station");
            var route = station.GetComponent<StormworksRoute>();
            var theatre = station.Find("Surveillance and mirror/Kinja examination theatre").GetComponent<StationExaminationWing>();
            var authority = new Component[] { route, theatre };
            var before = authority.Select(component => EditorJsonUtility.ToJson(component)).ToArray();
            var physical = content.GetComponentsInChildren<Collider>(true).ToDictionary(collider => collider,
                collider => (record: EditorJsonUtility.ToJson(collider), pose: collider.transform.localToWorldMatrix));

            var wornSteel = R51BFinish(Folder + "Station worked manganese alloy.mat");
            var graphite = R51BFinish(Folder + "R47 sterile graphite housing.mat");
            var copper = R51BFinish(Art + "StationFinishes/Chronostat copper hardware.mat");
            var glass = R51BFinish(Folder + "R47 recorder dark glass.mat");
            var phosphor = R51BFinish(Folder + "R47 specimen status phosphor.mat");
            var ivory = R51BFinish(Folder + "Tactile neutral ivory enamel.mat");
            var enamel = R51BFinish(Folder + "R47 blue-grey sterile enamel.mat");
            FitR51BRelay(station, route, new[] { graphite, copper, wornSteel, glass }, phosphor);
            FitR51BVitrines(theatre, new[] { graphite, wornSteel, ivory, enamel }, phosphor);

            var after = content.GetComponentsInChildren<Collider>(true);
            if (!before.SequenceEqual(authority.Select(component => EditorJsonUtility.ToJson(component))) ||
                after.Length != physical.Count || after.Any(collider => !physical.TryGetValue(collider, out var old) ||
                    old.record != EditorJsonUtility.ToJson(collider) || old.pose != collider.transform.localToWorldMatrix))
                throw new InvalidDataException("Relay or observation finish changed the existing station route or collision.");

            AssetDatabase.SaveAssets();
            if (!EditorSceneManager.SaveScene(scene)) throw new IOException("Could not save Relay and Observation finish.");
            Debug.Log($"ECHO_R51_RELAY_OBSERVATION_SAVED colliders={physical.Count} posts=8 instruments=3");
        }

        private static Material R51BFinish(string path)
        {
            var material = AssetDatabase.LoadAssetAtPath<Material>(path);
            return material ? material : throw new FileNotFoundException(path);
        }

        private static void FitR51BRelay(Transform station, StormworksRoute route, Material[] materials, Material phosphor)
        {
            var measuredOrigin = new Vector3(-15.25f, 1.1f, 57.3f);
            var console = station.Cast<Transform>().Single(node => node.name == "SignalTerminal" &&
                (node.localPosition - measuredOrigin).sqrMagnitude < .0001f);
            var mount = Find(console, "EchoSignalConsole_ScreenMount");
            var entry = station.TransformDirection(Vector3.back);
            var facing = Vector3.Dot(mount.forward, entry);
            if (Mathf.Abs(facing) < .80f) throw new InvalidDataException("The Relay display opening faces away from the stair approach.");
            var outward = facing < 0 ? -mount.forward : mount.forward;
            var face = ResetNamed(station, R51Relay);
            face.SetPositionAndRotation(mount.position + outward * .073f, Quaternion.LookRotation(outward, mount.up));

            var bezel = new Plates(materials.Length);
            bezel.Raised(0f, 0f, 1.158f, .581f, .044f, .018f, .011f, 0);
            bezel.Raised(0f, .021f, 1.049f, .446f, .027f, .026f, .010f, 1);
            bezel.Raised(0f, .021f, .994f, .395f, .020f, .032f, .008f, 3);
            bezel.Raised(.054f, -.028f, .005f, .271f, .001f, .035f, .001f, 1);
            bezel.Raised(-.216f, -.018f, .377f, .005f, .001f, .035f, .001f, 1);
            foreach (var x in new[] { -.531f, .531f })
            foreach (var y in new[] { -.238f, .232f })
                bezel.Bolt(x, y, .015f, .012f, .028f);
            for (var index = 0; index < 9; index++)
            {
                var radians = Mathf.Deg2Rad * (-64f + index * 16f);
                bezel.Raised(.280f + Mathf.Sin(radians) * .138f, -.047f + Mathf.Cos(radians) * .138f,
                    .016f, index % 2 == 0 ? .017f : .010f, .002f, .041f, .001f, index is 0 or 8 ? 1 : 2);
            }
            bezel.Bolt(.28f, -.047f, .020f, .030f, .045f);
            for (var index = 0; index < 6; index++)
                bezel.Raised(-.391f + index * .151f, -.243f, .111f, .012f, .004f, .028f, .002f, 1);
            SetPanel(face, "R51 Relay copper instrument fascia", bezel, materials);

            var steady = new Color(.85f, .75f, .58f);
            var standby = new Color(.90f, .49f, .22f);
            AddLegend(face, "WEST RELAY", new Vector3(-.215f, .107f, .044f), .011f, steady);
            AddLegend(face, "FEED OPEN", new Vector3(-.217f, -.088f, .044f), .010f, standby);
            AddLegend(face, "OUTPUT", new Vector3(.281f, -.143f, .043f), .0047f, steady);

            var bearing = Node(face, "Relay instrument needle", new Vector3(.28f, -.047f, 0f));
            bearing.localRotation = Quaternion.AngleAxis(64f, Vector3.forward);
            var needle = new Plates(1);
            needle.Raised(0f, .057f, .013f, .120f, .005f, .046f, .002f, 0);
            SetPanel(bearing, "R51 Relay damped instrument needle", needle, new[] { materials[1] });
            var feedLamp = Node(face, "Relay feed lamp", new Vector3(-.201f, -.154f, 0f));
            var insert = new Plates(1);
            insert.Raised(0f, 0f, .27f, .017f, .006f, .047f, .003f, 0);
            SetPanel(feedLamp, "R51 Relay feed lamp lens", insert, new[] { phosphor });

            DressR51FactoryCasting(Find(console, "EchoSignalConsole_Static_Graphite").GetComponent<MeshRenderer>(), materials[0]);
            DressR51FactoryCasting(Find(console, "EchoSignalConsole_Static_Titanium").GetComponent<MeshRenderer>(), materials[2]);
            BindR51Indicator(face, bearing, feedLamp.GetComponent<MeshRenderer>(), route, null,
                face.Find("FEED OPEN").GetComponent<TextMesh>(), standby, new Color(.53f, .85f, .63f), 64f, -64f);
        }

        private static void FitR51BVitrines(StationExaminationWing theatre, Material[] materials, Material phosphor)
        {
            const string source = "Godot examination architecture/PactRevengePresentation/ClinicalLabArchitecture";
            var native = theatre.transform.Find(source);
            if (!native) throw new InvalidDataException("The original clinical vitrine architecture is missing.");
            var layer = ResetNamed(theatre.transform, R51Observation);
            var profile = new (float radius, float height, int finish)[]
            {
                (.053f, -.090f, 0), (.090f, -.090f, 0), (.101f, -.069f, 1), (.101f, -.041f, 1),
                (.083f, -.021f, 1), (.072f, .025f, 0), (.072f, .048f, 0), (.079f, .061f, 2),
                (.079f, .085f, 2), (.061f, .097f, 1), (.053f, .097f, 0), (.053f, -.090f, 0)
            };
            var collar = SaveInductorMesh("R51 Observation shoulder collet", InductorLathe(profile));
            var railMaterials = materials.Take(3).ToArray();
            using var state = new SerializedObject(theatre);

            FitR51VitrinePair(layer, native, "ClinicalVitrineGlass", "_MeshInstance3D_670",
                new[] { "VitrineSupport", "_MeshInstance3D_663", "_MeshInstance3D_665", "_MeshInstance3D_667" },
                (Light)state.FindProperty("shizukaSignal").objectReferenceValue, new Color(.33f, .24f, .39f), collar, railMaterials, materials[3], phosphor);
            FitR51VitrinePair(layer, native, "_MeshInstance3D_689", "_MeshInstance3D_687",
                new[] { "_MeshInstance3D_676", "_MeshInstance3D_678", "_MeshInstance3D_680", "_MeshInstance3D_682" },
                (Light)state.FindProperty("yukiSignal").objectReferenceValue, new Color(.21f, .34f, .38f), collar, railMaterials, materials[3], phosphor);
        }

        private static void FitR51VitrinePair(Transform layer, Transform native, string glassName, string lowerRail, string[] postNames,
            Light cue, Color standby, Mesh collar, Material[] materials, Material enamel, Material phosphor)
        {
            if (!cue) throw new InvalidDataException("The clinical vitrine has no authored memory signal.");
            var vitrine = native.Find(glassName).GetComponent<MeshRenderer>();
            var supportLayer = Node(layer, cue.name + " seal hardware", Vector3.zero);
            var posts = postNames.Select(name => native.Find(name).GetComponent<MeshRenderer>()).ToArray();
            DressR51FactoryCasting(native.Find(lowerRail).GetComponent<MeshRenderer>(), enamel);
            foreach (var post in posts)
            {
                var bounds = post.bounds;
                if ((bounds.size - new Vector3(.075f, 4f, .075f)).sqrMagnitude > .0004f)
                    throw new InvalidDataException("The surveyed post dimensions changed: " + post.name);
                DressR51FactoryCasting(post, materials[0]);
                foreach (var y in new[] { bounds.min.y + .127f, bounds.max.y - .134f })
                {
                    var fitting = Node(supportLayer, "Banded vitrine collet", Vector3.zero);
                    fitting.position = new Vector3(bounds.center.x, y, bounds.center.z);
                    fitting.gameObject.AddComponent<MeshFilter>().sharedMesh = collar;
                    var renderer = fitting.gameObject.AddComponent<MeshRenderer>();
                    renderer.sharedMaterials = materials;
                    renderer.shadowCastingMode = ShadowCastingMode.Off;
                }
            }

            var front = posts.OrderBy(post => post.bounds.min.z).ThenBy(post => Mathf.Abs(post.bounds.center.x - cue.transform.position.x)).First();
            var center = front.bounds.center;
            var outward = Vector3.ProjectOnPlane(center - vitrine.bounds.center, Vector3.up).normalized;
            var instrument = Node(supportLayer, "Vitrine seal monitor", Vector3.zero);
            instrument.SetPositionAndRotation(center + outward * .053f + Vector3.down * .865f, Quaternion.LookRotation(outward, Vector3.up));
            var body = new Plates(materials.Length);
            body.Raised(0f, 0f, .188f, .315f, .036f, .020f, .010f, 0);
            body.Raised(0f, .013f, .151f, .182f, .020f, .030f, .006f, 1);
            body.Raised(0f, .009f, .119f, .153f, .015f, .037f, .004f, 0);
            body.Bolt(0f, -.124f, .018f, .018f, .032f);
            body.Bolt(0f, .125f, .018f, .018f, .032f);
            SetPanel(instrument, "R51 Observation pressure seal plate", body, materials);

            var pivot = Node(instrument, "Seal monitor needle", Vector3.zero);
            pivot.localRotation = Quaternion.AngleAxis(46f, Vector3.forward);
            var needle = new Plates(1);
            needle.Raised(0f, .026f, .010f, .053f, .003f, .049f, .0015f, 0);
            SetPanel(pivot, "R51 Observation monitor needle", needle, new[] { materials[2] });
            var lamp = Node(instrument, "Vitrine memory status lens", new Vector3(0f, -.077f, 0f));
            var lens = new Plates(1);
            lens.Raised(0f, 0f, .066f, .010f, .003f, .043f, .001f, 0);
            SetPanel(lamp, "R51 Observation relay status lens", lens, new[] { phosphor });
            BindR51Indicator(instrument, pivot, lamp.GetComponent<MeshRenderer>(), null, cue, null, standby, Color.clear, 46f, -35f);
        }

        private static void DressR51FactoryCasting(MeshRenderer renderer, Material material)
        {
            if (!renderer || renderer.sharedMaterials.Length != 1) throw new InvalidDataException("One surveyed hardware surface changed its material slots.");
            renderer.sharedMaterial = material;
            PrefabUtility.RecordPrefabInstancePropertyModifications(renderer);
        }

        private static void BindR51Indicator(Transform housing, Transform needle, Renderer lens, StormworksRoute route,
            Light memorySignal, TextMesh label, Color inactive, Color energized, float standby, float live)
        {
            using var data = new SerializedObject(housing.gameObject.AddComponent<StationMechanicalIndicator>());
            data.FindProperty("relay").objectReferenceValue = route;
            data.FindProperty("memorySignal").objectReferenceValue = memorySignal;
            data.FindProperty("needle").objectReferenceValue = needle;
            data.FindProperty("lens").objectReferenceValue = lens;
            data.FindProperty("label").objectReferenceValue = label;
            data.FindProperty("inactiveColor").colorValue = inactive;
            data.FindProperty("relayOnlineColor").colorValue = energized;
            data.FindProperty("standbyAngle").floatValue = standby;
            data.FindProperty("liveAngle").floatValue = live;
            data.ApplyModifiedPropertiesWithoutUndo();
        }
    }
}
