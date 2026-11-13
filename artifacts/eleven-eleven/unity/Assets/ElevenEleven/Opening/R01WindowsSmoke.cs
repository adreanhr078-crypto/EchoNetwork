#if ECHO_R01_VERIFY_EXPORTED_PLAYER
using System;
using System.Collections;
using System.IO;
using System.Linq;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.SceneManagement;
using UnityEngine.UI;

namespace ElevenEleven.Opening
{
    internal sealed class R01WindowsSmoke : MonoBehaviour
    {
        private string output;

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        private static void StartIfRequested()
        {
            var directory = Environment.GetEnvironmentVariable("ECHO_R01_PLAYER_EVIDENCE");
            if (string.IsNullOrEmpty(directory)) return;
            var probe = new GameObject("R01 export verification").AddComponent<R01WindowsSmoke>();
            DontDestroyOnLoad(probe.gameObject);
            probe.output = directory;
            Application.runInBackground = true;
            Application.targetFrameRate = 30;
            probe.StartCoroutine(probe.CheckRoute());
        }

        private IEnumerator CheckRoute()
        {
            yield return null;
            Require(SceneManager.GetActiveScene().name == "ChapterTitle", "Normal title is the first build scene.");
            Press("Motion on");
            Press("Tap to Start");
            yield return Await(() => SceneManager.GetActiveScene().name == "ChapterOpening", "Opening scene");
            yield return null;
            Press("Piece 1");
            Press("Piece 2");
            Press("Piece 5");
            Press("Piece 6");
            yield return Await(() => FindFirstObjectByType<OpeningCinematicPresenter>() != null, "Cover to film");
            Press("Continue");
            Press("Continue");
            Press("I am ready.");
            Press("Continue");
            yield return Await(() => SceneManager.GetActiveScene().name == "ChapterRoom01", "Experiment to Room 01");
            yield return null;
            var actor = FindFirstObjectByType<Room01Player>();
            Require(actor != null && Camera.main != null && Camera.main.isActiveAndEnabled, "Normal Room 01 gameplay camera.");
            var pivot = actor.transform.Find("School65 facing");
            Require(pivot != null, "Default avatar selects the school pivot.");
            var bones = pivot.GetComponentsInChildren<SkinnedMeshRenderer>().SelectMany(mesh => mesh.bones).Distinct().Count();
            Require(bones == 65, "School65 has exactly 65 joints.");
            Require(pivot.GetComponentInChildren<Animation>().IsPlaying("Idle"), "The exported first frame has School Idle.");
            Directory.CreateDirectory(output);
            if (SystemInfo.graphicsDeviceType != GraphicsDeviceType.Null)
                Capture(Camera.main, Path.Combine(output, "room01-exported-gameplay.png"));
            InputSystem.settings.backgroundBehavior = InputSettings.BackgroundBehavior.IgnoreFocus;
            var keyboard = InputSystem.AddDevice<Keyboard>();
            keyboard.MakeCurrent();
            var spawn = actor.transform.position;
            InputSystem.QueueStateEvent(keyboard, new KeyboardState(Key.W));
            InputSystem.Update();
            yield return Await(() => actor.transform.position.z > spawn.z + 0.15f, "School65 walk");
            Require(pivot.GetComponentInChildren<Animation>().IsPlaying("Walk"), "The exported capsule drives School Walk.");
            InputSystem.RemoveDevice(keyboard);
            Debug.Log($"R01_WINDOWS_NORMAL_ROUTE_PASS avatar=School65 bones={bones} graphics={SystemInfo.graphicsDeviceType}");
            File.WriteAllText(Path.Combine(output, "normal-entry.txt"), $"School65\n{bones} bones\n{SystemInfo.graphicsDeviceName}\n{SystemInfo.graphicsDeviceType}\n");
            Application.Quit(0);
        }

        private static IEnumerator Await(Func<bool> condition, string stage)
        {
            var deadline = Time.realtimeSinceStartup + 75f;
            while (!condition() && Time.realtimeSinceStartup < deadline)
                yield return null;
            Require(condition(), "Timed out at " + stage);
        }

        private static void Press(string name)
        {
            var buttons = FindObjectsByType<Button>(FindObjectsInactive.Exclude, FindObjectsSortMode.None);
            var button = Array.Find(buttons, candidate => candidate.name == name);
            Require(button != null && button.interactable, "Unavailable control: " + name);
            button.onClick.Invoke();
        }

        private static void Require(bool condition, string reason)
        {
            if (condition) return;
            Application.Quit(1);
            throw new InvalidOperationException(reason);
        }

        internal static void Capture(Camera camera, string file)
        {
            const int width = 1280;
            const int height = 720;
            var target = new RenderTexture(width, height, 24, RenderTextureFormat.ARGB32);
            var pixels = new Texture2D(width, height, TextureFormat.RGB24, false);
            var oldTarget = RenderTexture.active;
            try
            {
                target.Create();
                var request = new UniversalRenderPipeline.SingleCameraRequest { destination = target };
                Require(RenderPipeline.SupportsRenderRequest(camera, request), "The export's renderer cannot capture the gameplay camera.");
                RenderPipeline.SubmitRenderRequest(camera, request);
                RenderTexture.active = target;
                pixels.ReadPixels(new Rect(0, 0, width, height), 0, 0);
                pixels.Apply();
                File.WriteAllBytes(file, pixels.EncodeToPNG());
            }
            finally
            {
                RenderTexture.active = oldTarget;
                target.Release();
                Destroy(target);
                Destroy(pixels);
            }
        }
    }
}
#endif
