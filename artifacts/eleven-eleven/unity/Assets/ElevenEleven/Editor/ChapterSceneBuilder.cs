using System;
using System.IO;
using System.Linq;
using ElevenEleven.Opening;
using UnityEditor;
using UnityEditor.Events;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.InputSystem.UI;
using UnityEngine.Rendering;
using UnityEngine.SceneManagement;
using UnityEngine.UI;
using UnityEngine.Video;
using static ElevenEleven.Editor.OpeningReviewSceneBuilder;

namespace ElevenEleven.Editor
{
    internal static class ChapterSceneBuilder
    {
        private const string Root = "Assets/ElevenEleven";
        private const string Scenes = Root + "/Scenes/";
        private const string RoomAssets = Root + "/Opening/Room01/";
        private const string TitlePath = Scenes + "ChapterTitle.unity";
        private const string OpeningPath = Scenes + "ChapterOpening.unity";
        private const string RoomPath = Scenes + "ChapterRoom01.unity";
        private static readonly string[] ChapterPaths = { TitlePath, OpeningPath, RoomPath };
        private const int PlayerLayer = 2;
        private static readonly Color Plate = new Color(0.03f, 0.08f, 0.12f, 0.96f);
        private static Font Font => Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");

        [MenuItem("11.11/Open Chapter 1")]
        public static void OpenChapter()
        {
            if (!EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo()) return;
            RegisterScenes();
            OpenRegisteredTitle();
        }

        public static void BuildChapter()
        {
            BuildTitle();
            BuildOpening();
            BuildRoom();
            RegisterScenes();
            OpenRegisteredTitle();
        }

        internal static void RebuildRoom() => BuildRoom();

        public static void RebuildEntry()
        {
            OpeningReviewSceneBuilder.Rebuild();
            BuildTitle();
            BuildOpening();
            OpenRegisteredTitle();
        }

        internal static void RebuildLoadingScenes()
        {
            BuildTitle();
            BuildOpening();
        }

        internal static void RebuildEntryAndRoom()
        {
            BuildTitle();
            BuildRoom();
        }

        private static void RegisterScenes() =>
            EditorBuildSettings.scenes = ChapterPaths.Select(path => new EditorBuildSettingsScene(path, true)).ToArray();

        internal static void OpenRegisteredTitle()
        {
            var enabled = EditorBuildSettings.scenes.Where(scene => scene.enabled).Select(scene => scene.path);
            if (!enabled.SequenceEqual(ChapterPaths))
                throw new InvalidOperationException("The chapter scenes are missing from the project build settings.");
            EditorSceneManager.OpenScene(TitlePath);
            Debug.Log("CHAPTER_R01_SCENES_READY title, opening, room01");
        }

