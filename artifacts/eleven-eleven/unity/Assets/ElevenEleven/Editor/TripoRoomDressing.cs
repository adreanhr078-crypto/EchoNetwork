using System.IO;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using static ElevenEleven.Editor.GodotRoomAssembly;

namespace ElevenEleven.Editor
{
    internal static class TripoRoomDressing
    {
        private const string Folder = "Assets/ElevenEleven/Opening/Stormworks/";
        private static readonly Color Teal = new Color(0.06f, 0.92f, 0.86f);
        private static readonly Color Violet = new Color(0.67f, 0.12f, 1f);

        internal static void SpecimenFacade(Transform root)
        {
            var module = AssetDatabase.LoadAssetAtPath<GameObject>(Folder + "ContainmentFacade-Tripo.glb");
            if (module == null) return;
            var mounts = Node(root, "Containment façade system", Vector3.zero);
            foreach (var x in new[] { -3f, -9f, -15f, -21f, -27f })
                Mount(mounts, module, "North wall service bank", new Vector3(x, 2.36f, 17.68f),
                    new Vector3(5.75f, 4.07f, 1.92f), 180f);
            foreach (var z in new[] { -3f, 3f, 9f, 15f })
                Mount(mounts, module, "East wall environmental cabinet", new Vector3(-0.29f, 2.36f, z),
                    new Vector3(5.66f, 4.07f, 1.92f), -90f);
            foreach (var z in new[] { -2.9f, 2.5f, 8f, 15.52f })
                Mount(mounts, module, "West wall environmental cabinet", new Vector3(-29.68f, 2.02f, z),
                    new Vector3(4.55f, 3.53f, 1.60f), 90f);
            Light(mounts, "Entry cabinet optic bounce", new Vector3(-1.51f, 2.57f, -2.1f), Teal, 4.2f, 5.8f);
            Light(mounts, "Rear coolant bounce", new Vector3(-17.5f, 3.55f, 15.4f), Teal, 5.0f, 8.8f);
        }

        internal static void ArchiveCore(Transform root)
        {
            var model = AssetDatabase.LoadAssetAtPath<GameObject>(Folder + "MemoryCore-Tripo.glb");
            if (model == null) return;
            Mount(root, model, "Memory core housing", new Vector3(-10.7f, 1.81f, -5.35f),
                new Vector3(2.58f, 3.62f, 2.18f), 160f);
            Light(root, "Prism chromatic bloom", new Vector3(-10.65f, 3.7f, -5.65f), Violet, 4.1f, 8.5f);
            Light(root, "Coolant edge fill", new Vector3(-10.65f, 1.52f, -3.7f), Teal, 1.85f, 5.8f);
        }

        private static void Mount(Transform parent, GameObject prototype, string title, Vector3 center, Vector3 dimensions,
            float yaw)
        {
            var seat = Node(parent, title, center);
            seat.localRotation = Quaternion.Euler(0, yaw, 0);
            var mesh = (GameObject)PrefabUtility.InstantiatePrefab(prototype, seat);
            var combined = BoundsFromRoot(mesh.transform, seat);
            mesh.transform.localPosition -= combined.center;
            var scale = Mathf.Min(dimensions.x / combined.size.x,
                Mathf.Min(dimensions.y / combined.size.y, dimensions.z / combined.size.z));
            seat.localScale = Vector3.one * scale;
            var hit = seat.gameObject.AddComponent<BoxCollider>();
            hit.size = combined.size * 0.96f;
            foreach (var renderer in mesh.GetComponentsInChildren<MeshRenderer>(true))
                renderer.shadowCastingMode = ShadowCastingMode.Off;
        }

        private static Bounds BoundsFromRoot(Transform model, Transform root)
        {
            var bounds = new Bounds();
            var first = true;
            foreach (var renderer in model.GetComponentsInChildren<MeshRenderer>(true))
            {
                var matrix = root.worldToLocalMatrix * renderer.localToWorldMatrix;
                var item = renderer.localBounds;
                for (var i = 0; i < 8; i++)
                {
                    var sign = new Vector3((i & 1) == 0 ? -1 : 1, (i & 2) == 0 ? -1 : 1, (i & 4) == 0 ? -1 : 1);
                    var vertex = matrix.MultiplyPoint3x4(item.center + Vector3.Scale(item.extents, sign));
                    if (first) bounds = new Bounds(vertex, Vector3.zero);
                    else bounds.Encapsulate(vertex);
                    first = false;
                }
            }
            if (first || Mathf.Min(bounds.size.x, Mathf.Min(bounds.size.y, bounds.size.z)) < 0.002f)
                throw new InvalidDataException($"Tripo asset has invalid size: {model.name}");
            return bounds;
        }

        private static void Light(Transform parent, string name, Vector3 position, Color color, float intensity, float range)
        {
            var point = Node(parent, name, position).gameObject.AddComponent<Light>();
            point.type = LightType.Point;
            point.color = color;
            point.intensity = intensity;
            point.range = range;
        }
    }
}

