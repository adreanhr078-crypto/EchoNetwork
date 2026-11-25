using System;
using System.IO;
using ElevenEleven.Opening;
using UnityEditor;
using UnityEditor.Events;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.InputSystem.UI;
using UnityEngine.UI;
using UnityEngine.Video;

namespace ElevenEleven.Editor
{
    internal static class OpeningReviewSceneBuilder
    {
        private const string Root = "Assets/ElevenEleven";
        private const string Media = Root + "/Opening/Media/";
        private const string ScenePath = Root + "/Scenes/OpeningReview.unity";
        private static readonly Color Background = new Color(0.032f, 0.055f, 0.10f);
        private static readonly Color ControlColor = new Color(0.13f, 0.24f, 0.36f);

        [MenuItem("11.11/Open cover puzzle and cinematic review")]
        public static void Build()
        {
            if (!EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo()) return;
            if (AssetDatabase.LoadAssetAtPath<SceneAsset>(ScenePath) != null)
            {
                EditorSceneManager.OpenScene(ScenePath);
                return;
            }

            Rebuild();
        }

        internal static void Rebuild()
        {
            var cover = Load<Texture2D>("Cover.png");
            var backdrop = Load<Texture2D>("CoverBackdrop.png");
            var schoolClip = Load<VideoClip>("Opening3D-friends.mp4");
            var laboratoryClip = Load<VideoClip>("Opening3D-lab-continuity.mp4");
            var experimentClip = Load<VideoClip>("Opening3D-trial-continuity.mp4");
            var schoolPoster = Load<Texture2D>("Opening3D-friends.png");
            var laboratoryPoster = Load<Texture2D>("Opening3D-lab-continuity.png");
            var experimentPoster = Load<Texture2D>("Opening3D-trial-continuity.png");
            var schoolAudio = Load<AudioClip>("SchoolAmbience.ogg");
            var pressureAir = Load<AudioClip>("PressureAir.wav");

            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene);
            var canvasObject = new GameObject("Opening Review", typeof(RectTransform), typeof(Canvas),
                typeof(CanvasScaler), typeof(GraphicRaycaster), typeof(AudioListener), typeof(OpeningReviewHost));
            canvasObject.GetComponent<Canvas>().renderMode = RenderMode.ScreenSpaceOverlay;
            var scaler = canvasObject.GetComponent<CanvasScaler>();
            scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
            scaler.referenceResolution = new Vector2(1280, 720);
            scaler.matchWidthOrHeight = 0.5f;
            var host = canvasObject.GetComponent<OpeningReviewHost>();
            var font = Load<Font>("NotoSansArabic.ttf");

