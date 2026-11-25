using System;
using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

namespace ElevenEleven.Editor
{
    internal static class HospitalWardArt
    {
        private const string Scene = "Assets/ElevenEleven/Scenes/ChapterRoom01.unity";
        private const string Finishes = "Assets/ElevenEleven/Opening/Hospital/Finishes/";
        private const string Dressing = "Ward architectural finish";

        [MenuItem("11.11/Apply Ward Art and Dialogue Finish")]
        public static void Upgrade()
        {
            if (!Application.isBatchMode && !EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo()) return;
            var scene = EditorSceneManager.OpenScene(Scene);
            var content = scene.GetRootGameObjects().Single(root => root.name == "Room content").transform;
            var room = content.Find("Echo Station/Hospital transfer/Awakening ward");
            Dress(room);
            var hud = content.Find("Room 01 HUD");
            CinematicDialogueStyle.RefineHud(hud);
            if (!EditorSceneManager.SaveScene(scene)) throw new InvalidOperationException("Could not save the ward art pass.");
            Debug.Log("ECHO_WARD_ART_SCENE_SAVED");
        }

        public static void UpgradeAndReview()
        {
            Upgrade();
            StormworksSmoke.Run();
        }

        internal static void Dress(Transform room)
        {
            var prior = room.Find(Dressing);
            if (prior != null) UnityEngine.Object.DestroyImmediate(prior.gameObject);
            var art = GodotRoomAssembly.Node(room, Dressing, Vector3.zero);

            var vinyl = Surface("Ward mottled vinyl", new Color(0.60f, 0.72f, 0.72f), 0.0f, 0.46f, "MottledVinyl", new Vector2(8, 8));
            var enamel = Surface("Ward eggshell enamel", new Color(0.82f, 0.85f, 0.79f), 0.0f, 0.34f, "OrangePeelEnamel", new Vector2(5, 3));
            var dado = Surface("Ward green enamel", new Color(0.25f, 0.42f, 0.43f), 0.02f, 0.41f, "OrangePeelEnamel", new Vector2(4, 2));
            var rubber = Surface("Ward graphite rubber", new Color(0.087f, 0.126f, 0.137f), 0.03f, 0.32f);
            var steel = Surface("Ward satin steel", new Color(0.39f, 0.48f, 0.48f), 0.48f, 0.47f);
            var warm = Indicator("Ward amber signal", new Color(0.80f, 0.34f, 0.09f), 2.1f);
            var pearl = Indicator("Ward luminaire diffuser", new Color(0.83f, 0.91f, 0.91f), 0.65f);

            room.Find("Ward floor").GetComponent<MeshRenderer>().sharedMaterial = vinyl;
            foreach (var name in new[] { "Headwall", "Vanity wall", "Ward exit wall", "Window lintel", "Window sill",
                                         "Window left pier", "Window right pier", "Vanity counter" })
                room.Find(name).GetComponent<MeshRenderer>().sharedMaterial = enamel;

            foreach (var side in new[] { -1, 1 })
            {
                Trim(art, "Wall protection panels", dado, new Vector3(side * 3.097f, 0.47f, 0), new Vector3(0.045f, 0.94f, 5.63f));
                if (side > 0)
                    Trim(art, "Rounded wall guard", steel, new Vector3(3.061f, 0.965f, 0), new Vector3(0.057f, 0.06f, 5.62f));
                else
                    foreach (var section in new[] { -1.90f, 1.90f })
                        Trim(art, "Bedside wall guard", steel, new Vector3(-3.061f, 0.965f, section), new Vector3(0.057f, 0.06f, 1.75f));
                Trim(art, "Coved floor edge", rubber, new Vector3(side * 3.070f, 0.064f, 0), new Vector3(0.075f, 0.125f, 5.65f));
                Trim(art, "Vinyl threshold inlay", rubber, new Vector3(side * 2.99f, 0.001f, 0), new Vector3(0.046f, 0.004f, 5.60f));
                Trim(art, "Window jamb", steel, new Vector3(side * 1.40f, 1.854f, -2.79f), new Vector3(0.068f, 1.86f, 0.13f));
                Trim(art, "Privacy rail mount", steel, new Vector3(side * 1.68f, 3.06f, -2.51f), new Vector3(0.04f, 0.21f, 0.05f));
            }

            Trim(art, "Window lower reveal", steel, new Vector3(0f, 0.952f, -2.76f), new Vector3(2.88f, 0.067f, 0.23f));
            Trim(art, "Window upper reveal", rubber, new Vector3(0f, 2.751f, -2.81f), new Vector3(2.88f, 0.065f, 0.20f));
            Trim(art, "Privacy track", steel, new Vector3(0f, 2.96f, -2.51f), new Vector3(3.54f, 0.047f, 0.048f));
            Trim(art, "Window radiator case", rubber, new Vector3(0f, 0.49f, -2.749f), new Vector3(1.87f, 0.54f, 0.18f));
            for (var grille = 0; grille < 16; grille++)
                Trim(art, "Radiator louvre", steel, new Vector3((grille - 7.5f) * 0.11f, 0.493f, -2.651f), new Vector3(0.045f, 0.38f, 0.032f));

            var fabric = Surface("Ward privacy weave", new Color(0.38f, 0.52f, 0.48f), 0f, 0.19f);
            fabric.SetFloat("_Cull", 0f);
            EditorUtility.SetDirty(fabric);
            AssetDatabase.SaveAssetIfDirty(fabric);
            var curtains = room.Cast<Transform>().Where(item => item.name == "Pleated curtain").ToArray();
            for (var index = 0; index < curtains.Length; index++)
            {
                var curtain = curtains[index];
                var panels = curtain.GetComponentsInChildren<Renderer>();
                foreach (var panel in panels)
                {
                    panel.sharedMaterial = fabric;
                    panel.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.TwoSided;
                }
                var bounds = panels.Select(renderer => renderer.bounds).Aggregate((a, b) => { a.Encapsulate(b); return a; });
                var span = bounds.size;
                if (span.x < 0.001f || span.y < 0.001f) continue;
                curtain.localScale = Vector3.Scale(curtain.localScale, new Vector3(0.62f / span.x, 2.13f / span.y, 1f));
                var fit = curtain.GetComponentsInChildren<Renderer>().Select(renderer => renderer.bounds).Aggregate((a, b) => { a.Encapsulate(b); return a; });
                var center = room.TransformPoint(new Vector3(index == 0 ? -1.49f : 1.49f, 1.86f, -2.47f));
                curtain.position += center - fit.center;
            }

            Trim(art, "Vanity drawer frame", rubber, new Vector3(2.96f, 0.48f, -1f), new Vector3(0.32f, 0.55f, 1.40f));
            Trim(art, "Vanity powder-coated face", dado, new Vector3(2.791f, 0.48f, -1f), new Vector3(0.034f, 0.51f, 1.34f));
            Trim(art, "Vanity recessed hardware", steel, new Vector3(2.764f, 0.63f, -1f), new Vector3(0.035f, 0.042f, 0.32f));
            Trim(art, "Vanity upper light housing", rubber, new Vector3(2.98f, 2.40f, -1f), new Vector3(0.24f, 0.103f, 1.30f));
            Trim(art, "Vanity upper diffuser", pearl, new Vector3(2.95f, 2.341f, -1f), new Vector3(0.17f, 0.024f, 1.10f));

            Trim(art, "Ward sealed door recess", rubber, new Vector3(0.58f, 1.18f, 2.799f), new Vector3(1.61f, 2.36f, 0.085f));
            Trim(art, "Ward sealed door skin", dado, new Vector3(0.58f, 1.142f, 2.747f), new Vector3(1.39f, 2.255f, 0.055f));
            Trim(art, "Door inset push plate", steel, new Vector3(0.98f, 1.09f, 2.704f), new Vector3(0.19f, 0.29f, 0.037f));
            Trim(art, "Door vision panel gasket", rubber, new Vector3(0.52f, 1.62f, 2.708f), new Vector3(0.39f, 0.55f, 0.050f));
            Trim(art, "Door obscured vision panel", steel, new Vector3(0.52f, 1.62f, 2.678f), new Vector3(0.31f, 0.47f, 0.024f));
            Trim(art, "Ward access reader", rubber, new Vector3(1.60f, 1.26f, 2.766f), new Vector3(0.23f, 0.30f, 0.097f));
            Trim(art, "Lock status light", warm, new Vector3(1.60f, 1.327f, 2.709f), new Vector3(0.11f, 0.025f, 0.014f));
            Trim(art, "Door crossing wear strip", steel, new Vector3(0.57f, 0.004f, 2.72f), new Vector3(1.62f, 0.007f, 0.13f));
            Trim(art, "Ceiling luminaire housing", rubber, new Vector3(0f, 3.14f, 0.10f), new Vector3(0.66f, 0.08f, 1.22f));
            Trim(art, "Ceiling luminaire inset", pearl, new Vector3(0f, 3.094f, 0.10f), new Vector3(0.50f, 0.025f, 1.04f));

            Spot(room.Find("Cold daylight").GetComponent<Light>(), new Vector3(-0.52f, 2.68f, -2.48f),
                new Vector3(0.56f, 0.52f, 0.73f), new Color(0.71f, 0.84f, 1f), 9.2f, 6.8f, 85f, true);
            Spot(room.Find("Ceiling bounce").GetComponent<Light>(), new Vector3(0f, 3.044f, 0.10f),
                new Vector3(-0.87f, 0.15f, 0.42f), new Color(1f, 0.91f, 0.73f), 3.1f, 5.2f, 112f, false);
            Spot(room.Find("Vanity fill").GetComponent<Light>(), new Vector3(2.76f, 2.29f, -0.88f),
                new Vector3(1.60f, 1.27f, -1.09f), new Color(0.87f, 0.94f, 1f), 1.85f, 3.15f, 79f, false);
            var signal = room.Find("EX-011 signal").GetComponent<Light>();
            signal.intensity = 0.31f;
            signal.range = 1.84f;
        }

