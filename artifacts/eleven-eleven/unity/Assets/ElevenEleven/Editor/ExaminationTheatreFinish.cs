using System;
using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using static ElevenEleven.Editor.GodotRoomAssembly;

namespace ElevenEleven.Editor
{
    internal static class ExaminationTheatreFinish
    {
        private const string ScenePath = "Assets/ElevenEleven/Scenes/ChapterRoom01.unity";
        private const string Materials = "Assets/ElevenEleven/Opening/Stormworks/";
        private const string FinishRoot = "Examination architectural finish";
        private static readonly Color Violet = new Color(0.49f, 0.35f, 0.78f);
        private static readonly Color Aqua = new Color(0.28f, 0.72f, 0.73f);

        [MenuItem("11.11/Apply Examination Theatre Finish")]
        public static void Upgrade()
        {
            if (!Application.isBatchMode && !EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo()) return;
            var scene = EditorSceneManager.OpenScene(ScenePath);
            var station = scene.GetRootGameObjects().Single(root => root.name == "Room content").transform.Find("Echo Station");
            var room = Find(station, "Kinja examination theatre");
            Dress(room, room.Find("Godot examination architecture"));
            if (!EditorSceneManager.SaveScene(scene)) throw new InvalidOperationException("Examination finish could not be saved.");
            Debug.Log("ECHO_EXAMINATION_FINISH_SAVED");
        }

        public static void UpgradeAndReview()
        {
            Upgrade();
            StormworksSmoke.Run();
        }

