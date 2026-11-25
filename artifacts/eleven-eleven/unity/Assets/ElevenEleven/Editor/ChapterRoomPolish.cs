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
using Object = UnityEngine.Object;

namespace ElevenEleven.Editor
{
    internal sealed class ChapterRoomPolish
    {
        private const string Scene = "Assets/ElevenEleven/Scenes/ChapterRoom01.unity";
        private const string Stormworks = "Assets/ElevenEleven/Opening/Stormworks/";
        private const string Folder = Stormworks + "ChapterRoomPolish/";
        private const string MeshPath = Folder + "Metric floor meshes.asset";
        private const int MetricVertexBudget = 30000;
        private const string Extras = "Fitted room mechanisms";
        private static readonly string[] DeckParts =
        {
            "Floor", "Flooded deck", "Threshold floor", "Airlock tread", "Wet service base",
            "Wet path panel", "Sealed link floor", "Open branch deck", "Fabricated service tread",
            "Ward floor", "Main catwalk", "ServiceWalkway", "ObservationCatwalkDeck",
            "SouthCircuitWalkway", "EastCircuitWalkway", "EntryBalconyDeck", "ExitGantryDeck",
            "WestServiceLanding", "BridgeAccessLanding", "Reserve power conduit floor",
            "CommandDaisDeck", "EastStairLanding", "WestStairLanding", "Decon transition landing",
            "Specimen to archive deck", "West traversal", "Specimen to Station return deck"
        };
        private static readonly string[] CassetteParts =
        {
            "Pressure-rated deck cassette", "Drainage bridge floor cassette", "Sealed floor cassette",
            "Archive floor cassette", "Recessed examination floor cassette", "Suspended maintenance plate tread"
        };
        private enum Track { Iris, Vent, Resonator, Monitor, Curtain }
        private readonly struct Mount
        {
            internal readonly Vector3 Position;
            internal readonly float Yaw;
            internal readonly float Scale;
            internal readonly string Label;
            internal readonly Track Type;
            internal readonly string Signal;

            internal Mount(string label, Track type, string signal, float x, float y, float z,
                float yaw, float scale)
            {
                Label = label;
                Type = type;
                Signal = signal;
                Position = new Vector3(x, y, z);
                Yaw = yaw;
                Scale = scale;
            }
        }
        // Position and yaw are measured in each room art layer, where forward points out of the housing.
        private static readonly Dictionary<string, Mount> Mounts = new Dictionary<string, Mount>
        {
            ["Window chips and condensation"] = new Mount("Signal phase register", Track.Monitor, "Amber", 6.9f, 1.38f, 4.67f, -90f, 1.2f),
            ["Condensate and extraction shutters"] = new Mount("Plenum differential regulator", Track.Vent, "Amber", 3.22f, 2.88f, -.76f, -90f, 1.05f),
            ["High orbit glacial shards"] = new Mount("Chronostat reference iris", Track.Resonator, "Aqua", 1.97f, 1.10f, 69.03f, 180f, .94f),
            ["Relay wind and copper cladding chips"] = new Mount("Relay guide rollers", Track.Vent, "Amber", -16.78f, 1.63f, 55.36f, 219f, .71f),
            ["Laboratory diffraction shelf"] = new Mount("Laboratory spectrometer", Track.Iris, "Aqua", 17.2f, 2.88f, 65.65f, 180f, 1.02f),
            ["Sensor louvers and dust"] = new Mount("Security optical gimbal", Track.Iris, "Amber", 3.30f, 2.68f, 9.55f, -90f, 1.09f),
            ["Sample glass and filter shutters"] = new Mount("Sample filter metering bank", Track.Vent, "Aqua", -12.75f, 2.40f, 15.83f, 180f, 1.26f),
            ["Decoder fragments and iris petals"] = new Mount("Memory indexing rotor", Track.Resonator, "Violet", -10.85f, 2.85f, -5.85f, 0f, 1.22f),
            ["Hot debris and regulator plates"] = new Mount("Reactor thermal bypass shutters", Track.Vent, "Amber", 2.26f, .64f, 15.73f, 205f, 1.30f),
            ["Condensate and check valves"] = new Mount("Decontamination downdraft regulator", Track.Vent, "Aqua", 5.64f, 4.76f, 17.9f, -90f, 1.15f),
            ["Optical blades and scratched glass"] = new Mount("Surveillance scan carriage", Track.Monitor, "Aqua", -3.31f, 2.45f, 10.7f, 90f, 1.18f),
            ["Mirror service edge and reflected dust"] = new Mount("Reflection registration bars", Track.Monitor, "Aqua", 7.72f, 2.89f, 11.08f, -90f, .51f),
            ["Examination filtration fins and air"] = new Mount("Examination objective iris", Track.Iris, "Aqua", 1.36f, 4.4f, 19.14f, 194f, 1.09f),
            ["Detached violet memories"] = new Mount("Zero carrier field", Track.Resonator, "Violet", 0f, 1.28f, 33.65f, 180f, 1.5f),
            ["Observation alcove afterimages"] = new Mount("Observation telemetry sweep", Track.Monitor, "Violet", -5.35f, 3.32f, 20.65f, 90f, 1.18f),
            ["Dust drifting across the window reveal"] = new Mount("Window curtain in the morning draft", Track.Curtain, "Aqua", 0f, 2.63f, -2.56f, 0f, 1f)
        };
        private readonly Dictionary<string, Material> floors;
        private readonly Dictionary<string, Mesh> baked;
        private readonly Mesh shell;
        private readonly Mesh petal;
        private readonly Material metal;
        private readonly Material inset;
        private readonly Dictionary<string, Material> lenses;

