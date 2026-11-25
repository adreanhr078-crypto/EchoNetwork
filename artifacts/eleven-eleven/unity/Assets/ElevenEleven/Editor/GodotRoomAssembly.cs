using System;
using System.IO;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEditor;
using UnityEngine;

namespace ElevenEleven.Editor
{
    internal static class GodotRoomAssembly
    {
        private const string Inventory = "Migration/GodotRoomsSource.json";

        internal static Transform PlaceArt(Transform root, string path, string name)
        {
            var source = AssetDatabase.LoadAssetAtPath<GameObject>(path) ?? throw new FileNotFoundException(path);
            var instance = (GameObject)PrefabUtility.InstantiatePrefab(source, root);
            instance.name = name;
            instance.transform.localRotation = Quaternion.Euler(0, 180f, 0);
            return instance.transform;
        }

        internal static Transform Find(Transform art, string name) =>
            art.GetComponentsInChildren<Transform>(true).Single(child => child.name == name);

        internal static void Collisions(Transform root, string sourceRoom, Func<string, Transform> movingBody)
        {
            var sources = JArray.Parse(File.ReadAllText(Inventory));
            var shapeSet = sources.Single(room => (string)room["name"] == sourceRoom)["colliders"];
            var holder = Node(root, "Authored Godot collision", Vector3.zero);
            Mesh cylinder = null;
            foreach (var shape in shapeSet)
            {
                if ((bool)shape["disabled"]) continue;
                var path = (string)shape["path"];
                var name = path.Split('/')[0];
                var moving = movingBody(name);
                var matrix = (JArray)shape["transform"];
                var right = Convert((JArray)matrix[0]);
                var up = Convert((JArray)matrix[1]);
                var forward = -Convert((JArray)matrix[2]);
                var target = Node(holder, name, Convert((JArray)matrix[3]));
                target.localRotation = Quaternion.LookRotation(forward, up);
                var scale = new Vector3(right.magnitude, up.magnitude, forward.magnitude);
                switch ((string)shape["type"])
                {
                    case "BoxShape3D":
                        var size = (JArray)shape["size"];
                        target.gameObject.AddComponent<BoxCollider>().size = Vector3.Scale(
                            new Vector3((float)size[0], (float)size[1], (float)size[2]), scale);
                        break;
                    case "CylinderShape3D":
                        if (cylinder == null)
                        {
                            var primitive = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
                            cylinder = primitive.GetComponent<MeshFilter>().sharedMesh;
                            UnityEngine.Object.DestroyImmediate(primitive);
                        }
                        var diameter = (float)shape["radius"] * 2f;
                        target.localScale = Vector3.Scale(new Vector3(diameter, (float)shape["height"] * 0.5f, diameter), scale);
                        target.gameObject.AddComponent<MeshCollider>().sharedMesh = cylinder;
                        break;
                    default:
                        throw new InvalidDataException($"Unmapped collider {shape["type"]} at {path}.");
                }
                if (moving != null) target.SetParent(moving, true);
            }
        }

        internal static Transform Node(Transform parent, string name, Vector3 position)
        {
            var node = new GameObject(name).transform;
            node.SetParent(parent, false);
            node.localPosition = position;
            return node;
        }

        internal static Transform Block(Transform parent, string name, Vector3 local, Vector3 size, Material material)
        {
            var item = GameObject.CreatePrimitive(PrimitiveType.Cube);
            item.name = name;
            item.transform.SetParent(parent, false);
            item.transform.localPosition = local;
            item.transform.localScale = size;
            item.GetComponent<MeshRenderer>().sharedMaterial = material;
            return item.transform;
        }

        private static Vector3 Convert(JArray value) => new Vector3((float)value[0], (float)value[1], -(float)value[2]);
    }
}

