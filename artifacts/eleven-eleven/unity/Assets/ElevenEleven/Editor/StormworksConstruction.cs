using System;
using System.Collections.Generic;
using System.IO;
using ElevenEleven.Opening;
using UnityEditor;
using UnityEditor.Events;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.SceneManagement;
using UnityEngine.UI;
using UnityEngine.Video;
using static ElevenEleven.Editor.OpeningReviewSceneBuilder;

namespace ElevenEleven.Editor
{
    internal static class StormworksConstruction
    {
        private const string Root = "Assets/ElevenEleven/";
        private const string Output = Root + "Opening/Stormworks/";
        private const string Room = Root + "Scenes/ChapterRoom01.unity";
        private static readonly Color Teal = new Color(0.035f, 1f, 0.73f);
        private static readonly Color Gold = new Color(1f, 0.41f, 0.055f);
        private static readonly Color Violet = new Color(0.60f, 0.16f, 1f);
        private static readonly Color Indigo = new Color(0.18f, 0.075f, 0.43f);

        [MenuItem("11.11/Build Station Extension")]
        public static void Upgrade()
        {
            if (!Application.isBatchMode && !EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo()) return;
            var scene = EditorSceneManager.OpenScene(Room);
            Apply(scene);
            if (!EditorSceneManager.SaveScene(scene)) throw new IOException($"Could not save {Room}");
        }

        internal static void Apply(Scene scene)
        {
            var content = Array.Find(scene.GetRootGameObjects(), item => item.name == "Room content").transform;
            var shell = content.Find("Sector 11");
            var prior = content.Find("Echo Station");
            if (prior != null) UnityEngine.Object.DestroyImmediate(prior.gameObject);
            var hud = content.Find("Room 01 HUD");
            foreach (var label in new[] { "Station readout", "Station observation", "Jump", "Skip vista", "Archive memory frame" })
            {
                var priorLabel = hud.Find(label);
                if (priorLabel != null) UnityEngine.Object.DestroyImmediate(priorLabel.gameObject);
            }

            var palette = new Palette();
            var root = Group("Echo Station", content);
            EnlargeContainment(shell, root, palette);
            BuildAirlock(shell, root, palette, out var valve, out var wheel, out var pressureSignals);
            BuildStation(root, palette, out var relay, out var door, out var log);
            var security = StationSecurityConstruction.Build(root, palette.Frame, palette.Wet);
            var specimen = StationSpecimenConstruction.Build(root, palette.Frame, palette.Wet, palette.Cyan);
            var archive = StationArchiveConstruction.Build(root, palette.Frame, palette.Wet, palette.Cyan);
            var reactor = StationReactorConstruction.Build(root, palette.Frame, palette.Wet);
            var quarantine = StationQuarantineConstruction.BuildQuarantine(root, palette.Frame, palette.Wet, palette.Cyan, palette.Amber);
            var surveillance = StationQuarantineConstruction.BuildSurveillance(root, palette.Frame, palette.Wet, palette.Cyan, palette.Amber);
            BuildAirAndEnergy(root, palette);
            StormworksArtPass.Dress(root, shell);
            StationWallDressing.Opening(root, shell, palette.Cyan);
            StationSurfaceDressing.Opening(root, palette.Wet);
            InstallAtmosphere(root, content.GetComponentInChildren<Camera>(true));

            var player = content.GetComponentInChildren<Room01Player>(true);
            var route = root.gameObject.AddComponent<StormworksRoute>();
            var font = Load<Font>(Root + "Opening/Media/NotoSansArabic.ttf");
            var vignettes = BuildArchiveMedia(root, hud);
            var readout = BackedLabel("Station readout", hud, font, 27, 0.32f, 0.67f, 0.68f, 0.76f);
            readout.gameObject.SetActive(false);
            var note = BackedLabel("Station observation", hud, font, 21, 0.24f, 0.09f, 0.73f, 0.18f);
            note.gameObject.SetActive(false);
            var jump = Control("Jump", hud, font, 0.78f, 0.24f, 0.95f, 0.34f);
            jump.gameObject.SetActive(false);
            var skip = Control("Skip vista", hud, font, 0.79f, 0.09f, 0.95f, 0.20f);
            skip.gameObject.SetActive(false);
            UnityEventTools.AddPersistentListener(jump.onClick, player.RequestJump);
            UnityEventTools.AddPersistentListener(skip.onClick, player.SkipStationVista);
            hud.Find("Objective plate/Current objective").GetComponent<Text>().font = font;
            var inspect = hud.Find("Inspect  [E]") ?? hud.Find("Interact");
            if (inspect != null) inspect.GetComponentInChildren<Text>(true).font = font;

            var drip = Loop(root, "Containment leak", new Vector3(4.3f, 2.3f, 6.5f),
                Load<AudioClip>(Output + "ServiceDrip.ogg"), 17f);
            var pressure = Loop(root, "Air and turbine", new Vector3(0, 2.8f, 25.7f),
                Load<AudioClip>(Root + "Opening/Media/PressureAir.wav"), 42f);
            var vista = Group("Station reveal camera mark", root);
            vista.localPosition = new Vector3(3.4f, 4.7f, 38.5f);
            var focus = Group("Station reveal aim", root);
            focus.localPosition = new Vector3(0, 7.2f, 63f);
            Wire(route, ("valve", valve), ("wheel", wheel), ("labDoor", door), ("relay", relay), ("labLog", log),
                ("pressureDisplay", readout), ("security", security), ("specimen", specimen), ("archive", archive), ("reactor", reactor),
                ("quarantine", quarantine), ("surveillance", surveillance), ("vignettes", vignettes), ("machinery", pressure), ("drip", drip), ("vista", vista), ("vistaFocus", focus));
            var data = new SerializedObject(route);
            var signals = data.FindProperty("pressureSignals");
            signals.arraySize = pressureSignals.Count;
            for (var index = 0; index < pressureSignals.Count; index++)
                signals.GetArrayElementAtIndex(index).objectReferenceValue = pressureSignals[index];
            data.ApplyModifiedPropertiesWithoutUndo();
            Wire(player, ("station", route), ("jumpControl", jump), ("skipVista", skip), ("stationObservation", note),
                ("schoolRun", SchoolRunReview.BakeInPlace()));
            EditorSceneManager.MarkSceneDirty(scene);
        }

