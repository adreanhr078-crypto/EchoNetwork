using System;
using System.IO;
using System.Linq;
using ElevenEleven.Opening;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;

namespace ElevenEleven.Editor
{
    internal static partial class ChapterWallFabrication
    {
        internal const string R51ArchiveFace = "Archive decoder optical readout";
        internal const string R51PressureIntake = "Pressure intake cassette assembly";

        public static void FitArchiveDecoderAndPressureIntake()
        {
            var scene = EditorSceneManager.OpenScene(ScenePath);
            var content = scene.GetRootGameObjects().Single(root => root.name == "Room content").transform;
            var station = content.Find("Echo Station");
            var route = station.GetComponent<StormworksRoute>();
            var archive = station.Find("Memory archive wing").GetComponent<StationArchiveWing>();
            var authority = new Component[] { route, archive };
            var authorityBefore = authority.Select(component => EditorJsonUtility.ToJson(component)).ToArray();
            var colliders = content.GetComponentsInChildren<Collider>(true).ToDictionary(collider => collider,
                collider => (serialized: EditorJsonUtility.ToJson(collider), matrix: collider.transform.localToWorldMatrix));

            var graphite = R51Material("R47 sterile graphite housing");
            var manganese = R51Material("Station worked manganese alloy");
            var amber = R51Material("R47 ochre service markers");
            var phosphor = R51Material("R47 specimen status phosphor");
            FitR51Archive(archive.transform, route, new[] { graphite, R51Material("R47 blue-grey sterile enamel"),
                manganese, amber, R51Material("R47 recorder dark glass") }, phosphor);
            FitR51Pressure(station, route, new[] { R51Material("Dark neutral iron backing"), manganese,
                R51Material("Surveillance grate and screw heads"), amber }, phosphor);
            FrameR51PressureValve(station, content.GetComponentInChildren<ChapterCameraFraming>(true));

            var after = content.GetComponentsInChildren<Collider>(true);
            if (after.Length != colliders.Count || after.Any(collider => !colliders.TryGetValue(collider, out var before) ||
                    before.serialized != EditorJsonUtility.ToJson(collider) || before.matrix != collider.transform.localToWorldMatrix) ||
                !authorityBefore.SequenceEqual(authority.Select(component => EditorJsonUtility.ToJson(component))))
                throw new InvalidDataException("The Archive readout or pressure intake changed route authority or collision.");

            AssetDatabase.SaveAssets();
            if (!EditorSceneManager.SaveScene(scene)) throw new IOException("Could not save the Archive and Pressure finish.");
            Debug.Log($"ECHO_R51_ARCHIVE_PRESSURE_SAVED colliders={colliders.Count} authority={authority.Length} intake_cassettes=6");
        }

        private static Material R51Material(string name)
        {
            var material = AssetDatabase.LoadAssetAtPath<Material>(Folder + name + ".mat");
            return material ? material : throw new InvalidDataException("Missing cached R51 material: " + name);
        }

        private static void FrameR51PressureValve(Transform station, ChapterCameraFraming camera)
        {
            if (!station.Find("Pressure bypass") || !camera)
                throw new InvalidDataException("The live pressure controls or camera are missing.");
            using var settings = new SerializedObject(camera);
            var limits = settings.FindProperty("approachArms");
            if (limits.arraySize == 3) limits.InsertArrayElementAtIndex(3);
            if (limits.arraySize != 4) throw new InvalidDataException("The three previously verified approaches are required.");
            var valve = limits.GetArrayElementAtIndex(3);
            valve.FindPropertyRelative("reference").objectReferenceValue = station;
            valve.FindPropertyRelative("center").vector3Value = new Vector3(-2.15f, .3f, 23.15f);
            valve.FindPropertyRelative("size").vector3Value = new Vector3(1.15f, 3f, 1.05f);
            valve.FindPropertyRelative("blendMargin").floatValue = .54f;
            valve.FindPropertyRelative("maximumArm").floatValue = .95f;
            settings.ApplyModifiedPropertiesWithoutUndo();
        }

