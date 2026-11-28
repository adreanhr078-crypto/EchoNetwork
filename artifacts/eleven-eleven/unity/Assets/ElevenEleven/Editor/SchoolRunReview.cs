using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

namespace ElevenEleven.Editor
{
    internal static class SchoolRunReview
    {
        private const string Root = "Assets/ElevenEleven/";
        private const string Source = Root + "MotionReview/SchoolRunSkeleton.glb";
        private const string Times = Root + "MotionReview/SchoolRunSource.json";
        internal const string BakedPath = Root + "Echo/Locomotion/SchoolRun.anim";
        private const string School = Root + "Echo/School/EchoSchool-Tripo-Original.glb";

        [Serializable]
        private sealed class Samples { public float[] times; }

        public static void Run()
        {
            if (!Application.isBatchMode) throw new InvalidOperationException("Use Unity batch mode.");
            EditorSceneManager.NewScene(NewSceneSetup.EmptyScene);
            AssetDatabase.ImportAsset(Source, ImportAssetOptions.ForceSynchronousImport | ImportAssetOptions.ForceUpdate);
            var clip = BuildRetargeted();
            UnityEngine.Object.DestroyImmediate(clip);
            EditorApplication.Exit(0);
        }

        internal static AnimationClip BakeInPlace()
        {
            var existing = AssetDatabase.LoadAssetAtPath<AnimationClip>(BakedPath);
            if (existing != null) return existing;
            var clip = BuildRetargeted();
            var horizontal = AnimationUtility.GetCurveBindings(clip).Single(binding =>
                binding.path.EndsWith("mixamorig:Hips", StringComparison.Ordinal) &&
                binding.propertyName == "m_LocalPosition.x");
            var curve = AnimationUtility.GetEditorCurve(clip, horizontal);
            var keys = curve.keys;
            var first = keys[0];
            var last = keys[keys.Length - 1];
            var velocity = (last.value - first.value) / (last.time - first.time);
            if (Mathf.Abs(velocity) < 0.5f) throw new InvalidDataException("The Run does not contain expected forward travel.");
            for (var i = 0; i < keys.Length; i++)
            {
                var key = keys[i];
                key.value -= velocity * (key.time - first.time);
                key.inTangent -= velocity;
                key.outTangent -= velocity;
                keys[i] = key;
            }
            curve.keys = keys;
            clip.legacy = true;
            clip.wrapMode = WrapMode.Loop;
            AnimationUtility.SetEditorCurve(clip, horizontal, curve);
            clip.name = "SchoolRun";
            AssetDatabase.CreateAsset(clip, BakedPath);
            return clip;
        }

        private static AnimationClip BuildRetargeted()
        {
            var source = Instantiate(Source);
            var target = Instantiate(School);
            try
            {
                return CompareAndRemap(source, target, Source, Times, "Run", 25);
            }
            finally
            {
                UnityEngine.Object.DestroyImmediate(source);
                UnityEngine.Object.DestroyImmediate(target);
            }
        }