        private static void EnlargeContainment(Transform shell, Transform root, Palette p)
        {
            foreach (var name in new[] { "Flooded deck", "Ceiling", "Rear wall" })
            {
                var item = shell.Find(name);
                item.localScale = new Vector3(24f, item.localScale.y, item.localScale.z);
                item.GetComponent<MeshRenderer>().sharedMaterial = name == "Flooded deck" ? p.Wet : p.Wall;
            }
            foreach (var side in new[] { -1f, 1f })
            {
                var wall = shell.Find(side < 0 ? "West wall" : "East wall");
                wall.localPosition = new Vector3(side * 12f, wall.localPosition.y, wall.localPosition.z);
                wall.GetComponent<MeshRenderer>().sharedMaterial = p.Wall;
                Box(root, "Outer blast wall", new Vector3(side * 10.4f, 3.6f, 18),
                    new Vector3(3.2f, 7.2f, 0.8f), p.Wall);
                for (var i = 0; i < 5; i++)
                {
                    var z = -5f + i * 5f;
                    Box(root, "Wet service base", new Vector3(side * 10.28f, 0.055f, z), new Vector3(2.6f, 0.11f, 4.42f), p.Wet);
                    Box(root, "Floor guide", new Vector3(side * 8.95f, 0.042f, z), new Vector3(0.055f, 0.04f, 4.2f), p.Cyan, false);
                    Box(root, "Lumen cut", new Vector3(side * 11.35f, 4.6f, z + 0.35f), new Vector3(0.08f, 0.085f, 3f), i % 2 == 0 ? p.Cyan : p.Amber, false);
                }
            }
            FittedProp(root, "Original Godot service hatch", "stormworks_precision_bulkhead_v1.glb",
                new Vector3(-11.28f, 1.68f, 5.8f), new Vector3(3.5f, 2.8f, 0.27f), 90f);
            FittedProp(root, "Original Godot service hatch", "stormworks_precision_bulkhead_v1.glb",
                new Vector3(11.28f, 1.68f, 10.8f), new Vector3(3.5f, 2.8f, 0.27f), -90f);
            Point(root, "West service bounce", new Vector3(-9, 2.3f, 6), Teal, 3.0f, 8f);
            Point(root, "East observation bounce", new Vector3(9, 2.8f, 10), Violet, 3.3f, 9f);
            Point(root, "Blast approach practical", new Vector3(0, 4.8f, 13.2f), Gold, 2.4f, 8f);
        }