        private ChapterRoomPolish()
        {
            floors = new[] { "Pressure", "Service", "Reactor", "Sealed", "Clinical", "Ward" }
                .ToDictionary(name => name, FloorMaterial);
            var library = AssetDatabase.LoadMainAssetAtPath(MeshPath);
            if (!library)
            {
                library = new Mesh { name = "Metric floor meshes" };
                AssetDatabase.CreateAsset(library, MeshPath);
            }
            baked = AssetDatabase.LoadAllAssetsAtPath(MeshPath).OfType<Mesh>().ToDictionary(mesh => mesh.name);
            shell = Shape("Beveled equipment case", new[] { .78f, 1f, 1f, .80f });
            petal = Shape("Chamfered shutter leaf", new[] { .52f, 1f, 1f, .66f });
            metal = Load<Material>(Stormworks + "StationFinishes/Chronostat oxide-filled steel.mat");
            inset = Load<Material>(Stormworks + "Casing recess.mat");
            lenses = new Dictionary<string, Material>
            {
                ["Amber"] = Load<Material>(Stormworks + "Echo Station amber lens.mat"),
                ["Aqua"] = Load<Material>(Stormworks + "Echo Station aqua lens.mat"),
                ["Violet"] = Load<Material>(Stormworks + "Examination violet indicator.mat")
            };
        }

        [MenuItem("11.11/Polish Chapter Floors and Mechanisms")]
        public static void Apply()
        {
            if (!Application.isBatchMode && !EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo()) return;
            var scene = EditorSceneManager.OpenScene(Scene);
            var content = scene.GetRootGameObjects().Single(root => root.name == "Room content").transform;
            var station = content.Find("Echo Station");
            var authority = content.GetComponentsInChildren<Collider>(true)
                .ToDictionary(collider => collider, ColliderState);
            var rooms = station.GetComponentsInChildren<RoomEnvironmentMotion>(true);
            if (rooms.Length != Mounts.Count || !rooms.Select(room => room.name).ToHashSet().SetEquals(Mounts.Keys))
                throw new InvalidDataException("The chapter mechanism placements require the sixteen current room anchors.");

            var pass = new ChapterRoomPolish();
            int surfaces;
            AssetDatabase.StartAssetEditing();
            try
            {
                surfaces = pass.FinishDecks(content, station);
            }
            finally
            {
                AssetDatabase.StopAssetEditing();
            }
            surfaces += pass.FinishBakedDecks(station);
            var fixtures = pass.FinishFixtures(content, station);
            foreach (var room in rooms) pass.FitMechanism(room, Mounts[room.name]);
            var final = content.GetComponentsInChildren<Collider>(true);
            if (final.Length != authority.Count || final.Any(item =>
                !authority.TryGetValue(item, out var state) || state != ColliderState(item)))
                throw new InvalidDataException("The visual floor and hardware pass altered collision authority.");
            if (rooms.Any(room => room.PieceCount < 23))
                throw new InvalidDataException("A polished area is missing an authored motion track.");

            AssetDatabase.SaveAssets();
            if (!EditorSceneManager.SaveScene(scene)) throw new IOException("Could not save polished chapter rooms.");
            Debug.Log($"ECHO_ROOM_POLISH_SAVED surfaces={surfaces} fixtures={fixtures} colliders={authority.Count} zones={rooms.Length} " +
                $"tracks={rooms.Sum(room => room.PieceCount)} minimum={rooms.Min(room => room.PieceCount)}");
            if (Environment.GetEnvironmentVariable("ECHO_STATION_CAPTURE") != null)
                ChapterRoomTripoKit.CaptureChapter(content, station, "Polished");
        }

