using ElevenEleven.Opening;
using UnityEditor;
using UnityEngine;
using UnityEngine.UI;

namespace ElevenEleven.Editor
{
    internal static class CinematicDialogueStyle
    {
        internal enum Palette { Laboratory, Zero, Kinja, Ward, System }

        internal static void Apply(GameObject plate, Palette palette)
        {
            var image = plate.GetComponent<Image>();
            image.color = Color.white;
            image.material = Glass(palette);
            image.raycastTarget = false;
            plate.AddComponent<CanvasGroup>();
            if (palette != Palette.System) plate.AddComponent<DialogueGlassMotion>();
        }

        internal static void Story(Text text)
        {
            text.gameObject.AddComponent<StoryTextReveal>();
            var shadow = text.gameObject.AddComponent<Shadow>();
            shadow.effectColor = new Color(0.014f, 0.024f, 0.06f, 0.86f);
            shadow.effectDistance = new Vector2(1f, -1f);
        }

        internal static void RefineHud(Transform hud)
        {
            var skin = ButtonSkin();
            foreach (var name in new[] { "Back to title", "Inspect  [E]", "Interact", "Jump", "Pact strike", "Skip vista" })
            {
                var control = hud.Find(name);
                if (control != null && control.TryGetComponent<Button>(out var button))
                    Round(button, skin);
            }

            var examination = hud.Find("Examination dialogue");
            Refine(examination.Find("Examination caption"), Palette.Laboratory);
            var leave = examination.Find("Leave trial");
            var back = (RectTransform)hud.Find("Back to title");
            Place(leave, back.anchorMin.x, back.anchorMin.y, back.anchorMax.x, back.anchorMax.y);
            Round(leave.GetComponent<Button>(), skin);
            Refine(hud.Find("Zero pact dialogue/Decision plate"), Palette.Zero);
            Refine(hud.Find("Kinja decision/Kinja caption"), Palette.Kinja);
            var ward = hud.Find("Hospital recovery/Recovery caption");
            Refine(ward, Palette.Ward);
            Place(ward, 0.215f, 0.032f, 0.785f, 0.232f);
            var speaker = ward.Find("Ward speaker").GetComponent<Text>();
            speaker.fontSize = 21;
            speaker.verticalOverflow = VerticalWrapMode.Overflow;
            speaker.color = new Color(0.67f, 0.91f, 0.94f);
            Place(speaker.transform, 0.11f, 0.71f, 0.89f, 0.95f);
            var line = ward.Find("Ward line").GetComponent<Text>();
            line.fontSize = 23;
            line.resizeTextForBestFit = true;
            line.resizeTextMinSize = 16;
            line.resizeTextMaxSize = 23;
            Place(line.transform, 0.085f, 0.30f, 0.915f, 0.72f);
            var action = ward.Find("Ward advance");
            Place(action, 0.34f, 0.052f, 0.66f, 0.285f);
            Glyph(action, "Advance chevron", "DialogueChevron", new Color(0.80f, 0.97f, 0.98f),
                0.89f, 0.50f, 16f);
            Place(action.Find("Label"), 0.03f, 0, 0.85f, 1);
        }

        private static void Refine(Transform plate, Palette palette)
        {
            var old = plate.Find("Dialogue trace icon");
            if (old != null) Object.DestroyImmediate(old.gameObject);

            var accent = Glass(palette).GetColor("_Edge");
            var icon = palette switch
            {
                Palette.Ward => "DialogueWard",
                Palette.Zero => "DialoguePact",
                _ => "DialogueSpeech",
            };
            Glyph(plate, "Dialogue context", icon, Color.Lerp(accent, Color.white, 0.40f),
                0.068f, 0.82f, 25f);

            var skin = ButtonSkin();
            foreach (var button in plate.GetComponentsInChildren<Button>(true))
            {
                Round(button, skin);
                button.image.color = Color.Lerp(new Color(0.20f, 0.29f, 0.37f, 0.93f), accent, 0.13f);
                var states = button.colors;
                states.normalColor = Color.white;
                states.highlightedColor = new Color(1.27f, 1.26f, 1.23f, 1f);
                states.selectedColor = states.highlightedColor;
                states.pressedColor = new Color(0.74f, 0.80f, 0.87f, 1f);
                states.fadeDuration = 0.13f;
                button.colors = states;
                var label = button.GetComponentInChildren<Text>(true);
                label.color = new Color(0.93f, 0.97f, 1f);
                label.verticalOverflow = VerticalWrapMode.Overflow;
            }
        }

