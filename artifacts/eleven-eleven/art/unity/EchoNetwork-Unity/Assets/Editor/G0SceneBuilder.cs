#if UNITY_EDITOR
using EchoNetwork.UnityG0;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace EchoNetwork.UnityG0.Editor
{
    /// <summary>
    /// Rebuilds the bounded G0 room using Unity-native scene objects while
    /// referencing the migrated FBX assets. This is deliberately not a world
    /// builder and never touches the web application's current runtime.
    /// </summary>
    public static class G0SceneBuilder
    {
        private const string ScenePath = "Assets/Scenes/G0_Sector11_Escape.unity";
        private const string RoomAssetPath = "Assets/Art/FBX/Sector11_G0_Room.fbx";
        private const string EchoAssetPath = "Assets/Art/FBX/Echo_G0_MotionStudy.fbx";

        [MenuItem("11.11/Build G0 Sector 11 Escape Scene")]
        public static void BuildAndSave()
        {
            // Never replace an artist's open scene during an assembly reload.
            if (EditorApplication.isPlayingOrWillChangePlaymode)
                throw new System.InvalidOperationException("Stop Play Mode before rebuilding G0.");
            if (AssetDatabase.LoadAssetAtPath<GameObject>(RoomAssetPath) == null ||
                AssetDatabase.LoadAssetAtPath<GameObject>(EchoAssetPath) == null)
                throw new System.InvalidOperationException("Both migrated FBX assets must import before scene creation.");
            if (!Application.isBatchMode &&
                (!EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo() ||
                 !EditorUtility.DisplayDialog("Rebuild G0", "Replace the generated G0 scene on disk?", "Rebuild", "Cancel")))
                return;
            var scene = BuildScene();
            if (!EditorSceneManager.SaveScene(scene, ScenePath))
                throw new System.IO.IOException("Could not save the generated G0 scene.");
            EditorBuildSettings.scenes = new[] { new EditorBuildSettingsScene(ScenePath, true) };
            Debug.Log($"UNITY_G0_SCENE_BUILT path={ScenePath}");
        }

        public static void BuildAndSmoke()
        {
            BuildAndSave();
            // Building a scene is not a Play Mode, collision or visual parity test.
            Debug.Log("UNITY_G0_SCENE_SERIALIZED_RUNTIME_UNVERIFIED");
        }

        private static Scene BuildScene()
        {
            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            var root = new GameObject("G0_Sector11_Escape");
            var bootstrap = root.AddComponent<UnityG0Bootstrap>();
            root.AddComponent<G0SmokeProbe>();

            var roomAnchor = new GameObject("Sector11Room_Imported").transform;
            roomAnchor.SetParent(root.transform, false);
            var roomAsset = AssetDatabase.LoadAssetAtPath<GameObject>(RoomAssetPath);
            if (roomAsset != null)
            {
                var room = (GameObject)PrefabUtility.InstantiatePrefab(roomAsset, roomAnchor);
                room.name = "Sector11Room_BlenderBridge";
            }
            else
            {
                Debug.LogWarning($"UNITY_G0_ROOM_FBX_PENDING path={RoomAssetPath}");
            }

            var echoSpawn = new GameObject("EchoSpawn").transform;
            echoSpawn.SetParent(root.transform, false);
            echoSpawn.position = new Vector3(0f, 0.05f, 0.7f);
            var echoAsset = AssetDatabase.LoadAssetAtPath<GameObject>(EchoAssetPath);
            if (echoAsset != null)
            {
                var echo = (GameObject)PrefabUtility.InstantiatePrefab(echoAsset, echoSpawn);
                echo.name = "Echo_G0_MotionStudy_Imported";
                echo.transform.localRotation = Quaternion.Euler(0f, 180f, 0f);
            }

            bootstrap.GetType().GetField(
                "roomAsset",
                System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance)
                ?.SetValue(bootstrap, roomAsset);
            bootstrap.GetType().GetField(
                "echoAsset",
                System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance)
                ?.SetValue(bootstrap, echoAsset);
            bootstrap.GetType().GetField(
                "roomAnchor",
                System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance)
                ?.SetValue(bootstrap, roomAnchor);
            bootstrap.GetType().GetField(
                "echoSpawn",
                System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance)
                ?.SetValue(bootstrap, echoSpawn);

            BuildPlayer(root.transform, echoSpawn);
            BuildCamera(root.transform, echoSpawn);
            BuildLighting(root.transform);
            BuildCollisionShell(root.transform);
            BuildInteractables(root.transform);
            return scene;
        }

        private static void BuildCollisionShell(Transform parent)
        {
            // Mirrors the Godot G0 bounds as collision-only objects. The authored
            // GLB remains visual; no procedural renderer may replace it.
            CreateCollision(parent, "FloorCollision", new Vector3(0f, -0.15f, 0f), new Vector3(15f, 0.3f, 15f));
            CreateCollision(parent, "BackWallCollision", new Vector3(0f, 2f, -7.2f), new Vector3(15f, 4f, 0.3f));
            CreateCollision(parent, "LeftWallCollision", new Vector3(-7.2f, 2f, 0f), new Vector3(0.3f, 4f, 15f));
            CreateCollision(parent, "RightWallCollision", new Vector3(7.2f, 2f, 0f), new Vector3(0.3f, 4f, 15f));
        }

        private static void CreateCollision(Transform parent, string name, Vector3 position, Vector3 size)
        {
            var collision = new GameObject(name);
            collision.transform.SetParent(parent, false);
            collision.transform.position = position;
            collision.AddComponent<BoxCollider>().size = size;
        }

        private static void BuildPlayer(Transform parent, Transform spawn)
        {
            var player = new GameObject("EchoPlayer");
            player.transform.SetParent(parent, false);
            player.transform.position = spawn.position;
            var capsule = player.AddComponent<CharacterController>();
            capsule.height = 1.7f;
            capsule.radius = 0.28f;
            capsule.center = new Vector3(0f, 0.85f, 0f);
            // The visual and controller must travel together.
            spawn.SetParent(player.transform, true);
            var controller = player.AddComponent<ThirdPersonController>();
            var target = new GameObject("CameraTarget").transform;
            target.SetParent(player.transform, false);
            target.localPosition = Vector3.zero;
            typeof(ThirdPersonController)
                .GetField("cameraTarget", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance)
                ?.SetValue(controller, target);
        }

        private static void BuildCamera(Transform parent, Transform target)
        {
            var cameraObject = new GameObject("Main Camera");
            cameraObject.transform.SetParent(parent, false);
            cameraObject.tag = "MainCamera";
            cameraObject.transform.position = target.position + new Vector3(0.55f, 2.2f, 2.5f);
            cameraObject.transform.LookAt(target.position + Vector3.up * 1.35f);
            cameraObject.AddComponent<Camera>().fieldOfView = 47f;
            cameraObject.AddComponent<AudioListener>();
        }

        private static void BuildLighting(Transform parent)
        {
            var lightObject = new GameObject("Key Light");
            lightObject.transform.SetParent(parent, false);
            lightObject.transform.rotation = Quaternion.Euler(38f, -28f, 0f);
            var light = lightObject.AddComponent<Light>();
            light.type = LightType.Directional;
            light.intensity = 1.1f;
            light.color = new Color(0.75f, 0.86f, 1f);
        }

        private static void BuildInteractables(Transform parent)
        {
            CreateInteractable(parent, "SignalNode", new Vector3(-3.0f, 0.8f, -2.6f),
                new Color(0.2f, 0.8f, 1f), G0Interactable.InteractionKind.SignalNode, "Read signal");
            CreateInteractable(parent, "MemoryClue", new Vector3(3.0f, 0.65f, 0.8f),
                new Color(0.65f, 0.2f, 0.95f), G0Interactable.InteractionKind.MemoryClue, "Inspect memory");
            CreateInteractable(parent, "ExitDoor", new Vector3(0f, 1.5f, -6.95f),
                new Color(0.85f, 0.08f, 0.12f), G0Interactable.InteractionKind.ExitDoor, "Attempt escape");
        }

        private static void CreateInteractable(
            Transform parent,
            string name,
            Vector3 position,
            Color color,
            G0Interactable.InteractionKind kind,
            string prompt)
        {
            var objectRoot = GameObject.CreatePrimitive(PrimitiveType.Cube);
            objectRoot.name = name;
            objectRoot.transform.SetParent(parent, false);
            objectRoot.transform.position = position;
            objectRoot.transform.localScale = kind == G0Interactable.InteractionKind.ExitDoor
                ? new Vector3(2.6f, 3.2f, 0.18f)
                : new Vector3(0.45f, 0.45f, 0.45f);
            var material = new Material(Shader.Find("Standard")) { color = color };
            objectRoot.GetComponent<Renderer>().sharedMaterial = material;
            var interactable = objectRoot.AddComponent<G0Interactable>();
            typeof(G0Interactable).GetField("kind", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance)
                ?.SetValue(interactable, kind);
            typeof(G0Interactable).GetField("prompt", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance)
                ?.SetValue(interactable, prompt);
        }
    }
}
#endif