        public static void ApplyAndReview()
        {
            Apply();
            var reviewCaptures = Environment.GetEnvironmentVariable("ECHO_POLISH_PLAY_CAPTURE");
            Environment.SetEnvironmentVariable("ECHO_STATION_CAPTURE", reviewCaptures);
            Environment.SetEnvironmentVariable("ECHO_STATION_CAPTURE_ONLY", "12");
            EditorSceneManager.NewScene(NewSceneSetup.EmptyScene);
            StormworksSmoke.Run();
        }

        public static void RefineBakedDecks()
        {
            var scene = EditorSceneManager.OpenScene(Scene);
            var content = scene.GetRootGameObjects().Single(root => root.name == "Room content").transform;
            var station = content.Find("Echo Station");
            var authority = content.GetComponentsInChildren<Collider>(true)
                .ToDictionary(collider => collider, ColliderState);
            var art = new ChapterRoomPolish();
            var surfaces = art.FinishBakedDecks(station);
            var colliders = content.GetComponentsInChildren<Collider>(true);
            if (surfaces != 2 || colliders.Length != authority.Count ||
                colliders.Any(collider => !authority.TryGetValue(collider, out var state) || state != ColliderState(collider)))
                throw new InvalidDataException("The two baked deck finishes must keep the existing collision.");
            AssetDatabase.SaveAssets();
            if (!EditorSceneManager.SaveScene(scene)) throw new IOException("Could not save the two baked decks.");
            Debug.Log($"ECHO_BAKED_DECKS_SAVED surfaces={surfaces} colliders={colliders.Length}");
            ChapterRoomTripoKit.CaptureChapter(content, station, "Polished");
        }