            var coverPanel = Element("Cover Recovery", canvasObject.transform, 0, 0, 1, 1);
            coverPanel.AddComponent<Image>().color = Background;
            var background = Picture("Backdrop", coverPanel.transform, 0, 0, 1, 1);
            background.texture = backdrop;
            background.color = new Color(0.40f, 0.45f, 0.62f);
            var backdropFit = background.gameObject.AddComponent<AspectRatioFitter>();
            backdropFit.aspectMode = AspectRatioFitter.AspectMode.EnvelopeParent;
            backdropFit.aspectRatio = (float)backdrop.width / backdrop.height;
            var coverPresenter = coverPanel.AddComponent<CoverRecoveryPresenter>();
            var boardRegion = Element("Cover Region", coverPanel.transform, 0.08f, 0.08f, 0.49f, 0.92f);
            var board = Element("Six Pieces", boardRegion.transform, 0, 0, 1, 1);
            var fit = board.AddComponent<AspectRatioFitter>();
            fit.aspectMode = AspectRatioFitter.AspectMode.FitInParent;
            fit.aspectRatio = (float)cover.width / cover.height;
            var frame = EntryStyle.Glass(Element("Cover frame", board.transform, 0, 0, 1, 1));
            frame.rectTransform.offsetMin = new Vector2(-8, -8);
            frame.rectTransform.offsetMax = new Vector2(8, 8);
            frame.color = new Color(0.54f, 0.65f, 1f);
            var pieceImages = new RawImage[CoverPuzzle.TileCount];
            var edges = new Image[CoverPuzzle.TileCount];
            var firstTile = MakePieces(board.transform, coverPresenter, pieceImages, edges);
            var reference = Picture("Full Cover", board.transform, 0, 0, 1, 1);
            var fracture = Element("Cover fracture", coverPanel.transform, 0, 0, 1, 1).AddComponent<CoverFracture>();
            var fractureData = new SerializedObject(fracture);
            Set(fractureData, "crack", Load<AudioClip>("Opening3D-fracture.wav"));
            fractureData.ApplyModifiedPropertiesWithoutUndo();
            fracture.gameObject.SetActive(false);
            var panel = Element("Recovery controls", coverPanel.transform, 0.535f, 0.145f, 0.94f, 0.85f);
            var controls = panel.AddComponent<CanvasGroup>();
            EntryStyle.Glass(panel);
            var heading = Label("Heading", panel.transform, font, "", 38, 0.06f, 0.64f, 0.94f, 0.89f);
            heading.color = EntryStyle.Paper;
            heading.resizeTextForBestFit = true;
            heading.resizeTextMinSize = 22;
            heading.resizeTextMaxSize = 38;
            var instruction = Label("Instruction", panel.transform, font, "", 22, 0.05f, 0.48f, 0.95f, 0.64f);
            instruction.color = EntryStyle.Paper;
            instruction.resizeTextForBestFit = true;
            instruction.resizeTextMinSize = 15;
            instruction.resizeTextMaxSize = 22;
            var state = Label("Recovery status", panel.transform, font, "", 20, 0.05f, 0.35f, 0.95f, 0.45f);
            state.color = EntryStyle.Ice;
            state.resizeTextForBestFit = true;
            state.resizeTextMinSize = 13;
            state.resizeTextMaxSize = 20;
            var referenceButton = EntryStyle.Action("View or hide cover", panel.transform, font, "Reference", 0.08f, 0.20f, 0.92f, 0.33f, 22);
            var undoButton = EntryStyle.Action("Undo", panel.transform, font, "Undo", 0.08f, 0.055f, 0.47f, 0.175f);
            var resetButton = EntryStyle.Action("Shuffle again", panel.transform, font, "Reset", 0.50f, 0.055f, 0.92f, 0.175f);
            var language = EntryStyle.Action("Language", coverPanel.transform, font, "Language", 0.79f, 0.89f, 0.94f, 0.96f);
            UnityEventTools.AddPersistentListener(language.onClick, coverPresenter.ToggleLanguage);
            UnityEventTools.AddPersistentListener(referenceButton.onClick, coverPresenter.ToggleReference);
            UnityEventTools.AddPersistentListener(undoButton.onClick, coverPresenter.Undo);
            UnityEventTools.AddPersistentListener(resetButton.onClick, coverPresenter.ResetCover);
            var coverData = new SerializedObject(coverPresenter);
            Set(coverData, "cover", cover);
            Set(coverData, "reference", reference);
            Set(coverData, "undoButton", undoButton);
            Set(coverData, "referenceButton", referenceButton);
            Set(coverData, "resetButton", resetButton);
            Set(coverData, "languageButton", language);
            Set(coverData, "heading", heading);
            Set(coverData, "instruction", instruction);
            Set(coverData, "stateLabel", state);
            Set(coverData, "board", board.transform);
            Set(coverData, "controls", controls);
            Set(coverData, "fracture", fracture);
            var frames = coverData.FindProperty("edges");
            frames.arraySize = edges.Length;
            for (var index = 0; index < edges.Length; index++)
                frames.GetArrayElementAtIndex(index).objectReferenceValue = edges[index];
            var pieces = coverData.FindProperty("pieces");
            pieces.arraySize = pieceImages.Length;
            for (var index = 0; index < pieceImages.Length; index++)
                pieces.GetArrayElementAtIndex(index).objectReferenceValue = pieceImages[index];
            coverData.ApplyModifiedPropertiesWithoutUndo();
            UnityEventTools.AddPersistentListener(coverPresenter.Restored, host.EnterFilm);

            var filmPanel = Element("School to Laboratory", canvasObject.transform, 0, 0, 1, 1);
            filmPanel.AddComponent<Image>().color = Color.black;
            var video = filmPanel.AddComponent<VideoPlayer>();
            var audio = filmPanel.AddComponent<AudioSource>();
            audio.volume = Mathf.Pow(10f, -10f / 20f);
            var surface = Picture("Film Surface", filmPanel.transform, 0, 0, 1, 1);
            var videoFit = surface.gameObject.AddComponent<AspectRatioFitter>();
            videoFit.aspectMode = AspectRatioFitter.AspectMode.FitInParent;
            videoFit.aspectRatio = 16f / 9f;
            var cinematic = filmPanel.AddComponent<OpeningCinematicPresenter>();
            var filmData = new SerializedObject(cinematic);
            ConfigureShot(filmData, "school", schoolClip, schoolPoster, schoolAudio);
            ConfigureShot(filmData, "laboratory", laboratoryClip, laboratoryPoster, pressureAir);
            ConfigureShot(filmData, "experiment", experimentClip, experimentPoster, pressureAir);
            ConfigureShot(filmData, "memory", Load<VideoClip>("Opening3D-threshold.mp4"),
                Load<Texture2D>("Opening3D-threshold.png"), Load<AudioClip>("MemoryFriends.ogg"));
            Set(filmData, "surface", surface);
            Set(filmData, "player", video);
            Set(filmData, "ambience", audio);
            filmData.ApplyModifiedPropertiesWithoutUndo();