        private static void BuildTitle()
        {
            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene);
            var canvas = Canvas("Chapter title");
            canvas.gameObject.AddComponent<AudioListener>();
            Element("Black surround", canvas, 0, 0, 1, 1).AddComponent<Image>().color = Color.black;
            var surface = Picture("Title moon", canvas, 0, 0, 1, 1);
            var fit = surface.gameObject.AddComponent<AspectRatioFitter>();
            fit.aspectMode = AspectRatioFitter.AspectMode.FitInParent;
            fit.aspectRatio = 16f / 9f;
            var poster = Asset<Texture2D>(Root + "/Opening/Media/TitleMoonLoopPoster.png");
            surface.texture = poster;
            var font = Asset<Font>(Root + "/Opening/Media/NotoSansArabic.ttf");
            var start = EntryStyle.Action("Chapter entry", canvas, font, "Forward", 0.39f, 0.065f, 0.61f, 0.153f, 25, 0.38f);
            var language = EntryStyle.Action("Language", canvas, font, "Language", 0.035f, 0.895f, 0.165f, 0.965f);
            var motion = EntryStyle.Action("Motion on", canvas, font, "Pause", 0.68f, 0.895f, 0.815f, 0.965f);
            var sound = EntryStyle.Action("Sound off", canvas, font, "Mute", 0.825f, 0.895f, 0.965f, 0.965f);
            var video = canvas.gameObject.AddComponent<VideoPlayer>();
            video.clip = Asset<VideoClip>(Root + "/Opening/Media/TitleMoonLoop.mp4");
            video.playOnAwake = false;
            video.isLooping = true;
            video.renderMode = VideoRenderMode.APIOnly;
            video.audioOutputMode = VideoAudioOutputMode.None;
            var water = canvas.gameObject.AddComponent<AudioSource>();
            water.clip = Asset<AudioClip>(Root + "/Opening/Media/TitleWater.ogg");
            water.playOnAwake = false;
            water.loop = true;
            water.volume = 0.316f;
            var loading = LoadingView(canvas);
            language.transform.SetAsLastSibling();
            motion.transform.SetAsLastSibling();
            sound.transform.SetAsLastSibling();
            var newGameLink = Link(canvas.gameObject, OpeningPath, loading: loading);
            var continueLink = Link(canvas.gameObject, RoomPath, loading: loading, stage: true);
            var title = canvas.gameObject.AddComponent<ChapterTitle>();
            Assign(title, ("video", video), ("image", surface), ("poster", poster), ("water", water),
                ("motionLabel", motion.GetComponentInChildren<Text>()), ("soundLabel", sound.GetComponentInChildren<Text>()),
                ("newGameLink", newGameLink), ("continueLink", continueLink), ("entryButton", start),
                ("bootView", loading),
                ("languageLabel", language.GetComponentInChildren<Text>()),
                ("motionIcon", motion.GetComponentInChildren<RawImage>()), ("soundIcon", sound.GetComponentInChildren<RawImage>()),
                ("playGlyph", EntryStyle.Artwork<Texture2D>("Play")), ("pauseGlyph", EntryStyle.Artwork<Texture2D>("Pause")),
                ("soundGlyph", EntryStyle.Artwork<Texture2D>("Sound")), ("muteGlyph", EntryStyle.Artwork<Texture2D>("Mute")));
            UnityEventTools.AddPersistentListener(start.onClick, title.EnterChapter);
            UnityEventTools.AddPersistentListener(motion.onClick, title.ToggleMotion);
            UnityEventTools.AddPersistentListener(sound.onClick, title.ToggleSound);
            UnityEventTools.AddPersistentListener(language.onClick, title.ToggleLanguage);
            start.gameObject.SetActive(false);
            Events(null);
            Save(scene, TitlePath);
        }

        private static void BuildOpening()
        {
            var review = EditorSceneManager.OpenScene(Scenes + "OpeningReview.unity");
            if (!EditorSceneManager.SaveScene(review, OpeningPath, true))
                throw new IOException("Unable to copy the existing opening.");
            var scene = EditorSceneManager.OpenScene(OpeningPath);
            var host = UnityEngine.Object.FindFirstObjectByType<OpeningReviewHost>();
            var hostData = new SerializedObject(host);
            hostData.FindProperty("useChapterPreferences").boolValue = true;
            hostData.ApplyModifiedPropertiesWithoutUndo();
            var film = host.GetComponentInChildren<OpeningCinematicPresenter>(true);
            var loading = LoadingView(film.transform);
            var link = Link(film.gameObject, RoomPath, loading: loading, stage: true);
            UnityEventTools.AddPersistentListener(film.Completed, link.Begin);
            Save(scene, OpeningPath);
        }

        private static void BuildRoom()
        {
            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene);
            var shell = new GameObject("Sector 11").transform;
            var wall = Material("Containment", new Color(0.11f, 0.15f, 0.22f), 0.34f, 0.46f);
            var deck = Material("Deck", new Color(0.09f, 0.12f, 0.17f), 0.45f, 0.65f);
            var gate = Material("Bulkhead", new Color(0.15f, 0.18f, 0.22f), 0.54f, 0.36f);
            Box("Flooded deck", shell, new Vector3(0, -0.2f, 5.5f), new Vector3(18, 0.4f, 25.4f), deck);
            Box("West wall", shell, new Vector3(-9, 3.6f, 5.5f), new Vector3(0.8f, 7.2f, 25.4f), wall);
            Box("East wall", shell, new Vector3(9, 3.6f, 5.5f), new Vector3(0.8f, 7.2f, 25.4f), wall);
            Box("Rear wall", shell, new Vector3(0, 3.6f, -7), new Vector3(18, 7.2f, 0.8f), wall);
            Box("Ceiling", shell, new Vector3(0, 7.2f, 5.5f), new Vector3(18, 0.6f, 25.4f), wall);
            var blastGate = BuildBlastGate(shell, deck, wall, gate);