        internal static void Dress(Transform room, Transform architecture)
        {
            var previous = room.Find(FinishRoot);
            if (previous != null) UnityEngine.Object.DestroyImmediate(previous.gameObject);
            var finish = Node(room, FinishRoot, Vector3.zero);
            var graphite = Surface("Examination graphite housing", new Color(0.085f, 0.105f, 0.115f), 0.35f, 0.33f);
            var steel = Surface("Examination brushed hardware", new Color(0.32f, 0.36f, 0.35f), 0.52f, 0.46f);
            var ivory = Surface("Examination chalk enamel", new Color(0.68f, 0.66f, 0.57f), 0.04f, 0.42f);
            var signal = Surface("Examination controlled-area enamel", new Color(0.61f, 0.34f, 0.11f), 0.04f, 0.29f);
            var warm = Surface("Examination warm diffuser", new Color(0.96f, 0.86f, 0.69f), 0.0f, 0.37f, 0.85f);
            var jade = Surface("Examination aqua indicator", Aqua, 0.0f, 0.38f, 0.85f);
            var lilac = Surface("Examination violet indicator", Violet, 0.0f, 0.38f, 0.85f);

            var deck = StormworksConstruction.PersistentMaterial("Examination ceramic deck", "StormworksSurface.shader");
            deck.SetColor("_BaseColor", new Color(0.22f, 0.25f, 0.26f));
            deck.SetColor("_ShadowTone", new Color(0.17f, 0.19f, 0.21f));
            deck.SetFloat("_Wetness", 0.15f);
            deck.SetFloat("_ExaminationDetail", 1f);
            deck.EnableKeyword("_EXAMINATION_DETAIL");
            Save(deck);
            foreach (var panel in room.Find("Examination platform deck").GetComponentsInChildren<MeshRenderer>())
                panel.receiveShadows = true;

            FinishVitrine(room, architecture, "ClinicalVitrineGlass", "_MeshInstance3D_653");
            FinishVitrine(room, architecture, "_MeshInstance3D_689", "_MeshInstance3D_654");

            foreach (var side in new[] { -1f, 1f })
            {
                var marker = side < 0 ? lilac : jade;
                BuildServiceRibs(finish, graphite, steel, marker, side);
                Box(finish, "Dais edge rail", steel, new Vector3(side * 5.96f, 1.18f, 19.8f), new Vector3(0.09f, 0.08f, 11.5f));
                Box(finish, "Dais casing", graphite, new Vector3(side * 5.99f, 1.06f, 19.8f), new Vector3(0.11f, 0.22f, 11.5f));
                for (var segment = 0; segment < 5; segment++)
                    Box(finish, "Dais channel marker", marker, new Vector3(side * 5.935f, 1.218f, 15.9f + segment * 2.0f),
                        new Vector3(0.034f, 0.018f, 0.68f));

                Box(finish, "Overhead tool rail", graphite, new Vector3(side * 2.9f, 6.46f, 19.9f), new Vector3(0.34f, 0.28f, 6.2f));
                Box(finish, "Tool rail inset diffuser", warm, new Vector3(side * 2.9f, 6.306f, 19.9f), new Vector3(0.16f, 0.024f, 4.9f));
                foreach (var depth in new[] { 17.7f, 22.1f })
                {
                    Box(finish, "Suspended rail hanger", steel, new Vector3(side * 2.9f, 7.95f, depth), new Vector3(0.11f, 2.85f, 0.11f));
                    Box(finish, "Rail service bracket", graphite, new Vector3(side * 2.9f, 6.55f, depth), new Vector3(0.57f, 0.36f, 0.24f));
                }
            }
            foreach (var side in new[] { -1f, 1f })
                MarkArea(finish, ivory, signal, side);

            // Light the chair from the scanner rail. Where the existing lights already
            // serve interaction cues, retain them and only shape their falloff and color.
            SetSpot(room.Find("Neural rig key").GetComponent<Light>(), new Vector3(2.31f, 5.36f, 17.8f),
                new Vector3(-0.30f, 1.66f, 19.92f), new Color(1f, 0.91f, 0.76f), 24.5f, 10.2f, 60f, true);
            SetSpot(room.Find("Kinja key").GetComponent<Light>(), new Vector3(-2.84f, 4.55f, 17.20f),
                new Vector3(-2.18f, 1.89f, 19.54f), new Color(1f, 0.83f, 0.69f), 6.8f, 7.0f, 61f);
            SetSpot(room.Find("Theatre bounce").GetComponent<Light>(), new Vector3(-4.92f, 6.5f, 23.5f),
                new Vector3(-1.0f, 1.82f, 19.0f), new Color(0.57f, 0.75f, 1f), 7.7f, 12.8f, 79f);
            SetSpot(room.Find("Lab threshold key").GetComponent<Light>(), new Vector3(0f, 4.65f, 4.25f),
                new Vector3(0f, 0.15f, 8.5f), new Color(0.36f, 0.71f, 0.73f), 7.6f, 13.4f, 73f);
            room.Find("Altar approach lighting").GetComponent<Light>().intensity = 4.8f;
            var wallWash = Node(finish, "Observation wall wash", Vector3.zero).gameObject.AddComponent<Light>();
            SetSpot(wallWash, new Vector3(-7.2f, 6.6f, 35.0f), new Vector3(-5.8f, 2.9f, 39.5f),
                new Color(0.59f, 0.77f, 0.75f), 15.0f, 10.0f, 83f);
        }

        private static void FinishVitrine(Transform room, Transform architecture, string glassNode, string innerNode)
        {
            var window = Find(architecture, glassNode).GetComponent<MeshRenderer>();
            var medium = Find(architecture, innerNode).GetComponent<MeshRenderer>();
            var left = room.InverseTransformPoint(window.bounds.center).x < 0f;
            var side = left ? "left" : "right";
            var glass = StormworksConstruction.PersistentMaterial($"Examination {side} memory glass", "ContainmentOptics.shader");
            glass.SetFloat("_Mode", 0f);
            glass.SetColor("_Tint", left ? new Color(0.37f, 0.31f, 0.68f, 0.25f) : new Color(0.13f, 0.52f, 0.55f, 0.26f));
            Save(glass);
            window.sharedMaterial = glass;
            var carrier = StormworksConstruction.PersistentMaterial($"Examination {side} memory medium", "ContainmentOptics.shader");
            carrier.SetFloat("_Mode", 0f);
            carrier.SetColor("_Tint", left ? new Color(0.34f, 0.23f, 0.57f, 0.41f) : new Color(0.12f, 0.39f, 0.40f, 0.41f));
            Save(carrier);
            medium.sharedMaterial = carrier;
        }