        private static void FitR51Archive(Transform archive, StormworksRoute route, Material[] materials, Material phosphor)
        {
            const string model = "Native Godot archive geometry/ArchiveDecoderConsole/Model7/EchoSignalConsole_Root";
            var console = archive.Find(model);
            var display = console?.Find("EchoSignalConsole_ScreenMount/NativeArchiveDecoderReadout");
            var graphiteShell = console?.Find("EchoSignalConsole_Static_Graphite")?.GetComponent<MeshRenderer>();
            var titaniumShell = console?.Find("EchoSignalConsole_Static_Titanium")?.GetComponent<MeshRenderer>();
            if (!display || !graphiteShell || !titaniumShell)
                throw new InvalidDataException("The surveyed Archive decoder display and casting are missing.");
            var legacy = display.GetComponent<MeshRenderer>();
            var mesh = display.GetComponent<MeshFilter>().sharedMesh;
            if (mesh.subMeshCount != 1 || mesh.GetIndexCount(0) != 6 ||
                Mathf.Abs(mesh.bounds.size.x - 1.10f) > .01f || Mathf.Abs(mesh.bounds.size.y - .59f) > .01f)
                throw new InvalidDataException("The Archive decoder screen no longer matches the measured optical opening.");

            var towardEntry = archive.TransformDirection(Vector3.back);
            var normal = display.forward;
            var facing = Vector3.Dot(normal, towardEntry);
            if (Mathf.Abs(facing) < .80f) throw new InvalidDataException("The Archive decoder opening has turned away from its approach.");
            if (facing < 0f) normal = -normal;

            var face = ResetNamed(archive, R51ArchiveFace);
            face.SetPositionAndRotation(legacy.bounds.center + normal * .002f, Quaternion.LookRotation(normal, display.up));
            var bezel = new Plates(materials.Length);
            bezel.Raised(0f, 0f, 1.164f, .602f, .045f, .016f, .010f, 0);
            bezel.Raised(0f, .030f, 1.053f, .460f, .036f, .029f, .010f, 2);
            bezel.Raised(0f, .030f, .998f, .402f, .025f, .035f, .006f, 4);
            bezel.Raised(0f, .101f, .892f, .004f, .001f, .037f, .001f, 1);
            bezel.Raised(.108f, -.030f, .006f, .197f, .002f, .037f, .001f, 1);
            bezel.Raised(0f, -.237f, .976f, .035f, .008f, .029f, .005f, 1);
            for (var index = 0; index < 8; index++)
            {
                var x = -.413f + index * .116f;
                bezel.Raised(x, -.238f, .075f, .010f, .003f, .035f, .001f, index == 7 ? 3 : 0);
            }
            foreach (var x in new[] { -.540f, .540f })
            foreach (var y in new[] { -.231f, .228f })
                bezel.Bolt(x, y, .014f, .015f, .027f);
            for (var index = 0; index < 3; index++)
                bezel.Raised(-.395f + index * .163f, -.041f, .131f, .051f, .013f, .041f, .004f, 0);
            SetPanel(face, "R51 Archive decoder sealed fascia", bezel, materials);

            var label = new Color(.53f, .72f, .74f);
            AddLegend(face, "ARCHIVE DECODER", new Vector3(-.158f, .166f, .043f), .0090f, new Color(.76f, .93f, .93f));
            AddLegend(face, "FRAGMENT BANK", new Vector3(-.231f, .046f, .043f), .0054f, label);
            AddLegend(face, "SECTOR 11", new Vector3(.322f, .159f, .043f), .0057f, label);
            AddLegend(face, "0 / 3", new Vector3(.290f, .011f, .043f), .0154f, new Color(.93f, .62f, .33f));
            AddLegend(face, "AWAITING FRAGMENTS", new Vector3(-.056f, -.135f, .043f), .0061f, new Color(.93f, .62f, .33f));

            var capsule = new Plates(1);
            capsule.Raised(0f, 0f, .090f, .022f, .006f, .047f, .003f, 0);
            var lampMesh = SaveInductorMesh("R51 Archive fragment capsule", capsule.Build("Archive fragment capsule"));
            using var displayData = new SerializedObject(face.gameObject.AddComponent<ArchiveDecoderReadout>());
            displayData.FindProperty("route").objectReferenceValue = route;
            displayData.FindProperty("count").objectReferenceValue = face.Cast<Transform>()
                .Single(child => child.name == "0 / 3").GetComponent<TextMesh>();
            displayData.FindProperty("state").objectReferenceValue = face.Find("AWAITING FRAGMENTS").GetComponent<TextMesh>();
            var lamps = displayData.FindProperty("fragmentLamps");
            lamps.arraySize = 3;
            for (var index = 0; index < lamps.arraySize; index++)
            {
                var lamp = new GameObject($"Fragment capsule {index + 1}").transform;
                lamp.SetParent(face, false);
                lamp.localPosition = new Vector3(-.395f + index * .163f, -.041f, 0f);
                lamp.gameObject.AddComponent<MeshFilter>().sharedMesh = lampMesh;
                var renderer = lamp.gameObject.AddComponent<MeshRenderer>();
                renderer.sharedMaterial = phosphor;
                renderer.shadowCastingMode = ShadowCastingMode.Off;
                renderer.enabled = false;
                lamps.GetArrayElementAtIndex(index).objectReferenceValue = renderer;
            }
            displayData.ApplyModifiedPropertiesWithoutUndo();

            legacy.enabled = false;
            graphiteShell.sharedMaterial = materials[0];
            titaniumShell.sharedMaterial = materials[2];
            foreach (var renderer in new[] { legacy, graphiteShell, titaniumShell })
                PrefabUtility.RecordPrefabInstancePropertyModifications(renderer);
        }