        private static void BuildAirlock(Transform shell, Transform root, Palette p, out Transform valve,
            out Transform wheel, out List<Renderer> pressureSignals)
        {
            var cap = shell.Find("Next corridor bulkhead");
            cap.gameObject.SetActive(false);
            var floor = shell.Find("Threshold floor");
            floor.GetComponent<MeshRenderer>().sharedMaterial = p.Wet;
            Box(root, "Airlock tread", new Vector3(0, -0.23f, 28.17f), new Vector3(8.4f, 0.46f, 11.7f), p.Wet);
            foreach (var side in new[] { -1f, 1f })
            {
                Box(root, "Plenum wall", new Vector3(side * 4.05f, 2.8f, 28.1f), new Vector3(0.62f, 5.6f, 11.65f), p.Wall);
                Box(root, "Plenum bumper", new Vector3(side * 3.58f, 0.4f, 28.1f), new Vector3(0.2f, 0.8f, 11.6f), p.Frame);
            }
            Box(root, "Airlock canopy", new Vector3(0, 5.7f, 27.2f), new Vector3(8.4f, 0.6f, 9.8f), p.Frame);
            pressureSignals = new List<Renderer>();
            foreach (var z in new[] { 23f, StormworksRoute.PressureStart, 26.4f, 29.2f, 31.6f })
            {
                Box(root, "Service portal header", new Vector3(0, 4.92f, z), new Vector3(7.5f, 0.48f, 0.46f), p.Frame);
                foreach (var side in new[] { -1f, 1f })
                {
                    Box(root, "Service portal column", new Vector3(side * 3.6f, 2.5f, z), new Vector3(0.42f, 5f, 0.46f), p.Frame);
                    pressureSignals.Add(Box(root, "Pressure beacon", new Vector3(side * 3.34f, 2.34f, z),
                        new Vector3(0.06f, 1.36f, 0.16f), p.Cyan, false).GetComponent<Renderer>());
                }
            }
            Box(root, "Pressure intake grille", new Vector3(0, 0.027f, 25.7f), new Vector3(6.35f, 0.05f, 1.4f), p.Frame, false);
            for (var n = 0; n < 12; n++)
                Box(root, "Grille slot", new Vector3(n * 0.55f - 3.03f, 0.054f, 25.7f),
                    new Vector3(0.13f, 0.009f, 1.25f), p.Wet, false);
            valve = Group("Pressure bypass", root);
            valve.localPosition = new Vector3(-2.28f, 1.08f, 23.9f);
            Box(root, "Valve pedestal", new Vector3(-2.28f, 0.51f, 24.17f), new Vector3(0.46f, 1.02f, 0.44f), p.Frame);
            Box(root, "Valve face", new Vector3(-2.28f, 1.1f, 24.07f), new Vector3(0.61f, 0.61f, 0.18f), p.Amber);
            wheel = Group("Valve wheel spindle", valve);
            var original = Load<GameObject>(Root + "MotionReview/stormworks_precision_wheel_v1.glb");
            var model = (GameObject)PrefabUtility.InstantiatePrefab(original, wheel);
            model.transform.localPosition = Vector3.back * 0.06f;
            model.transform.localScale = Vector3.one * 1.6f;
            const string pressureGovernor = "PressureGovernor-Unity.glb";
            if (AssetDatabase.LoadAssetAtPath<GameObject>(Output + pressureGovernor) != null)
            {
                var center = new Vector3(2.32f, 1.17f, 24.0f);
                FittedProp(root, "Hydraulic pressure governor", pressureGovernor, center,
                    new Vector3(1.68f, 2.28f, 1.05f), 180f);
                Box(root, "Governor collision", center, new Vector3(1.57f, 2.25f, 0.95f), p.Frame)
                    .GetComponent<MeshRenderer>().enabled = false;
                Point(root, "Governor gauge spill", center + new Vector3(-0.54f, 0.84f, -1.15f),
                    new Color(0.53f, 0.81f, 1f), 2.3f, 4.1f);
            }
            Point(root, "Airlock tungsten", new Vector3(-1.4f, 3.1f, 23.3f), Gold, 3f, 7f);
            Point(root, "Receiving end", new Vector3(0, 3.7f, 31.2f), Teal, 4f, 9f);
            Sign(root, "Bypass", new Vector3(-2.22f, 1.64f, 23.93f), Gold, 0.18f);
        }

