using ElevenEleven.Opening;
using UnityEditor;
using UnityEngine;
using static ElevenEleven.Editor.GodotRoomAssembly;

namespace ElevenEleven.Editor
{
    internal static class StationReactorConstruction
    {
        private const string Art = "Assets/ElevenEleven/Opening/Stormworks/Reactor-Godot-Art.glb";
        internal static StationReactorWing Build(Transform station, Material frame, Material deck)
        {
            var root = Node(station, "Reserve reactor wing", new Vector3(-35.5f, 4f, 146f));
            var model = PlaceArt(root, Art, "Native Godot reactor geometry");
            var bridge = Find(model, "HydraulicBridge");
            var hatch = Find(model, "NorthExitGate");
            Collisions(root, "core_reactor_room", source => source switch
            {
                "HydraulicBridge" => bridge,
                "NorthExitGate" => hatch,
                _ => null,
            });
            var entrance = Block(root, "Reactor ingress shutter", new Vector3(0, -2.5f, -0.07f),
                new Vector3(2.48f, 3.0f, 0.19f), frame);
            Block(root, "Reserve power conduit floor", new Vector3(0, -4.23f, -6.18f),
                new Vector3(2.61f, 0.46f, 13.21f), deck);
            foreach (var x in new[] { -1.41f, 1.41f })
                Block(root, "Reserve conduit wall", new Vector3(x, -2.42f, -5.98f),
                    new Vector3(0.24f, 3.2f, 12.70f), frame);
            Block(root, "Reserve conduit ceiling", new Vector3(0f, -0.74f, -6.0f), new Vector3(2.94f, 0.32f, 12.2f), frame);
            Block(root, "Decon transition landing", new Vector3(0f, -0.23f, 45.33f), new Vector3(2.53f, 0.46f, 3.2f), deck);

            var west = Node(root, "West breaker reach", new Vector3(-12.5f, -1.13f, 16f));
            var east = Node(root, "East breaker reach", new Vector3(12.5f, -1.13f, 28f));
            var volumes = new[]
            {
                new Bounds(new Vector3(-6f, -1.9f, 14.8f), new Vector3(3.5f, 1.2f, 2.2f)),
                new Bounds(new Vector3(11f, -1.9f, 20.0f), new Vector3(3.5f, 1.2f, 2.2f)),
            };
            var wing = root.gameObject.AddComponent<StationReactorWing>();
            var data = new SerializedObject(wing);
            data.FindProperty("bridge").objectReferenceValue = bridge;
            data.FindProperty("hatch").objectReferenceValue = hatch;
            data.FindProperty("entrance").objectReferenceValue = entrance;
            var switches = data.FindProperty("breakers");
            switches.arraySize = 2;
            switches.GetArrayElementAtIndex(0).objectReferenceValue = west;
            switches.GetArrayElementAtIndex(1).objectReferenceValue = east;

            var triggerData = data.FindProperty("arcVolumes");
            var arcLights = data.FindProperty("arcs");
            triggerData.arraySize = volumes.Length;
            arcLights.arraySize = volumes.Length;
            for (var index = 0; index < volumes.Length; index++)
            {
                triggerData.GetArrayElementAtIndex(index).boundsValue = volumes[index];
                arcLights.GetArrayElementAtIndex(index).objectReferenceValue = LightPool(root, "Alternating hazard spill",
                    volumes[index].center + Vector3.up * 0.4f, new Color(0.1f, 0.6f, 1f), 2f, 6f);
            }
            data.ApplyModifiedPropertiesWithoutUndo();
            LightPool(root, "Reserve reactor crown", new Vector3(0, 4.0f, 23.5f), new Color(0.15f, 0.54f, 1f), 14f, 23f);
            LightPool(root, "Reserve reactor base", new Vector3(0, -7f, 23.5f), new Color(0.56f, 0.13f, 1f), 16f, 21f);
            LightPool(root, "West transformer relay", west.localPosition + new Vector3(1.3f, 2.9f, 0.9f),
                new Color(1f, 0.34f, 0.08f), 8f, 12f);
            LightPool(root, "East capacitor relay", east.localPosition + new Vector3(-1.3f, 2.9f, 0.9f),
                new Color(0.12f, 1f, 0.77f), 8f, 12f);
            LightPool(root, "Reactor elevator", new Vector3(0f, 4f, 39.8f), new Color(0.18f, 0.49f, 1f), 6f, 11f);
            return wing;
        }

        private static Light LightPool(Transform root, string name, Vector3 local, Color color, float power, float range)
        {
            var light = Node(root, name, local).gameObject.AddComponent<Light>();
            light.type = LightType.Point;
            light.color = color;
            light.intensity = power;
            light.range = range;
            return light;
        }
    }
}

