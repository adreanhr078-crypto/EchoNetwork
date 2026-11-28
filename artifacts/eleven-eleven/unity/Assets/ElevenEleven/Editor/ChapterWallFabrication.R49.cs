using System;
using System.IO;
using System.Linq;
using ElevenEleven.Opening;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using static ElevenEleven.Editor.GodotRoomAssembly;

namespace ElevenEleven.Editor
{
    internal static partial class ChapterWallFabrication
    {
        internal const string R49Quarantine = "Quarantine operating status panel";

        public static void FitReactorAndQuarantine()
        {
            var scene = EditorSceneManager.OpenScene(ScenePath);
            var content = scene.GetRootGameObjects().Single(root => root.name == "Room content").transform;
            var station = content.Find("Echo Station");
            var reactor = station.GetComponentInChildren<StationReactorWing>(true);
            var quarantine = station.GetComponentInChildren<StationQuarantineWing>(true);
            var framing = content.GetComponentInChildren<ChapterCameraFraming>(true);
            var route = station.GetComponent<StormworksRoute>();
            var routeJson = EditorJsonUtility.ToJson(route);
            var reactorJson = EditorJsonUtility.ToJson(reactor);
            var colliders = content.GetComponentsInChildren<Collider>(true).ToDictionary(c => c,
                c => (record: EditorJsonUtility.ToJson(c), matrix: c.transform.localToWorldMatrix));

            AddReactorClearance(reactor.transform, framing);
            FitReactorConduit(reactor.transform);
            FitQuarantineReadout(quarantine);
            RefinePrecisionMechanisms(station);

            var after = content.GetComponentsInChildren<Collider>(true);
            if (routeJson != EditorJsonUtility.ToJson(route) || reactorJson != EditorJsonUtility.ToJson(reactor) ||
                after.Length != colliders.Count || after.Any(c => !colliders.TryGetValue(c, out var prior) ||
                    prior.record != EditorJsonUtility.ToJson(c) || prior.matrix != c.transform.localToWorldMatrix))
                throw new InvalidDataException("The approach finish modified reactor authority or a physical route shape.");
            AssetDatabase.SaveAssets();
            if (!EditorSceneManager.SaveScene(scene)) throw new IOException("Could not save the reactor and quarantine approaches.");
            Debug.Log($"ECHO_R49_APPROACHES_SAVED approach_arms=3 reactive_quarantine_panel=true colliders={colliders.Count}");
        }

        private static void AddReactorClearance(Transform reactor, ChapterCameraFraming framing)
        {
            using var layout = new SerializedObject(framing);
            var limits = layout.FindProperty("approachArms");
            if (limits.arraySize == 2) limits.InsertArrayElementAtIndex(2);
            if (limits.arraySize != 3) throw new InvalidDataException("Expected the pressure and surveillance approach volumes.");
            var clearance = limits.GetArrayElementAtIndex(2);
            clearance.FindPropertyRelative("reference").objectReferenceValue = reactor;
            // Keep the threshold edge and lengthen the blend on the room side.
            clearance.FindPropertyRelative("center").vector3Value = new Vector3(0f, -3.86f, 1.9275f);
            clearance.FindPropertyRelative("size").vector3Value = new Vector3(2.4f, 1.64f, 2.145f);
            clearance.FindPropertyRelative("blendMargin").floatValue = 1.65f;
            clearance.FindPropertyRelative("maximumArm").floatValue = 1.03f;
            layout.ApplyModifiedPropertiesWithoutUndo();
        }

