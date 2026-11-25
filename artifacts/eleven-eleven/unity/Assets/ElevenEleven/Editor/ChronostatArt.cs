using System;
using System.Collections.Generic;
using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using static ElevenEleven.Editor.GodotRoomAssembly;

namespace ElevenEleven.Editor
{
    internal static class ChronostatArt
    {
        private const string Scene = "Assets/ElevenEleven/Scenes/ChapterRoom01.unity";
        private const string Materials = "Assets/ElevenEleven/Opening/Stormworks/StationFinishes/";
        private const string AssemblyRoot = "Chronostat machinery finish";
        private const float ClockY = 13.70f;
        private const float ClockZ = 82.2f;

        [MenuItem("11.11/Apply Chronostat Art")]
        public static void Upgrade()
        {
            if (!Application.isBatchMode && !EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo()) return;
            var scene = EditorSceneManager.OpenScene(Scene);
            var station = scene.GetRootGameObjects().Single(root => root.name == "Room content").transform.Find("Echo Station");
            Dress(station);
            if (!EditorSceneManager.SaveScene(scene)) throw new InvalidOperationException("Could not save the Chronostat art pass.");
            Debug.Log("ECHO_CHRONOSTAT_SAVED");
        }

        public static void UpgradeAndReview()
        {
            Upgrade();
            StormworksSmoke.Run();
        }

        internal static void Dress(Transform station)
        {
            var old = station.Find(AssemblyRoot);
            if (old != null) UnityEngine.Object.DestroyImmediate(old.gameObject);
            var root = Node(station, AssemblyRoot, Vector3.zero);
            var body = Material("Chronostat oxide-filled steel", new Color(0.27f, 0.33f, 0.33f), 0.52f, 0.39f, brushed: true);
            var lightMetal = Material("Chronostat machined channels", new Color(0.43f, 0.48f, 0.45f), 0.47f, 0.43f, brushed: true);
            var patina = Material("Chronostat copper hardware", new Color(0.42f, 0.255f, 0.12f), 0.42f, 0.38f, brushed: true);
            var dark = Material("Chronostat insulated joints", new Color(0.062f, 0.092f, 0.10f), 0.17f, 0.30f);
            var glass = Material("Chronostat dial enamel", new Color(0.067f, 0.134f, 0.158f), 0.21f, 0.48f);
            var aqua = Material("Chronostat telemetry lens", new Color(0.27f, 0.82f, 0.78f), 0.0f, 0.46f,
                new Color(0.23f, 0.94f, 0.85f) * 1.25f);
            var amber = Material("Chronostat calibration lens", new Color(0.85f, 0.49f, 0.20f), 0.0f, 0.35f,
                new Color(1.0f, 0.49f, 0.19f) * 0.62f);

            HideBlueprint(station);
            var structure = station.Find("Stormworks structural modules");
            StationStructureArt.Dress(root, structure, body, lightMetal, patina, dark, aqua, amber);
            StationReservoirArt.Dress(root, station, body, lightMetal, amber);
            BuildClock(root, station, body, lightMetal, patina, dark, glass, aqua, amber);
            BuildSupports(root, body, lightMetal, dark, aqua);
            BuildLiftCladding(root, station, body, lightMetal, patina, dark, amber);

            Spot(root, "Cold clock key", new Vector3(-8.3f, 22.6f, 64f), new Vector3(-3f, 14.6f, 82f),
                new Color(0.68f, 0.86f, 1.0f), 165f, 39f, 59f);
            Spot(root, "Warm clock rim", new Vector3(11.2f, 12.9f, 71.5f), new Vector3(4.2f, 14.0f, 82f),
                new Color(1.0f, 0.73f, 0.46f), 83f, 26f, 68f);
        }

        private static void HideBlueprint(Transform station)
        {
            foreach (Transform item in station)
            {
                if (item.name == "Tower clock face" || item.name == "Phase antenna rib" || item.name == "Phase antenna glass")
                    item.GetComponent<MeshRenderer>().enabled = false;
            }
            var previousRim = station.Find("Echo Station architectural finish");
            if (previousRim == null) return;
            foreach (Transform item in previousRim)
                if (item.name == "Chronostat segmented rim") item.GetComponent<MeshRenderer>().enabled = false;
        }

