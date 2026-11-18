using System;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using static ElevenEleven.Editor.GodotRoomAssembly;

namespace ElevenEleven.Editor
{
    internal static class StationWallDressing
    {
        private const string Folder = "Assets/ElevenEleven/Opening/Stormworks/";
        private const float SpecimenHeight = 7.2f;

        internal static void Opening(Transform station, Transform shell, Material glow)
        {
            var walls = Node(station, "Full-height containment bulkheads", Vector3.zero);
            foreach (var side in new[] { -1f, 1f })
            {
                var source = shell.Find(side < 0f ? "West wall" : "East wall");
                var floor = Mathf.Max(0f, source.localPosition.y - source.localScale.y * 0.5f);
                var ceiling = source.localPosition.y + source.localScale.y * 0.5f;
                var x = source.localPosition.x - side * (source.localScale.x * 0.5f + 0.018f);
                var width = source.localScale.z;
                Span(walls, new Vector3(x, floor, source.localPosition.z), Vector3.left * side,
                    width, ceiling - floor, glow, true);
                var plenum = Node(walls, side < 0f ? "West plenum wall" : "East plenum wall", Vector3.zero);
                Span(plenum, new Vector3(side * 3.721f, 0f, 28.1f), Vector3.left * side, 11.62f, 5.56f, glow, false);
                Span(walls, new Vector3(side * 6.3f, 0f, 17.585f), Vector3.back, 5.37f, 7.16f, glow, true);
                Span(walls, new Vector3(side * 10.4f, 0f, 17.585f), Vector3.back, 3.16f, 7.16f, glow, false);
            }
            Span(walls, new Vector3(0f, 0f, -6.585f), Vector3.forward, 23.17f, 7.16f, glow, false);
        }

        internal static void Specimen(Transform room, Material glow)
        {
            var walls = Node(room, "Continuous specimen bulkheads", Vector3.zero);
            Span(walls, new Vector3(-15f, 0, 17.973f), Vector3.back, 29.96f, SpecimenHeight, glow, false);
            Span(walls, new Vector3(-0.026f, 0, 6f), Vector3.left, 23.94f, SpecimenHeight, glow, true);
            Span(walls, new Vector3(-16.9f, 0, -5.973f), Vector3.forward, 26.12f, SpecimenHeight, glow, false);
            Span(walls, new Vector3(-0.6f, 0, -5.973f), Vector3.forward, 1.12f, SpecimenHeight, glow, false);
            Span(walls, new Vector3(-2.5f, 3.18f, -5.973f), Vector3.forward, 2.53f, 4.02f, glow, false);
            Span(walls, new Vector3(-29.974f, 0, 2.5f), Vector3.right, 16.96f, SpecimenHeight, glow, true);
            Span(walls, new Vector3(-29.974f, 0, 15.5f), Vector3.right, 4.94f, SpecimenHeight, glow, false);
            Span(walls, new Vector3(-29.974f, 3.44f, 12f), Vector3.right, 2.12f, 3.76f, glow, false);
        }

        internal static void Archive(Transform room, Material glow)
        {
            var walls = Node(room, "Continuous archive bulkheads", Vector3.zero);
            Span(walls, new Vector3(-11f, 0f, -13.977f), Vector3.forward, 21.94f, 8.47f, glow, true);
            Span(walls, new Vector3(-21.977f, 0f, 0f), Vector3.right, 27.94f, 8.47f, glow, false);
            foreach (var z in new[] { -7.65f, 7.65f })
                Span(walls, new Vector3(-0.024f, 0f, z), Vector3.left, 12.66f, 8.47f, glow, false);
            Span(walls, new Vector3(-0.024f, 3.24f, 0f), Vector3.left, 2.54f, 5.23f, glow, false);
            foreach (var x in new[] { -17.0125f, -4.9875f })
                Span(walls, new Vector3(x, 0f, 13.977f), Vector3.back, 9.93f, 8.47f, glow, false);
            Span(walls, new Vector3(-11f, 3.45f, 13.977f), Vector3.back, 2f, 5.02f, glow, false);
        }

        internal static void Quarantine(Transform room, Material glow)
        {
            var walls = Node(room, "Continuous quarantine bulkheads", Vector3.zero);
            foreach (var side in new[] { -1f, 1f })
            {
                Span(walls, new Vector3(side * 10.024f, 0f, 16f), Vector3.left * side, 31.8f, 7.16f, glow, false);
                Span(walls, new Vector3(side * 5.725f, 0f, 29.675f), Vector3.back, 8.70f, 7.16f, glow, false);
                Span(walls, new Vector3(side * 5.65f, 0f, 0.026f), Vector3.forward, 8.66f, 7.16f, glow, false);
            }
        }

