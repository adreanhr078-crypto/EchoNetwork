using System.IO;
using System.Linq;
using ElevenEleven.Opening;
using UnityEditor;
using UnityEditor.Events;
using UnityEngine;
using UnityEngine.UI;
using UnityEngine.Video;
using static ElevenEleven.Editor.GodotRoomAssembly;
using static ElevenEleven.Editor.OpeningReviewSceneBuilder;
using static ElevenEleven.Editor.StormworksConstruction;

namespace ElevenEleven.Editor
{
    internal static class HospitalWardConstruction
    {
        private const string Folder = "Assets/ElevenEleven/Opening/Hospital/";

        internal static StationHospitalWard Build(Transform station, Transform hud, Font font, Room01Player player)
        {
            var root = Node(station, "Hospital transfer", new Vector3(95f, 0f, 300f));
            var room = Node(root, "Awakening ward", Vector3.zero);
            var plaster = Material("Ward plaster", new Color(0.70f, 0.73f, 0.71f), 0.24f);
            var floor = Material("Ward linoleum", new Color(0.36f, 0.43f, 0.45f), 0.56f);
            var sill = Material("Ward frame", new Color(0.31f, 0.36f, 0.37f), 0.48f);
            var light = Material("Ward practical", new Color(0.92f, 0.91f, 0.78f), 0.24f);
            light.EnableKeyword("_EMISSION");
            light.SetColor("_EmissionColor", new Color(0.39f, 0.40f, 0.31f));
            EditorUtility.SetDirty(light);
            AssetDatabase.SaveAssetIfDirty(light);
            Slab(room, "Ward floor", floor, new Vector3(0, -0.08f, 0), new Vector3(6.4f, 0.16f, 5.8f));
            Slab(room, "Ward ceiling", plaster, new Vector3(0, 3.28f, 0), new Vector3(6.4f, 0.16f, 5.8f));
            Slab(room, "Headwall", plaster, new Vector3(-3.2f, 1.60f, 0), new Vector3(0.16f, 3.2f, 5.8f));
            Slab(room, "Vanity wall", plaster, new Vector3(3.2f, 1.60f, 0), new Vector3(0.16f, 3.2f, 5.8f));
            Slab(room, "Ward exit wall", plaster, new Vector3(0, 1.60f, 2.9f), new Vector3(6.4f, 3.2f, 0.16f));
            Slab(room, "Window sill", plaster, new Vector3(0, 0.475f, -2.90f), new Vector3(6.4f, 0.95f, 0.16f));
            Slab(room, "Window lintel", plaster, new Vector3(0, 2.975f, -2.90f), new Vector3(6.4f, 0.45f, 0.16f));
            Slab(room, "Window left pier", plaster, new Vector3(-2.30f, 1.85f, -2.90f), new Vector3(1.8f, 1.8f, 0.16f));
            Slab(room, "Window right pier", plaster, new Vector3(2.30f, 1.85f, -2.90f), new Vector3(1.8f, 1.8f, 0.16f));
            var outside = Material("Ward exterior", new Color(0.88f, 0.94f, 1f), 0f);
            outside.shader = Shader.Find("Universal Render Pipeline/Unlit");
            outside.mainTexture = Load<Texture2D>("WardExterior.png");
            EditorUtility.SetDirty(outside);
            AssetDatabase.SaveAssetIfDirty(outside);
            Slab(room, "Ward sealed window", outside, new Vector3(0, 1.85f, -2.945f), new Vector3(2.82f, 1.85f, 0.06f));
            Slab(room, "Window centre mullion", sill, new Vector3(0, 1.85f, -2.90f), new Vector3(0.035f, 1.85f, 0.10f));
            Slab(room, "Ceiling practical", light, new Vector3(0, 3.175f, 0.10f), new Vector3(0.56f, 0.024f, 1.1f));
            for (var index = 0; index < 2; index++)
            {
                var curtain = PlaceArt(room, Folder + "WardCurtain.glb", "Pleated curtain");
                curtain.localPosition = new Vector3(index == 0 ? -1.67f : 1.67f, 0.96f, -2.70f);
            }

            var bed = PlaceArt(room, Folder + "WardBed.glb", "Measured hospital bed");
            var bedBounds = Bounds(bed);
            if (bedBounds.size.z > bedBounds.size.x) bed.Rotate(0f, 90f, 0f, Space.World);
            bed.localScale *= 2.2f / Bounds(bed).size.x;
            bedBounds = Bounds(bed);
            var bedSpot = room.TransformPoint(new Vector3(-1.10f, 0f, 0f));
            bed.position += bedSpot - new Vector3(bedBounds.center.x, bedBounds.min.y, bedBounds.center.z);
            var bedFootprint = Node(room, "Bed collision", new Vector3(-1.10f, 0.36f, 0f)).gameObject.AddComponent<BoxCollider>();
            bedFootprint.size = new Vector3(2.19f, 0.72f, 1.03f);
            var headwall = PlaceArt(room, Folder + "WardHeadwall.glb", "Measured headwall service panel");
            headwall.localPosition = new Vector3(-3.10f, 0.4f, -0.1f);
            headwall.localRotation = Quaternion.Euler(0f, 90f, 0f);
            Slab(room, "Vanity counter", plaster, new Vector3(2.86f, 0.82f, -1.0f), new Vector3(0.50f, 0.12f, 1.47f));
            Slab(room, "Vanity mirror backing", sill, new Vector3(3.08f, 1.54f, -1.0f), new Vector3(0.05f, 1.62f, 1.14f));
            var mirror = GameObject.CreatePrimitive(PrimitiveType.Quad);
            mirror.name = "Hospital live mirror";
            mirror.transform.SetParent(room, false);
            mirror.transform.localPosition = new Vector3(3.045f, 1.54f, -1.0f);
            mirror.transform.localRotation = Quaternion.Euler(0f, 90f, 0f);
            mirror.transform.localScale = new Vector3(1.06f, 1.52f, 1f);
            Object.DestroyImmediate(mirror.GetComponent<Collider>());
            var renderer = mirror.GetComponent<MeshRenderer>();
            var mirrorMaterial = PersistentMaterial("Hospital silver mirror", "StationReflection.shader");
            mirrorMaterial.SetColor("_Reflectance", new Color(0.96f, 0.98f, 1f));
            mirrorMaterial.SetColor("_BaseTint", new Color(0.008f, 0.012f, 0.018f));
            mirrorMaterial.SetColor("_RimColor", new Color(0.10f, 0.14f, 0.18f));
            EditorUtility.SetDirty(mirrorMaterial);
            AssetDatabase.SaveAssetIfDirty(mirrorMaterial);
            renderer.sharedMaterial = mirrorMaterial;
            var reflector = mirror.AddComponent<StationReflection>();
            var variant = WardMirageArt.Build(room, player.transform.Find("Pact72 facing"));
            Wire(reflector, ("surface", renderer), ("alternateAvatar", variant),
                ("liveAvatar", player.transform.Find("School65 facing")));
            var reflectionSettings = new SerializedObject(reflector);
            reflectionSettings.FindProperty("horizontalPixels").intValue = 1024;
            reflectionSettings.ApplyModifiedPropertiesWithoutUndo();
            Practical(room, "Cold daylight", new Vector3(-0.24f, 2.3f, -2.24f), new Color(0.63f, 0.80f, 1f), 12f, 7.5f);
            Practical(room, "Ceiling bounce", new Vector3(0, 2.85f, 0.54f), new Color(1f, 0.91f, 0.73f), 9.5f, 6.20f);
            Practical(room, "Vanity fill", new Vector3(2.65f, 1.78f, -0.95f), new Color(0.83f, 0.90f, 1f), 1.1f, 2.2f);
            var markLight = Practical(room, "EX-011 signal", new Vector3(2.25f, 1.63f, -1.0f), new Color(0.55f, 0.25f, 1f), 0.72f, 2.2f);
            markLight.enabled = false;
            HospitalWardArt.Dress(room);

            var bedside = Node(room, "Ward bedside resume", new Vector3(-0.30f, 0.045f, 1.18f));
            var vanity = Node(room, "Ward mirror resume", new Vector3(1.80f, 0.045f, -1.0f));
            var bedsideShot = Node(room, "Ward bedside camera", new Vector3(0.84f, 1.80f, 2.34f));
            bedsideShot.LookAt(room.TransformPoint(new Vector3(-1.05f, 0.96f, -0.15f)));
            var mirrorShot = Node(room, "Ward reflection camera", new Vector3(0.36f, 1.72f, -0.27f));
            mirrorShot.LookAt(room.TransformPoint(new Vector3(2.71f, 1.55f, -1.04f)));
            var closeShot = Node(room, "Ward eye-line close-up", new Vector3(0.77f, 1.81f, -1.70f));
            closeShot.LookAt(room.TransformPoint(new Vector3(2.96f, 1.64f, -1.03f)));
            var signal = Node(room, "Glass resonance", new Vector3(2.94f, 1.68f, -1.0f)).gameObject.AddComponent<AudioSource>();
            signal.clip = AssetDatabase.LoadAssetAtPath<AudioClip>("Assets/ElevenEleven/Opening/Stormworks/ZeroSeal.ogg");
            signal.playOnAwake = false;
            signal.spatialBlend = 0.50f;
            signal.volume = 0.24f;
            var panel = Element("Hospital recovery", hud, 0, 0, 1, 1);
            panel.AddComponent<Image>().color = new Color(0.018f, 0.025f, 0.040f, 0.09f);
            var videoImage = Picture("Awakening film", panel.transform, 0, 0, 1, 1);
            var fit = videoImage.gameObject.AddComponent<AspectRatioFitter>();
            fit.aspectMode = AspectRatioFitter.AspectMode.FitInParent;
            fit.aspectRatio = 864f / 496f;
            var plate = Element("Recovery caption", panel.transform, 0.16f, 0.025f, 0.84f, 0.26f);
            plate.AddComponent<Image>().color = new Color(0.039f, 0.052f, 0.071f, 0.96f);
            CinematicDialogueStyle.Apply(plate, CinematicDialogueStyle.Palette.Ward);
            var speaker = Label("Ward speaker", plate.transform, font, "", 29, 0.045f, 0.73f, 0.955f, 0.98f);
            var line = Label("Ward line", plate.transform, font, "", 24, 0.045f, 0.32f, 0.955f, 0.74f);
            CinematicDialogueStyle.Story(line);
            var advance = Control("Ward advance", plate.transform, font, 0.51f, 0.045f, 0.96f, 0.27f);
            var film = root.gameObject.AddComponent<VideoPlayer>();
            film.clip = Load<VideoClip>("WardAwakening.mp4");
            film.playOnAwake = false;
            film.renderMode = VideoRenderMode.APIOnly;
            film.audioOutputMode = VideoAudioOutputMode.None;
            var ward = root.gameObject.AddComponent<StationHospitalWard>();
            Wire(ward, ("ward", room.gameObject), ("bedside", bedside), ("vanity", vanity), ("mirror", mirror.transform),
                ("bedsideShot", bedsideShot), ("mirrorShot", mirrorShot), ("closeShot", closeShot), ("mirrorCue", signal), ("markLight", markLight), ("reflection", reflector),
                ("panel", panel), ("media", videoImage), ("poster", Load<Texture2D>("WardAwakening.png")), ("film", film),
                ("speaker", speaker), ("line", line), ("advance", advance));
            UnityEventTools.AddPersistentListener(advance.onClick, ward.Advance);
            panel.SetActive(false);
            videoImage.gameObject.SetActive(false);
            room.gameObject.SetActive(false);
            return ward;
        }