        private static void FitR51Pressure(Transform station, StormworksRoute route, Material[] materials, Material phosphor)
        {
            var legacy = station.Find("Pressure intake grille");
            var slots = station.Cast<Transform>().Where(part => part.name == "Grille slot").ToArray();
            if (!legacy || slots.Length != 12 || (legacy.localScale - new Vector3(6.35f, .05f, 1.4f)).sqrMagnitude > .0001f)
                throw new InvalidDataException("The surveyed pressure intake footprint or slot count changed.");

            var layer = ResetNamed(station, R51PressureIntake);
            layer.localPosition = new Vector3(legacy.localPosition.x, legacy.localPosition.y - .025f, legacy.localPosition.z);
            layer.localRotation = Quaternion.LookRotation(Vector3.up, Vector3.forward);
            var plate = new Plates(materials.Length);
            plate.Raised(0f, 0f, 6.34f, 1.39f, .046f, .014f, .008f, 0);
            foreach (var z in new[] { -.648f, .648f })
                plate.Raised(0f, z, 6.31f, .095f, .024f, .041f, .008f, 1);
            foreach (var x in new[] { -3.119f, 3.119f })
                plate.Raised(x, 0f, .092f, 1.24f, .023f, .043f, .009f, 1);

            for (var bay = 0; bay < 6; bay++)
            {
                var center = (bay - 2.5f) * 1.015f;
                if (bay != 0)
                    plate.Raised(center - .508f, 0f, .079f, 1.230f, .014f, .043f, .007f, 1);
                foreach (var z in new[] { -.549f, .549f })
                    plate.Raised(center, z, .955f, .074f, .011f, .036f, .006f, 1);
                for (var slat = 0; slat < 10; slat++)
                    plate.Raised(center + (slat - 4.5f) * .093f, 0f, .053f, 1.04f, .010f, .045f, .006f, 2);
                foreach (var z in new[] { -.648f, .648f })
                foreach (var x in new[] { -.398f, .398f })
                    plate.Bolt(center + x, z, .020f, .038f, .054f);
            }

            foreach (var x in new[] { -2.69f, 2.69f })
                plate.Raised(x, -.648f, .177f, .043f, .008f, .046f, .003f, 3);
            SetPanel(layer, "R51 six pressure intake cassettes", plate, materials);
            layer.GetComponent<MeshRenderer>().shadowCastingMode = ShadowCastingMode.On;

            var marker = new GameObject("Intake pressure status indicators").transform;
            marker.SetParent(layer, false);
            var indicators = new Plates(1);
            foreach (var z in new[] { -.648f, .648f })
            foreach (var x in new[] { -.152f, .152f })
                indicators.Raised(x, z, .110f, .027f, .006f, .050f, .003f, 0);
            SetPanel(marker, "R51 pressure intake status lenses", indicators, new[] { phosphor });
            var spill = new GameObject("Intake status bounce").AddComponent<Light>();
            spill.transform.SetParent(marker, false);
            spill.transform.localPosition = Vector3.forward * .13f;
            spill.type = LightType.Point;
            spill.range = .58f;
            spill.shadows = LightShadows.None;
            using var cue = new SerializedObject(marker.gameObject.AddComponent<RoomSystemCue>());
            cue.FindProperty("route").objectReferenceValue = route;
            cue.FindProperty("channel").enumValueIndex = (int)RoomSystemCue.SystemChannel.Pressure;
            cue.FindProperty("lens").objectReferenceValue = marker.GetComponent<MeshRenderer>();
            cue.FindProperty("spill").objectReferenceValue = spill;
            cue.ApplyModifiedPropertiesWithoutUndo();
            legacy.GetComponent<MeshRenderer>().enabled = false;
            foreach (var slot in slots) slot.GetComponent<MeshRenderer>().enabled = false;
        }
    }
}
