using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using ElevenEleven.Opening;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;

namespace ElevenEleven.Editor
{
    internal static class SchoolLocomotionReview
    {
        private const string Root = "Assets/ElevenEleven/";
        private const string SourceFolder = Root + "MotionReview/";
        internal const string ClipFolder = Root + "Echo/Locomotion";

        [Serializable]
        private sealed class SourceSamples { public float[] times; }

        public static void Run()
        {
            var output = Environment.GetEnvironmentVariable("ECHO_R01_MOTION_REVIEW");
            if (!Application.isBatchMode || string.IsNullOrWhiteSpace(output) || SystemInfo.graphicsDeviceType == GraphicsDeviceType.Null)
                throw new InvalidOperationException("A rendered Unity batch motion review is required.");
            Directory.CreateDirectory(output);
            if (!AssetDatabase.IsValidFolder(ClipFolder)) AssetDatabase.CreateFolder(Root + "Echo", "Locomotion");

            Review("Run", 25, false, output);
            Review("Idle", 58, true, output);
            Review("Walk", 37, true, output);
            EditorApplication.Exit(0);
        }

        private static void Review(string name, int expectedSamples, bool saveClip, string output)
        {
            EditorSceneManager.OpenScene(Root + "Scenes/ChapterRoom01.unity");
            var actor = UnityEngine.Object.FindFirstObjectByType<Room01Player>();
            var model = actor.transform.Find("School65 facing").GetChild(0).gameObject;
            var targetJoints = model.GetComponentsInChildren<SkinnedMeshRenderer>()
                .SelectMany(renderer => renderer.bones).Distinct().ToDictionary(bone => bone.name);
            var sourcePath = SourceFolder + "School" + name + "Skeleton.glb";
            var source = (GameObject)PrefabUtility.InstantiatePrefab(AssetDatabase.LoadAssetAtPath<GameObject>(sourcePath));
            var clip = AssetDatabase.LoadAllAssetsAtPath(sourcePath).OfType<AnimationClip>().Single();
            var mapped = new AnimationClip { name = name, frameRate = clip.frameRate };
            var matched = new Dictionary<string, Transform>();
            foreach (var curve in AnimationUtility.GetCurveBindings(clip))
            {
                var original = source.transform.Find(curve.path);
                if (original == null || curve.type != typeof(Transform) || !targetJoints.TryGetValue(original.name, out var target))
                    throw new InvalidDataException($"{name}: unmatched curve {curve.path}");
                matched[original.name] = original;
                var binding = curve;
                binding.path = AnimationUtility.CalculateTransformPath(target, model.transform);
                AnimationUtility.SetEditorCurve(mapped, binding, AnimationUtility.GetEditorCurve(clip, curve));
            }
            if (matched.Count != 65 || targetJoints.Count != 65)
                throw new InvalidDataException($"{name}: expected all 65 bones.");
            foreach (var item in matched)
            {
                var joint = item.Value;
                var target = targetJoints[item.Key];
                if (matched.ContainsKey(joint.parent.name) && joint.parent.name != target.parent.name)
                    throw new InvalidDataException($"{name}: mismatched joint parent {item.Key}");
            }
            Compare(matched, targetJoints, name, "rest");
            var times = JsonUtility.FromJson<SourceSamples>(File.ReadAllText(SourceFolder + "School" + name + "Source.json")).times;
            if (times.Length != expectedSamples) throw new InvalidDataException($"{name}: unexpected sample count.");
            foreach (var time in times)
            {
                clip.SampleAnimation(source, time);
                mapped.SampleAnimation(model, time);
                Compare(matched, targetJoints, name, $"sample {time:F6}");
            }

            var hip = targetJoints.Values.Single(bone => bone.name.EndsWith(":Hips", StringComparison.Ordinal));
            var foot = targetJoints.Values.Single(bone => bone.name.EndsWith(":LeftFoot", StringComparison.Ordinal));
            var start = foot.localRotation;
            mapped.SampleAnimation(model, times[times.Length / 3]);
            var span = Quaternion.Angle(start, foot.localRotation);
            if (span < 0.1f) throw new InvalidDataException($"{name}: the foot curves did not vary.");
            var reviewObject = new GameObject("Motion evidence camera");
            try
            {
                var camera = reviewObject.AddComponent<Camera>();
                camera.enabled = false;
                camera.clearFlags = CameraClearFlags.SolidColor;
                camera.backgroundColor = new Color(0.035f, 0.047f, 0.064f);
                camera.fieldOfView = 46f;
                CaptureSample(name, "front", times[times.Length / 4], model, mapped, camera, hip, output);
                CaptureSample(name, "side", times[times.Length * 2 / 3], model, mapped, camera, hip, output);
            }
            finally
            {
                UnityEngine.Object.DestroyImmediate(reviewObject);
            }

            if (saveClip)
            {
                mapped.legacy = true;
                mapped.wrapMode = WrapMode.Loop;
                var path = ClipFolder + "/School" + name + ".anim";
                var existing = AssetDatabase.LoadAssetAtPath<AnimationClip>(path);
                if (existing == null) AssetDatabase.CreateAsset(mapped, path);
                else EditorUtility.CopySerialized(mapped, existing);
                AssetDatabase.SaveAssets();
            }
            Debug.Log($"R01_SCHOOL_MOTION_PASS name={name} joints={matched.Count} samples={times.Length}");
        }

        private static void Compare(Dictionary<string, Transform> source, Dictionary<string, Transform> target, string name, string stage)
        {
            foreach (var item in source)
            {
                var joint = item.Value;
                var mapped = target[item.Key];
                if (Vector3.Distance(joint.localPosition, mapped.localPosition) > 0.00005f ||
                    Quaternion.Angle(joint.localRotation, mapped.localRotation) > 0.1f ||
                    Vector3.Distance(joint.localScale, mapped.localScale) > 0.0002f)
                    throw new InvalidDataException($"{name}: {stage} pose mismatch at {item.Key}.");
            }
        }

        private static void CaptureSample(string name, string angle, float time, GameObject model, AnimationClip clip,
            Camera camera, Transform hip, string output)
        {
            clip.SampleAnimation(model, time);
            var focus = new Vector3(hip.position.x, 0.91f, hip.position.z);
            var offset = angle == "front" ? new Vector3(0.25f, 0.35f, 2.7f) : new Vector3(2.7f, 0.35f, 0.35f);
            camera.transform.position = focus + offset;
            camera.transform.LookAt(focus);
            R01DeviceCapture.Capture(camera, Path.Combine(output, $"{name.ToLowerInvariant()}-{angle}.png"));
        }
    }
}
