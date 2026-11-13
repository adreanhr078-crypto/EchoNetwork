using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;

namespace ElevenEleven.Editor
{
    internal static class FaceLayerReview
    {
        private const string Root = "Assets/ElevenEleven/";
        private const int PortraitLayer = 30;
        private static readonly float[] Angles = { 0f, 42f, 86f };
        private static readonly string[] AngleNames = { "front", "three-quarter", "profile" };
        private static readonly Vector3 RecoveryPosition = new Vector3(-0.65f, 2.10f, -2.58f);
        private static readonly Color RecoveryColor = new Color(0.76f, 0.84f, 1f);
        private const float RecoveryIntensity = 1.65f;
        private const float RecoveryRange = 4.8f;

        public static void InstallRecoveryAndTest()
        {
            if (!Application.isBatchMode) throw new InvalidOperationException("Use the isolated Unity batch project.");
            var room = EditorSceneManager.OpenScene(Root + "Scenes/ChapterRoom01.unity");
            var content = room.GetRootGameObjects().Single(root => root.name == "Room content");
            var light = content.GetComponentsInChildren<Light>(true).Single(value => value.name == "Recovery glow");
            light.transform.position = RecoveryPosition;
            light.color = RecoveryColor;
            light.intensity = RecoveryIntensity;
            light.range = RecoveryRange;
            EditorSceneManager.MarkSceneDirty(room);
            if (!EditorSceneManager.SaveScene(room)) throw new IOException("Unable to save the recovery light.");
            ChapterR01Smoke.Run();
        }

        public static void CompareRecovery()
        {
            var output = Environment.GetEnvironmentVariable("ECHO_R08_CAPTURE_DIRECTORY");
            if (!Application.isBatchMode || string.IsNullOrWhiteSpace(output) || Directory.Exists(output) ||
                SystemInfo.graphicsDeviceType == GraphicsDeviceType.Null)
                throw new InvalidOperationException("A new isolated graphics evidence folder is required.");
            Directory.CreateDirectory(output);

            var room = EditorSceneManager.OpenScene(Root + "Scenes/ChapterRoom01.unity");
            var content = room.GetRootGameObjects().Single(root => root.name == "Room content");
            content.SetActive(true);
            var light = content.GetComponentsInChildren<Light>().Single(value => value.name == "Recovery glow");
            var original = (light.transform.position, light.color, light.intensity, light.range);
            var school = content.GetComponentsInChildren<Transform>().Single(item => item.name == "School65 facing");
            var model = school.GetComponentInChildren<Animation>().gameObject;
            var idle = AssetDatabase.LoadAssetAtPath<AnimationClip>(Root + "Echo/Locomotion/SchoolIdle.anim");
            idle.SampleAnimation(model, 0.40f);
            var pact = Import(Root + "MotionReview/echo_pact72_candidate.glb", school.position);
            var camera = new GameObject("Fixed face comparison camera").AddComponent<Camera>();
            camera.enabled = false;
            camera.cullingMask = 1 << PortraitLayer;
            camera.clearFlags = CameraClearFlags.SolidColor;
            camera.backgroundColor = new Color(0.085f, 0.1f, 0.13f);
            camera.nearClipPlane = 0.025f;
            camera.farClipPlane = 12f;
            camera.fieldOfView = 25f;
            var samples = new[]
            {
                ("before", original.position, original.color, original.intensity, original.range),
                ("low", RecoveryPosition, RecoveryColor, 0.95f, RecoveryRange),
                ("mid", RecoveryPosition, RecoveryColor, RecoveryIntensity, RecoveryRange),
            };
            foreach (var actor in new[] { school, pact })
            {
                school.gameObject.SetActive(actor == school);
                pact.gameObject.SetActive(actor == pact);
                foreach (var item in actor.GetComponentsInChildren<Transform>(true)) item.gameObject.layer = PortraitLayer;
                var name = actor == school ? "school65" : "pact72";
                var bones = actor.GetComponentsInChildren<SkinnedMeshRenderer>().SelectMany(value => value.bones).Distinct().ToArray();
                var head = Bone(bones, "Head");
                var up = (head.position - Bone(bones, "Neck").position).normalized;
                var focus = head.position + up * 0.035f + Vector3.forward * 0.05f;
                foreach (var (key, position, color, intensity, range) in samples)
                {
                    light.transform.position = position;
                    light.color = color;
                    light.intensity = intensity;
                    light.range = range;
                    Shot(camera, focus, 0.65f, 0, output, $"{name}-{key}-front");
                    Shot(camera, focus, 0.65f, 42f, output, $"{name}-{key}-three-quarter");
                    Shot(camera, focus - Vector3.up * 0.45f, 2.95f, 42f, output, $"{name}-{key}-play-distance");
                }
            }
            Debug.Log($"R08_FACE_LIGHT_REVIEW_PASS captures=18 device={SystemInfo.graphicsDeviceName}");
            EditorApplication.Exit(0);
        }