            var strip = Element("Dialogue and Playback", filmPanel.transform, 0, 0, 1, 0.27f);
            strip.AddComponent<Image>();
            CinematicDialogueStyle.Apply(strip, CinematicDialogueStyle.Palette.Laboratory);
            var dialogue = Label("Dialogue", strip.transform, font, "", 24, 0.06f, 0.56f, 0.94f, 0.96f);
            CinematicDialogueStyle.Story(dialogue);
            var next = EntryStyle.Action("Continue", filmPanel.transform, font, "Forward", 0.40f, 0.045f, 0.60f, 0.12f, 21, 0.50f);
            var pause = EntryStyle.Action("Pause", filmPanel.transform, font, "Pause", 0.025f, 0.91f, 0.15f, 0.975f, 16, 0.34f);
            var skip = EntryStyle.Action("Skip shot", filmPanel.transform, font, "Forward", 0.81f, 0.04f, 0.97f, 0.105f, 17, 0.36f);
            skip.gameObject.AddComponent<CanvasGroup>().alpha = 0f;
            var aboutExperiment = EntryStyle.Action("What is this experiment?", strip.transform, font, "Reference", 0.16f, 0.16f, 0.39f, 0.5f, 18, 0.55f);
            var aboutSafety = EntryStyle.Action("What about safety?", strip.transform, font, "Reference", 0.40f, 0.16f, 0.62f, 0.5f, 18, 0.55f);
            var ready = EntryStyle.Action("I am ready.", strip.transform, font, "Forward", 0.63f, 0.16f, 0.84f, 0.5f, 18, 0.55f);
            var back = EntryStyle.Action("Back to questions", strip.transform, font, "Undo", 0.38f, 0.16f, 0.62f, 0.5f, 18, 0.55f);
            var motion = EntryStyle.Action("Full motion", filmPanel.transform, font, "Pause", 0.70f, 0.91f, 0.83f, 0.975f, 16, 0.34f);
            var sound = EntryStyle.Action("Sound on", filmPanel.transform, font, "Sound", 0.84f, 0.91f, 0.975f, 0.975f, 16, 0.34f);
            UnityEventTools.AddPersistentListener(next.onClick, cinematic.ContinueShot);
            UnityEventTools.AddPersistentListener(skip.onClick, host.Skip);
            UnityEventTools.AddPersistentListener(pause.onClick, cinematic.TogglePause);
            UnityEventTools.AddPersistentListener(aboutExperiment.onClick, cinematic.AskAboutExperiment);
            UnityEventTools.AddPersistentListener(aboutSafety.onClick, cinematic.AskAboutSafety);
            UnityEventTools.AddPersistentListener(ready.onClick, cinematic.BeginExperiment);
            UnityEventTools.AddPersistentListener(back.onClick, cinematic.ReturnToQuestions);
            UnityEventTools.AddPersistentListener(motion.onClick, host.ToggleMotion);
            UnityEventTools.AddPersistentListener(sound.onClick, host.ToggleSound);
            var hostData = new SerializedObject(host);
            Set(hostData, "coverPanel", coverPanel);
            Set(hostData, "filmPanel", filmPanel);
            Set(hostData, "cinematic", cinematic);
            Set(hostData, "dialogue", dialogue);
            Set(hostData, "nextShot", next);
            Set(hostData, "skip", skip);
            Set(hostData, "skipGroup", skip.GetComponent<CanvasGroup>());
            Set(hostData, "playGlyph", EntryStyle.Artwork<Texture2D>("Play"));
            Set(hostData, "pauseGlyph", EntryStyle.Artwork<Texture2D>("Pause"));
            Set(hostData, "soundGlyph", EntryStyle.Artwork<Texture2D>("Sound"));
            Set(hostData, "muteGlyph", EntryStyle.Artwork<Texture2D>("Mute"));
            Set(hostData, "pause", pause);
            Set(hostData, "experimentQuestion", aboutExperiment);
            Set(hostData, "safetyQuestion", aboutSafety);
            Set(hostData, "ready", ready);
            Set(hostData, "back", back);
            Set(hostData, "motion", motion);
            Set(hostData, "sound", sound);
            hostData.ApplyModifiedPropertiesWithoutUndo();
            filmPanel.SetActive(false);