        private int FinishBakedDecks(Transform station)
        {
            var decon = station.Find("Decontamination and quarantine");
            var floor = decon.Find("Authored Godot collision/Floor").GetComponent<BoxCollider>();
            var name = "Measured vinyl over baked floor";
            var before = floor.transform.Find(name);
            if (before) Object.DestroyImmediate(before.gameObject);
            var edge = new Vector3(floor.size.x*.5f-.10f, floor.size.y*.5f+.011f, floor.size.z*.5f-.10f);
            var tile = AssetDatabase.LoadAssetAtPath<Mesh>(Folder + "Quarantine floor skin.asset");
            if (!tile)
            {
                tile = new Mesh { name = "Quarantine floor skin" };
                AssetDatabase.CreateAsset(tile, Folder + "Quarantine floor skin.asset");
            }
            // The original visual floor and walls share one mesh. Finish the walkable rectangle
            // within the measured floor box while leaving its baked seams and puddles above the skin.
            tile.vertices = new[]
            {
                new Vector3(-edge.x, 0f, -edge.z), new Vector3(-edge.x, 0f, edge.z),
                new Vector3(edge.x, 0f, edge.z), new Vector3(edge.x, 0f, -edge.z)
            };
            tile.triangles = new[] { 0, 1, 2, 0, 2, 3 };
            tile.RecalculateNormals();
            var vinyl = Render(floor.transform, name,
                floor.center + Vector3.up*edge.y, Vector3.one, floors["Clinical"], tile);
            ProjectUV(tile, vinyl, 2.8f);

            var reactor = station.Find("Reserve reactor wing");
            var abyss = Find(reactor.Find("Native Godot reactor geometry"), "AbyssFloor");
            var baseMesh = abyss.GetComponentInChildren<MeshFilter>(true);
            var cast = AssetDatabase.LoadAssetAtPath<Mesh>(Folder + "Reactor lower deck UV.asset");
            if (!cast)
            {
                cast = Object.Instantiate(baseMesh.sharedMesh);
                cast.name = "Reactor lower deck UV";
                AssetDatabase.CreateAsset(cast, Folder + "Reactor lower deck UV.asset");
            }
            ProjectUV(cast, baseMesh.transform, 2.95f);
            baseMesh.sharedMesh = cast;
            var renderer = baseMesh.GetComponent<MeshRenderer>();
            renderer.sharedMaterial = floors["Reactor"];
            PrefabUtility.RecordPrefabInstancePropertyModifications(baseMesh);
            PrefabUtility.RecordPrefabInstancePropertyModifications(renderer);
            return 2;
        }

        private static string ColliderState(Collider collider) => EditorJsonUtility.ToJson(collider);

        private static T Load<T>(string path) where T : Object =>
            AssetDatabase.LoadAssetAtPath<T>(path) ?? throw new FileNotFoundException(path);

        private static Material FloorMaterial(string name)
        {
            if (name == "Ward")
                return Load<Material>("Assets/ElevenEleven/Opening/Hospital/Finishes/Ward mottled vinyl.mat");
            var path = Folder + name + " deck.mat";
            var material = AssetDatabase.LoadAssetAtPath<Material>(path);
            if (!material)
            {
                material = new Material(Shader.Find("Universal Render Pipeline/Lit"));
                AssetDatabase.CreateAsset(material, path);
            }
            material.SetTexture("_BaseMap", Map(name + "-Base", TextureImporterType.Default, true));
            material.SetTexture("_BumpMap", Map(name + "-Normal", TextureImporterType.NormalMap, false));
            material.SetTexture("_MetallicGlossMap", Map(name + "-MetalSmooth", TextureImporterType.Default, false));
            material.SetFloat("_BumpScale", .89f);
            material.SetFloat("_Smoothness", .88f);
            material.EnableKeyword("_NORMALMAP");
            material.EnableKeyword("_METALLICSPECGLOSSMAP");
            EditorUtility.SetDirty(material);
            return material;
        }

        private static Texture2D Map(string name, TextureImporterType type, bool srgb)
        {
            var path = Folder + name + ".png";
            var importer = (TextureImporter)AssetImporter.GetAtPath(path);
            if (importer.textureType != type || importer.sRGBTexture != srgb || importer.maxTextureSize != 512 ||
                importer.wrapMode != TextureWrapMode.Repeat || importer.anisoLevel != 8)
            {
                importer.textureType = type;
                importer.sRGBTexture = srgb;
                importer.maxTextureSize = 512;
                importer.wrapMode = TextureWrapMode.Repeat;
                importer.anisoLevel = 8;
                importer.SaveAndReimport();
            }
            return Load<Texture2D>(path);
        }