        private static void FitReactorConduit(Transform reactor)
        {
            var sleeves = reactor.Cast<Transform>().Where(child => child.name == "Reserve conduit wall").ToArray();
            if (sleeves.Length != 2) throw new InvalidDataException("Expected the two approved reserve conduit walls.");
            var root = ResetNamed(reactor, "Reserve conduit meter and ventilation liners");
            var graphite = AssetDatabase.LoadAssetAtPath<Material>(Folder + "R47 sterile graphite housing.mat");
            var alloy = AssetDatabase.LoadAssetAtPath<Material>(Folder + "Station worked manganese alloy.mat");
            var enamel = AssetDatabase.LoadAssetAtPath<Material>(Folder + "R47 blue-grey sterile enamel.mat");
            var cyan = AssetDatabase.LoadAssetAtPath<Material>(Folder + "R47 specimen status phosphor.mat");
            var amber = AssetDatabase.LoadAssetAtPath<Material>(Folder + "R47 ochre service markers.mat");
            var palette = new[] { graphite, enamel, alloy, cyan, amber };
            var lining = new Plates(palette.Length);
            for (var i = 0; i < 5; i++)
            {
                var x = (i - 2) * 2.45f;
                lining.Raised(x, .02f, 2.41f, 2.948f, .076f, .019f, .012f, 0);
                lining.Raised(x, .27f, 2.31f, 1.32f, .071f, .036f, .016f, 1);
                lining.Raised(x, -.75f, 2.26f, .581f, .044f, .044f, .012f, 1);
                lining.Raised(x, 1.031f, 2.24f, .084f, .014f, .047f, .009f, 2);
                lining.Raised(x, 1.031f, 1.51f, .020f, .005f, .050f, .003f, i == 0 || i == 4 ? 4 : 3);
                for (var slot = 0; slot < 6; slot++)
                    lining.Raised(x -.65f + slot * .26f, -.741f, .115f, .268f, .016f, .052f, .003f, 2);
                lining.Bolt(x - 1.07f, .829f, .032f, .037f, .054f);
                lining.Bolt(x + 1.07f, .829f, .032f, .037f, .054f);
            }
            foreach (var surface in sleeves)
            {
                var normal = surface.localPosition.x > 0f ? Vector3.left : Vector3.right;
                var liner = Node(root, normal.x > 0f ? "West conduit recessed plates" : "East conduit recessed plates",
                    surface.localPosition + normal * (surface.localScale.x * .5f + .004f));
                liner.localRotation = Quaternion.LookRotation(normal, Vector3.up);
                SetPanel(liner, "R49 reserve conduit liner", lining, palette);
            }
        }

        private static void FitQuarantineReadout(StationQuarantineWing quarantine)
        {
            var root = quarantine.transform;
            var art = root.Find("Godot quarantine architecture");
            var terminal = Find(art, "QuarantineOverrideTerminal");
            var native = terminal.Find("_MeshInstance3D_535").GetComponent<MeshRenderer>();
            var oldReadout = terminal.Find("_MeshInstance3D_535/PressureReadout").GetComponent<MeshRenderer>();
            var panel = ResetNamed(root, R49Quarantine);
            panel.localPosition = root.InverseTransformPoint(native.bounds.center) + new Vector3(0f, .009f, -.047f);
            panel.localRotation = Quaternion.LookRotation(new Vector3(0f, .29f, -1f), Vector3.up);
            native.enabled = false;
            oldReadout.enabled = false;
            root.Find("Quarantine console status").GetComponent<Light>().intensity = 2.15f;

            var graphite = AssetDatabase.LoadAssetAtPath<Material>(Folder + "R47 sterile graphite housing.mat");
            var alloy = AssetDatabase.LoadAssetAtPath<Material>(Folder + "Station worked manganese alloy.mat");
            var glass = AssetDatabase.LoadAssetAtPath<Material>(Folder + "R47 recorder dark glass.mat");
            var body = new Plates(3);
            body.Raised(0f, 0f, 1.09f, .563f, .039f, .020f, .011f, 0);
            body.Raised(0f, .013f, .981f, .445f, .028f, .036f, .010f, 1);
            body.Raised(0f, .011f, .903f, .377f, .018f, .042f, .006f, 2);
            foreach (var x in new[] { -.502f, .502f })
            foreach (var y in new[] { -.233f, .228f })
                body.Bolt(x, y, .012f, .022f, .044f);
            SetPanel(panel, "R49 quarantine instrumentation bezel", body, new[] { graphite, alloy, glass });
            var lamp = root.Find("R40 fitted architectural finish/Quarantine extraction state");
            if (!lamp || !lamp.GetComponent<RoomSystemCue>())
                throw new InvalidDataException("The original live quarantine status lamp is missing.");
            lamp.SetPositionAndRotation(panel.TransformPoint(new Vector3(.306f, -.014f, .068f)),
                Quaternion.LookRotation(-panel.forward, panel.up));
            lamp.localScale = Vector3.one * .61f;
            AddLegend(panel, "QUARANTINE", new Vector3(-.124f, .106f, .048f), .0095f, new Color(.72f, .85f, .86f));
            var locked = Node(panel, "Locked cue", Vector3.zero);
            AddLegend(locked, "RESTRICTED", new Vector3(-.124f, -.063f, .049f), .0095f, new Color(1f, .66f, .30f));
            var cleared = Node(panel, "Cleared cue", Vector3.zero);
            AddLegend(cleared, "CLEARED", new Vector3(-.124f, -.063f, .049f), .0095f, new Color(.34f, .96f, .68f));
            cleared.gameObject.SetActive(false);
            StormworksConstruction.Wire(quarantine, ("lockedCue", locked.gameObject), ("clearedCue", cleared.gameObject));
        }
    }
}
