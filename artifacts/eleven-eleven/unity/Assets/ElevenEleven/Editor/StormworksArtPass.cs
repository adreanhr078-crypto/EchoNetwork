using System;
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

namespace ElevenEleven.Editor
{
    internal static class StormworksArtPass
    {
        private const string KitPath = "Assets/ElevenEleven/Opening/Stormworks/Stormworks-Godot-Kit.glb";
        private static readonly Color Indigo = new Color(0.14f, 0.426f, 1.0f);
        private static readonly Color Orchid = new Color(0.64f, 0.20f, 1.0f);
        private static readonly Color Turquoise = new Color(0.07f, 1.0f, 0.76f);
        private static readonly Color Copper = new Color(1.0f, 0.35f, 0.08f);

        internal static void Dress(Transform owner, Transform containment)
        {
            var kit = AssetDatabase.LoadAssetAtPath<GameObject>(KitPath);
            if (kit == null) throw new FileNotFoundException("Import the Stormworks Godot kit before building the station.", KitPath);
            var modules = new Dictionary<string, MeshRenderer>();
            foreach (var renderer in kit.GetComponentsInChildren<MeshRenderer>(true))
            {
                var key = renderer.gameObject.name;
                if (key.StartsWith("GODOT_", StringComparison.Ordinal)) modules.Add(key, renderer);
            }

            // Place visual modules independently of the authored movement and camera collision.
            var root = Add("Stormworks structural modules", owner, Vector3.zero);
            Mount(root, modules, 0, "Chronostat headwall", new Vector3(0, 6.0f, 84.5f), new Vector3(24f, 15f, 2.6f));
            Mount(root, modules, 2, "Intake superstructure", new Vector3(-9.7f, 6.35f, 43f), new Vector3(10.0f, 12.3f, 4.3f), 12);
            Mount(root, modules, 17, "Observation superstructure", new Vector3(10.8f, 6.2f, 45f), new Vector3(8.9f, 11.7f, 6.1f), -14);
            Mount(root, modules, 7, "West resonator tower", new Vector3(-11f, 5.25f, 62.5f), new Vector3(4.5f, 12.4f, 5.2f), 100);
            Mount(root, modules, 1, "East resonator tower", new Vector3(9.8f, 5.6f, 60.5f), new Vector3(3.6f, 12.8f, 9.8f), -100);
            Mount(root, modules, 3, "West turbine bank", new Vector3(-17.0f, 0.1f, 60.3f), new Vector3(6.0f, 3.6f, 2.7f), 90);
            Mount(root, modules, 9, "East turbine bank", new Vector3(18f, 0.7f, 53.5f), new Vector3(3.9f, 3.7f, 2.8f), -90);
            Mount(root, modules, 4, "Overhead crossfeed", new Vector3(0, 6.8f, 69f), new Vector3(9.2f, 1.3f, 2.5f));
            Mount(root, modules, 18, "Lab suspended pipes", new Vector3(13.95f, 5.9f, 67f), new Vector3(7.5f, 1.5f, 3.8f), -90);
            Mount(root, modules, 19, "Left pump riser", new Vector3(-6f, 2.12f, 61.3f), new Vector3(1.2f, 7.2f, 2.3f), 70);
            Mount(root, modules, 16, "Containment supply", new Vector3(7.0f, 1.02f, -5.3f), new Vector3(2.45f, 2.1f, 1.7f), -21);
            Mount(root, modules, 1, "Containment wall conduit", new Vector3(-11.03f, 3.05f, 3.7f), new Vector3(1.75f, 6.1f, 7.2f));
            Mount(root, modules, 7, "Containment return conduit", new Vector3(11.1f, 3.05f, 7.6f), new Vector3(1.62f, 6.1f, 6.5f));
            Mount(root, modules, 8, "West filtration cartridge", new Vector3(-10.25f, 1.09f, -2.65f), new Vector3(1.6f, 2.2f, 1.55f));
            Mount(root, modules, 13, "East filtration cartridge", new Vector3(10.32f, 1.12f, 14f), new Vector3(1.6f, 2.2f, 1.55f), 180);

            LightPool(root, "Cold wake light", new Vector3(-2f, 3.25f, -3f), Indigo, 3.0f, 7.9f);
            LightPool(root, "Containment circuit", new Vector3(4.35f, 4.8f, 2.8f), Orchid, 2.9f, 9.5f);
            LightPool(root, "Warm clue light", new Vector3(-1.1f, 2.75f, -1.4f), Copper, 2.9f, 6.5f);
            LightPool(root, "Intake spill left", new Vector3(-5.7f, 4.75f, 44f), Turquoise, 8.4f, 15f);
            LightPool(root, "Observation spill right", new Vector3(5.8f, 5.4f, 47f), Orchid, 8.0f, 14f);
            LightPool(root, "Service flame bounce", new Vector3(-10.1f, 2.8f, 50.5f), Copper, 6.4f, 10.8f);
            LightPool(root, "Clock apparatus glow", new Vector3(0f, 8.9f, 80f), Turquoise, 12.5f, 27f);
            LightPool(root, "Tailwater magenta", new Vector3(6.5f, -0.2f, 55.5f), Orchid, 7.3f, 14f);
            LightPool(root, "Tailwater blue", new Vector3(-3.9f, -0.3f, 62.7f), Indigo, 6.3f, 13f);

            var main = containment.parent.Find("Cool overhead fill");
            if (main != null)
            {
                var fill = main.GetComponent<Light>();
                fill.color = new Color(0.61f, 0.69f, 1f);
                fill.intensity = 0.41f;
            }
        }

        private static void Mount(Transform root, Dictionary<string, MeshRenderer> modules, int module,
            string name, Vector3 center, Vector3 size, float yaw = 0)
        {
            var source = modules[$"GODOT_{module:00}"];
            var mesh = source.GetComponent<MeshFilter>().sharedMesh;
            var bounds = mesh.bounds;
            var extents = bounds.size;
            if (extents.x < 0.001f || extents.y < 0.001f || extents.z < 0.001f)
                throw new InvalidDataException($"Unusable dimensions on {mesh.name}.");
            var anchor = Add(name, root, center);
            anchor.localRotation = Quaternion.Euler(0, yaw, 0);
            anchor.localScale = new Vector3(size.x / extents.x, size.y / extents.y, size.z / extents.z);
            var model = Add(mesh.name, anchor, -bounds.center);
            model.gameObject.AddComponent<MeshFilter>().sharedMesh = mesh;
            var renderer = model.gameObject.AddComponent<MeshRenderer>();
            renderer.sharedMaterials = source.sharedMaterials;
            renderer.shadowCastingMode = ShadowCastingMode.Off;
        }

        private static Transform Add(string name, Transform parent, Vector3 position)
        {
            var item = new GameObject(name).transform;
            item.SetParent(parent, false);
            item.localPosition = position;
            return item;
        }

        private static void LightPool(Transform root, string name, Vector3 position, Color color, float power, float range)
        {
            var light = Add(name, root, position).gameObject.AddComponent<Light>();
            light.type = LightType.Point;
            light.color = color;
            light.intensity = power;
            light.range = range;
        }
    }
}