        public static void Run()
        {
            var output = Environment.GetEnvironmentVariable("ECHO_R07_CAPTURE_DIRECTORY");
            if (!Application.isBatchMode || string.IsNullOrWhiteSpace(output) || Directory.Exists(output) ||
                SystemInfo.graphicsDeviceType == GraphicsDeviceType.Null)
                throw new InvalidOperationException("A new isolated graphics evidence folder is required.");
            Directory.CreateDirectory(output);

            var room = EditorSceneManager.OpenScene(Root + "Scenes/ChapterRoom01.unity");
            var content = room.GetRootGameObjects().Single(root => root.name == "Room content");
            content.SetActive(true);
            var roomLights = content.GetComponentsInChildren<Light>(true).Where(light => light.enabled).ToArray();
            var roomAmbient = RenderSettings.ambientLight;
            var school = content.GetComponentsInChildren<Transform>(true).Single(item => item.name == "School65 facing");
            var anchor = school.position;
            var godotSchool = Import(Root + "MotionReview/echo_school65_candidate.glb", anchor);
            var pact = Import(Root + "MotionReview/echo_pact72_candidate.glb", anchor);
            var v31 = Import(Root + "MotionReview/echo_v31_short_jacket.glb", anchor);
            var camera = new GameObject("Fixed portrait camera").AddComponent<Camera>();
            camera.enabled = false;
            camera.cullingMask = 1 << PortraitLayer;
            camera.clearFlags = CameraClearFlags.SolidColor;
            camera.backgroundColor = new Color(0.085f, 0.1f, 0.13f);
            camera.nearClipPlane = 0.025f;
            camera.farClipPlane = 12f;
            camera.fieldOfView = 25f;
            var key = Direction("Neutral key", new Vector3(27, 155, 0), 1.15f);
            var fill = Direction("Neutral fill", new Vector3(13, 211, 0), 0.35f);
            var neutral = new[] { key, fill };
            school.gameObject.SetActive(false);
            godotSchool.gameObject.SetActive(false);
            pact.gameObject.SetActive(false);
            v31.gameObject.SetActive(false);

            using var inventory = new StreamWriter(Path.Combine(output, "unity-inventory.tsv"));
            inventory.WriteLine("asset\tbones\trenderers\tmeshes\tmaterials\tblend_shapes\tshader\tsurface\tbase_map\tbase_map_size\tnormal_map");
            var captures = 0;
            captures += Record("school65", school, 65, camera, roomLights, roomAmbient, neutral, output, inventory);
            captures += Record("school65-godot-source", godotSchool, 65, camera, roomLights, roomAmbient, neutral, output, inventory);
            captures += Record("pact72", pact, 72, camera, roomLights, roomAmbient, neutral, output, inventory);
            captures += Record("v31", v31, 68, camera, roomLights, roomAmbient, neutral, output, inventory);
            inventory.Flush();
            Debug.Log($"R07_FACE_CAPTURE_PASS captures={captures} device={SystemInfo.graphicsDeviceName} api={SystemInfo.graphicsDeviceType}");
            EditorApplication.Exit(0);
        }