            var events = new GameObject("UI Events", typeof(EventSystem), typeof(InputSystemUIInputModule));
            events.GetComponent<EventSystem>().firstSelectedGameObject = firstTile;
            events.GetComponent<InputSystemUIInputModule>().AssignDefaultActions();
            if (!AssetDatabase.IsValidFolder(Root + "/Scenes")) AssetDatabase.CreateFolder(Root, "Scenes");
            if (!EditorSceneManager.SaveScene(scene, ScenePath)) throw new IOException("Failed to save the opening review scene.");
        }

        private static GameObject MakePieces(Transform board, CoverRecoveryPresenter presenter, RawImage[] pieces, Image[] edges)
        {
            for (var position = 0; position < pieces.Length; position++)
            {
                var column = position % CoverPuzzle.Columns;
                var row = CoverPuzzle.Rows - 1 - position / CoverPuzzle.Columns;
                var tile = Element($"Piece {position + 1}", board, column / 2f, row / 3f, (column + 1) / 2f, (row + 1) / 3f);
                pieces[position] = tile.AddComponent<RawImage>();
                var edge = EntryStyle.Glass(Element("Tile edge", tile.transform, 0, 0, 1, 1));
                edge.fillCenter = false;
                edges[position] = edge;
                var button = tile.AddComponent<Button>();
                button.targetGraphic = pieces[position];
                var input = tile.AddComponent<CoverTileInput>();
                var data = new SerializedObject(input);
                Set(data, "cover", presenter);
                data.FindProperty("position").intValue = position;
                data.ApplyModifiedPropertiesWithoutUndo();
                UnityEventTools.AddPersistentListener(button.onClick, input.Select);
            }
            for (var index = 0; index < pieces.Length; index++)
            {
                var button = pieces[index].GetComponent<Button>();
                var nav = button.navigation;
                nav.mode = Navigation.Mode.Explicit;
                nav.selectOnLeft = index % 2 == 1 ? pieces[index - 1].GetComponent<Button>() : null;
                nav.selectOnRight = index % 2 == 0 ? pieces[index + 1].GetComponent<Button>() : null;
                nav.selectOnUp = index >= 2 ? pieces[index - 2].GetComponent<Button>() : null;
                nav.selectOnDown = index < 4 ? pieces[index + 2].GetComponent<Button>() : null;
                button.navigation = nav;
            }
            return pieces[0].gameObject;
        }

        private static void ConfigureShot(SerializedObject target, string field, VideoClip clip, Texture2D poster, AudioClip audio)
        {
            var shot = target.FindProperty(field);
            shot.FindPropertyRelative("clip").objectReferenceValue = clip;
            shot.FindPropertyRelative("poster").objectReferenceValue = poster;
            shot.FindPropertyRelative("ambience").objectReferenceValue = audio;
        }

        private static T Load<T>(string name) where T : UnityEngine.Object =>
            AssetDatabase.LoadAssetAtPath<T>(Media + name) ?? throw new InvalidOperationException($"Unity has not imported {name} as {typeof(T).Name}.");

        private static void Set(SerializedObject target, string field, UnityEngine.Object value) =>
            target.FindProperty(field).objectReferenceValue = value;

        internal static GameObject Element(string name, Transform parent, float left, float bottom, float right, float top)
        {
            var item = new GameObject(name, typeof(RectTransform));
            var rect = item.GetComponent<RectTransform>();
            rect.SetParent(parent, false);
            rect.anchorMin = new Vector2(left, bottom);
            rect.anchorMax = new Vector2(right, top);
            rect.offsetMin = Vector2.zero;
            rect.offsetMax = Vector2.zero;
            return item;
        }

        internal static RawImage Picture(string name, Transform parent, float left, float bottom, float right, float top)
        {
            var picture = Element(name, parent, left, bottom, right, top).AddComponent<RawImage>();
            picture.raycastTarget = false;
            return picture;
        }

        internal static Text Label(string name, Transform parent, Font font, string copy, int size, float left, float bottom, float right, float top)
        {
            var label = Element(name, parent, left, bottom, right, top).AddComponent<Text>();
            label.font = font;
            label.fontSize = size;
            label.text = copy;
            label.alignment = TextAnchor.MiddleCenter;
            label.raycastTarget = false;
            return label;
        }

        internal static Button Control(string title, Transform parent, Font font, float left, float bottom, float right, float top)
        {
            var control = Element(title, parent, left, bottom, right, top);
            var image = control.AddComponent<Image>();
            image.color = ControlColor;
            var button = control.AddComponent<Button>();
            button.targetGraphic = image;
            Label("Label", control.transform, font, title, 18, 0, 0, 1, 1);
            return button;
        }
    }
}
