using ElevenEleven.Opening;
using UnityEditor;
using UnityEditor.Events;
using UnityEngine;
using UnityEngine.UI;
using static ElevenEleven.Editor.GodotRoomAssembly;
using static ElevenEleven.Editor.OpeningReviewSceneBuilder;

namespace ElevenEleven.Editor
{
    internal static class StationExaminationConstruction
    {
        private const string Folder = "Assets/ElevenEleven/Opening/Stormworks/";
        internal const float StartDepth = 39.03f;
        private static readonly Color Cyan = new Color(0.12f, 0.83f, 0.91f);
        private static readonly Color Violet = new Color(0.55f, 0.21f, 0.95f);

        internal static StationExaminationWing Build(Transform surveillance, Transform hud, Font font, ArchiveVignettes fragments)
        {
            var root = Node(surveillance, "Kinja examination theatre", new Vector3(0f, 0f, StartDepth));
            var art = PlaceArt(root, Folder + "Lab-Godot-Art.glb", "Godot examination architecture");
            var kinja = StationExaminationArt.Dress(root, art);
            Collisions(root, "dr_kinja_lab_room", _ => null);
            var altarCollider = root.Find("Authored Godot collision/ZeroContractAltar").GetComponent<BoxCollider>();
            altarCollider.size = new Vector3(0.95f, 1.62f, 0.95f);
            altarCollider.center = new Vector3(0f, 0.21f, 0f);
            var shizukaStill = AssetDatabase.LoadAssetAtPath<Texture2D>(Folder + "Shizuka-PDF041.png");
            var yukiStill = AssetDatabase.LoadAssetAtPath<Texture2D>(Folder + "Yuki-PDF041.png");
            var console = Node(root, "Neural rig approach", new Vector3(2.5f, 1.245f, 18.8f));
            var shizuka = Node(root, "Shizuka memory", new Vector3(-4.1f, 1.245f, 20f));
            var yuki = Node(root, "Yuki memory", new Vector3(4.1f, 1.245f, 22.2f));
            var overload = ExperimentScreen(root, "Neural overload record", "LabFragment-Overload", new Vector3(-4.7f, 1.245f, 16.8f), 1f);
            var repetition = ExperimentScreen(root, "Repeat trial record", "LabFragment-Repeat", new Vector3(4.65f, 1.245f, 16.7f), -1f);
            var shizukaPlate = MemoryPlate(root, "Shizuka projection", shizukaStill, -7f);
            var yukiPlate = MemoryPlate(root, "Yuki projection", yukiStill, 7f);
            var shot = Node(root, "Examination camera", new Vector3(0.1f, 3.29f, 13.65f));
            shot.rotation = Quaternion.LookRotation(root.TransformPoint(new Vector3(0.1f, 2.54f, 19.0f)) - shot.position);
            Point(root, "Kinja key", new Vector3(-1.05f, 3.72f, 16.35f), new Color(1.0f, 0.78f, 0.58f), 7.5f, 7.9f);
            Point(root, "Altar approach lighting", new Vector3(4f, 5.6f, 34f), Cyan, 5.8f, 13f);
            Point(root, "Lab threshold key", new Vector3(0, 4.65f, 4.25f), Cyan, 9f, 12f);
            Point(root, "Theatre bounce", new Vector3(-4.6f, 6.1f, 16f), Cyan, 13f, 15f);
            Point(root, "Neural rig key", new Vector3(3.4f, 4.2f, 18.65f), new Color(0.69f, 0.85f, 1f), 10f, 10f);
            var leftSignal = Point(shizuka, "Shizuka memory signal", new Vector3(0, 2f, 0), Violet, 4.9f, 5.2f);
            var rightSignal = Point(yuki, "Yuki memory signal", new Vector3(0, 2f, 0), Violet, 4.9f, 5.2f);
            var altar = Point(root, "Presence at the altar", new Vector3(0, 2.5f, 32.3f), Violet, 17f, 11f);

            ExaminationTheatreFinish.Dress(root, art);

            var panel = Element("Examination dialogue", hud, 0, 0, 1, 1);
            var scrim = panel.AddComponent<Image>();
            var caption = Element("Examination caption", panel.transform, 0.13f, 0.025f, 0.87f, 0.30f);
            caption.AddComponent<Image>().color = new Color(0.038f, 0.067f, 0.114f, 0.98f);
            CinematicDialogueStyle.Apply(caption, CinematicDialogueStyle.Palette.Laboratory);
            var speaker = Label("Speaker", caption.transform, font, "", 26, 0.04f, 0.69f, 0.96f, 0.98f);
            speaker.color = new Color(0.66f, 0.92f, 1f);
            var line = Label("Line", caption.transform, font, "", 23, 0.06f, 0.33f, 0.94f, 0.70f);
            CinematicDialogueStyle.Story(line);
            line.resizeTextForBestFit = true;
            line.resizeTextMinSize = 16;
            line.resizeTextMaxSize = 23;
            var advance = Control("Continue examination", caption.transform, font, 0.52f, 0.06f, 0.95f, 0.29f);
            var alternative = Control("Review memories", caption.transform, font, 0.05f, 0.06f, 0.48f, 0.29f);
            var chooseShizuka = Control("Choose Shizuka", caption.transform, font, 0.05f, 0.32f, 0.48f, 0.53f);
            var chooseYuki = Control("Choose Yuki", caption.transform, font, 0.52f, 0.32f, 0.95f, 0.53f);
            var timerTrack = Element("Kinja countdown", caption.transform, 0.06f, 0.962f, 0.94f, 0.979f);
            timerTrack.AddComponent<Image>().color = new Color(0.31f, 0.15f, 0.24f);
            var timer = Element("Time remaining", timerTrack.transform, 0, 0, 1, 1);
            timer.AddComponent<Image>().color = new Color(1f, 0.17f, 0.46f);
            var close = Control("Leave trial", panel.transform, font, 0.79f, 0.89f, 0.96f, 0.97f);
            var frame = Element("Memory frame", panel.transform, 0.18f, 0.41f, 0.82f, 0.88f);
            var memory = Picture("Manhwa memory", frame.transform, 0, 0, 1, 1);
            var fitter = memory.gameObject.AddComponent<AspectRatioFitter>();
            fitter.aspectMode = AspectRatioFitter.AspectMode.FitInParent;

            var wing = root.gameObject.AddComponent<StationExaminationWing>();
            StormworksConstruction.Wire(wing, ("console", console), ("kinja", kinja), ("shizuka", shizuka), ("yuki", yuki),
                ("shizukaSignal", leftSignal), ("yukiSignal", rightSignal), ("altarLight", altar),
                ("shizukaPlate", shizukaPlate), ("yukiPlate", yukiPlate), ("examinationShot", shot), ("scrim", scrim),
                ("panel", panel), ("speaker", speaker), ("line", line), ("memory", memory), ("memoryAspect", fitter),
                ("advance", advance), ("alternative", alternative), ("close", close), ("chooseShizuka", chooseShizuka),
                ("chooseYuki", chooseYuki), ("countdown", timerTrack), ("timer", timer.GetComponent<RectTransform>()),
                ("shizukaStill", shizukaStill), ("yukiStill", yukiStill), ("fragments", fragments),
                ("overloadRecord", overload), ("repeatRecord", repetition));
            UnityEventTools.AddPersistentListener(advance.onClick, wing.Advance);
            UnityEventTools.AddPersistentListener(close.onClick, wing.CancelReading);
            UnityEventTools.AddPersistentListener(alternative.onClick, wing.ReviewMemories);
            UnityEventTools.AddIntPersistentListener(chooseShizuka.onClick, wing.ResolveUltimatum, 1);
            UnityEventTools.AddIntPersistentListener(chooseYuki.onClick, wing.ResolveUltimatum, 2);
            leftSignal.enabled = rightSignal.enabled = altar.enabled = false;
            shizukaPlate.SetActive(false);
            yukiPlate.SetActive(false);
            panel.SetActive(false);
            return wing;
        }