        private static int Record(string name, Transform actor, int boneCount, Camera camera, Light[] roomLights,
            Color roomAmbient, Light[] neutral, string output, StreamWriter inventory)
        {
            actor.gameObject.SetActive(true);
            foreach (var item in actor.GetComponentsInChildren<Transform>(true)) item.gameObject.layer = PortraitLayer;
            var skins = actor.GetComponentsInChildren<SkinnedMeshRenderer>(true);
            var bones = skins.SelectMany(skin => skin.bones).Distinct().ToArray();
            var skin = skins.Single();
            if (bones.Length != boneCount || skin.sharedMesh.blendShapeCount != 0 || skin.sharedMaterials.Length != 1)
                throw new InvalidDataException($"Unexpected source anatomy for {name}.");
            var original = skin.sharedMaterial;
            var texture = original.mainTexture;
            inventory.WriteLine($"{name}\t{bones.Length}\t{skins.Length}\t{skin.sharedMesh.subMeshCount}\t{skin.sharedMaterials.Length}" +
                $"\t{skin.sharedMesh.blendShapeCount}\t{original.shader.name}\t{(original.HasProperty("_Surface") ? original.GetFloat("_Surface") : -1f)}" +
                $"\t{texture.name}\t{texture.width}x{texture.height}\t{original.GetTexture("_BumpMap")?.name}");

            var head = Bone(bones, "Head");
            var top = bones.SingleOrDefault(bone => bone.name.EndsWith("HeadTop_End", StringComparison.Ordinal));
            var up = (head.position - Bone(bones, "Neck").position).normalized;
            var crown = top != null ? top.position : head.position + up * 0.19f;
            var focus = head.position + up * (top != null ? 0.035f : 0.095f) + Vector3.forward * 0.05f;
            var distance = Mathf.Clamp(Vector3.Distance(head.position, crown) * 3.1f, 0.54f, 0.75f);

            SetLights(roomLights, false);
            SetLights(neutral, true);
            RenderSettings.ambientLight = new Color(0.34f, 0.34f, 0.34f);
            for (var i = 0; i < Angles.Length; i++)
                Shot(camera, focus, distance, Angles[i], output, $"{name}-neutral-{AngleNames[i]}");

            SetLights(roomLights, true);
            SetLights(neutral, false);
            RenderSettings.ambientLight = roomAmbient;
            for (var i = 0; i < Angles.Length; i++)
                Shot(camera, focus, distance, Angles[i], output, $"{name}-room01-{AngleNames[i]}");
            Shot(camera, focus - Vector3.up * 0.45f, 2.95f, 42f, output, $"{name}-room01-play-distance");

            var flat = new Material(Shader.Find("Universal Render Pipeline/Unlit"));
            var matte = new Material(Shader.Find("Universal Render Pipeline/Lit"));
            try
            {
                flat.SetTexture("_BaseMap", texture);
                skin.sharedMaterial = flat;
                Shot(camera, focus, distance, 0f, output, $"{name}-atlas-only");

                SetLights(roomLights, false);
                SetLights(neutral, true);
                matte.SetColor("_BaseColor", new Color(0.48f, 0.5f, 0.52f));
                matte.SetFloat("_Smoothness", 0f);
                matte.SetFloat("_Metallic", 0f);
                matte.SetFloat("_SpecularHighlights", 0f);
                matte.EnableKeyword("_SPECULARHIGHLIGHTS_OFF");
                skin.sharedMaterial = matte;
                Shot(camera, focus, distance, 0f, output, $"{name}-geometry-only");
            }
            finally
            {
                skin.sharedMaterial = original;
                UnityEngine.Object.DestroyImmediate(flat);
                UnityEngine.Object.DestroyImmediate(matte);
            }
            var motionCaptures = 0;
            if (name == "school65")
            {
                SetLights(roomLights, true);
                SetLights(neutral, false);
                RenderSettings.ambientLight = roomAmbient;
                var model = actor.GetComponentInChildren<Animation>().gameObject;
                var poseOffset = focus - head.position;
                foreach (var (clipName, seconds, angle) in new[] { ("SchoolIdle", 0.40f, 0f), ("SchoolWalk", 0.31f, 42f) })
                {
                    var clip = AssetDatabase.LoadAssetAtPath<AnimationClip>(Root + $"Echo/Locomotion/{clipName}.anim");
                    clip.SampleAnimation(model, seconds);
                    Shot(camera, head.position + poseOffset, distance, angle, output, $"{name}-room01-{clipName}");
                    motionCaptures++;
                }
            }
            actor.gameObject.SetActive(false);
            return 9 + motionCaptures;
        }

        private static Transform Import(string path, Vector3 anchor)
        {
            var source = AssetDatabase.LoadAssetAtPath<GameObject>(path) ?? throw new FileNotFoundException(path);
            var actor = ((GameObject)PrefabUtility.InstantiatePrefab(source)).transform;
            var skins = actor.GetComponentsInChildren<SkinnedMeshRenderer>();
            var bones = skins.SelectMany(skin => skin.bones).Distinct().ToArray();
            var heading = Vector3.Cross(Vector3.up, Bone(bones, "LeftShoulder").position - Bone(bones, "RightShoulder").position);
            actor.rotation = Quaternion.FromToRotation(heading.normalized, Vector3.forward);
            var bounds = EchoSchoolImportReview.MeasureSkinnedBounds(skins);
            var head = Bone(bones, "Head");
            var crown = bones.SingleOrDefault(bone => bone.name.EndsWith("HeadTop_End", StringComparison.Ordinal));
            var bodyHeight = crown != null ? crown.position.y - bounds.min.y : bounds.size.y;
            var scale = 1.76f / bodyHeight;
            actor.localScale *= scale;
            actor.position = anchor - Vector3.up * (bounds.min.y * scale) -
                new Vector3(head.position.x - actor.position.x, 0, head.position.z - actor.position.z);
            return actor;
        }

        private static Transform Bone(Transform[] bones, string name) => bones.Single(bone => bone.name.EndsWith(name, StringComparison.Ordinal));

        private static Light Direction(string name, Vector3 euler, float intensity)
        {
            var light = new GameObject(name).AddComponent<Light>();
            light.type = LightType.Directional;
            light.intensity = intensity;
            light.transform.rotation = Quaternion.Euler(euler);
            return light;
        }

        private static void SetLights(Light[] lights, bool value)
        {
            foreach (var light in lights) light.enabled = value;
        }

        private static void Shot(Camera camera, Vector3 focus, float distance, float yaw, string output, string name)
        {
            camera.transform.position = focus + Quaternion.AngleAxis(yaw, Vector3.up) * Vector3.forward * distance;
            camera.transform.LookAt(focus);
            R01DeviceCapture.Capture(camera, Path.Combine(output, name + ".png"));
        }
    }
}