        private static void BuildStation(Transform root, Palette p, out Transform relay, out Transform labDoor, out Transform log)
        {
            Box(root, "Receiving apron", new Vector3(0, -0.25f, 36.8f), new Vector3(14f, 0.5f, 6.8f), p.Wet);
            Box(root, "Station perimeter", new Vector3(0, -0.25f, 77f), new Vector3(38f, 0.5f, 8f), p.Wet);
            Box(root, "Water below", new Vector3(0, -4.4f, 57.8f), new Vector3(70f, 0.1f, 62f), p.Pool, false);
            Walkway(root, p, "Central drainage bridge", 0, 56.35f, 5.8f, 33.1f);
            Walkway(root, p, "West service loop", -15f, 55.15f, 4.3f, 35.7f);
            Walkway(root, p, "East observation loop", 15f, 55.6f, 7.5f, 34.8f);
            Walkway(root, p, "West access", -9f, 40f, 15f, 4.4f);
            Walkway(root, p, "East access", 9f, 40f, 15f, 4.4f);
            Walkway(root, p, "North relay access", -8f, 65f, 14.5f, 4.7f);
            Walkway(root, p, "Lab access", 9f, 62.65f, 16f, 3.3f);

            var tiles = new[]
            {
                new Vector3(-4.72f, 0.20f, 51.7f), new Vector3(-7.31f, 0.41f, 52.95f),
                new Vector3(-9.94f, 0.63f, 54.05f), new Vector3(-12.22f, 0.82f, 55.25f)
            };
            foreach (var tile in tiles)
            {
                Box(root, "Suspended service plate", tile, new Vector3(1.65f, 0.42f, 2.05f), p.Frame);
                Box(root, "Lit anchor edge", tile + new Vector3(0, 0.195f, -1.035f), new Vector3(1.62f, 0.07f, 0.06f), p.Cyan, false);
                Box(root, "Service plate pier", tile + Vector3.down * 2.2f, new Vector3(0.52f, 4.1f, 0.55f), p.Wall, false);
            }
            Box(root, "Relay tower porch", new Vector3(-15, 0.7f, 56.4f), new Vector3(4.3f, 0.8f, 3.6f), p.Wet);
            for (var step = 0; step < 6; step++)
            {
                var h = (step + 1) * 0.183f;
                Box(root, "Relay access step", new Vector3(-15, h * 0.5f, 51f + step * 0.62f),
                    new Vector3(2.75f, h, 0.63f), p.Frame);
                Box(root, "Relay tread nosing", new Vector3(-15, h + 0.006f, 50.73f + step * 0.62f),
                    new Vector3(2.65f, 0.017f, 0.065f), p.Amber, false);
            }
            Box(root, "Relay access landing", new Vector3(-15, 0.54f, 54.48f), new Vector3(2.75f, 1.08f, 0.6f), p.Frame);
            relay = Group("West relay", root);
            relay.localPosition = new Vector3(-15.25f, 1.8f, 56.8f);
            var console = (GameObject)PrefabUtility.InstantiatePrefab(Load<GameObject>(Root + "Opening/Room01/SignalTerminal.glb"), root);
            console.transform.localPosition = new Vector3(-15.25f, 1.1f, 57.3f);
            console.transform.localRotation = Quaternion.Euler(0, 180f, 0);
            Box(root, "Relay terminal collision", new Vector3(-15.25f, 1.75f, 57.28f), new Vector3(0.98f, 1.3f, 0.76f), p.Frame)
                .GetComponent<MeshRenderer>().enabled = false;
            Box(root, "Relay sign backplate", new Vector3(-15.3f, 2.85f, 57.23f),
                new Vector3(2.22f, 0.42f, 0.15f), p.Frame, false);
            Sign(root, "Relay", new Vector3(-15.3f, 2.85f, 57.14f), Teal, 0.23f);
            Point(root, "Relay pool light", new Vector3(-15, 3.8f, 55.7f), Gold, 3.8f, 9f);

            BuildLab(root, p, out labDoor, out log);
            BuildSkyline(root, p);
            Box(root, "Station name plate", new Vector3(-4.9f, 1.95f, 43.1f),
                new Vector3(3.0f, 0.74f, 0.21f), p.Frame, false);
            Box(root, "Station sign support", new Vector3(-4.9f, 0.82f, 43.1f),
                new Vector3(0.28f, 1.72f, 0.39f), p.Frame, false);
            Sign(root, "Station", new Vector3(-4.9f, 1.95f, 42.98f), Teal, 0.40f);
            var clockFace = Tube(root, "Tower clock face", new Vector3(0, 13.1f, 82.65f),
                new Vector3(14.6f, 0.17f, 14.6f), p.Wall);
            clockFace.localRotation = Quaternion.Euler(90f, 0, 0);
            Sign(root, "Clock", new Vector3(0, 13.1f, 82.44f), new Color(0.47f, 0.86f, 1f), 2.1f);
            Point(root, "Entry practical", new Vector3(0, 3.1f, 39f), Teal, 4.0f, 11f);
            Point(root, "Reflector wash", new Vector3(1, 5.0f, 61f), Violet, 5.5f, 18f);
            Point(root, "East lab wash", new Vector3(14, 4.5f, 62f), Teal, 3.2f, 11f);
        }