        private int FinishDecks(Transform content, Transform station)
        {
            var counts = floors.Keys.ToDictionary(name => name, _ => 0);
            var cassettes = floors.Keys.ToDictionary(name => name, _ => 0);
            var projected = baked.Values.Sum(mesh => mesh.vertexCount);
            foreach (var filter in content.GetComponentsInChildren<MeshFilter>(true))
            {
                var surface = filter.GetComponent<MeshRenderer>();
                if (!surface || !surface.enabled || !filter.sharedMesh) continue;
                var materials = surface.sharedMaterials;
                if (materials.Length == 0) continue;
                var part = filter.transform;
                var deck = false;
                var cassette = false;
                var room = "Pressure";
                for (var t = part; t && t != content && t != station; t = t.parent)
                {
                    if (t.name == "Flow reference architectural kit" || t.name == Extras || t.name == "Measured vinyl over baked floor")
                    {
                        deck = false;
                        break;
                    }
                    cassette |= CassetteParts.Contains(t.name);
                    deck |= DeckParts.Contains(t.name) || cassette;
                    if (t.name is "Awakening ward") room = "Ward";
                    else if (t.name is "Kinja examination theatre" or "Decontamination and quarantine") room = "Clinical";
                    else if (t.name is "Specimen containment" or "Memory archive wing") room = "Sealed";
                    else if (t.name is "Memory Observatory" or "Echo Station architectural finish" or
                        "Security wing" or "Surveillance and mirror" && room == "Pressure") room = "Service";
                    else if (t.name == "Reserve reactor wing") room = "Reactor";
                }
                var size = surface.bounds.size;
                if (!deck || size.x < .27f || size.z < .26f || size.y > 1.05f) continue;
                if (cassette)
                {
                    // Slot zero is the continuous walking skin. Preserve the grates, rim and guide enamel.
                    materials[0] = floors[room];
                    surface.sharedMaterials = materials;
                    PrefabUtility.RecordPrefabInstancePropertyModifications(surface);
                    cassettes[room]++;
                    continue;
                }
                if (materials.Length != 1) continue;
                var source = filter.sharedMesh;
                // Reproject broad simple decks. Imported modules already have authored UVs.
                if (source.isReadable && source.vertexCount <= 960)
                {
                    var id = GlobalObjectId.GetGlobalObjectIdSlow(filter);
                    var key = $"Floor {id.targetObjectId}:{id.targetPrefabId}";
                    if (!baked.TryGetValue(key, out var mesh) && projected + source.vertexCount <= MetricVertexBudget)
                    {
                        mesh = Object.Instantiate(source);
                        mesh.name = key;
                        AssetDatabase.AddObjectToAsset(mesh, MeshPath);
                        baked.Add(key, mesh);
                        projected += mesh.vertexCount;
                    }
                    if (mesh)
                    {
                        var metres = room == "Ward" ? 1.55f : room == "Clinical" ? 2.8f : 2.95f;
                        ProjectUV(mesh, filter.transform, metres);
                        filter.sharedMesh = mesh;
                        PrefabUtility.RecordPrefabInstancePropertyModifications(filter);
                    }
                }
                surface.sharedMaterial = floors[room];
                PrefabUtility.RecordPrefabInstancePropertyModifications(surface);
                counts[room]++;
            }
            Debug.Log($"ECHO_ROOM_FLOOR_UV vertices={projected} budget={MetricVertexBudget}");
            foreach (var entry in counts)
                Debug.Log($"ECHO_ROOM_FLOOR {entry.Key} surfaces={entry.Value + cassettes[entry.Key]} cassettes={cassettes[entry.Key]}");
            if (counts.Any(entry => entry.Value + cassettes[entry.Key] == 0))
                throw new InvalidDataException("A chapter floor profile did not reach any visible mesh.");
            return counts.Values.Sum() + cassettes.Values.Sum();
        }

        private static void ProjectUV(Mesh mesh, Transform space, float repeat)
        {
            var points = mesh.vertices;
            var normals = mesh.normals;
            if (normals.Length != points.Length)
            {
                mesh.RecalculateNormals();
                normals = mesh.normals;
            }
            var normalToWorld = space.worldToLocalMatrix.transpose;
            var toWorld = space.localToWorldMatrix;
            var uv = new Vector2[points.Length];
            for (var i = 0; i < uv.Length; i++)
            {
                var p = toWorld.MultiplyPoint3x4(points[i]);
                var n = normalToWorld.MultiplyVector(normals[i]);
                var y = Mathf.Abs(n.y);
                var x = Mathf.Abs(n.x);
                var z = Mathf.Abs(n.z);
                uv[i] = (y >= x && y >= z ? new Vector2(p.x, -p.z) :
                    x > z ? new Vector2(p.z, p.y) : new Vector2(p.x, p.y)) / repeat;
            }
            mesh.uv = uv;
            mesh.RecalculateTangents();
            EditorUtility.SetDirty(mesh);
        }

