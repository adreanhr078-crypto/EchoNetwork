using System;
using System.Collections;
using System.Security.Cryptography;
using System.Text;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.Networking;
using UnityEngine.UI;

namespace ElevenEleven.Opening
{
    [DefaultExecutionOrder(100)]
    public sealed class ChapterAccountGate : MonoBehaviour
    {
        public enum EntryMode { Pending, LocalGuest, LinkedAccount }

        [SerializeField] private CanvasGroup titleActions;
        [SerializeField] private Selectable titleFocus;
        [SerializeField] private Button guest;
        [SerializeField] private Button google;
        [SerializeField] private Button facebook;
        [SerializeField] private Button paste;
        [SerializeField] private Button renew;
        [SerializeField] private GameObject browserActions;
        [SerializeField] private Text status;
        [SerializeField] private Font arabicFont;
        [SerializeField] private string accountOrigin;

        public static EntryMode Session { get; private set; }

        private Uri service;
        private string verifier;
        private UnityWebRequest activeRequest;
        private bool arabic;

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
        private static void ResetSession() => Session = EntryMode.Pending;

        private void Awake()
        {
            if (Session != EntryMode.Pending)
            {
                gameObject.SetActive(false);
                return;
            }

            titleActions.alpha = 0f;
            titleActions.interactable = false;
            titleActions.blocksRaycasts = false;
            service = ParseOrigin(accountOrigin);
            arabic = Application.systemLanguage == SystemLanguage.Arabic && arabicFont != null;
            if (arabic) Localize();
            google.interactable = service != null;
            facebook.interactable = false;
            browserActions.SetActive(false);
            SetStatus(service == null ? Copy.NoService : Copy.GoogleAvailable);
        }

        private void Start()
        {
            if (Session == EntryMode.Pending && EventSystem.current != null)
                EventSystem.current.SetSelectedGameObject(guest.gameObject);
        }

        public void PlayAsGuest()
        {
            if (Session == EntryMode.Pending && activeRequest == null) Finish(EntryMode.LocalGuest);
        }

        public void OpenAccountWebsite()
        {
            if (service == null || activeRequest != null || Session != EntryMode.Pending) return;
            if (verifier == null)
            {
                var random = new byte[32];
                using (var generator = RandomNumberGenerator.Create()) generator.GetBytes(random);
                verifier = Encode(random);
            }

            byte[] hash;
            using (var sha = SHA256.Create()) hash = sha.ComputeHash(Encoding.ASCII.GetBytes(verifier));
            Application.OpenURL(service.GetLeftPart(UriPartial.Authority) + "/?native_challenge=" + Encode(hash) + "#/opening-recovery");
            browserActions.SetActive(true);
            SetStatus(Copy.BrowserInstructions);
            if (EventSystem.current != null) EventSystem.current.SetSelectedGameObject(paste.gameObject);
        }

        public void NewConnection()
        {
            if (activeRequest != null) return;
            verifier = null;
            OpenAccountWebsite();
        }

        public void PasteConnectionCode()
        {
            if (service == null || verifier == null || activeRequest != null || Session != EntryMode.Pending) return;
            var code = CleanCode(GUIUtility.systemCopyBuffer);
            if (code == null)
            {
                SetStatus(Copy.InvalidCode);
                return;
            }

            var response = new BoundedResponse();
            var grant = new JObject { ["code"] = code, ["verifier"] = verifier };
            var request = new UnityWebRequest(new Uri(service, "/api/player/native-entry/exchange").AbsoluteUri, "POST")
            {
                uploadHandler = new UploadHandlerRaw(Encoding.UTF8.GetBytes(grant.ToString(Formatting.None))),
                downloadHandler = response,
                redirectLimit = 0,
                timeout = 12,
            };
            request.SetRequestHeader("Content-Type", "application/json");
            activeRequest = request;
            SetBusy(true);
            SetStatus(Copy.Connecting);
            StartCoroutine(Exchange(request, response));
        }

        private IEnumerator Exchange(UnityWebRequest request, BoundedResponse response)
        {
            UnityWebRequestAsyncOperation operation;
            try { operation = request.SendWebRequest(); }
            catch (InvalidOperationException)
            {
                CompleteRequest(request, false);
                yield break;
            }

            yield return operation;
            if (activeRequest != request) yield break;
            var confirmed = request.result == UnityWebRequest.Result.Success && request.responseCode == 200 && IsConfirmed(response.ReadBody());
            CompleteRequest(request, confirmed);
        }