        private static void BuildLab(Transform root, Palette p, out Transform door, out Transform log)
        {
            Box(root, "Lab east envelope", new Vector3(18.8f, 2.6f, 67f), new Vector3(0.40f, 5.2f, 8.0f), p.Wall);
            Box(root, "Lab west envelope", new Vector3(11.26f, 2.6f, 67f), new Vector3(0.40f, 5.2f, 8.0f), p.Wall);
            Box(root, "Lab rear envelope", new Vector3(15f, 2.6f, 71f), new Vector3(8f, 5.2f, 0.46f), p.Wall);
            Box(root, "Lab canopy", new Vector3(15f, 4.7f, 67f), new Vector3(8f, 0.45f, 8.1f), p.Frame);
            foreach (var side in new[] { -1f, 1f })
                Box(root, "Lab frontage", new Vector3(15f + side * 2.65f, 2.6f, 63f),
                    new Vector3(2.7f, 5.2f, 0.46f), p.Frame);
            Box(root, "Lab door header", new Vector3(15f, 4.28f, 63f), new Vector3(2.55f, 1.25f, 0.49f), p.Frame);
            door = Box(root, "Lab isolation shutter", new Vector3(15f, 1.86f, 63f), new Vector3(2.55f, 3.72f, 0.35f), p.Wall);
            FittedProp(door, "Original Godot shutter armor", "stormworks_precision_gate_v1.glb",
                new Vector3(0, 0f, -0.38f), new Vector3(0.94f, 0.96f, 0.49f), 180f);
            Sign(root, "Lab", new Vector3(15f, 3.97f, 62.71f), Teal, 0.26f);
            log = Group("Lab log", root);
            log.localPosition = new Vector3(15f, 1f, 67.9f);
            Box(root, "Log console", new Vector3(15f, 0.55f, 68.05f), new Vector3(1.5f, 1.10f, 0.76f), p.Frame);
            Box(root, "Log display", new Vector3(15f, 1.14f, 67.69f), new Vector3(1.26f, 0.32f, 0.06f), p.Cyan, false);
            Sign(root, "Clock", new Vector3(15f, 2.75f, 70.69f), Teal, 0.53f);
            foreach (var x in new[] { 12.45f, 17.55f })
            {
                FittedProp(root, "Original Godot server cabinet", "server_rack.glb", new Vector3(x, 1.12f, 66.2f),
                    new Vector3(1.22f, 2.20f, 0.77f), 180f);
                Box(root, "Server cabinet collision", new Vector3(x, 1.1f, 66.2f), new Vector3(1.2f, 2.2f, 0.78f), p.Frame)
                    .GetComponent<MeshRenderer>().enabled = false;
            }
            Point(root, "Lab interior radiance", new Vector3(15, 3.1f, 67), Teal, 2.2f, 7f);

            foreach (var x in new[] { 12.45f, 17.55f })
            {
                Tube(root, "Coil base", new Vector3(x, 0.28f, 69.3f), new Vector3(1.35f, 0.28f, 1.35f), p.Frame);
                Tube(root, "Coil core", new Vector3(x, 1.73f, 69.3f), new Vector3(0.57f, 1.25f, 0.57f), p.Cyan);
                for (var y = 0.73f; y <= 3f; y += 0.45f)
                    Tube(root, "Coil insulator", new Vector3(x, y, 69.3f), new Vector3(1.0f, 0.055f, 1.0f), p.Frame);
            }
        }

        private static void BuildSkyline(Transform root, Palette p)
        {
            var center = new Vector3(0, 13.7f, 82.2f);
            for (var i = 0; i < 32; i++)
            {
                var theta = (i + 0.5f) * 2f * Mathf.PI / 32f;
                var direction = new Vector3(Mathf.Sin(theta), Mathf.Cos(theta), 0);
                var rotation = Quaternion.Euler(0f, 0f, -theta * Mathf.Rad2Deg);
                var segment = Box(root, "Phase antenna rib", center + direction * 10.15f, new Vector3(2.06f, 1.18f, 1.88f), p.Frame, false);
                segment.rotation = rotation;
                var light = Box(root, "Phase antenna glass", center + direction * 9.68f + Vector3.back * 1.02f,
                    new Vector3(1.66f, 0.21f, 0.13f), i % 4 == 0 ? p.Amber : p.Cyan, false);
                light.rotation = rotation;
            }
            foreach (var side in new[] { -1f, 1f })
            {
                for (var i = 0; i < 5; i++)
                {
                    var z = 48f + i * 11.8f;
                    var x = side * (24f + (i % 2) * 4.4f);
                    var height = 12.5f + 2.7f * ((i + 1) % 4);
                    Box(root, "Distant buttress", new Vector3(x, height * 0.32f, z),
                        new Vector3(3.75f, height, 4.3f), p.Wall, false);
                    Box(root, "Lift machine housing", new Vector3(x, height * 0.58f, z - 0.54f),
                        new Vector3(5.26f, 3.6f, 5.2f), p.Frame, false);
                    Box(root, "Lift service beacon", new Vector3(x, height * 0.58f, z - 3.2f),
                        new Vector3(2.2f, 0.28f, 0.18f), i % 2 == 0 ? p.Amber : p.Cyan, false);
                    var brace = Box(root, "Suspended cable bridge", new Vector3(side * 20f, height * 0.4f, z),
                        new Vector3(13, 0.34f, 1.18f), p.Frame, false);
                    brace.rotation = Quaternion.Euler(0, 0, side * 37);
                }
            }
        }

        private static void Walkway(Transform root, Palette p, string name, float x, float z, float width, float length)
        {
            Box(root, name, new Vector3(x, -0.23f, z), new Vector3(width, 0.46f, length), p.Wet);
            if (length < 10f) return;
            foreach (var offset in new[] { -0.5f, 0.5f })
            {
                Box(root, "Walkway edge", new Vector3(x + width * offset, -0.12f, z),
                    new Vector3(0.13f, 0.33f, length), p.Frame, false);
                for (var start = -length * 0.5f + 1f; start < length * 0.5f - 0.7f; start += 3f)
                    Box(root, "Walkway marker", new Vector3(x + width * offset, 0.045f, z + start),
                        new Vector3(0.095f, 0.04f, 0.87f), p.Cyan, false);
            }
        }