        private static void Spot(Light light, Vector3 position, Vector3 target, Color tint, float intensity, float range, float angle, bool shadows)
        {
            light.transform.localPosition = position;
            light.transform.localRotation = Quaternion.LookRotation(target - position);
            light.type = LightType.Spot;
            light.color = tint;
            light.intensity = intensity;
            light.range = range;
            light.spotAngle = angle;
            light.innerSpotAngle = angle * 0.68f;
            light.shadows = shadows ? LightShadows.Soft : LightShadows.None;
            if (!shadows) return;
            light.shadowStrength = 0.86f;
            light.shadowBias = 0.065f;
            light.shadowNormalBias = 0.32f;
        }

        private static void Trim(Transform root, string name, Material material, Vector3 position, Vector3 dimensions)
        {
            var piece = GameObject.CreatePrimitive(PrimitiveType.Cube);
            piece.name = name;
            piece.transform.SetParent(root, false);
            piece.transform.localPosition = position;
            piece.transform.localScale = dimensions;
            piece.GetComponent<Renderer>().sharedMaterial = material;
            UnityEngine.Object.DestroyImmediate(piece.GetComponent<Collider>());
        }

        private static Material Surface(string name, Color tint, float metallic, float smoothness, string texture = null, Vector2 tile = default)
        {
            var path = Finishes + name + ".mat";
            var surface = AssetDatabase.LoadAssetAtPath<Material>(path);
            if (surface == null)
            {
                surface = new Material(Shader.Find("Universal Render Pipeline/Lit"));
                AssetDatabase.CreateAsset(surface, path);
            }
            surface.color = tint;
            surface.SetFloat("_Metallic", metallic);
            surface.SetFloat("_Smoothness", smoothness);
            if (texture != null)
            {
                var normalPath = Finishes + texture + "-Normal.png";
                var importer = (TextureImporter)AssetImporter.GetAtPath(normalPath);
                if (importer.textureType != TextureImporterType.NormalMap)
                {
                    importer.textureType = TextureImporterType.NormalMap;
                    importer.SaveAndReimport();
                }
                surface.SetTexture("_BaseMap", AssetDatabase.LoadAssetAtPath<Texture2D>(Finishes + texture + "-Base.png"));
                surface.SetTexture("_BumpMap", AssetDatabase.LoadAssetAtPath<Texture2D>(normalPath));
                surface.SetTextureScale("_BaseMap", tile);
                surface.SetFloat("_BumpScale", 0.85f);
                surface.EnableKeyword("_NORMALMAP");
            }
            EditorUtility.SetDirty(surface);
            AssetDatabase.SaveAssetIfDirty(surface);
            return surface;
        }

        private static Material Indicator(string name, Color tint, float glow)
        {
            var material = Surface(name, tint, 0f, 0.35f);
            material.SetColor("_EmissionColor", tint * glow);
            material.EnableKeyword("_EMISSION");
            EditorUtility.SetDirty(material);
            AssetDatabase.SaveAssetIfDirty(material);
            return material;
        }
    }
}