            foreach (var z in new[] { -2f, 6f, 15f })
            {
                Model("ServiceModule", shell, new Vector3(-8.6f, 0, z), -90f);
                Model(z == 6f ? "ObservationModule" : "ServiceModule", shell, new Vector3(8.6f, 0, z), 90f);
            }
            foreach (var z in new[] { -2.5f, 2.5f, 7.5f, 12.5f, 17.5f })
                Model("CeilingTile", shell, new Vector3(0, 6.81f, z));
            var dais = Model("CryoDais", shell, new Vector3(-2.5f, 0, -2.8f), -30f, 0.72f);
            var pod = Model("CryoPod", dais, new Vector3(0, 2, 0), 90f, 4f);
            pod.gameObject.AddComponent<BoxCollider>().size = new Vector3(0.62f, 1.02f, 0.65f);
            var clock = Landmark("StoppedClock", shell, new Vector3(-1.85f, 0, -1.8f), wall, 0.965f, 0.6f);
            var trace = Landmark("PersonalTrace", shell, new Vector3(3.7f, 0, 1.5f), wall, 0.965f, 1f);
            var terminal = Model("SignalTerminal", shell, new Vector3(2.8f, 0, -2.4f));
            var consoleCollider = terminal.gameObject.AddComponent<BoxCollider>();
            consoleCollider.center = new Vector3(0, 0.7f, 0);
            consoleCollider.size = new Vector3(1.05f, 1.4f, 0.64f);
            var conduit = Model("PowerConduit", shell, new Vector3(-3.5f, 0, 4f));
            var conduitCollider = conduit.gameObject.AddComponent<CapsuleCollider>();
            conduitCollider.radius = 0.45f;
            conduitCollider.height = 1.8f;
            conduitCollider.center = Vector3.up * 0.9f;
            var conduitSignal = Point("Conduit power signal", conduit.position + Vector3.up * 1.3f, new Color(1f, 0.45f, 0.08f), 1.2f, 5f);

            RenderSettings.ambientMode = AmbientMode.Flat;
            RenderSettings.ambientLight = new Color(0.31f, 0.37f, 0.49f);
            RenderSettings.fog = false;
            var fill = new GameObject("Cool overhead fill").AddComponent<Light>();
            fill.type = LightType.Directional;
            fill.intensity = 0.65f;
            fill.color = new Color(0.76f, 0.86f, 1);
            fill.transform.rotation = Quaternion.Euler(44, -27, 0);
            Point("Recovery glow", new Vector3(-0.65f, 2.10f, -2.58f), new Color(0.76f, 0.84f, 1f), 1.65f, 4.8f);
            Point("Evidence wash", new Vector3(2.3f, 4f, 0), new Color(0.34f, 0.83f, 1), 2f, 9);
            Point("Bulkhead glow", new Vector3(-2.15f, 2.75f, 16.25f), new Color(0.96f, 0.68f, 0.40f), 5.4f, 7.1f);
            OpeningRoomFidelity.Build(shell, wall, deck, gate);