        private static void BuildAirAndEnergy(Transform root, Palette p)
        {
            foreach (var x in new[] { -2.88f, 2.88f })
            {
                var at = new Vector3(x, 0.85f, 25.8f);
                Effect(root, "Pressure steam", at, new Vector2(1.7f, 1.75f), 0, 0.34f, Teal, x, true, 22f);
                Effect(root, "Pressure steam cross-layer", at, new Vector2(1.4f, 1.78f), 0, 0.23f, Teal, x + 7f, true, 100f);
            }
            foreach (var x in new[] { -5.3f, 6.1f })
            {
                Effect(root, "Canal evaporation", new Vector3(x, -1.8f, 42.8f), new Vector2(6f, 4.1f),
                    0, 0.2f, Violet * 1.25f, x, false, 36f);
                Effect(root, "Canal evaporation", new Vector3(x, -2.2f, 60.7f), new Vector2(7f, 4f),
                    0, 0.24f, Teal, x + 4f, false, 145f);
            }
            var burner = new Vector3(-13.6f, -0.61f, 43.65f);
            Box(root, "Maintenance pilot housing", burner, new Vector3(0.9f, 0.32f, 0.9f), p.Frame, false);
            Effect(root, "Pilot flame", burner + Vector3.up * 0.54f, new Vector2(1f, 1.1f),
                1, 0.82f, Gold * 2f, 3f, false, 0f);
            Effect(root, "Pilot exhaust", burner + Vector3.up * 1.3f, new Vector2(1.3f, 2.2f),
                0, 0.26f, Gold * 0.8f, 5f, false, 64f);
            Point(root, "Pilot spill", burner + Vector3.up * 0.7f, Gold, 1.7f, 4.6f);
            foreach (var x in new[] { 12.45f, 17.55f })
                Effect(root, "Lab discharge", new Vector3(x, 1.85f, 68.92f), new Vector2(0.57f, 2.4f),
                    2, 0.87f, Teal * 2f, x, false, 0f);
            foreach (var x in new[] { -2.35f, 2.35f })
            {
                var fan = Group("Airlock extractor rotor", root);
                fan.localPosition = new Vector3(x, 4.05f, 29.6f);
                fan.gameObject.AddComponent<StationRotor>();
                var hub = Tube(fan, "Extractor axle", Vector3.zero, new Vector3(0.32f, 0.10f, 0.32f), p.Frame);
                hub.localRotation = Quaternion.Euler(90f, 0, 0);
                for (var blade = 0; blade < 6; blade++)
                {
                    var angle = blade * 60f;
                    var radial = Quaternion.AngleAxis(angle, Vector3.forward);
                    var vane = Box(fan, "Extractor blade", radial * Vector3.up * 0.36f,
                        new Vector3(0.22f, 0.54f, 0.09f), p.Frame, false);
                    vane.localRotation = radial * Quaternion.Euler(0f, 0, 19f);
                }
                Box(root, "Extractor recess", fan.localPosition + Vector3.forward * 0.22f,
                    new Vector3(1.42f, 1.41f, 0.2f), p.Wall, false);
            }
        }

        internal static void Effect(Transform parent, string name, Vector3 at, Vector2 size, int effect,
            float opacity, Color tint, float phase, bool driveByPressure, float yaw)
        {
            var material = PersistentMaterial($"{name} {phase}", "StationAtmosphere.shader");
            tint.a = opacity;
            material.SetColor("_Tint", tint);
            material.SetFloat("_Effect", effect);
            material.SetFloat("_Phase", phase);
            material.SetFloat("_PressureVent", driveByPressure ? 1f : 0f);
            EditorUtility.SetDirty(material);
            AssetDatabase.SaveAssetIfDirty(material);
            Primitive(PrimitiveType.Quad, parent, name, at, new Vector3(size.x, size.y, 1f), material, false)
                .localRotation = Quaternion.Euler(0f, yaw, 0f);
        }

        private static void InstallAtmosphere(Transform root, Camera camera)
        {
            RenderSettings.fog = true;
            RenderSettings.fogMode = FogMode.ExponentialSquared;
            RenderSettings.fogColor = new Color(0.085f, 0.10f, 0.28f);
            RenderSettings.fogDensity = 0.012f;
            camera.farClipPlane = 112f;
            camera.backgroundColor = RenderSettings.fogColor;
            camera.clearFlags = CameraClearFlags.Skybox;
            RenderSettings.skybox = PersistentMaterial("Station sky", "StationSky.shader");
            camera.allowHDR = true;
            var cameraData = camera.GetUniversalAdditionalCameraData();
            cameraData.renderPostProcessing = true;
            cameraData.antialiasing = AntialiasingMode.SubpixelMorphologicalAntiAliasing;
            var profile = AssetDatabase.LoadAssetAtPath<VolumeProfile>(Output + "Station Grade.asset");
            if (profile == null)
            {
                profile = ScriptableObject.CreateInstance<VolumeProfile>();
                AssetDatabase.CreateAsset(profile, Output + "Station Grade.asset");
                var tone = profile.Add<Tonemapping>(true);
                tone.mode.Override(TonemappingMode.ACES);
                AssetDatabase.AddObjectToAsset(tone, profile);
                var bloom = profile.Add<Bloom>();
                bloom.threshold.Override(0.92f);
                bloom.intensity.Override(0.27f);
                bloom.scatter.Override(0.64f);
                AssetDatabase.AddObjectToAsset(bloom, profile);
                var grade = profile.Add<ColorAdjustments>();
                grade.postExposure.Override(0.23f);
                grade.contrast.Override(13f);
                grade.saturation.Override(25f);
                AssetDatabase.AddObjectToAsset(grade, profile);
                EditorUtility.SetDirty(profile);
                AssetDatabase.SaveAssets();
            }
            profile.TryGet<ColorAdjustments>(out var correction);
            correction.saturation.Override(36f);
            correction.contrast.Override(21f);
            correction.postExposure.Override(0.31f);
            EditorUtility.SetDirty(correction);
            AssetDatabase.SaveAssetIfDirty(correction);
            var volume = Group("Station chromatic grade", root).gameObject.AddComponent<Volume>();
            volume.isGlobal = true;
            volume.priority = 10f;
            volume.sharedProfile = profile;
        }