        private static void BuildClock(Transform parent, Transform station, Material body, Material metal, Material patina,
            Material dark, Material glass, Material aqua, Material amber)
        {
            var clock = Node(parent, "Radial clock assembly", new Vector3(0, ClockY, ClockZ));
            var disc = Piece(clock, "Inset clock body", PrimitiveType.Cylinder, dark, new Vector3(0, 0, -0.14f),
                new Vector3(15.25f, 0.55f, 15.25f));
            disc.localRotation = Quaternion.Euler(90f, 0, 0);
            var screen = Piece(clock, "Smoked instrument dial", PrimitiveType.Cylinder, glass, new Vector3(0, 0, -0.78f),
                new Vector3(14.5f, 0.10f, 14.5f));
            screen.localRotation = Quaternion.Euler(90f, 0, 0);
            Ring(clock, "Main pressure housing", body, 8.73f, 10.82f, -1.01f, 0.75f, 16, 12, 0.020f, 0.16f);
            Ring(clock, "Instrument face gasket", dark, 7.04f, 7.64f, -1.01f, -0.40f, 1, 96, 0f, 0.062f);
            Ring(clock, "Instrument bezel", metal, 7.61f, 7.85f, -1.13f, -0.60f, 12, 10, 0.039f, 0.039f);
            Ring(clock, "Inset lens channel", dark, 9.38f, 10.11f, -1.10f, -0.89f, 32, 5, 0.044f, 0.035f);
            Ring(clock, "Aquamarine annunciators", aqua, 9.63f, 9.86f, -1.18f, -1.07f, 32, 5, 0.27f, 0.025f, 1);
            Ring(clock, "Amber timing marks", amber, 9.63f, 9.86f, -1.20f, -1.07f, 32, 5, 0.23f, 0.025f, 2);
            Ring(clock, "Rim reinforcement rails", metal, 10.50f, 10.67f, -1.17f, -0.98f, 32, 4, 0.14f, 0.028f);
            Ring(clock, "Anodized retaining straps", patina, 8.86f, 9.24f, -1.09f, -0.93f, 16, 5, 0.63f, 0.032f);
            Ring(clock, "Machined face graduations", metal, 6.53f, 6.80f, -0.904f, -0.84f, 48, 3, 0.82f, 0.015f);
            Ring(clock, "Bezel registration marks", amber, 6.38f, 6.74f, -0.922f, -0.84f, 4, 3, 0.96f, 0.017f);

            foreach (var side in new[] { -1f, 1f })
            {
                Piece(clock, "Radial shock mount", PrimitiveType.Cube, patina, new Vector3(side * 8.35f, -3.7f, -0.83f),
                    new Vector3(1.18f, 0.84f, 0.59f)).localRotation = Quaternion.Euler(0, 0, side * 26f);
                Piece(clock, "Instrument status well", PrimitiveType.Cube, dark, new Vector3(side * 3.7f, -2.4f, -0.94f),
                    new Vector3(0.85f, 0.30f, 0.10f));
                Piece(clock, "Instrument status line", PrimitiveType.Cube, aqua, new Vector3(side * 3.70f, -2.4f, -1.006f),
                    new Vector3(0.56f, 0.055f, 0.027f));
            }
            var clockReadout = station.Cast<Transform>().Single(item => item.name == "Clock" && item.localPosition.z > 78f);
            clockReadout.localPosition = new Vector3(0, ClockY - 0.45f, ClockZ - 1.11f);
        }

        private static void BuildSupports(Transform root, Material body, Material trim, Material dark, Material lens)
        {
            foreach (var side in new[] { -1f, 1f })
            {
                var x = side * 8.7f;
                Piece(root, "Clock assembly lower bearing tower", PrimitiveType.Cube, body, new Vector3(x, 2.95f, 81.56f),
                    new Vector3(1.27f, 7.5f, 1.35f));
                Piece(root, "Clock support bolted bearing collar", PrimitiveType.Cube, trim, new Vector3(x, 5.7f, 81.43f),
                    new Vector3(1.88f, 0.54f, 1.62f));
                Piece(root, "Bearing base isolation stack", PrimitiveType.Cube, dark, new Vector3(x, 0.24f, 81.43f),
                    new Vector3(2.1f, 0.48f, 1.92f));
                Piece(root, "Clock support telemetry channel", PrimitiveType.Cube, lens, new Vector3(x, 3.96f, 80.854f),
                    new Vector3(0.108f, 1.61f, 0.035f));
            }
        }

