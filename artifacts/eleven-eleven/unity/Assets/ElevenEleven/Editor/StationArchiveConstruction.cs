using ElevenEleven.Opening;
using UnityEditor;
using UnityEngine;
using static ElevenEleven.Editor.GodotRoomAssembly;

namespace ElevenEleven.Editor
{
    internal static class StationArchiveConstruction
    {
        private const string Art = "Assets/ElevenEleven/Opening/Stormworks/Archive-Godot-Art.glb";

        internal static StationArchiveWing Build(Transform station, Material frame, Material deck, Material glow)
        {
            var root = Node(station, "Memory archive wing", new Vector3(-24.5f, 0f, 117f));
            var art = PlaceArt(root, Art, "Native Godot archive geometry");
            ContainmentMaterials.Archive(art, deck);
            var exit = Find(art, "NorthExitBlastGate");
            Collisions(root, "memory_archive_wing", name => name == "NorthExitBlastGate" ? exit : null);

            var entrance = Block(root, "Archive security shutter", new Vector3(0.11f, 1.6f, 0f),
                new Vector3(0.22f, 3.2f, 2.58f), frame);
            Block(root, "Specimen to archive deck", new Vector3(6.0f, -0.23f, 0f),
                new Vector3(12.3f, 0.46f, 2.55f), deck);
            Block(root, "Archive conduit north wall", new Vector3(5.89f, 1.8f, 1.38f),
                new Vector3(11.82f, 3.6f, 0.30f), frame);
            Block(root, "Archive conduit south wall", new Vector3(5.67f, 1.8f, -1.38f),
                new Vector3(10.85f, 3.6f, 0.30f), frame);
            Block(root, "Archive conduit canopy", new Vector3(5.8f, 3.43f, 0f),
                new Vector3(11.7f, 0.25f, 2.8f), frame);
            Block(root, "Reactor transition landing", new Vector3(-11f, -0.23f, 15.52f),
                new Vector3(2.15f, 0.46f, 3.15f), deck);
            var decoder = Node(root, "Memory decoder reach", new Vector3(-11f, 0.89f, 3.2f));

            var shardNames = new[] { "Shard_shard_shizuka", "Shard_shard_yuki", "Shard_shard_sector11" };
            var shardPoints = new[]
            {
                new Vector3(-6f, 0.85f, -4.1f), new Vector3(-16f, 0.85f, 4.1f), new Vector3(-11f, 3.95f, 0f),
            };
            var anchors = new Transform[3];
            var visuals = new Transform[3];
            for (var index = 0; index < shardNames.Length; index++)
            {
                anchors[index] = Node(root, "Archive reach " + index, shardPoints[index]);
                visuals[index] = Find(art, shardNames[index]);
                Illuminate(root, shardPoints[index] + new Vector3(0f, 1.9f, -0.6f),
                    index == 1 ? new Color(0.54f, 0.28f, 1f) : new Color(0.09f, 0.75f, 1f), 3.9f, 7.4f);
            }
            var core = Illuminate(root, new Vector3(-11f, 6f, 0f), new Color(0.65f, 0.22f, 1f), 8.4f, 15f);
            Illuminate(root, new Vector3(-2f, 3.4f, 1.0f), new Color(0.23f, 0.95f, 0.92f), 4.0f, 8f);
            Illuminate(root, new Vector3(5.6f, 2.9f, 0.08f), new Color(0.76f, 0.29f, 1f), 4.8f, 8.5f);
            Illuminate(root, new Vector3(-18f, 6.6f, 8.8f), new Color(0.32f, 0.42f, 1f), 5.6f, 12f);

            TripoRoomDressing.ArchiveCore(root);
            StationSurfaceDressing.Archive(root, deck);
            StationWallDressing.Archive(root, glow);
            var wing = root.gameObject.AddComponent<StationArchiveWing>();
            var data = new SerializedObject(wing);
            data.FindProperty("entrance").objectReferenceValue = entrance;
            data.FindProperty("exit").objectReferenceValue = exit;
            data.FindProperty("decoder").objectReferenceValue = decoder;
            data.FindProperty("coreLight").objectReferenceValue = core;
            data.FindProperty("anchors").arraySize = anchors.Length;
            data.FindProperty("visual").arraySize = anchors.Length;
            for (var index = 0; index < anchors.Length; index++)
            {
                data.FindProperty("anchors").GetArrayElementAtIndex(index).objectReferenceValue = anchors[index];
                data.FindProperty("visual").GetArrayElementAtIndex(index).objectReferenceValue = visuals[index];
            }
            data.ApplyModifiedPropertiesWithoutUndo();
            return wing;
        }

        private static Light Illuminate(Transform root, Vector3 at, Color color, float intensity, float range)
        {
            var light = Node(root, "Archive practical", at).gameObject.AddComponent<Light>();
            light.type = LightType.Point;
            light.color = color;
            light.intensity = intensity;
            light.range = range;
            return light;
        }
    }
}