        private sealed class Palette
        {
            internal readonly Material Wall = Surface("Wall enamel", new Color(0.16f, 0.21f, 0.37f), 0f, 0.46f);
            internal readonly Material Frame = Surface("Ceramic steel", new Color(0.29f, 0.34f, 0.48f), 0f, 0.84f);
            internal readonly Material Wet = Surface("Flooded plates", new Color(0.20f, 0.25f, 0.38f), 0.75f, 0.55f);
            internal readonly Material Pool = Surface("Tailwater", new Color(0.035f, 0.13f, 0.29f), 1f, 0f, waterBody: true);
            internal readonly Material Cyan = Surface("Cool practical", new Color(0.13f, 0.49f, 0.56f), 0f, 0.54f, Teal * 1.80f);
            internal readonly Material Amber = Surface("Warm practical", new Color(0.48f, 0.23f, 0.09f), 0f, 0.54f, Gold * 1.65f);
        }

        private static Material Surface(string name, Color paint, float wet, float frequency, Color emission = default, bool waterBody = false)
        {
            var path = Output + name + ".mat";
            var shader = Load<Shader>(Output + "StormworksSurface.shader");
            var material = AssetDatabase.LoadAssetAtPath<Material>(path);
            if (material == null)
            {
                material = new Material(shader);
                AssetDatabase.CreateAsset(material, path);
            }
            material.SetColor("_BaseColor", paint);
            material.SetColor("_ShadowTone", Indigo);
            material.SetColor("_EmissionColor", emission);
            material.SetFloat("_Wetness", wet);
            material.SetFloat("_PanelScale", frequency);
            material.SetFloat("_WaterBody", waterBody ? 1 : 0);
            EditorUtility.SetDirty(material);
            AssetDatabase.SaveAssetIfDirty(material);
            return material;
        }

        private static Transform Group(string name, Transform parent)
        {
            var item = new GameObject(name).transform;
            item.SetParent(parent, false);
            return item;
        }

        private static Transform Box(Transform parent, string name, Vector3 at, Vector3 size, Material material,
            bool collision = true) => Primitive(PrimitiveType.Cube, parent, name, at, size, material, collision);

        private static Transform Tube(Transform parent, string name, Vector3 at, Vector3 size, Material material) =>
            Primitive(PrimitiveType.Cylinder, parent, name, at, size, material, false);

        private static Transform Primitive(PrimitiveType type, Transform parent, string name, Vector3 at,
            Vector3 size, Material material, bool collision)
        {
            var item = GameObject.CreatePrimitive(type);
            item.name = name;
            item.transform.SetParent(parent, false);
            item.transform.localPosition = at;
            item.transform.localScale = size;
            var renderer = item.GetComponent<MeshRenderer>();
            renderer.sharedMaterial = material;
            renderer.shadowCastingMode = ShadowCastingMode.Off;
            if (!collision) UnityEngine.Object.DestroyImmediate(item.GetComponent<Collider>());
            return item.transform;
        }

        private static void Point(Transform parent, string name, Vector3 at, Color color, float intensity, float range)
        {
            var item = Group(name, parent);
            item.localPosition = at;
            var light = item.gameObject.AddComponent<Light>();
            light.type = LightType.Point;
            light.color = color;
            light.intensity = intensity;
            light.range = range;
        }

        private static void Sign(Transform parent, string artwork, Vector3 at, Color color, float height)
        {
            var texture = Load<Texture2D>(Output + artwork + ".png");
            var material = PersistentMaterial(artwork + " sign", "WorldSignal.shader");
            material.SetTexture("_BaseMap", texture);
            material.SetColor("_BaseColor", color * 1.8f);
            EditorUtility.SetDirty(material);
            AssetDatabase.SaveAssetIfDirty(material);
            Primitive(PrimitiveType.Quad, parent, artwork, at,
                new Vector3(height * texture.width / texture.height, height, 1f), material, false);
        }

        internal static Material PersistentMaterial(string name, string shaderFile)
        {
            var path = Output + name + ".mat";
            var material = AssetDatabase.LoadAssetAtPath<Material>(path);
            if (material != null) return material;
            material = new Material(Load<Shader>(Output + shaderFile));
            AssetDatabase.CreateAsset(material, path);
            return material;
        }