        private static void BuildLiftCladding(Transform root, Transform station, Material body, Material trim, Material patina,
            Material dark, Material amber)
        {
            foreach (var column in station.Cast<Transform>().Where(item => item.name == "Distant buttress"))
                column.GetComponent<MeshRenderer>().sharedMaterial = body;
            foreach (var beam in station.Cast<Transform>().Where(item => item.name == "Suspended cable bridge"))
                beam.GetComponent<MeshRenderer>().sharedMaterial = body;
            var vents = AssetDatabase.LoadAssetAtPath<Mesh>(Materials + "Lift face louvers.asset");
            if (vents == null)
            {
                var cube = GameObject.CreatePrimitive(PrimitiveType.Cube);
                var mesh = cube.GetComponent<MeshFilter>().sharedMesh;
                vents = new Mesh { name = "Stamped lift equipment louvers" };
                var slats = new CombineInstance[9];
                for (var row = 0; row < slats.Length; row++)
                    slats[row] = new CombineInstance { mesh = mesh,
                        transform = Matrix4x4.TRS(new Vector3(0, (row - 4) * 0.18f, 0),
                            Quaternion.Euler(-22f, 0, 0), new Vector3(2.60f, 0.06f, 0.18f)) };
                vents.CombineMeshes(slats);
                UnityEngine.Object.DestroyImmediate(cube);
                AssetDatabase.CreateAsset(vents, Materials + "Lift face louvers.asset");
            }
            foreach (var block in station.Cast<Transform>().Where(item => item.name == "Lift machine housing"))
            {
                block.GetComponent<MeshRenderer>().sharedMaterial = body;
                var panel = Node(root, "Lift tower service fascia", block.localPosition - Vector3.forward * (block.localScale.z * 0.5f));
                Piece(panel, "Inset vent enclosure", PrimitiveType.Cube, dark, new Vector3(0, 0.03f, -0.10f),
                    new Vector3(4.62f, 2.91f, 0.18f));
                Attach(Node(panel, "Vented machine panel", new Vector3(-0.38f, 0.10f, -0.23f)), vents, trim);
                for (var side = -1; side <= 1; side += 2)
                    Piece(panel, "Door edge reinforcement", PrimitiveType.Cube, patina, new Vector3(side * 2.03f, 0, -0.23f),
                        new Vector3(0.081f, 2.30f, 0.06f));
                Piece(panel, "Service bay index light", PrimitiveType.Cube, amber, new Vector3(1.42f, -0.42f, -0.24f),
                    new Vector3(0.17f, 0.48f, 0.071f));
            }
        }

        private static void Ring(Transform parent, string name, Material material, float inner, float outer, float front, float back,
            int sections, int steps, float gap, float bevel, int filter = 0)
        {
            var path = Materials + name + ".asset";
            var mesh = AssetDatabase.LoadAssetAtPath<Mesh>(path);
            if (mesh == null)
            {
                mesh = BuildRing(name, inner, outer, front, back, sections, steps, gap, bevel, filter);
                AssetDatabase.CreateAsset(mesh, path);
            }
            Attach(Node(parent, name, Vector3.zero), mesh, material);
        }