        private int FinishFixtures(Transform content, Transform station)
        {
            FitCase(station.Find("Valve pedestal"), "PressureCassette", 180f);
            FitCase(station.Find("Log console"), "SignalConsole", 180f);
            var count = 2;
            foreach (var part in station.Cast<Transform>().Where(t => t.name == "Service portal column"))
            {
                var renderer = part.GetComponent<MeshRenderer>();
                renderer.sharedMaterial = metal;
                part.GetComponent<MeshFilter>().sharedMesh = shell;
                count++;
            }
            var signal = content.Find("Sector 11");
            FinishDisplayStand(signal.Find("StoppedClock pedestal"), lenses["Amber"], 90f);
            FinishDisplayStand(signal.Find("PersonalTrace pedestal"), lenses["Aqua"], -90f);
            return count + 2;
        }

        private void FinishDisplayStand(Transform support, Material indicator, float yaw)
        {
            var label = support.name + " display housing";
            var old = support.parent.Find(label);
            if (old) Object.DestroyImmediate(old.gameObject);
            var node = Node(support.parent, label, support.localPosition);
            node.localRotation = Quaternion.Euler(0f, yaw, 0f);
            var height = support.localScale.y;
            Render(node, "Chamfered recessed chassis", Vector3.zero, new Vector3(.53f, height, .53f), metal, shell);
            Render(node, "Sealed foot and anchor flange", Vector3.down*(height*.439f),
                new Vector3(.58f, .104f, .58f), inset, shell);
            Render(node, "Isolated exhibit top", Vector3.up*(height*.459f),
                new Vector3(.575f, .082f, .575f), metal, shell);
            Render(node, "Inset inspection panel", new Vector3(0f,.07f,.26f),
                new Vector3(.30f, .42f, .032f), inset, shell);
            for (var rail = -1; rail <= 1; rail += 2)
                Render(node, "Protected power channel", new Vector3(rail*.113f,.034f,.282f),
                    new Vector3(.025f,.27f,.019f), metal, petal);
            Render(node, "Steady exhibit indicator", new Vector3(0f,.181f,.291f),
                new Vector3(.12f,.018f,.012f), indicator, petal);
            support.GetComponent<MeshRenderer>().enabled = false;
        }

        private static void FitCase(Transform support, string model, float yaw)
        {
            if (!support) throw new InvalidDataException($"The shell anchor for {model} is missing.");
            var renderer = support.GetComponent<MeshRenderer>();
            var old = support.parent.Find(support.name + " finished shell");
            if (old) Object.DestroyImmediate(old.gameObject);
            var size = support.localScale;
            var turned = Quaternion.Euler(0, yaw, 0) * size;
            var extent = new Vector3(Mathf.Abs(turned.x), Mathf.Abs(turned.y), Mathf.Abs(turned.z));
            StormworksConstruction.FittedProp(support.parent, support.name + " finished shell",
                "TripoChapterKit/" + model + ".glb", support.localPosition, extent, yaw);
            renderer.enabled = false;
        }