        private static void BuildServiceRibs(Transform finish, Material housing, Material steel, Material marker, float side)
        {
            foreach (var depth in new[] { 12.8f, 24.8f, 36.8f })
            {
                Box(finish, "Wall utility post", housing, new Vector3(side * 15.30f, 4.93f, depth), new Vector3(0.43f, 8.18f, 0.50f));
                Box(finish, "Utility access spine", steel, new Vector3(side * 15.064f, 4.93f, depth), new Vector3(0.095f, 7.7f, 0.31f));
                Box(finish, "Utility check status", marker, new Vector3(side * 14.997f, 5.87f, depth), new Vector3(0.035f, 0.82f, 0.068f));
                Box(finish, "Utility foot guard", housing, new Vector3(side * 15.10f, 1.01f, depth), new Vector3(0.8f, 0.72f, 0.74f));
            }
            Box(finish, "Wall duct", housing, new Vector3(side * 15.19f, 7.65f, 24.5f), new Vector3(0.37f, 0.22f, 24.7f));
            for (var blade = 0; blade < 7; blade++)
                Box(finish, "Upper service grille louvre", steel, new Vector3(side * 14.96f, 7.64f, 30.4f + blade * 0.22f),
                    new Vector3(0.09f, 0.13f, 0.10f));
        }

        private static void MarkArea(Transform finish, Material enamel, Material amber, float side)
        {
            const float markerY = 1.224f;
            foreach (var depth in new[] { 17.15f, 22.55f })
            {
                Box(finish, "Chair clearance long mark", enamel, new Vector3(side * 1.66f, markerY, depth),
                    new Vector3(0.06f, 0.008f, 0.62f));
                Box(finish, "Chair clearance end mark", enamel, new Vector3(side * 1.47f, markerY, depth < 20f ? depth - 0.28f : depth + 0.28f),
                    new Vector3(0.42f, 0.008f, 0.06f));
            }
            for (var mark = 0; mark < 3; mark++)
            {
                var stripe = Box(finish, "Platform corner warning", amber, new Vector3(side * (5.2f + mark * 0.21f), markerY, 14.22f),
                    new Vector3(0.07f, 0.008f, 0.34f));
                stripe.localRotation = Quaternion.Euler(0f, -35f * side, 0f);
            }
        }

        private static void SetSpot(Light light, Vector3 origin, Vector3 target, Color tint, float intensity, float range, float angle, bool cast = false)
        {
            light.transform.localPosition = origin;
            light.transform.localRotation = Quaternion.LookRotation(target - origin);
            light.type = LightType.Spot;
            light.color = tint;
            light.intensity = intensity;
            light.range = range;
            light.spotAngle = angle;
            light.innerSpotAngle = angle * 0.67f;
            light.shadows = cast ? LightShadows.Soft : LightShadows.None;
            if (!cast) return;
            light.shadowStrength = 0.88f;
            light.shadowBias = 0.055f;
            light.shadowNormalBias = 0.26f;
        }

        private static Transform Box(Transform parent, string name, Material material, Vector3 position, Vector3 size)
        {
            var part = GameObject.CreatePrimitive(PrimitiveType.Cube);
            part.name = name;
            var transform = part.transform;
            transform.SetParent(parent, false);
            transform.localPosition = position;
            transform.localScale = size;
            var renderer = part.GetComponent<MeshRenderer>();
            renderer.sharedMaterial = material;
            renderer.shadowCastingMode = ShadowCastingMode.Off;
            UnityEngine.Object.DestroyImmediate(part.GetComponent<Collider>());
            return transform;
        }

        private static Material Surface(string name, Color tint, float metallic, float smoothness, float glow = 0f)
        {
            var path = Materials + name + ".mat";
            var material = AssetDatabase.LoadAssetAtPath<Material>(path);
            if (material == null)
            {
                material = new Material(Shader.Find("Universal Render Pipeline/Lit"));
                AssetDatabase.CreateAsset(material, path);
            }
            material.SetColor("_BaseColor", tint);
            material.SetFloat("_Metallic", metallic);
            material.SetFloat("_Smoothness", smoothness);
            if (glow > 0f)
            {
                material.EnableKeyword("_EMISSION");
                material.SetColor("_EmissionColor", tint * glow);
            }
            Save(material);
            return material;
        }

        private static void Save(Material material)
        {
            EditorUtility.SetDirty(material);
            AssetDatabase.SaveAssetIfDirty(material);
        }
    }
}