        private static void FittedProp(Transform parent, string name, string asset, Vector3 center, Vector3 size, float yaw)
        {
            var socket = Group(name, parent);
            socket.localPosition = center;
            socket.localRotation = Quaternion.Euler(0f, yaw, 0f);
            var model = (GameObject)PrefabUtility.InstantiatePrefab(Load<GameObject>(Output + asset), socket);
            model.transform.localPosition = Vector3.zero;
            var combined = new Bounds();
            var hasBounds = false;
            foreach (var mesh in model.GetComponentsInChildren<MeshRenderer>())
            {
                var m = socket.worldToLocalMatrix * mesh.localToWorldMatrix;
                var b = mesh.localBounds;
                for (var i = 0; i < 8; i++)
                {
                    var corner = b.center + Vector3.Scale(b.extents,
                        new Vector3((i & 1) == 0 ? -1 : 1, (i & 2) == 0 ? -1 : 1, (i & 4) == 0 ? -1 : 1));
                    var point = m.MultiplyPoint3x4(corner);
                    if (!hasBounds) combined = new Bounds(point, Vector3.zero);
                    else combined.Encapsulate(point);
                    hasBounds = true;
                }
            }
            if (!hasBounds || combined.size.x < 0.001f || combined.size.y < 0.001f || combined.size.z < 0.001f)
                throw new InvalidDataException($"Invalid Godot asset bounds for {asset}.");
            socket.localScale = new Vector3(size.x / combined.size.x, size.y / combined.size.y, size.z / combined.size.z);
            model.transform.localPosition -= combined.center;
        }

        private static AudioSource Loop(Transform parent, string name, Vector3 at, AudioClip clip, float range)
        {
            var item = Group(name, parent);
            item.localPosition = at;
            var source = item.gameObject.AddComponent<AudioSource>();
            source.clip = clip;
            source.playOnAwake = false;
            source.loop = true;
            source.spatialBlend = 0.87f;
            source.dopplerLevel = 0f;
            source.minDistance = 3f;
            source.maxDistance = range;
            source.volume = 0f;
            return source;
        }

        private static ArchiveVignettes BuildArchiveMedia(Transform root, Transform hud)
        {
            var view = Element("Archive memory frame", hud, 0.18f, 0.21f, 0.82f, 0.82f);
            var image = view.AddComponent<RawImage>();
            image.raycastTarget = false;
            view.SetActive(false);

            var host = Group("Memory fragments playback", root).gameObject;
            var media = host.AddComponent<ArchiveVignettes>();
            var video = host.AddComponent<VideoPlayer>();
            video.playOnAwake = false;
            video.waitForFirstFrame = true;
            video.aspectRatio = VideoAspectRatio.FitInside;
            video.renderMode = VideoRenderMode.RenderTexture;
            video.audioOutputMode = VideoAudioOutputMode.None;
            var ambience = host.AddComponent<AudioSource>();
            ambience.playOnAwake = false;
            ambience.volume = 0.35f;
            ambience.clip = Load<AudioClip>(Root + "Opening/Media/MemoryFriends.ogg");

            Wire(media, ("image", image), ("player", video), ("ambience", ambience));
            var data = new SerializedObject(media);
            var clips = data.FindProperty("clips");
            var stills = data.FindProperty("stills");
            var filenames = new[] { "Flow-school", "Flow-memory", "Flow-experiment" };
            clips.arraySize = filenames.Length;
            stills.arraySize = filenames.Length;
            for (var index = 0; index < filenames.Length; index++)
            {
                var stem = Root + "Opening/Media/" + filenames[index];
                clips.GetArrayElementAtIndex(index).objectReferenceValue = Load<VideoClip>(stem + ".mp4");
                stills.GetArrayElementAtIndex(index).objectReferenceValue = Load<Texture2D>(stem + "-poster.png");
            }
            data.ApplyModifiedPropertiesWithoutUndo();
            return media;
        }

        private static Text BackedLabel(string name, Transform parent, Font font, int size, float left, float bottom,
            float right, float top)
        {
            var text = Label(name, parent, font, "", size, left, bottom, right, top);
            text.alignment = TextAnchor.MiddleCenter;
            text.resizeTextForBestFit = true;
            text.resizeTextMinSize = 14;
            text.resizeTextMaxSize = size;
            text.color = new Color(0.84f, 0.97f, 1f);
            text.gameObject.AddComponent<Outline>().effectColor = new Color(0.025f, 0.03f, 0.1f, 0.97f);
            return text;
        }

        private static T Load<T>(string path) where T : UnityEngine.Object =>
            AssetDatabase.LoadAssetAtPath<T>(path) ?? throw new FileNotFoundException(path);

        internal static void Wire(UnityEngine.Object target, params (string key, UnityEngine.Object value)[] values)
        {
            var data = new SerializedObject(target);
            foreach (var (key, value) in values) data.FindProperty(key).objectReferenceValue = value;
            data.ApplyModifiedPropertiesWithoutUndo();
        }
    }
}