        internal static void Surveillance(Transform room, Material glow)
        {
            var walls = Node(room, "Continuous surveillance bulkheads", Vector3.zero);
            foreach (var side in new[] { -1f, 1f })
            {
                Span(walls, new Vector3(side * 13.973f, 0f, 18f), Vector3.left * side, 35.92f, 7.96f, glow, false);
                Span(walls, new Vector3(side * 7.65f, 0f, 0.027f), Vector3.forward, 12.64f, 7.96f, glow, false);
                Span(walls, new Vector3(side * 7.5125f, 0f, 35.973f), Vector3.back, 12.92f, 7.96f, glow, false);
            }
        }

        private static void Span(Transform walls, Vector3 foot, Vector3 inward, float width, float height,
            Material glow, bool bigRisers)
        {
            if (width <= 0f || height < 1f) throw new ArgumentException("Wall span dimensions must be positive.");
            var root = Node(walls, $"Bulkhead {walls.childCount + 1}", foot);
            root.localRotation = Quaternion.LookRotation(-inward);
            var casing = Metal("Casing indigo", new Color(0.128f, 0.172f, 0.255f), 0.52f, 0.55f);
            var inset = Metal("Casing recess", new Color(0.053f, 0.076f, 0.117f), 0.33f, 0.47f);
            var alloy = Metal("Coolant titanium", new Color(0.26f, 0.34f, 0.44f), 0.71f, 0.60f);
            var collar = Metal("Coolant copper collars", new Color(0.43f, 0.24f, 0.10f), 0.54f, 0.62f);

            Skin(root, "Sealed backing", new Vector3(0f, height * 0.5f, -0.029f),
                new Vector3(width, height - 0.018f, 0.075f), inset);
            Skin(root, "Lower mounting keel", new Vector3(0f, 0.16f, -0.10f),
                new Vector3(width, 0.28f, 0.13f), casing);
            Skin(root, "Upper crown rail", new Vector3(0f, height - 0.17f, -0.119f),
                new Vector3(width, 0.31f, 0.19f), casing);

            var count = Mathf.CeilToInt(width / 4.15f);
            var bay = width / count;
            for (var i = 0; i < count; i++)
            {
                var x = -width * 0.5f + (i + 0.5f) * bay;
                var panel = Node(root, "Full height service panel", new Vector3(x, 0, 0));
                Skin(panel, "Panel plate", new Vector3(0f, height * 0.51f, -0.084f),
                    new Vector3(bay - 0.052f, height * 0.915f, 0.105f), casing);
                Skin(panel, "Panel recessed access line", new Vector3(0f, height * 0.49f, -0.14f),
                    new Vector3(bay - 0.29f, 0.09f, 0.035f), inset);
                Skin(panel, "Vertical interlocking frame", new Vector3(-bay * 0.5f + 0.105f, height * 0.50f, -0.171f),
                    new Vector3(0.155f, height * 0.93f, 0.115f), alloy);

                if (bay < 1.45f) continue;
                var ventCenter = new Vector3(0f, height * 0.785f, -0.165f);
                Skin(panel, "Mounted air return plenum", ventCenter, new Vector3(bay - 0.49f, height * 0.24f, 0.135f), inset);
                for (var vent = 0; vent < 5; vent++)
                {
                    var offset = (vent - 2) * height * 0.036f;
                    Skin(panel, "Recessed louvre", ventCenter + new Vector3(0, offset, -0.08f),
                        new Vector3(bay - 0.62f, 0.062f, 0.095f), alloy).localRotation = Quaternion.Euler(26f, 0f, 0f);
                }
                if (i % 2 == 0)
                    Skin(panel, "Service continuity light", new Vector3(bay * 0.31f, height * 0.66f, -0.249f),
                        new Vector3(0.39f, 0.055f, 0.029f), glow);
            }

            if (width < 4.2f || height < 4.9f) return;
            var upper = height - 0.66f;
            var first = -width * 0.5f + (bigRisers ? 0.90f : 0.22f);
            var end = width * 0.5f - (bigRisers ? 0.90f : 0.22f);
            Header(root, "Primary coolant manifold", first, end, upper, -0.58f, 0.51f, alloy, collar, bigRisers);
            Header(root, "Coolant return manifold", first + 0.24f, end - 0.24f, upper - 0.61f, -0.423f, 0.276f,
                alloy, collar, bigRisers);
        }

