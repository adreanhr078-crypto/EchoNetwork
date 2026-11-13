using UnityEditor;
using UnityEngine;
using UnityEngine.UI;
using static ElevenEleven.Editor.OpeningReviewSceneBuilder;

namespace ElevenEleven.Editor
{
    internal static class EntryStyle
    {
        private const string Art = "Assets/ElevenEleven/Opening/Media/Interface/";
        internal static readonly Color Ice = new Color(0.67f, 0.92f, 1f);
        internal static readonly Color Paper = new Color(0.86f, 0.9f, 1f);

        internal static T Artwork<T>(string name) where T : Object
        {
            var asset = AssetDatabase.LoadAssetAtPath<T>(Art + name + ".png");
            return asset != null ? asset : throw new System.InvalidOperationException($"Missing entry artwork: {name}");
        }

        internal static Image Glass(GameObject item)
        {
            var path = Art + "GlassPlate.png";
            var importer = AssetImporter.GetAtPath(path) as TextureImporter;
            if (importer.textureType != TextureImporterType.Sprite || importer.spriteBorder != new Vector4(20, 20, 20, 20))
            {
                importer.textureType = TextureImporterType.Sprite;
                importer.spriteImportMode = SpriteImportMode.Single;
                importer.spriteBorder = new Vector4(20, 20, 20, 20);
                importer.alphaIsTransparency = true;
                importer.mipmapEnabled = false;
                importer.SaveAndReimport();
            }

            var glass = item.GetComponent<Image>() ?? item.AddComponent<Image>();
            glass.sprite = Artwork<Sprite>("GlassPlate");
            glass.type = Image.Type.Sliced;
            glass.raycastTarget = false;
            return glass;
        }

        internal static Button Action(string name, Transform parent, Font font, string icon,
            float left, float bottom, float right, float top, int fontSize = 19, float opacity = 1f)
        {
            var button = Control(name, parent, font, left, bottom, right, top);
            var glass = Glass(button.gameObject);
            glass.color = new Color(1f, 1f, 1f, opacity);
            glass.raycastTarget = true;
            var colors = button.colors;
            colors.normalColor = Color.white;
            colors.highlightedColor = new Color(0.74f, 0.93f, 1f, 1f);
            colors.selectedColor = new Color(0.70f, 0.88f, 1f, 1f);
            colors.pressedColor = new Color(0.63f, 0.76f, 1f, 1f);
            colors.disabledColor = new Color(0.60f, 0.65f, 0.76f, 0.42f);
            button.colors = colors;
            var label = button.GetComponentInChildren<Text>();
            label.fontSize = fontSize;
            label.color = Paper;
            if (opacity < 1f)
            {
                var shadow = label.gameObject.AddComponent<Shadow>();
                shadow.effectColor = new Color(0.015f, 0.04f, 0.10f, 0.92f);
                shadow.effectDistance = new Vector2(1f, -1f);
                var edge = glass.gameObject.AddComponent<Outline>();
                edge.effectColor = new Color(0.30f, 0.76f, 0.95f, 0.24f);
                edge.effectDistance = new Vector2(1f, -1f);
            }
            label.rectTransform.anchorMin = new Vector2(0.23f, 0);
            label.rectTransform.anchorMax = new Vector2(0.95f, 1);
            label.resizeTextForBestFit = true;
            label.resizeTextMinSize = 12;
            label.resizeTextMaxSize = fontSize;
            var iconSlot = Element("Icon slot", button.transform, 0.05f, 0.20f, 0.23f, 0.80f);
            var glyph = Picture("Icon", iconSlot.transform, 0, 0, 1, 1);
            glyph.texture = Artwork<Texture2D>(icon);
            var ratio = glyph.gameObject.AddComponent<AspectRatioFitter>();
            ratio.aspectMode = AspectRatioFitter.AspectMode.FitInParent;
            ratio.aspectRatio = 1;
            return button;
        }
    }
}