        private void FitMechanism(RoomEnvironmentMotion room, Mount mount)
        {
            using var data = new SerializedObject(room);
            var pieces = data.FindProperty("pieces");
            var old = room.transform.Find(Extras);
            if (old)
            {
                for (var i = pieces.arraySize - 1; i >= 0; i--)
                {
                    var target = pieces.GetArrayElementAtIndex(i).FindPropertyRelative("target").objectReferenceValue as Transform;
                    if (target && target.IsChildOf(old)) pieces.DeleteArrayElementAtIndex(i);
                }
                Object.DestroyImmediate(old.gameObject);
            }
            var root = Node(room.transform, Extras, room.transform.InverseTransformPoint(room.transform.parent.TransformPoint(mount.Position)));
            root.rotation = room.transform.parent.rotation * Quaternion.Euler(0f, mount.Yaw, 0f);
            root.localScale = Vector3.one * mount.Scale;
            var hardware = Node(root, mount.Label, Vector3.zero);
            var lamp = lenses[mount.Signal];

            if (mount.Type == Track.Curtain)
            {
                WardDraft(hardware, pieces, room.transform.parent.parent);
            }
            else if (mount.Type == Track.Vent)
            {
                Housing(hardware, 1.12f, .53f);
                for (var i = 0; i < 6; i++)
                {
                    var vane = Render(hardware, $"Louver {i+1}", new Vector3(0f, (i-2.5f)*.066f, .083f),
                        new Vector3(.95f, .048f, .067f), metal, petal);
                    Append(pieces, vane, RoomEnvironmentMotion.Movement.Hinge, Vector3.right, 1.16f, 23f, i*.28f);
                }
                Meter(hardware, pieces, lamp, 2, -.205f, .085f);
            }
            else if (mount.Type == Track.Monitor)
            {
                Housing(hardware, 1.44f, .52f);
                Meter(hardware, pieces, lamp, 6, .126f, .16f);
                for (var i = 0; i < 2; i++)
                {
                    var needle = Render(hardware, $"Read head {i+1}", new Vector3((i*2-1)*.28f,-.102f,.092f),
                        new Vector3(.125f,.035f,.018f), lamp, petal);
                    Append(pieces, needle, RoomEnvironmentMotion.Movement.Slide, Vector3.right, .88f, .16f, i*Mathf.PI);
                }
            }
            else
            {
                var field = mount.Label == "Zero carrier field";
                if (!field) Housing(hardware, 1.18f, .82f);
                for (var i = 0; i < 6; i++)
                {
                    var angle = i * 60f;
                    var radial = new Vector3(Mathf.Cos(angle * Mathf.Deg2Rad), Mathf.Sin(angle * Mathf.Deg2Rad), 0f);
                    var vane = Render(hardware, field ? $"Memory resonance {i+1}" : $"Aperture leaf {i+1}",
                        radial * (field ? .64f : .24f) + Vector3.forward * .10f,
                        new Vector3(field ? .12f : .246f, field ? .026f : .083f, .035f),
                        field ? lamp : i % 2 == 0 ? metal : inset, petal);
                    vane.localRotation = Quaternion.Euler(0, 0, angle+16f);
                    Append(pieces, vane, mount.Type == Track.Iris ? RoomEnvironmentMotion.Movement.Slide : RoomEnvironmentMotion.Movement.Hinge,
                        mount.Type == Track.Iris ? radial : Vector3.forward, field ? .95f : 1.21f,
                        mount.Type == Track.Iris ? .059f : 17f, i*.46f);
                }
                Meter(hardware, pieces, lamp, 2, field ? -.57f : -.312f, .056f);
            }
            data.ApplyModifiedPropertiesWithoutUndo();
            Debug.Log($"ECHO_ROOM_MECHANISM {room.name}: {mount.Label} pieces={room.PieceCount}");
        }

        private void Housing(Transform root, float width, float height)
        {
            Render(root, "Beveled mounting flange", Vector3.zero, new Vector3(width, height, .125f), metal, shell);
            Render(root, "Gasket and recessed face", new Vector3(0, 0, .061f), new Vector3(width*.88f, height*.8f, .039f), inset, shell);
        }

        private void Meter(Transform root, SerializedProperty pieces, Material lamp, int count, float y, float travel)
        {
            for (var i = 0; i < count; i++)
            {
                var x = (i-(count-1)*.5f)*(count == 2 ? .53f : .154f);
                var slot = Render(root, $"Readout {i+1}", new Vector3(x, y, .089f),
                    new Vector3(.075f, .022f, .016f), lamp, petal);
                Append(pieces, slot, RoomEnvironmentMotion.Movement.Slide, Vector3.up, .92f+(i%3)*.21f, travel*.49f, i*.69f);
            }
        }