            var camera = new GameObject("Room 01 camera", typeof(Camera), typeof(AudioListener)).GetComponent<Camera>();
            camera.tag = "MainCamera";
            camera.clearFlags = CameraClearFlags.SolidColor;
            camera.backgroundColor = new Color(0.025f, 0.035f, 0.06f);
            camera.nearClipPlane = 0.05f;
            camera.farClipPlane = 42;
            camera.fieldOfView = 60;
            var player = new GameObject("Echo");
            player.layer = PlayerLayer;
            player.transform.position = new Vector3(0, 0.04f, -4);
            var controller = player.AddComponent<CharacterController>();
            controller.height = 1.76f;
            controller.center = new Vector3(0, 0.88f, 0);
            controller.radius = 0.28f;
            var school = BuildSchool(player.transform);
            var motion = school.GetChild(0).gameObject.AddComponent<Animation>();
            motion.playAutomatically = false;
            motion.wrapMode = WrapMode.Loop;
            var driver = player.AddComponent<Room01Player>();
            Assign(driver, ("terminal", terminal), ("conduit", conduit), ("conduitSignal", conduitSignal), ("gate", blastGate),
                ("schoolMotion", motion), ("schoolIdle", Asset<AnimationClip>(Root + "/Echo/Locomotion/SchoolIdle.anim")),
                ("schoolWalk", Asset<AnimationClip>(Root + "/Echo/Locomotion/SchoolWalk.anim")));
            var (hud, roomEvents) = BuildRoomHud(driver, school, camera, new[] { clock, trace });
            var content = new GameObject("Room content");
            foreach (var root in scene.GetRootGameObjects())
            {
                if (root != content) root.transform.SetParent(content.transform, true);
            }
            content.SetActive(false);
            var stage = new GameObject("Room stage").AddComponent<ChapterRoomStage>();
            Assign(stage, ("content", content), ("player", driver), ("gameplayCamera", camera),
                ("listener", camera.GetComponent<AudioListener>()), ("hud", hud), ("events", roomEvents));
            StormworksConstruction.Apply(scene);
            Save(scene, RoomPath);
        }

        private static Room01Gate BuildBlastGate(Transform shell, Material deck, Material wall, Material bulkhead)
        {
            const float z = 18f;
            Box("West bulkhead", shell, new Vector3(-6.3f, 3.6f, z), new Vector3(5.4f, 7.2f, 0.8f), bulkhead);
            Box("East bulkhead", shell, new Vector3(6.3f, 3.6f, z), new Vector3(5.4f, 7.2f, 0.8f), bulkhead);
            Box("Blast gate lintel", shell, new Vector3(0, 6.85f, z), new Vector3(7.2f, 0.7f, 0.8f), bulkhead);
            Box("Threshold floor", shell, new Vector3(0, -0.2f, 20.1f), new Vector3(8f, 0.4f, 4.8f), deck);
            Box("West threshold wall", shell, new Vector3(-3.95f, 3.6f, 20.2f), new Vector3(0.7f, 7.2f, 4.8f), wall);
            Box("East threshold wall", shell, new Vector3(3.95f, 3.6f, 20.2f), new Vector3(0.7f, 7.2f, 4.8f), wall);
            Box("Threshold ceiling", shell, new Vector3(0, 7.2f, 20.2f), new Vector3(8f, 0.6f, 4.8f), wall);
            Box("Next corridor bulkhead", shell, new Vector3(0, 3.6f, 22.5f), new Vector3(8f, 7.2f, 0.7f), bulkhead);

            var root = new GameObject("Blast gate").transform;
            root.SetParent(shell, false);
            var door = new GameObject("Sliding door").transform;
            door.SetParent(root, false);
            door.localPosition = new Vector3(0, 3.25f, z);
            Box("Gate panel", door, Vector3.zero, new Vector3(7.2f, 6.5f, 0.6f), wall);
            foreach (var x in new[] { -2.35f, 0f, 2.35f })
            {
                var plate = Box("Gate armor", door, new Vector3(x, 0, -0.34f), new Vector3(1.72f, 5.9f, 0.08f), bulkhead);
                plate.GetComponent<Collider>().enabled = false;
            }
            var doorSignal = Point("Blast gate signal", new Vector3(0, 4.5f, z - 1.1f), new Color(1f, 0.18f, 0.06f), 1.6f, 8f);
            var threshold = new GameObject("Threshold beyond blast gate").transform;
            threshold.SetParent(root, false);
            threshold.localPosition = new Vector3(0, 0, 19.05f);
            var gate = root.gameObject.AddComponent<Room01Gate>();
            Assign(gate, ("door", door), ("doorSignal", doorSignal), ("threshold", threshold));
            return gate;
        }

        private static Transform BuildSchool(Transform parent)
        {
            var pivot = new GameObject("School65 facing").transform;
            pivot.SetParent(parent, false);
            var asset = Asset<GameObject>(Root + "/Echo/School/EchoSchool-Tripo-Original.glb");
            var model = ((GameObject)PrefabUtility.InstantiatePrefab(asset, pivot)).transform;
            var skins = model.GetComponentsInChildren<SkinnedMeshRenderer>();
            var bones = skins.SelectMany(skin => skin.bones).Distinct().ToArray();
            if (skins.Length == 0 || bones.Length != 65)
                throw new InvalidDataException($"School65 import returned {bones.Length} bones.");
            var bounds = EchoSchoolImportReview.MeasureSkinnedBounds(skins);
            var left = bones.Single(bone => bone.name.EndsWith("LeftShoulder", StringComparison.Ordinal));
            var right = bones.Single(bone => bone.name.EndsWith("RightShoulder", StringComparison.Ordinal));
            var front = Vector3.Cross(Vector3.up, left.position - right.position).normalized;
            model.rotation = Quaternion.FromToRotation(front, Vector3.forward);
            var scale = 1.76f / bounds.size.y;
            model.localScale = Vector3.one * scale;
            model.localPosition = Vector3.down * ((bounds.min.y - parent.position.y) * scale);
            return pivot;
        }

        private static (GameObject hud, GameObject events) BuildRoomHud(Room01Player driver, Transform school, Camera camera, Transform[] landmarks)
        {
            var canvas = Canvas("Room 01 HUD");
            var header = Element("Objective plate", canvas, 0.04f, 0.83f, 0.48f, 0.96f);
            header.AddComponent<Image>().color = Plate;
            var objective = Label("Current objective", header.transform, Font, "", 24, 0.06f, 0.47f, 0.96f, 0.99f);
            var observation = Label("Last observation", header.transform, Font, "", 18, 0.06f, 0.02f, 0.96f, 0.48f);
            var returnTitle = Control("Back to title", canvas, Font, 0.80f, 0.87f, 0.96f, 0.95f);
            var loadStatus = Label("Title loading status", canvas, Font, "", 19, 0.57f, 0.80f, 0.96f, 0.86f);
            var saveStatus = Label("Checkpoint status", canvas, Font, "", 19, 0.55f, 0.73f, 0.96f, 0.79f);
            var titleLink = Link(canvas.gameObject, TitlePath, loadStatus, returnTitle);
            UnityEventTools.AddPersistentListener(returnTitle.onClick, driver.ReturnToTitle);
            var touchRegion = Element("Touch controls", canvas, 0.05f, 0.09f, 0.18f, 0.32f);
            var touch = Element("Move", touchRegion.transform, 0, 0, 1, 1);
            touch.AddComponent<AspectRatioFitter>().aspectMode = AspectRatioFitter.AspectMode.FitInParent;
            touch.AddComponent<Image>().color = new Color(0.10f, 0.21f, 0.29f, 0.77f);
            var knob = Element("Stick knob", touch.transform, 0.37f, 0.37f, 0.63f, 0.63f);
            var knobImage = knob.AddComponent<Image>();
            knobImage.color = new Color(0.70f, 0.88f, 0.94f);
            knobImage.raycastTarget = false;
            var stick = touch.AddComponent<Room01TouchStick>();
            Assign(stick, ("knob", knob.transform));
            var inspect = Control("Inspect  [E]", canvas, Font, 0.75f, 0.09f, 0.95f, 0.20f);
            var panel = Element("Inspection", canvas, 0.23f, 0.24f, 0.77f, 0.73f);
            panel.AddComponent<Image>().color = Plate;
            var note = Label("Inspection notes", panel.transform, Font, "", 25, 0.08f, 0.31f, 0.92f, 0.91f);
            var keep = Control("Keep this trace", panel.transform, Font, 0.07f, 0.07f, 0.49f, 0.28f);
            var close = Control("Back", panel.transform, Font, 0.51f, 0.07f, 0.93f, 0.28f);
            UnityEventTools.AddPersistentListener(inspect.onClick, driver.OpenInspection);
            UnityEventTools.AddPersistentListener(keep.onClick, driver.KeepObservation);
            UnityEventTools.AddPersistentListener(close.onClick, driver.CloseInspection);
            inspect.gameObject.SetActive(false);
            panel.SetActive(false);
            var tuner = BuildSignalTuner(canvas);
            Assign(driver, ("school", school), ("roomCamera", camera), ("touchMove", stick), ("objective", objective),
                ("observation", observation), ("inspect", inspect), ("inspection", panel), ("inspectionText", note), ("keep", keep),
                ("tuner", tuner), ("titleLink", titleLink), ("saveStatus", saveStatus));
            var data = new SerializedObject(driver);
            data.FindProperty("cameraObstacles").intValue = ~(1 << PlayerLayer);
            var targets = data.FindProperty("landmarks");
            targets.arraySize = landmarks.Length;
            for (var index = 0; index < landmarks.Length; index++)
                targets.GetArrayElementAtIndex(index).objectReferenceValue = landmarks[index];
            data.ApplyModifiedPropertiesWithoutUndo();
            return (canvas.gameObject, Events(null));
        }

        private static Room01SignalTuner BuildSignalTuner(Transform canvas)
        {
            var panel = Element("Signal terminal tuner", canvas, 0.20f, 0.13f, 0.80f, 0.87f);
            panel.AddComponent<Image>().color = Plate;
            Label("Tuner title", panel.transform, Font, "Signal terminal", 30, 0.06f, 0.86f, 0.94f, 0.98f);
            var status = Label("Alignment status", panel.transform, Font, "", 20, 0.06f, 0.73f, 0.94f, 0.86f);
            var frequency = TunerRow(panel.transform, "Frequency", 0.55f, 100, 300, 160);
            var phase = TunerRow(panel.transform, "Phase", 0.39f, 0, 180, 0);
            var channel = TunerRow(panel.transform, "Channel", 0.23f, 1, 10, 1);
            var back = Control("Close tuner", panel.transform, Font, 0.07f, 0.04f, 0.35f, 0.17f);
            var proceed = Control("Return to room", panel.transform, Font, 0.62f, 0.04f, 0.93f, 0.17f);
            var tuner = panel.AddComponent<Room01SignalTuner>();
            Assign(tuner, ("frequencyHalfSteps", frequency.slider), ("phase", phase.slider), ("channel", channel.slider),
                ("frequencyValue", frequency.value), ("phaseValue", phase.value), ("channelValue", channel.value),
                ("status", status), ("back", back), ("proceed", proceed));
            UnityEventTools.AddPersistentListener(back.onClick, tuner.Close);
            UnityEventTools.AddPersistentListener(proceed.onClick, tuner.Close);
            proceed.gameObject.SetActive(false);
            panel.SetActive(false);
            return tuner;
        }

        private static (Slider slider, Text value) TunerRow(Transform panel, string name, float y, int min, int max, int initial)
        {
            var label = Label(name + " label", panel, Font, name, 20, 0.06f, y, 0.28f, y + 0.13f);
            label.alignment = TextAnchor.MiddleLeft;
            var value = Label(name + " value", panel, Font, "", 20, 0.77f, y, 0.94f, y + 0.13f);
            var input = Element(name, panel, 0.29f, y, 0.76f, y + 0.13f);
            input.AddComponent<Image>().color = new Color(0.12f, 0.19f, 0.25f);
            var slideArea = Element("Handle area", input.transform, 0.07f, 0.15f, 0.93f, 0.85f);
            var handle = Element("Handle", slideArea.transform, 0.5f, 0, 0.5f, 1);
            var handleRect = handle.GetComponent<RectTransform>();
            handleRect.sizeDelta = new Vector2(22, 0);
            var grip = handle.AddComponent<Image>();
            grip.color = new Color(0.54f, 0.9f, 0.98f);
            var slider = input.AddComponent<Slider>();
            slider.targetGraphic = grip;
            slider.handleRect = handleRect;
            slider.wholeNumbers = true;
            slider.minValue = min;
            slider.maxValue = max;
            slider.SetValueWithoutNotify(initial);
            return (slider, value);
        }

        private static Transform Landmark(string model, Transform parent, Vector3 at, Material material, float height, float scale)
        {
            var pedestal = Box(model + " pedestal", parent, at + new Vector3(0, height * 0.5f, 0),
                new Vector3(0.57f, height, 0.57f), material);
            Model(model, parent, at + Vector3.up * height, 0f, scale);
            return pedestal;
        }

        private static Transform Model(string name, Transform parent, Vector3 position, float yaw = 0, float scale = 1)
        {
            var asset = Asset<GameObject>(RoomAssets + name + ".glb");
            var item = UnityEngine.Object.Instantiate(asset, parent, false).transform;
            item.name = name;
            item.SetLocalPositionAndRotation(position, Quaternion.Euler(0, yaw, 0));
            item.localScale = Vector3.one * scale;
            return item;
        }

        private static Transform Box(string name, Transform parent, Vector3 at, Vector3 size, Material material)
        {
            var box = GameObject.CreatePrimitive(PrimitiveType.Cube);
            box.name = name;
            box.transform.SetParent(parent, false);
            box.transform.localPosition = at;
            box.transform.localScale = size;
            box.GetComponent<MeshRenderer>().sharedMaterial = material;
            return box.transform;
        }

        private static Material Material(string name, Color color, float metallic, float smoothness)
        {
            var path = RoomAssets + name + ".mat";
            var material = AssetDatabase.LoadAssetAtPath<Material>(path);
            if (material == null)
            {
                var shader = Shader.Find("Universal Render Pipeline/Lit");
                if (shader == null) throw new InvalidOperationException("The Unity URP shader is missing.");
                material = new Material(shader);
                AssetDatabase.CreateAsset(material, path);
            }
            material.color = color;
            material.SetFloat("_Metallic", metallic);
            material.SetFloat("_Smoothness", smoothness);
            EditorUtility.SetDirty(material);
            AssetDatabase.SaveAssetIfDirty(material);
            return material;
        }

        private static Light Point(string name, Vector3 at, Color color, float intensity, float range)
        {
            var light = new GameObject(name).AddComponent<Light>();
            light.transform.position = at;
            light.type = LightType.Point;
            light.color = color;
            light.intensity = intensity;
            light.range = range;
            return light;
        }

        private static Transform Canvas(string name)
        {
            var canvas = new GameObject(name, typeof(RectTransform), typeof(Canvas), typeof(CanvasScaler), typeof(GraphicRaycaster));
            canvas.GetComponent<Canvas>().renderMode = RenderMode.ScreenSpaceOverlay;
            var scaler = canvas.GetComponent<CanvasScaler>();
            scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
            scaler.referenceResolution = new Vector2(1280, 720);
            scaler.matchWidthOrHeight = 0.5f;
            return canvas.transform;
        }

        private static GameObject Events(GameObject first)
        {
            var events = new GameObject("UI Events", typeof(EventSystem), typeof(InputSystemUIInputModule));
            events.GetComponent<EventSystem>().firstSelectedGameObject = first;
            events.GetComponent<InputSystemUIInputModule>().AssignDefaultActions();
            return events;
        }

        private static ChapterLoadingView LoadingView(Transform owner)
        {
            var overlay = Element("Chapter loading", owner, 0, 0, 1, 1);
            overlay.AddComponent<Image>().color = new Color(0.012f, 0.02f, 0.035f, 0.97f);
            var panel = Element("Loading panel", overlay.transform, 0.14f, 0.30f, 0.86f, 0.70f);
            panel.AddComponent<Image>().color = Plate;
            var message = Label("Loading message", panel.transform, Font, "", 32, 0.06f, 0.51f, 0.94f, 0.91f);
            var progress = Element("Loading progress", panel.transform, 0.06f, 0.43f, 0.94f, 0.47f);
            progress.AddComponent<Image>().color = new Color(0.13f, 0.22f, 0.29f);
            var fill = Element("Loaded", progress.transform, 0, 0, 0, 1);
            fill.AddComponent<Image>().color = new Color(0.35f, 0.85f, 0.95f);
            var retry = Control("Try again", panel.transform, Font, 0.06f, 0.09f, 0.47f, 0.30f);
            var back = Control("Back to title", panel.transform, Font, 0.53f, 0.09f, 0.94f, 0.30f);
            retry.GetComponentInChildren<Text>().fontSize = 24;
            back.GetComponentInChildren<Text>().fontSize = 24;
            var view = overlay.AddComponent<ChapterLoadingView>();
            var arabicFont = Asset<Font>(Root + "/Opening/Media/NotoSansArabic.ttf");
            Assign(view, ("message", message), ("progress", progress.transform), ("fill", fill.transform),
                ("retry", retry), ("back", back), ("arabicFont", arabicFont));
            overlay.SetActive(false);
            return view;
        }

        private static ChapterSceneLink Link(GameObject owner, string path, Text status = null, Button retry = null,
            ChapterLoadingView loading = null, bool stage = false)
        {
            var link = owner.AddComponent<ChapterSceneLink>();
            Assign(link, ("status", status), ("retry", retry), ("loadingView", loading));
            var data = new SerializedObject(link);
            data.FindProperty("stageBeforeEntry").boolValue = stage;
            data.FindProperty("destination").stringValue = Path.GetFileNameWithoutExtension(path);
            data.ApplyModifiedPropertiesWithoutUndo();
            return link;
        }

        private static T Asset<T>(string path) where T : UnityEngine.Object =>
            AssetDatabase.LoadAssetAtPath<T>(path) ?? throw new FileNotFoundException("Required Unity asset missing.", path);

        private static void Assign(UnityEngine.Object target, params (string field, UnityEngine.Object value)[] fields)
        {
            var data = new SerializedObject(target);
            foreach (var (field, value) in fields)
                data.FindProperty(field).objectReferenceValue = value;
            data.ApplyModifiedPropertiesWithoutUndo();
        }

        private static void Save(Scene scene, string path)
        {
            EditorSceneManager.MarkSceneDirty(scene);
            if (!EditorSceneManager.SaveScene(scene, path)) throw new IOException("Unable to save " + path);
        }
    }
}