        internal static AnimationClip CompareAndRemap(GameObject source, GameObject target, string sourcePath,
            string samplesPath, string motion, int expectedSamples)
        {
            var clips = AssetDatabase.LoadAllAssetsAtPath(sourcePath).OfType<AnimationClip>().ToArray();
            if (clips.Length != 1) throw new InvalidDataException($"Expected one imported {motion} clip, got {clips.Length}.");
            var sourceClip = clips[0];
            var targetJoints = target.GetComponentsInChildren<SkinnedMeshRenderer>()
                .SelectMany(renderer => renderer.bones).Distinct().ToDictionary(bone => bone.name);
            var sourceJoints = new Dictionary<string, Transform>();
            var bindings = AnimationUtility.GetCurveBindings(sourceClip);
            var retargeted = new AnimationClip { name = sourceClip.name, frameRate = sourceClip.frameRate };
            foreach (var binding in bindings)
            {
                var bone = source.transform.Find(binding.path);
                if (bone == null || !targetJoints.TryGetValue(bone.name, out var targetBone) || binding.type != typeof(Transform))
                    throw new InvalidDataException("Unmatched or unsupported animation curve: " + binding.path);
                sourceJoints[bone.name] = bone;
                var remapped = binding;
                remapped.path = AnimationUtility.CalculateTransformPath(targetBone, target.transform);
                AnimationUtility.SetEditorCurve(retargeted, remapped, AnimationUtility.GetEditorCurve(sourceClip, binding));
            }

            if (sourceJoints.Count != 65 || targetJoints.Count != 65)
                throw new InvalidDataException($"Expected 65 joints in each rig, got {sourceJoints.Count} and {targetJoints.Count}.");

            var restPosition = 0f;
            var restAngle = 0f;
            var restScale = 0f;
            foreach (var pair in sourceJoints)
            {
                var original = pair.Value;
                var mapped = targetJoints[pair.Key];
                if (original.parent != null && sourceJoints.ContainsKey(original.parent.name) &&
                    original.parent.name != mapped.parent.name)
                    throw new InvalidDataException("Joint parent differs: " + pair.Key);
                restPosition = Mathf.Max(restPosition, Vector3.Distance(original.localPosition, mapped.localPosition));
                restAngle = Mathf.Max(restAngle, Quaternion.Angle(original.localRotation, mapped.localRotation));
                restScale = Mathf.Max(restScale, Vector3.Distance(original.localScale, mapped.localScale));
            }
            Debug.Log(FormattableString.Invariant(
                $"SCHOOL_{motion.ToUpperInvariant()}_REST joints=65 position_m={restPosition:G8} rotation_deg={restAngle:G8} scale={restScale:G8}"));
            if (restPosition > 0.00005f || restAngle > 0.1f || restScale > 0.0002f)
                throw new InvalidDataException($"{motion} bind transforms require inspection before remapping.");

            var samples = JsonUtility.FromJson<Samples>(File.ReadAllText(samplesPath)).times;
            if (samples.Length != expectedSamples)
                throw new InvalidDataException($"The qualified {motion} has {expectedSamples} source samples.");
            var firstRotations = new Dictionary<string, Quaternion>();
            var errorPosition = 0f;
            var errorRotation = 0f;
            var errorScale = 0f;
            var swing = 0f;
            foreach (var time in samples)
            {
                sourceClip.SampleAnimation(source, time);
                retargeted.SampleAnimation(target, time);
                foreach (var pair in sourceJoints)
                {
                    var original = pair.Value;
                    var mapped = targetJoints[pair.Key];
                    errorPosition = Mathf.Max(errorPosition, Vector3.Distance(original.localPosition, mapped.localPosition));
                    errorRotation = Mathf.Max(errorRotation, Quaternion.Angle(original.localRotation, mapped.localRotation));
                    errorScale = Mathf.Max(errorScale, Vector3.Distance(original.localScale, mapped.localScale));
                    if (firstRotations.TryGetValue(pair.Key, out var first))
                        swing = Mathf.Max(swing, Quaternion.Angle(first, mapped.localRotation));
                    else firstRotations.Add(pair.Key, mapped.localRotation);
                }
            }
            Debug.Log(FormattableString.Invariant(
                $"SCHOOL_{motion.ToUpperInvariant()}_SAMPLES samples={samples.Length} curves={bindings.Length} position_m={errorPosition:G8} rotation_deg={errorRotation:G8} scale={errorScale:G8} motion_span_deg={swing:G8}"));
            if (errorPosition > 0.00005f || errorRotation > 0.1f || errorScale > 0.0002f || swing < 15f)
                throw new InvalidDataException($"{motion} sampling failed the Unity path-binding comparison.");
            Debug.Log($"SCHOOL_{motion.ToUpperInvariant()}_NUMERIC_PASS, isolated comparison");
            return retargeted;
        }

        internal static GameObject Instantiate(string path)
        {
            var prefab = AssetDatabase.LoadAssetAtPath<GameObject>(path);
            return prefab == null
                ? throw new FileNotFoundException("Missing Unity prefab", path)
                : (GameObject)PrefabUtility.InstantiatePrefab(prefab);
        }
    }
}
