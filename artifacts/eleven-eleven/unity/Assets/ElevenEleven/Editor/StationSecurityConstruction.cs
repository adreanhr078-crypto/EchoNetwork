using System;
using System.IO;
using System.Linq;
using ElevenEleven.Opening;
using Newtonsoft.Json.Linq;
using UnityEditor;
using UnityEngine;

namespace ElevenEleven.Editor
{
    internal static class StationSecurityConstruction
    {
        private const string Art = "Assets/ElevenEleven/Opening/Stormworks/Security-Godot-Art.glb";
        private const string Inventory = "Migration/GodotRoomsSource.json";

        internal static StationSecurityWing Build(Transform station, Material frame, Material deck)
        {
            var root = Add("Security wing", station, new Vector3(StationSecurityWing.CenterX, 0, StationSecurityWing.EntranceZ));
            var prefab = (GameObject)PrefabUtility.InstantiatePrefab(Load<GameObject>(Art), root);
            prefab.name = "Native Godot security geometry";
            prefab.transform.localRotation = Quaternion.Euler(0, 180f, 0);
            var exitBoundary = OwnedTransform(prefab.transform, "SecurityRearBarrier");
            exitBoundary.gameObject.SetActive(false);
            var gate = OwnedTransform(prefab.transform, "SecurityGate");

            var colliderSet = Add("Authoritative collision", root, Vector3.zero);
            var inventory = JArray.Parse(File.ReadAllText(Inventory));
            var source = inventory.Single(room => (string)room["name"] == "security_checkpoint_room");
            foreach (var shape in (JArray)source["colliders"])
            {
                if ((bool)shape["disabled"] || (string)shape["type"] != "BoxShape3D") continue;
                var path = (string)shape["path"];
                if (path.StartsWith("ExitRecoveryBoundary/", StringComparison.Ordinal)) continue;
                var matrix = (JArray)shape["transform"];
                var center = Point((JArray)matrix[3]);
                var right = Point((JArray)matrix[0]);
                var up = Point((JArray)matrix[1]);
                var forward = -Point((JArray)matrix[2]);
                var target = Add(path.Split('/')[0], colliderSet, center);
                target.localRotation = Quaternion.LookRotation(forward, up);
                var size = Dimensions((JArray)shape["size"]);
                target.gameObject.AddComponent<BoxCollider>().size =
                    Vector3.Scale(size, new Vector3(right.magnitude, up.magnitude, forward.magnitude));
                if (path.StartsWith("SecurityGate/", StringComparison.Ordinal)) target.SetParent(gate, true);
            }

            var entrance = Box(root, "Security sector shutter", new Vector3(0, 1.41f, 0.02f),
                new Vector3(1.79f, 2.82f, 0.25f), frame);
            var diversion = Add("Scanner diversion console", root, new Vector3(-3.5f, 0.9f, 1.8f));
            var panel = Add("Gate release console", root, new Vector3(-1.3f, 0.9f, 15.6f));
            var scanner = Add("Scanner detection origin", root, new Vector3(0, 2.0f, 14.5f));
            var sweep = scanner.gameObject.AddComponent<Light>();
            sweep.type = LightType.Spot;
            sweep.range = 13f;
            sweep.spotAngle = 24f;
            sweep.innerSpotAngle = 15f;
            sweep.shadows = LightShadows.None;
            var audio = Add("Security servo", root, panel.localPosition).gameObject.AddComponent<AudioSource>();
            audio.clip = Load<AudioClip>("Assets/ElevenEleven/Opening/Stormworks/SecurityServo.ogg");
            audio.playOnAwake = false;
            audio.spatialBlend = 0.95f;
            audio.minDistance = 2f;
            audio.maxDistance = 16f;
            audio.dopplerLevel = 0f;
            audio.volume = 0.42f;
            for (var z = 2.3f; z <= 17f; z += 4.6f)
            {
                Glow(root, new Vector3(-3.4f, 3.9f, z), new Color(0.08f, 0.58f, 1.0f), 4.4f, 6.9f);
                Glow(root, new Vector3(3.55f, 3.5f, z + 0.7f), new Color(1f, 0.44f, 0.09f), 4.0f, 5.9f);
            }

            Box(root, "Restricted exit landing", new Vector3(0, -0.23f, 19.33f),
                new Vector3(3.2f, 0.46f, 2.7f), deck);
            Box(root, "Right service ascent", new Vector3(3.61f, 0.35f, 1.13f),
                new Vector3(1.3f, 0.7f, 0.93f), frame);
            Box(root, "Right service middle", new Vector3(3.61f, 0.77f, 1.87f),
                new Vector3(1.3f, 1.54f, 0.75f), frame);

            var runtime = root.gameObject.AddComponent<StationSecurityWing>();
            var data = new SerializedObject(runtime);
            foreach (var pair in new (string key, UnityEngine.Object value)[]
            {
                ("scanner", scanner), ("sweep", sweep), ("diversion", diversion), ("gatePanel", panel),
                ("gate", gate), ("entry", entrance), ("mechanism", audio)
            }) data.FindProperty(pair.key).objectReferenceValue = pair.value;
            data.ApplyModifiedPropertiesWithoutUndo();
            return runtime;
        }

        private static T Load<T>(string path) where T : UnityEngine.Object =>
            AssetDatabase.LoadAssetAtPath<T>(path) ?? throw new FileNotFoundException(path);

        private static Transform OwnedTransform(Transform root, string name) =>
            root.GetComponentsInChildren<Transform>(true).Single(child => child.name == name);

        private static Vector3 Point(JArray v) => new Vector3((float)v[0], (float)v[1], -(float)v[2]);
        private static Vector3 Dimensions(JArray v) => new Vector3((float)v[0], (float)v[1], (float)v[2]);

        private static Transform Add(string name, Transform parent, Vector3 position)
        {
            var transform = new GameObject(name).transform;
            transform.SetParent(parent, false);
            transform.localPosition = position;
            return transform;
        }

        private static Transform Box(Transform parent, string name, Vector3 center, Vector3 size, Material material)
        {
            var item = GameObject.CreatePrimitive(PrimitiveType.Cube);
            item.name = name;
            item.transform.SetParent(parent, false);
            item.transform.localPosition = center;
            item.transform.localScale = size;
            item.GetComponent<MeshRenderer>().sharedMaterial = material;
            return item.transform;
        }

        private static void Glow(Transform root, Vector3 center, Color color, float power, float range)
        {
            var bulb = Add("Security practical", root, center).gameObject.AddComponent<Light>();
            bulb.type = LightType.Point;
            bulb.color = color;
            bulb.intensity = power;
            bulb.range = range;
        }
    }
}