        private static Material Material(string name, Color color, float smoothness)
        {
            var path = Folder + name + ".mat";
            var mat = AssetDatabase.LoadAssetAtPath<Material>(path);
            if (mat == null)
            {
                mat = new Material(Shader.Find("Universal Render Pipeline/Lit"));
                AssetDatabase.CreateAsset(mat, path);
            }
            mat.color = color;
            if (mat.HasProperty("_Smoothness")) mat.SetFloat("_Smoothness", smoothness);
            EditorUtility.SetDirty(mat);
            AssetDatabase.SaveAssetIfDirty(mat);
            return mat;
        }

        private static Bounds Bounds(Transform item)
        {
            var renderers = item.GetComponentsInChildren<MeshRenderer>();
            return renderers.Select(renderer => renderer.bounds).Aggregate((a, b) => { a.Encapsulate(b); return a; });
        }

        private static void Slab(Transform room, string name, Material material, Vector3 position, Vector3 scale)
        {
            var piece = GameObject.CreatePrimitive(PrimitiveType.Cube);
            piece.name = name;
            piece.transform.SetParent(room, false);
            piece.transform.localPosition = position;
            piece.transform.localScale = scale;
            piece.GetComponent<MeshRenderer>().sharedMaterial = material;
        }

        private static Light Practical(Transform root, string name, Vector3 at, Color color, float strength, float range)
        {
            var light = Node(root, name, at).gameObject.AddComponent<Light>();
            light.type = LightType.Point;
            light.color = color;
            light.intensity = strength;
            light.range = range;
            return light;
        }

        private static T Load<T>(string name) where T : Object =>
            AssetDatabase.LoadAssetAtPath<T>(Folder + name) ?? throw new FileNotFoundException(name);
    }
}
