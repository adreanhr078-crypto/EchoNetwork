using System;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace ElevenEleven.Opening
{
    public sealed class ChapterLoadingView : MonoBehaviour
    {
        [SerializeField] private Text message;
        [SerializeField] private RectTransform progress;
        [SerializeField] private RectTransform fill;
        [SerializeField] private Button retry;
        [SerializeField] private Button back;
        [SerializeField] private Font arabicFont;

        internal enum Phase { Opening, Room, Preparing, Returning, Error }
        private Action onRetry;
        private Action onBack;
        private bool rightToLeft;

        private void Awake()
        {
            retry.onClick.AddListener(() => onRetry?.Invoke());
            back.onClick.AddListener(() => onBack?.Invoke());
        }

        internal void Show(Phase phase, Action cancel = null, Action retryLoad = null)
        {
            rightToLeft = Application.systemLanguage == SystemLanguage.Arabic;
            onBack = cancel;
            onRetry = retryLoad;
            gameObject.SetActive(true);
            if (rightToLeft) message.font = arabicFont;
            message.alignment = rightToLeft ? TextAnchor.MiddleRight : TextAnchor.MiddleLeft;
            message.text = rightToLeft ? Arabic(phase) : English(phase);
            var hasProgress = phase == Phase.Opening || phase == Phase.Room || phase == Phase.Preparing;
            progress.gameObject.SetActive(hasProgress);
            SetProgress(phase == Phase.Preparing ? 1f : 0f);
            retry.gameObject.SetActive(retryLoad != null);
            back.gameObject.SetActive(cancel != null);
            PresentButton(retry, rightToLeft ? RetryArabic : "Try again", rightToLeft ? 0.53f : 0.06f);
            PresentButton(back, rightToLeft ? BackArabic : "Back to title", rightToLeft ? 0.06f : 0.53f);
            SetNavigation(retry, rightToLeft ? back : null, rightToLeft ? null : back);
            SetNavigation(back, rightToLeft ? null : retry, rightToLeft ? retry : null);
            if (EventSystem.current != null)
                EventSystem.current.SetSelectedGameObject(retryLoad != null ? retry.gameObject : cancel != null ? back.gameObject : null);
        }

        internal void ShowStartup()
        {
            Show(Phase.Preparing);
            message.font = arabicFont;
            message.alignment = TextAnchor.MiddleCenter;
            message.text = EntryCopy.Arabic ? "…ﺔﻳﺍﺪﺒﻟﺍ ﺰﻴﻬﺠﺗ ﺭﺎﺟ" : "Preparing the opening…";
            progress.gameObject.SetActive(false);
        }

        internal void SetProgress(float value)
        {
            value = Mathf.Clamp01(value);
            fill.anchorMin = new Vector2(rightToLeft ? 1f - value : 0f, 0f);
            fill.anchorMax = new Vector2(rightToLeft ? 1f : value, 1f);
        }

        private void PresentButton(Button button, string copy, float left)
        {
            var rect = (RectTransform)button.transform;
            rect.anchorMin = new Vector2(left, rect.anchorMin.y);
            rect.anchorMax = new Vector2(left + 0.41f, rect.anchorMax.y);
            var label = button.GetComponentInChildren<Text>(true);
            if (rightToLeft) label.font = arabicFont;
            label.text = copy;
        }

        private static void SetNavigation(Selectable button, Selectable left, Selectable right)
        {
            button.navigation = new Navigation
            {
                mode = Navigation.Mode.Explicit,
                selectOnLeft = left != null && left.gameObject.activeSelf ? left : null,
                selectOnRight = right != null && right.gameObject.activeSelf ? right : null,
            };
        }

        private static string English(Phase phase) => phase switch
        {
            Phase.Opening => "Loading the opening…",
            Phase.Room => "Loading Room 01…",
            Phase.Preparing => "Preparing the camera and floor…",
            Phase.Returning => "Returning to the title…",
            _ => "The scene could not load.",
        };

        // Legacy UGUI lays out left to right. These short fixed labels use the font's visual-order forms.
        private const string RetryArabic = "ﺍﺩﺪﺠﻣ ﻝﻭﺎﺣ";
        private const string BackArabic = "ﻥﺍﻮﻨﻌﻟﺍ ﻰﻟﺇ ﺓﺩﻮﻌﻟﺍ";
        private static string Arabic(Phase phase) => phase switch
        {
            Phase.Opening => "…ﺡﺎﺘﺘﻓﻻﺍ ﻞﻴﻤﺤﺗ ﺭﺎﺟ",
            Phase.Room => "…ﻰﻟﻭﻷﺍ ﺔﻓﺮﻐﻟﺍ ﻞﻴﻤﺤﺗ ﺭﺎﺟ",
            Phase.Preparing => "…ﺔﻴﺿﺭﻷﺍﻭ ﺍﺮﻴﻣﺎﻜﻟﺍ ﺰﻴﻬﺠﺗ ﺭﺎﺟ",
            Phase.Returning => "…ﻥﺍﻮﻨﻌﻟﺍ ﻰﻟﺇ ﻉﻮﺟﺮﻟﺍ ﺭﺎﺟ",
            _ => ".ﺪﻬﺸﻤﻟﺍ ﻞﻴﻤﺤﺗ ﺭﺬﻌﺗ",
        };
    }
}