        private static Mesh BuildRing(string name, float inner, float outer, float front, float back,
            int sections, int steps, float gap, float bevel, int filter)
        {
            var vertices = new List<Vector3>();
            var uv = new List<Vector2>();
            var triangles = new List<int>();
            var profile = new[] {
                new Vector2(inner + bevel, front), new Vector2(outer - bevel, front),
                new Vector2(outer, front + bevel), new Vector2(outer, back - bevel),
                new Vector2(outer - bevel, back), new Vector2(inner + bevel, back),
                new Vector2(inner, back - bevel), new Vector2(inner, front + bevel)
            };
            var fullAngle = 2f * Mathf.PI / sections;
            for (var section = 0; section < sections; section++)
            {
                var quarter = section % 8 == 0;
                if ((filter == 1 && quarter) || (filter == 2 && !quarter)) continue;
                var start = vertices.Count;
                for (var step = 0; step <= steps; step++)
                {
                    var part = Mathf.Lerp(gap * 0.5f, 1f - gap * 0.5f, (float)step / steps);
                    var angle = fullAngle * (section + part);
                    var direction = new Vector2(Mathf.Cos(angle), Mathf.Sin(angle));
                    for (var side = 0; side < profile.Length; side++)
                    {
                        var point = profile[side];
                        vertices.Add(new Vector3(direction.x * point.x, direction.y * point.x, point.y));
                        uv.Add(new Vector2((section + part) * 0.5f, side * 0.19f));
                    }
                }

                for (var step = 0; step < steps; step++)
                for (var side = 0; side < profile.Length; side++)
                {
                    var row = start + step * profile.Length;
                    var after = (side + 1) % profile.Length;
                    triangles.Add(row + side);
                    triangles.Add(row + profile.Length + side);
                    triangles.Add(row + after);
                    triangles.Add(row + after);
                    triangles.Add(row + profile.Length + side);
                    triangles.Add(row + profile.Length + after);
                }
                if (gap <= 0f && sections == 1) continue;
                var end = start + steps * profile.Length;
                for (var side = 1; side < profile.Length - 1; side++)
                {
                    triangles.Add(start);
                    triangles.Add(start + side);
                    triangles.Add(start + side + 1);
                    triangles.Add(end);
                    triangles.Add(end + side + 1);
                    triangles.Add(end + side);
                }
            }
            var mesh = new Mesh { name = name };
            mesh.SetVertices(vertices);
            mesh.SetUVs(0, uv);
            mesh.SetTriangles(triangles, 0);
            mesh.RecalculateNormals();
            mesh.RecalculateTangents();
            mesh.RecalculateBounds();
            return mesh;
        }

        private static Transform Piece(Transform parent, string name, PrimitiveType type, Material material, Vector3 at, Vector3 size)
        {
            var piece = GameObject.CreatePrimitive(type);
            piece.name = name;
            piece.transform.SetParent(parent, false);
            piece.transform.localPosition = at;
            piece.transform.localScale = size;
            var renderer = piece.GetComponent<MeshRenderer>();
            renderer.sharedMaterial = material;
            renderer.shadowCastingMode = ShadowCastingMode.Off;
            UnityEngine.Object.DestroyImmediate(piece.GetComponent<Collider>());
            return piece.transform;
        }

        private static void Attach(Transform root, Mesh mesh, Material material)
        {
            root.gameObject.AddComponent<MeshFilter>().sharedMesh = mesh;
            var renderer = root.gameObject.AddComponent<MeshRenderer>();
            renderer.sharedMaterial = material;
            renderer.shadowCastingMode = ShadowCastingMode.Off;
        }

        private static void Spot(Transform parent, string name, Vector3 origin, Vector3 target, Color color,
            float intensity, float range, float angle)
        {
            var source = Node(parent, name, origin);
            source.localRotation = Quaternion.LookRotation(target - origin);
            var light = source.gameObject.AddComponent<Light>();
            light.type = LightType.Spot;
            light.color = color;
            light.intensity = intensity;
            light.range = range;
            light.spotAngle = angle;
            light.innerSpotAngle = angle * 0.7f;
        }

        private static Material Material(string name, Color color, float metallic, float smoothness,
            Color emission = default, bool brushed = false)
        {
            var path = Materials + name + ".mat";
            var material = AssetDatabase.LoadAssetAtPath<Material>(path);
            if (material == null)
            {
                material = new Material(Shader.Find("Universal Render Pipeline/Lit"));
                AssetDatabase.CreateAsset(material, path);
            }
            material.SetColor("_BaseColor", color);
            material.SetFloat("_Metallic", metallic);
            material.SetFloat("_Smoothness", smoothness);
            if (emission.maxColorComponent > 0f)
            {
                material.SetColor("_EmissionColor", emission);
                material.EnableKeyword("_EMISSION");
            }
            if (brushed)
            {
                material.SetTexture("_BaseMap", AssetDatabase.LoadAssetAtPath<Texture2D>(Materials + "Station-BrushedSteel-Base.png"));
                material.SetTexture("_BumpMap", AssetDatabase.LoadAssetAtPath<Texture2D>(Materials + "Station-BrushedSteel-Normal.png"));
                material.SetFloat("_BumpScale", 0.71f);
                material.EnableKeyword("_NORMALMAP");
            }
            EditorUtility.SetDirty(material);
            AssetDatabase.SaveAssetIfDirty(material);
            return material;
        }
    }
}