        private void CompleteRequest(UnityWebRequest request, bool confirmed)
        {
            activeRequest = null;
            request.Dispose();
            if (confirmed)
            {
                Finish(EntryMode.LinkedAccount);
                return;
            }

            SetBusy(false);
            SetStatus(Copy.Rejected);
            if (EventSystem.current != null) EventSystem.current.SetSelectedGameObject(paste.gameObject);
        }

        private void SetBusy(bool busy)
        {
            guest.interactable = !busy;
            google.interactable = !busy && service != null;
            paste.interactable = !busy;
            renew.interactable = !busy;
        }

        private void Finish(EntryMode mode)
        {
            Session = mode;
            verifier = null;
            titleActions.alpha = 1f;
            titleActions.interactable = true;
            titleActions.blocksRaycasts = true;
            gameObject.SetActive(false);
            if (titleFocus != null && EventSystem.current != null)
                EventSystem.current.SetSelectedGameObject(titleFocus.gameObject);
        }

        private void OnDisable()
        {
            verifier = null;
            if (activeRequest == null) return;
            var request = activeRequest;
            activeRequest = null;
            StopAllCoroutines();
            request.Abort();
            request.Dispose();
        }

        internal static Uri ParseOrigin(string value)
        {
            if (string.IsNullOrWhiteSpace(value) || value.IndexOf('\\') >= 0 ||
                !Uri.TryCreate(value, UriKind.Absolute, out var origin) || origin.Scheme != Uri.UriSchemeHttps ||
                string.IsNullOrWhiteSpace(origin.Host) || origin.UserInfo.Length != 0 || origin.AbsolutePath != "/" ||
                origin.Query.Length != 0 || origin.Fragment.Length != 0)
                return null;

            return origin;
        }

        internal static string CleanCode(string clipboard)
        {
            if (clipboard == null || clipboard.Length > 96) return null;
            var normalized = new StringBuilder(clipboard.Length);
            foreach (var character in clipboard)
            {
                if (character == '\u200e' || character == '\u200f' ||
                    (character >= '\u202a' && character <= '\u202e') ||
                    (character >= '\u2066' && character <= '\u2069')) continue;
                normalized.Append(character);
            }

            var code = normalized.ToString().Trim();
            if (code.Length != 43) return null;
            foreach (var character in code)
            {
                if (!(character >= 'A' && character <= 'Z') && !(character >= 'a' && character <= 'z') &&
                    !(character >= '0' && character <= '9') && character != '_' && character != '-') return null;
            }

            return code;
        }

        internal static bool IsConfirmed(string payload)
        {
            if (string.IsNullOrEmpty(payload)) return false;
            try
            {
                var result = JObject.Parse(payload, new JsonLoadSettings { DuplicatePropertyNameHandling = DuplicatePropertyNameHandling.Error });
                return result["entryConfirmed"]?.Type == JTokenType.Boolean && (bool)result["entryConfirmed"] &&
                    result["scope"]?.Type == JTokenType.String && (string)result["scope"] == "native-chapter-entry" &&
                    result["coverReceiptId"]?.Type == JTokenType.String && !string.IsNullOrWhiteSpace((string)result["coverReceiptId"]);
            }
            catch (JsonException) { return false; }
        }

        private static string Encode(byte[] value) => Convert.ToBase64String(value).TrimEnd('=').Replace('+', '-').Replace('/', '_');

        private sealed class BoundedResponse : DownloadHandlerScript
        {
            private readonly byte[] body = new byte[16384];
            private int received;

            internal BoundedResponse() : base(new byte[4096]) { }

            protected override bool ReceiveData(byte[] data, int length)
            {
                if (data == null || length <= 0 || length > data.Length || length > body.Length - received) return false;
                Buffer.BlockCopy(data, 0, body, received, length);
                received += length;
                return true;
            }

            internal string ReadBody() => Encoding.UTF8.GetString(body, 0, received);
        }

        private void SetStatus(Copy value) => status.text = arabic ? AccountGateCopy.Arabic(value) : AccountGateCopy.English(value);

        private void Localize()
        {
            foreach (var label in GetComponentsInChildren<Text>(true))
            {
                var translation = AccountGateCopy.Label(label.gameObject.name);
                if (translation == null && label != status) continue;
                label.font = arabicFont;
                if (translation != null) label.text = translation;
            }
        }

        internal enum Copy { NoService, GoogleAvailable, BrowserInstructions, InvalidCode, Connecting, Rejected }
    }
}
