using ElevenEleven.Opening;
using UnityEditor;
using UnityEditor.Events;
using UnityEngine;
using UnityEngine.UI;

namespace ElevenEleven.Editor
{
    internal static class ChapterAccountGateBuilder
    {
        private static readonly Color Bright = new Color(.92f, .96f, 1f);
        private static readonly Color Subtle = new Color(.65f, .76f, .86f);

        internal static void Install(Transform canvas, CanvasGroup titleActions, Selectable titleFocus, string httpsOrigin = "")
        {
            var font = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
            var arabic = AssetDatabase.LoadAssetAtPath<Font>("Assets/ElevenEleven/Opening/Media/NotoSansArabic.ttf");
            var overlay = Box("Account entry", canvas, 0f, 0f, 1f, 1f);
            overlay.gameObject.AddComponent<Image>().color = new Color(.008f, .015f, .029f, .48f);
            var panel = Box("Account panel", overlay, .27f, .25f, .73f, .75f);
            Panel(panel, new Color(.023f, .049f, .087f, .94f));
            Panel(Box("Panel upper edge", panel, 0f, .996f, 1f, 1f), new Color(.26f, .61f, .78f, .68f));

            var heading = Label("Account heading", "Sign in", panel, .07f, .76f, .93f, .94f, font, 35, Bright);
            heading.fontStyle = FontStyle.Bold;
            var status = Label("Account status", "", panel, .075f, .22f, .925f, .40f, font, 18, Subtle);
            status.horizontalOverflow = HorizontalWrapMode.Wrap;
            var guest = Provider("Play as guest", "Guest", "Guest caption", ChapterAccountIcon.Mark.Guest, panel, .075f, .345f, font);
            var google = Provider("Sign in with Google", "Google", "Google caption", ChapterAccountIcon.Mark.Google, panel, .365f, .635f, font);
            var facebook = Provider("Facebook unavailable", "Facebook", "Facebook caption", ChapterAccountIcon.Mark.Facebook, panel, .655f, .925f, font);
            facebook.interactable = false;

            var browser = Box("Browser connection", panel, .075f, .065f, .925f, .22f);
            var paste = Action("Paste connection code", "Paste code", "Paste caption", browser, 0f, .48f, font);
            var renew = Action("New account connection", "New connection", "Renew caption", browser, .52f, 1f, font);
            browser.gameObject.SetActive(false);

            var gate = overlay.gameObject.AddComponent<ChapterAccountGate>();
            var fields = new SerializedObject(gate);
            fields.FindProperty("titleActions").objectReferenceValue = titleActions;
            fields.FindProperty("titleFocus").objectReferenceValue = titleFocus;
            fields.FindProperty("guest").objectReferenceValue = guest;
            fields.FindProperty("google").objectReferenceValue = google;
            fields.FindProperty("facebook").objectReferenceValue = facebook;
            fields.FindProperty("paste").objectReferenceValue = paste;
            fields.FindProperty("renew").objectReferenceValue = renew;
            fields.FindProperty("browserActions").objectReferenceValue = browser.gameObject;
            fields.FindProperty("status").objectReferenceValue = status;
            fields.FindProperty("arabicFont").objectReferenceValue = arabic;
            fields.FindProperty("accountOrigin").stringValue = httpsOrigin ?? "";
            fields.ApplyModifiedPropertiesWithoutUndo();

            UnityEventTools.AddPersistentListener(guest.onClick, gate.PlayAsGuest);
            UnityEventTools.AddPersistentListener(google.onClick, gate.OpenAccountWebsite);
            UnityEventTools.AddPersistentListener(paste.onClick, gate.PasteConnectionCode);
            UnityEventTools.AddPersistentListener(renew.onClick, gate.NewConnection);
        }

        private static Button Provider(string name, string copy, string caption, ChapterAccountIcon.Mark mark, Transform parent,
            float left, float right, Font font)
        {
            var rect = Box(name, parent, left, .43f, right, .74f);
            var button = ButtonSurface(rect);
            var iconRect = Box("Provider icon", rect, .29f, .33f, .71f, .95f);
            var icon = iconRect.gameObject.AddComponent<ChapterAccountIcon>();
            icon.SetMark(mark);
            icon.raycastTarget = false;
            Label(caption, copy, rect, .03f, .06f, .97f, .41f, font, 19, Bright);
            return button;
        }

        private static Button Action(string name, string copy, string caption, Transform parent, float left, float right, Font font)
        {
            var rect = Box(name, parent, left, 0f, right, 1f);
            var button = ButtonSurface(rect);
            Label(caption, copy, rect, .02f, 0f, .98f, 1f, font, 18, Bright);
            return button;
        }

        private static Button ButtonSurface(RectTransform rect)
        {
            var surface = rect.gameObject.AddComponent<Image>();
            var button = rect.gameObject.AddComponent<Button>();
            button.targetGraphic = surface;
            button.colors = new ColorBlock
            {
                colorMultiplier = 1f,
                fadeDuration = .1f,
                normalColor = new Color(.15f, .27f, .37f, .53f),
                highlightedColor = new Color(.20f, .39f, .52f, .82f),
                selectedColor = new Color(.21f, .42f, .54f, .9f),
                pressedColor = new Color(.30f, .55f, .65f, .92f),
                disabledColor = new Color(.11f, .18f, .25f, .40f),
            };
            return button;
        }

        private static void Panel(RectTransform rect, Color color)
        {
            var image = rect.gameObject.AddComponent<Image>();
            image.color = color;
            image.raycastTarget = false;
        }

        private static Text Label(string name, string copy, Transform parent, float left, float bottom, float right, float top,
            Font font, int size, Color color)
        {
            var label = Box(name, parent, left, bottom, right, top).gameObject.AddComponent<Text>();
            label.font = font;
            label.fontSize = size;
            label.color = color;
            label.alignment = TextAnchor.MiddleCenter;
            label.text = copy;
            label.raycastTarget = false;
            label.resizeTextForBestFit = true;
            label.resizeTextMinSize = 13;
            label.resizeTextMaxSize = size;
            return label;
        }

        private static RectTransform Box(string name, Transform parent, float left, float bottom, float right, float top)
        {
            var rect = (RectTransform)new GameObject(name, typeof(RectTransform)).transform;
            rect.SetParent(parent, false);
            rect.anchorMin = new Vector2(left, bottom);
            rect.anchorMax = new Vector2(right, top);
            rect.offsetMin = Vector2.zero;
            rect.offsetMax = Vector2.zero;
            return rect;
        }
    }
}