        private static void Glyph(Transform parent, string name, string asset, Color color,
            float horizontal, float vertical, float size)
        {
            var existing = parent.Find(name);
            var icon = existing != null ? existing.GetComponent<RawImage>() :
                OpeningReviewSceneBuilder.Picture(name, parent, horizontal, vertical, horizontal, vertical);
            if (icon.TryGetComponent<AspectRatioFitter>(out var fitter)) Object.DestroyImmediate(fitter);
            var rect = icon.rectTransform;
            rect.anchorMin = rect.anchorMax = new Vector2(horizontal, vertical);
            rect.anchoredPosition = Vector2.zero;
            rect.sizeDelta = new Vector2(size, size);
            icon.texture = EntryStyle.Artwork<Texture2D>(asset);
            icon.color = color;
        }

        private static Sprite ButtonSkin()
        {
            const string path = "Assets/ElevenEleven/Opening/Media/Interface/DialogueAction.png";
            var importer = (TextureImporter)AssetImporter.GetAtPath(path);
            if (importer.textureType != TextureImporterType.Sprite)
            {
                importer.textureType = TextureImporterType.Sprite;
                importer.spriteImportMode = SpriteImportMode.Single;
                importer.spriteBorder = new Vector4(16f, 16f, 16f, 16f);
                importer.alphaIsTransparency = true;
                importer.mipmapEnabled = false;
                importer.SaveAndReimport();
            }
            return AssetDatabase.LoadAssetAtPath<Sprite>(path);
        }

        private static void Round(Button button, Sprite skin)
        {
            button.image.sprite = skin;
            button.image.type = Image.Type.Sliced;
            button.image.pixelsPerUnitMultiplier = 1.75f;
        }

        private static void Place(Transform element, float left, float bottom, float right, float top)
        {
            var rect = (RectTransform)element;
            rect.anchorMin = new Vector2(left, bottom);
            rect.anchorMax = new Vector2(right, top);
            rect.offsetMin = Vector2.zero;
            rect.offsetMax = Vector2.zero;
        }

        internal static StationSystemBanner System(Transform hud, Font font)
        {
            var panel = OpeningReviewSceneBuilder.Element("System objective hologram", hud, 0.335f, 0.605f, 0.665f, 0.675f);
            panel.AddComponent<Image>();
            Apply(panel, Palette.System);
            var group = panel.GetComponent<CanvasGroup>();
            group.blocksRaycasts = false;
            group.interactable = false;
            group.alpha = 0f;
            var text = OpeningReviewSceneBuilder.Label("System objective", panel.transform, font, "", 18, 0.055f, 0.1f, 0.945f, 0.90f);
            text.color = new Color(0.68f, 0.94f, 1f);
            text.resizeTextForBestFit = true;
            text.resizeTextMinSize = 13;
            text.resizeTextMaxSize = 18;
            text.raycastTarget = false;
            var banner = panel.AddComponent<StationSystemBanner>();
            StormworksConstruction.Wire(banner, ("group", group), ("text", text));
            return banner;
        }

        private static Material Glass(Palette palette)
        {
            var path = "Assets/ElevenEleven/Opening/Media/Dialogue" + palette + ".mat";
            var material = AssetDatabase.LoadAssetAtPath<Material>(path);
            if (material != null) return material;
            material = new Material(Shader.Find("ElevenEleven/Dialogue Glass"));
            switch (palette)
            {
                case Palette.System:
                    Assign(material, new Color(0.035f, 0.15f, 0.37f, 0.71f), new Color(0.03f, 0.24f, 0.52f, 0.64f), new Color(0.14f, 0.78f, 1f));
                    material.SetFloat("_Drift", 0f);
                    break;
                case Palette.Zero:
                    Assign(material, new Color(0.04f, 0.07f, 0.24f, 0.92f), new Color(0.30f, 0.035f, 0.39f, 0.87f), new Color(0.72f, 0.25f, 1f));
                    break;
                case Palette.Kinja:
                    Assign(material, new Color(0.18f, 0.035f, 0.065f, 0.92f), new Color(0.28f, 0.085f, 0.20f, 0.89f), new Color(1f, 0.36f, 0.53f));
                    break;
                case Palette.Ward:
                    Assign(material, new Color(0.02f, 0.16f, 0.22f, 0.91f), new Color(0.10f, 0.11f, 0.33f, 0.88f), new Color(0.19f, 0.89f, 0.96f));
                    break;
                default:
                    Assign(material, new Color(0.025f, 0.17f, 0.27f, 0.91f), new Color(0.16f, 0.04f, 0.34f, 0.88f), new Color(0.20f, 0.84f, 1f));
                    break;
            }
            AssetDatabase.CreateAsset(material, path);
            return material;
        }

        private static void Assign(Material material, Color left, Color right, Color edge)
        {
            material.SetColor("_Near", left);
            material.SetColor("_Far", right);
            material.SetColor("_Edge", edge);
        }
    }
}
