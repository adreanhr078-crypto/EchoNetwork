using ElevenEleven.Opening;
using UnityEditor;
using UnityEngine;
using static ElevenEleven.Editor.GodotRoomAssembly;

namespace ElevenEleven.Editor
{
    internal static class StationSpecimenConstruction
    {
        internal const string AssetPath = "Assets/ElevenEleven/Opening/Stormworks/Specimen-Godot-Art.glb";

        internal static StationSpecimenWing Build(Transform station, Material wall, Material deck, Material glow)
        {
            var root = Node(station, "Specimen containment", new Vector3(StationSecurityWing.CenterX + 2.5f, 0, 105f));
            var art = PlaceArt(root, AssetPath, "Native Godot specimen geometry");
            ContainmentMaterials.Specimens(art, deck);
            var exit = Find(art, "ExitBlastGate");
            Collisions(root, "specimen_containment_wing", name => name == "ExitBlastGate" ? exit : null);
            var shutter = Block(root, "Containment entry shutter", new Vector3(-2.5f, 1.51f, -6.03f),
                new Vector3(2.58f, 3.02f, 0.22f), wall);
            Block(root, "Specimen exit landing", new Vector3(-31.6f, -0.23f, 12f), new Vector3(3.3f, 0.46f, 2.05f), deck);
            var shortcut = BuildReturnCatwalk(root, wall, deck);
            var terminal = Node(root, "EX-011 terminal reach", new Vector3(-26f, 0.83f, 11.34f));
            var scanner = Node(root, "Containment scanner origin", new Vector3(-15f, 6.60f, 6f));
            var beam = scanner.gameObject.AddComponent<Light>();
            beam.type = LightType.Spot;
            beam.spotAngle = 89f;
            beam.innerSpotAngle = 30f;
            beam.range = 22f;
            beam.intensity = 6.2f;

            var anchors = new Transform[6];
            for (var i = 0; i < anchors.Length; i++)
            {
                var x = -8f - (i % 3) * 6f;
                var z = i < 3 ? 0f : 12f;
                anchors[i] = Node(root, "Specimen sample " + (i + 1), new Vector3(x, 0.85f, z - 1.17f));
                var color = i == 5 ? new Color(1f, 0.46f, 0.10f) : new Color(0.10f, 0.84f, 1f);
                Illuminate(root, new Vector3(x - 1.8f, 3.5f, z + 1.4f), color, 4.0f, 6.4f);
            }
            Illuminate(root, new Vector3(-24f, 5.3f, 10f), new Color(0.36f, 0.11f, 1f), 6.5f, 9f);
            Illuminate(root, new Vector3(-3.5f, 4.0f, -3.9f), new Color(0.21f, 0.92f, 0.78f), 4.0f, 9f);

            StationWallDressing.Specimen(root, glow);
            TripoRoomDressing.SpecimenFacade(root);
            StationSurfaceDressing.Specimen(root, deck);
            var wing = root.gameObject.AddComponent<StationSpecimenWing>();
            var data = new SerializedObject(wing);
            foreach (var pair in new (string key, UnityEngine.Object value)[]
            {
                ("shutter", shutter), ("exit", exit), ("shortcut", shortcut), ("terminal", terminal), ("scanner", scanner), ("beam", beam)
            }) data.FindProperty(pair.key).objectReferenceValue = pair.value;
            var property = data.FindProperty("tanks");
            property.arraySize = anchors.Length;
            for (var i = 0; i < anchors.Length; i++) property.GetArrayElementAtIndex(i).objectReferenceValue = anchors[i];
            data.ApplyModifiedPropertiesWithoutUndo();
            return wing;
        }

        private static Transform BuildReturnCatwalk(Transform root, Material frame, Material deck)
        {
            const float center = -31.86f;
            const float start = -25.2f;
            const float end = 13.15f;
            var middle = (start + end) * 0.5f;
            Block(root, "Specimen to Station return deck", new Vector3(center, -0.23f, middle),
                new Vector3(2.66f, 0.46f, end - start), deck);
            const float outsideGuardEnd = 10.55f;
            Block(root, "Return catwalk outer guard", new Vector3(center - 1.29f, 0.62f, (start + outsideGuardEnd) * 0.5f),
                new Vector3(0.18f, 1.24f, outsideGuardEnd - start), frame);
            const float rightEnd = 10.2f;
            Block(root, "Return catwalk inner guard", new Vector3(center + 1.31f, 0.62f, (start + rightEnd) * 0.5f),
                new Vector3(0.18f, 1.24f, rightEnd - start), frame);
            for (var z = start + 3f; z < end; z += 5.8f)
            {
                Block(root, "Return catwalk buttress", new Vector3(center, -2.15f, z),
                    new Vector3(0.55f, 3.4f, 0.64f), frame);
                Illuminate(root, new Vector3(center - 1.15f, 2.05f, z), new Color(0.08f, 0.76f, 1f), 2.2f, 4.8f);
            }
            return Block(root, "Return catwalk shutter", new Vector3(center, 1.42f, -24.25f),
                new Vector3(2.49f, 2.84f, 0.24f), frame);
        }

        private static void Illuminate(Transform root, Vector3 at, Color color, float power, float range)
        {
            var light = Node(root, "Specimen practical", at).gameObject.AddComponent<Light>();
            light.type = LightType.Point;
            light.color = color;
            light.intensity = power;
            light.range = range;
        }
    }
}