        private static GameObject MemoryPlate(Transform theatre, string name, Texture2D still, float x)
        {
            var surface = GameObject.CreatePrimitive(PrimitiveType.Quad);
            surface.name = name;
            surface.transform.SetParent(theatre, false);
            surface.transform.localPosition = new Vector3(x, 2.30f, 19.69f);
            surface.transform.localScale = new Vector3(Mathf.Min(2.48f, 1.45f * still.width / still.height), 1.45f, 1f);
            Object.DestroyImmediate(surface.GetComponent<Collider>());
            var path = Folder + name + ".mat";
            var material = AssetDatabase.LoadAssetAtPath<Material>(path);
            if (material == null)
            {
                material = new Material(Shader.Find("Universal Render Pipeline/Unlit"));
                AssetDatabase.CreateAsset(material, path);
            }
            material.SetTexture("_BaseMap", still);
            material.SetInt("_Cull", (int)UnityEngine.Rendering.CullMode.Off);
            EditorUtility.SetDirty(material);
            AssetDatabase.SaveAssetIfDirty(material);
            surface.GetComponent<MeshRenderer>().sharedMaterial = material;
            return surface;
        }

        private static Transform ExperimentScreen(Transform room, string name, string poster, Vector3 location, float side)
        {
            var marker = Node(room, name, location);
            var still = AssetDatabase.LoadAssetAtPath<Texture2D>("Assets/ElevenEleven/Opening/Media/" + poster + ".png");
            var display = MemoryPlate(marker, name + " screen", still, 0f);
            display.transform.localPosition = new Vector3(0f, 1.15f, 0f);
            display.transform.localRotation = Quaternion.Euler(0f, side * 23f, 0f);
            display.transform.localScale = new Vector3(1.6f, 0.9f, 1f);
            Point(marker, name + " light", new Vector3(0f, 1.44f, -0.31f), side > 0 ? Cyan : Violet, 2.5f, 3f);
            return marker;
        }

        private static Light Point(Transform root, string name, Vector3 position, Color color, float intensity, float range)
        {
            var light = Node(root, name, position).gameObject.AddComponent<Light>();
            light.type = LightType.Point;
            light.color = color;
            light.intensity = intensity;
            light.range = range;
            return light;
        }
    }
}