        private void WardDraft(Transform root, SerializedProperty pieces, Transform ward)
        {
            var fabric = ward.Cast<Transform>().First(item => item.name == "Pleated curtain").GetComponent<Renderer>().sharedMaterial;
            for (var i = 0; i < 8; i++)
            {
                var side = i < 4 ? -1f : 1f;
                var fold = Render(root, $"Window-side curtain fold {i+1}",
                    new Vector3(side*(1.22f + (i%4)*.074f), -.80f, .022f+(i%2)*.034f),
                    new Vector3(.078f, 1.61f - (i%4)*.034f, .064f), fabric, petal);
                Append(pieces, fold, RoomEnvironmentMotion.Movement.Slide, Vector3.forward, .66f+(i%4)*.05f, .027f, i*.49f);
            }
        }

        private static void Append(SerializedProperty pieces, Transform target, RoomEnvironmentMotion.Movement movement,
            Vector3 direction, float rate, float amplitude, float phase)
        {
            var index = pieces.arraySize++;
            var piece = pieces.GetArrayElementAtIndex(index);
            piece.FindPropertyRelative("target").objectReferenceValue = target;
            piece.FindPropertyRelative("movement").enumValueIndex = (int)movement;
            piece.FindPropertyRelative("direction").vector3Value = direction;
            piece.FindPropertyRelative("rate").floatValue = rate;
            piece.FindPropertyRelative("amplitude").floatValue = amplitude;
            piece.FindPropertyRelative("phase").floatValue = phase;
        }

        private static Transform Render(Transform parent, string name, Vector3 at, Vector3 size, Material material, Mesh mesh)
        {
            var item = Node(parent, name, at);
            item.localScale = size;
            item.gameObject.AddComponent<MeshFilter>().sharedMesh = mesh;
            var renderer = item.gameObject.AddComponent<MeshRenderer>();
            renderer.sharedMaterial = material;
            renderer.shadowCastingMode = ShadowCastingMode.Off;
            return item;
        }

        private static Mesh Shape(string name, float[] band)
        {
            var path = Folder + name + ".asset";
            var saved = AssetDatabase.LoadAssetAtPath<Mesh>(path);
            if (saved) return saved;
            var corners = new[]
            {
                new Vector2(-.38f,-.5f), new Vector2(.38f,-.5f), new Vector2(.5f,-.38f), new Vector2(.5f,.38f),
                new Vector2(.38f,.5f), new Vector2(-.38f,.5f), new Vector2(-.5f,.38f), new Vector2(-.5f,-.38f)
            };
            var levels = new[] { -.5f, -.38f, .32f, .5f };
            var vertices = new List<Vector3>();
            var uv = new List<Vector2>();
            var triangles = new List<int>();
            Vector3 Point(int corner, int level)
            {
                var p = corners[corner] * band[level];
                return new Vector3(p.x,p.y,levels[level]);
            }
            void Add(Vector3 a, Vector3 b, Vector3 c)
            {
                var index = vertices.Count;
                vertices.AddRange(new[] { a,b,c });
                var n = Vector3.Cross(b-a,c-a);
                foreach (var v in new[] { a,b,c })
                    uv.Add(Mathf.Abs(n.z) > Mathf.Abs(n.x)+Mathf.Abs(n.y) ? new Vector2(v.x+.5f,v.y+.5f) :
                        new Vector2(v.x+v.y+.5f,v.z+.5f));
                triangles.AddRange(new[] { index,index+1,index+2 });
            }
            for (var i = 0; i < corners.Length; i++)
            {
                var next = (i+1)%corners.Length;
                Add(Vector3.back*.5f,Point(next,0),Point(i,0));
                Add(Vector3.forward*.5f,Point(i,3),Point(next,3));
                for (var level = 0; level < 3; level++)
                {
                    Add(Point(i,level),Point(next,level),Point(next,level+1));
                    Add(Point(i,level),Point(next,level+1),Point(i,level+1));
                }
            }
            var mesh = new Mesh { name = name };
            mesh.SetVertices(vertices);
            mesh.SetUVs(0, uv);
            mesh.SetTriangles(triangles, 0);
            mesh.RecalculateNormals();
            mesh.RecalculateTangents();
            AssetDatabase.CreateAsset(mesh,path);
            return mesh;
        }
    }
}
