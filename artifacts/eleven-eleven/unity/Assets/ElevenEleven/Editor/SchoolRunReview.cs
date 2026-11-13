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
        private const string School = Root + "Echo/School/EchoSchool-Tripo-Original.glb";

        [Serializable]
        private sealed class Samples { public float[] times; }

        public static void Run()
        {
            if (!Application.isBatchMode) throw new InvalidOperationException("Use Unity batch mode.");
            EditorSceneManager.NewScene(NewSceneSetup.EmptyScene);
            AssetDatabase.ImportAsset(Source, ImportAssetOptions.ForceSynchronousImport | ImportAssetOptions.ForceUpdate);
            var source = Instantiate(Source);
            var target = Instantiate(School);
            var clips = AssetDatabase.LoadAllAssetsAtPath(Source).OfType<AnimationClip>().ToArray();
            if (clips.Length != 1) throw new InvalidDataException($"Expected one imported Run clip, got {clips.Length}.");
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
                $"SCHOOL_RUN_REST joints=65 position_m={restPosition:G8} rotation_deg={restAngle:G8} scale={restScale:G8}"));
            if (restPosition > 0.00005f || restAngle > 0.1f || restScale > 0.0002f)
                throw new InvalidDataException("Run bind transforms require inspection before remapping.");

            var samples = JsonUtility.FromJson<Samples>(File.ReadAllText(Times)).times;
            if (samples.Length != 25) throw new InvalidDataException("The qualified Run has 25 source samples.");
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
                $"SCHOOL_RUN_SAMPLES samples={samples.Length} curves={bindings.Length} position_m={errorPosition:G8} rotation_deg={errorRotation:G8} scale={errorScale:G8} motion_span_deg={swing:G8}"));
            if (errorPosition > 0.00005f || errorRotation > 0.1f || errorScale > 0.0002f || swing < 15f)
                throw new InvalidDataException("Run sampling failed the Unity path-binding comparison.");
            Debug.Log("SCHOOL_RUN_NUMERIC_PASS, isolated comparison");
            EditorApplication.Exit(0);
        }

        private static GameObject Instantiate(string path)
        {
            var prefab = AssetDatabase.LoadAssetAtPath<GameObject>(path);
            return prefab == null
                ? throw new FileNotFoundException("Missing Unity prefab", path)
                : (GameObject)PrefabUtility.InstantiatePrefab(prefab);
        }
    }
}