        private static void Header(Transform root, string name, float start, float end, float y, float z,
            float diameter, Material alloy, Material collar, bool risers)
        {
            var pipes = Node(root, name, Vector3.zero);
            var elbowSize = diameter * 1.08f;
            var startTube = new Vector3(start, y, z);
            var endTube = new Vector3(end, y, z);
            Tube(pipes, "Seamless header", startTube, endTube, diameter, alloy);
            for (var x = start + 0.40f; x < end - 0.20f; x += 2.96f)
            {
                Tube(pipes, "Circumferential clamp", new Vector3(x - 0.107f, y, z), new Vector3(x + 0.107f, y, z),
                    diameter * 1.29f, collar);
                Skin(pipes, "Header anchor to panel", new Vector3(x, y, z * 0.48f),
                    new Vector3(0.23f, diameter * 0.74f, -z * 0.99f), alloy);
            }

            if (!risers) return;
            foreach (var sign in new[] { -1f, 1f })
            {
                var elbow = Node(pipes, "Curved forged branch", sign < 0 ? startTube : endTube);
                elbow.localScale = Vector3.one * elbowSize;
                if (sign < 0f) elbow.localRotation = Quaternion.Euler(0f, 180f, 0f);
                var mesh = elbow.gameObject.AddComponent<MeshFilter>();
                mesh.sharedMesh = ElbowMesh();
                var renderer = elbow.gameObject.AddComponent<MeshRenderer>();
                renderer.sharedMaterial = alloy;
                renderer.shadowCastingMode = ShadowCastingMode.Off;
                var top = elbow.localPosition + new Vector3(sign * elbowSize, -elbowSize, 0f);
                var bottom = new Vector3(top.x, diameter < 0.4f ? 0.87f : 0.26f, top.z);
                Tube(pipes, "Full height downcomer", bottom, top, diameter, alloy);
                for (var height = bottom.y + 0.26f; height < top.y - 0.17f; height += 1.29f)
                {
                    Tube(pipes, "Forged flange", new Vector3(top.x, height - 0.08f, z), new Vector3(top.x, height + 0.08f, z),
                        diameter * 1.41f, collar);
                    Skin(pipes, "Downcomer anchor bracket", new Vector3(top.x, height, z * 0.53f),
                        new Vector3(0.24f, 0.18f, -z * 1.00f), alloy);
                }
            }
        }

        private static Mesh ElbowMesh()
        {
            const string path = Folder + "Forged quarter turn.asset";
            var saved = AssetDatabase.LoadAssetAtPath<Mesh>(path);
            if (saved != null) return saved;

            const int bends = 14;
            const int sections = 24;
            const float radius = 0.5f / 1.08f;
            var points = new Vector3[(bends + 1) * (sections + 1)];
            var normals = new Vector3[points.Length];
            var triangles = new int[bends * sections * 6];
            var index = 0;
            for (var bend = 0; bend <= bends; bend++)
            {
                var t = bend * (Mathf.PI * 0.5f / bends);
                var radial = new Vector3(Mathf.Sin(t), Mathf.Cos(t), 0f);
                var axis = radial - Vector3.up;
                for (var section = 0; section <= sections; section++)
                {
                    var s = section * (2f * Mathf.PI / sections);
                    var vertex = bend * (sections + 1) + section;
                    normals[vertex] = Mathf.Cos(s) * radial + Mathf.Sin(s) * Vector3.forward;
                    points[vertex] = axis + normals[vertex] * radius;
                    if (bend == bends || section == sections) continue;
                    var next = vertex + sections + 1;
                    triangles[index++] = vertex;
                    triangles[index++] = next + 1;
                    triangles[index++] = next;
                    triangles[index++] = vertex;
                    triangles[index++] = vertex + 1;
                    triangles[index++] = next + 1;
                }
            }
            var mesh = new Mesh { name = "Forged quarter turn", vertices = points, normals = normals, triangles = triangles };
            mesh.RecalculateBounds();
            AssetDatabase.CreateAsset(mesh, path);
            AssetDatabase.SaveAssetIfDirty(mesh);
            return mesh;
        }

        private static Transform Skin(Transform owner, string name, Vector3 center, Vector3 size, Material material)
        {
            var item = Block(owner, name, center, size, material);
            UnityEngine.Object.DestroyImmediate(item.GetComponent<Collider>());
            item.GetComponent<MeshRenderer>().shadowCastingMode = ShadowCastingMode.Off;
            return item;
        }

        private static void Tube(Transform owner, string name, Vector3 start, Vector3 end, float diameter, Material material)
        {
            var tube = GameObject.CreatePrimitive(PrimitiveType.Cylinder).transform;
            tube.name = name;
            tube.SetParent(owner, false);
            tube.localPosition = (start + end) * 0.5f;
            tube.localRotation = Quaternion.FromToRotation(Vector3.up, end - start);
            tube.localScale = new Vector3(diameter, Vector3.Distance(start, end) * 0.5f, diameter);
            tube.GetComponent<MeshRenderer>().sharedMaterial = material;
            tube.GetComponent<MeshRenderer>().shadowCastingMode = ShadowCastingMode.Off;
            UnityEngine.Object.DestroyImmediate(tube.GetComponent<Collider>());
        }

        private static Material Metal(string name, Color color, float metallic, float smoothness)
        {
            var path = Folder + name + ".mat";
            var material = AssetDatabase.LoadAssetAtPath<Material>(path);
            if (material != null) return material;
            material = new Material(Shader.Find("Universal Render Pipeline/Lit"));
            material.SetColor("_BaseColor", color);
            material.SetFloat("_Metallic", metallic);
            material.SetFloat("_Smoothness", smoothness);
            AssetDatabase.CreateAsset(material, path);
            AssetDatabase.SaveAssetIfDirty(material);
            return material;
        }
    }
}
