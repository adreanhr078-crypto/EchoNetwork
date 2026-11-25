using System;
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
    internal static class ChapterRoomTripoKit
    {
        private const string ScenePath = "Assets/ElevenEleven/Scenes/ChapterRoom01.unity";
        private const string Kit = "TripoChapterKit/";
        private const string KitPath = "Assets/ElevenEleven/Opening/Stormworks/" + Kit;
        private const string Layer = "Flow reference architectural kit";
        private static readonly Color WarmSignal = new Color(1f, .62f, .27f);

        [MenuItem("11.11/Fit Chapter Tripo Architecture")]
        public static void Apply()
        {
            if (!Application.isBatchMode && !EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo()) return;
            var scene = EditorSceneManager.OpenScene(ScenePath);
            var content = scene.GetRootGameObjects().Single(root => root.name == "Room content").transform;
            var station = content.Find("Echo Station");
            var colliders = station.GetComponentsInChildren<Collider>(true).ToHashSet();
            var signal = Reset(station, Vector3.zero);
            foreach (var z in new[] { 2.65f, 7.9f, 13.75f })
                Fit(signal, "SignalArch", $"Signal roof frame {z}", new Vector3(0f, 3.39f, z),
                    new Vector3(20.7f, 6.78f, .78f), 0f);
            foreach (var side in new[] { -1, 1 })
            {
                foreach (var z in new[] { -3.4f, .45f, 12.7f, 16.12f })
                    Fit(signal, "SignalWall", $"Signal wall cassette {side} {z}", new Vector3(side * 11.37f, 2.86f, z),
                        new Vector3(3.35f, 5.42f, .57f), side < 0 ? 90f : -90f);
                Fit(signal, "PressureCassette", $"Plenum circulation controls {side}",
                    new Vector3(side * 3.55f, 2.60f, side < 0 ? 30.05f : 27.9f),
                    new Vector3(1.54f, 2.80f, .36f), side < 0 ? 90f : -90f);
            }
            Fit(signal, "SignalConsole", "Signal workbench with recessed instruments",
                new Vector3(8.6f, .79f, 10.6f), new Vector3(2.08f, 1.56f, 1.11f), -90f, optional: true);
            Pool(signal, "Workbench practical spill", new Vector3(7.78f, 1.77f, 10.48f), WarmSignal, 5.2f, 5.1f);
            foreach (var side in new[] { -1, 1 })
            {
                foreach (var z in new[] { -3.4f, .12f, 3.64f, 7.16f, 10.68f, 14.20f })
                    Fit(signal, "WetDeckSection", $"Riveted signal walkway skin {side} {z}",
                        new Vector3(side * 3.82f, .012f, z), new Vector3(2.04f, .040f, 3.46f), 0f, optional: true);
                Fit(signal, "WetDeckSection", $"Vented pressure tread skin {side}",
                    new Vector3(side * 1.82f, .012f, 28.25f), new Vector3(2.46f, .040f, 3.60f), 0f, optional: true);
                Fit(signal, "UtilityLamp", $"Amber corridor canopy luminaire {side}",
                    new Vector3(side * 3.22f, 4.53f, 25.85f), new Vector3(.61f, .37f, .27f),
                    side < 0 ? 90f : -90f, optional: true);
                Pool(signal, $"Pressure louvers' amber spill {side}",
                    new Vector3(side * 2.92f, 4.28f, 26.27f), WarmSignal, 3.4f, 5.25f);
            }
            foreach (var z in new[] { 27.2f, 30.16f })
                Fit(signal, "CeilingDuctCassette", $"Radiused ceiling duct cassette {z}",
                    new Vector3(-1.95f, 5.02f, z), new Vector3(2.72f, 1.64f, .30f), 0f, optional: true, pitch: 90f);
            var wetDeck = AssetDatabase.LoadAssetAtPath<Material>(
                "Assets/ElevenEleven/Opening/Room01/Fidelity/WetCeramicDeck.mat");
            if (!wetDeck) throw new InvalidDataException("The approved tracked wet deck material is missing.");
            content.Find("Sector 11/Flooded deck").GetComponent<MeshRenderer>().sharedMaterial = wetDeck;
            station.Find("Airlock tread").GetComponent<MeshRenderer>().sharedMaterial = wetDeck;

            var observatory = station.Find("Memory Observatory");
            var observatoryKit = Reset(observatory, Vector3.zero);
            Fit(observatoryKit, "RelayWinch", "Relay branch cable drum",
                new Vector3(-17.10f, 1.97f, 55.62f), new Vector3(1.07f, 1.10f, .94f), 77f, optional: true);
            Fit(observatoryKit, "MemoryLabCoolant", "Memory-lab coolant manifold",
                new Vector3(18.46f, 3.51f, 65.91f), new Vector3(2.64f, 1.49f, .31f), -90f, optional: true);

            var reactor = station.Find("Reserve reactor wing");
            var reactorKit = Reset(reactor, Vector3.zero);
            var core = Find(reactor.Find("Native Godot reactor geometry"), "ReactorCore");
            var shell = core.GetComponentsInChildren<MeshRenderer>(true);
            if (shell.Length == 0) throw new InvalidDataException("Reactor shell has no visual geometry.");
            var bounds = shell.Select(renderer => renderer.bounds).Aggregate((combined, next) =>
            {
                combined.Encapsulate(next);
                return combined;
            });
            var center = reactor.InverseTransformPoint(bounds.center);
            Fit(reactorKit, "ReactorJacket", "Reserve reactor cast-metal jacket",
                center, bounds.size, 180f);
            foreach (var renderer in shell) renderer.enabled = false;
            foreach (var side in new[] { -1, 1 })
            {
                foreach (var z in new[] { 11.42f, 16.08f, 28.65f })
                    Fit(reactorKit, "ReactorSideBus", $"Reactor walkway protected power bus {side} {z}",
                        new Vector3(side * 5.48f, -1.02f, z), new Vector3(4.42f, .70f, .32f),
                        side < 0 ? 90f : -90f, optional: true);
            }

            var security = Reset(station.Find("Security wing"), Vector3.zero);
            Fit(security, "SecurityBulkhead", "Security wall diagnostics inlay", new Vector3(3.74f, 2.52f, 9.0f),
                new Vector3(2.32f, 2.86f, .26f), -90f, optional: true);
            Fit(security, "SecurityBulkhead", "Security pressure telemetry bank", new Vector3(-3.75f, 2.53f, 12.7f),
                new Vector3(2.46f, 2.90f, .24f), 90f, optional: true);
            Fit(security, "UtilityLamp", "Security service amber hood", new Vector3(3.52f, 3.23f, 6.65f),
                new Vector3(.61f, .37f, .27f), -90f, optional: true);

            var specimens = Reset(station.Find("Specimen containment"), Vector3.zero);
            foreach (var x in new[] { -8.2f, -19.8f })
                Fit(specimens, "SpecimenServiceRack", $"Containment auxiliary filtration {x}",
                    new Vector3(x, 1.35f, 16.34f), new Vector3(.95f, 2.66f, .50f), 180f, optional: true);

            var archive = Reset(station.Find("Memory archive wing"), Vector3.zero);
            Fit(archive, "ArchivePrismYoke", "Prism cooling yoke", new Vector3(-10.71f, 3.0f, -6.38f),
                new Vector3(3.4f, 5.35f, .52f), 0f, optional: true);

            var quarantine = Reset(station.Find("Decontamination and quarantine"), Vector3.zero);
            foreach (var z in new[] { 13.5f, 20.3f, 26.2f })
                Fit(quarantine, "QuarantineAirHandler", $"Quarantine downdraft filter {z}",
                    new Vector3(5.9f, 5.24f, z), new Vector3(2.9f, 1.13f, .43f), -90f, optional: true);

            var surveillance = station.Find("Surveillance and mirror");
            var monitors = Reset(surveillance, Vector3.zero);
            foreach (var z in new[] { 7.4f, 14.2f })
                Fit(monitors, "SurveillanceCableBay", $"Smoked-glass monitoring bay {z}",
                    new Vector3(-3.5f, 2.55f, z), new Vector3(2.8f, 2.94f, .30f), 90f, optional: true);

            var theatre = Find(surveillance, "Kinja examination theatre");
            var theatreKit = Reset(theatre, Vector3.zero);
            Fit(theatreKit, "ExaminationCrown", "Suspended examination optics",
                new Vector3(1.35f, 5.15f, 19.55f), new Vector3(3.28f, 1.53f, 1.2f), 180f, optional: true);
            Fit(theatreKit, "ZeroBasaltRing", "Basalt fragments enclosing the threshold",
                new Vector3(0f, .064f, 32.65f), new Vector3(5.85f, .125f, 5.55f), 0f, optional: true);
            Fit(theatreKit, "KinjaObservationPanel", "Bruised-violet observation panel",
                new Vector3(-5.72f, 3.42f, 20.93f), new Vector3(3.36f, 2.29f, .32f), 90f, optional: true);

            var ward = Find(station, "Awakening ward");
            var wardrobe = Reset(ward, Vector3.zero);
            if (Fit(wardrobe, "WardRadiator", "Recessed ward radiator with satin louvres",
                    new Vector3(0f, .52f, -2.67f), new Vector3(1.87f, .63f, .23f), 0f, optional: true))
            {
                var old = ward.Find("Ward architectural finish");
                foreach (var detail in old.Cast<Transform>().Where(item => item.name is "Window radiator case" or "Radiator louvre"))
                    detail.GetComponent<MeshRenderer>().enabled = false;
            }

            if (!colliders.SetEquals(station.GetComponentsInChildren<Collider>(true)))
                throw new InvalidDataException("The architecture pass changed collision authority.");
            var motion = station.GetComponentsInChildren<RoomEnvironmentMotion>(true);
            if (motion.Length != 16 || motion.Any(room => room.PieceCount < 15))
                throw new InvalidDataException("An authored area lost environmental movement.");

            if (!EditorSceneManager.SaveScene(scene)) throw new IOException("Could not save the chapter Tripo architecture.");
            Debug.Log($"ECHO_CHAPTER_TRIPO_SAVED colliders={colliders.Count} zones={motion.Length} moving_elements={motion.Sum(room => room.PieceCount)}");

            if (Environment.GetEnvironmentVariable("ECHO_STATION_CAPTURE") != null)
            {
                CaptureChapter(content, station, "Tripo");
                Debug.Log("ECHO_CHAPTER_TRIPO_CAPTURED");
            }
        }

        internal static void CaptureChapter(Transform content, Transform station, string pass)
        {
            var reactor = station.Find("Reserve reactor wing");
            var security = station.Find("Security wing");
            var specimens = station.Find("Specimen containment");
            var archive = station.Find("Memory archive wing");
            var quarantine = station.Find("Decontamination and quarantine");
            var observatory = station.Find("Memory Observatory");
            var surveillance = station.Find("Surveillance and mirror");
            var theatre = Find(surveillance, "Kinja examination theatre");
            var ward = Find(station, "Awakening ward");
            content.gameObject.SetActive(true);
            var camera = content.GetComponentsInChildren<Camera>(true).Single(item => item.name == "Room 01 camera");
            foreach (var renderer in content.GetComponentInChildren<Room01Player>(true).GetComponentsInChildren<Renderer>(true))
                renderer.enabled = false;
            Frame(camera, station, $"41-{pass}-Signal", new Vector3(.75f, 1.84f, -5.8f), new Vector3(.25f, 2.70f, 13.2f));
            Frame(camera, station, $"42-{pass}-Signal-Reverse", new Vector3(-2.2f, 1.86f, 14.1f), new Vector3(-4.85f, 2.6f, .10f));
            Frame(camera, station, $"43-{pass}-Pressure", new Vector3(-.35f, 1.82f, 22.70f), new Vector3(1.90f, 2.4f, 29.95f));
            Frame(camera, reactor, $"49-{pass}-Reactor", new Vector3(0f, -1.99f, 7.9f),
                reactor.Find(Layer + "/Reserve reactor cast-metal jacket").localPosition);
            Frame(camera, security, $"46-{pass}-Security", new Vector3(-1.95f, 1.84f, 5.3f), new Vector3(3.3f, 2.5f, 10.25f));
            Frame(camera, specimens, $"47-{pass}-Specimens", new Vector3(-3.4f, 1.90f, 10.1f), new Vector3(-15f, 2.2f, 15.2f));
            Frame(camera, archive, $"48-{pass}-Archive", new Vector3(-6.5f, 2.42f, 2.1f), new Vector3(-10.7f, 2.64f, -5.1f));
            Frame(camera, quarantine, $"50-{pass}-Quarantine", new Vector3(-.6f, 1.86f, 11.1f), new Vector3(4.2f, 3.25f, 21.36f));
            Frame(camera, surveillance, $"51-{pass}-Surveillance", new Vector3(.8f, 2.2f, 5.4f), new Vector3(-2.78f, 2.55f, 13.2f));
            Frame(camera, theatre, $"54-{pass}-Examination", new Vector3(.1f, 3.29f, 13.65f), new Vector3(.9f, 3.66f, 19.4f));
            Frame(camera, observatory, $"44-{pass}-Relay", new Vector3(-13.6f, 2.58f, 51.65f), new Vector3(-16.9f, 1.85f, 55.7f));
            Frame(camera, observatory, $"45-{pass}-Memory-Lab", new Vector3(14.3f, 2.15f, 61.15f), new Vector3(17.35f, 2.68f, 66.2f));
            Frame(camera, theatre, $"55-{pass}-Zero", new Vector3(-.85f, 2.76f, 28.95f), new Vector3(0f, .58f, 32.65f));
            Frame(camera, theatre, $"56-{pass}-Confrontation", new Vector3(-2.67f, 2.52f, 17.10f), new Vector3(-4.88f, 3.31f, 20.9f));
            if (pass != "Tripo")
                Frame(camera, observatory, $"52-{pass}-Observatory", new Vector3(.2f, 1.85f, 57.4f), new Vector3(0f, 4.1f, 72.6f));
            if (pass is "R37" or "Lighting")
            {
                Frame(camera, station, $"61-{pass}-Signal-Instruments", new Vector3(-1.12f, 1.87f, .14f),
                    new Vector3(-6.54f, 1.56f, 4.56f));
                Frame(camera, station, $"62-{pass}-Pressure-Extractor", new Vector3(-1.72f, 1.89f, 25.37f),
                    new Vector3(2.95f, 2.45f, 28.18f));
                Frame(camera, security, $"63-{pass}-Security-Checkpoint", new Vector3(-.85f, 1.79f, 2.82f),
                    new Vector3(1.87f, 2.08f, 15.85f));
                Frame(camera, surveillance, $"64-{pass}-Surveillance-Stations", new Vector3(-6.93f, 1.81f, 9.3f),
                    new Vector3(-11.81f, 2.25f, 16.95f));
            }
            ward.gameObject.SetActive(true);
            Frame(camera, ward, $"57-{pass}-Ward", new Vector3(2.00f, 1.72f, 2.3f), new Vector3(-.62f, 1.32f, -2.02f));
            Debug.Log($"ECHO_CHAPTER_ROOM_CAPTURES {pass}");
        }

        private static Transform Reset(Transform room, Vector3 center)
        {
            if (!room) throw new InvalidDataException("An expected authored room was not found.");
            var existing = room.Find(Layer);
            if (existing) UnityEngine.Object.DestroyImmediate(existing.gameObject);
            return Node(room, Layer, center);
        }

        private static bool Fit(Transform layer, string asset, string label, Vector3 position, Vector3 size,
            float yaw, bool optional = false, float pitch = 0f)
        {
            if (optional && !AssetDatabase.LoadAssetAtPath<GameObject>(KitPath + asset + ".glb")) return false;
            StormworksConstruction.FittedProp(layer, label, Kit + asset + ".glb", position, size, yaw);
            var mount = layer.Find(label);
            mount.localRotation *= Quaternion.Euler(pitch, 0f, 0f);
            var filters = mount.GetComponentsInChildren<MeshFilter>(true);
            int triangles = 0;
            foreach (var filter in filters)
            {
                if (!filter.sharedMesh) throw new InvalidDataException($"Missing mesh in {asset}.");
                var mesh = filter.sharedMesh;
                for (var sub = 0; sub < mesh.subMeshCount; sub++)
                    triangles += (int)mesh.GetIndexCount(sub) / 3;
            }
            if (triangles is < 500 or > 30000)
                throw new InvalidDataException($"Unexpected triangle count for {asset}: {triangles}.");
            foreach (var renderer in mount.GetComponentsInChildren<MeshRenderer>(true))
                renderer.shadowCastingMode = ShadowCastingMode.Off;
            Debug.Log($"ECHO_CHAPTER_TRIPO_FIT {asset} {triangles} triangles / {label}");
            return true;
        }

        private static void Pool(Transform parent, string name, Vector3 at, Color color, float power, float range)
        {
            var light = Node(parent, name, at).gameObject.AddComponent<Light>();
            light.type = LightType.Point;
            light.color = color;
            light.intensity = power;
            light.range = range;
        }

        private static void Frame(Camera camera, Transform room, string name, Vector3 position, Vector3 focus)
        {
            var target = room.TransformPoint(focus);
            var origin = room.TransformPoint(position);
            camera.transform.SetPositionAndRotation(origin, Quaternion.LookRotation(target - origin));
            StormworksSmoke.Capture(camera, name);
        }
    }
}
