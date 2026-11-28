using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using ElevenEleven.Opening;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

namespace ElevenEleven.Editor
{
    /// <summary>
    /// Bakes all six authored School65 (Roll, Mantle, Hang) and Pact72 (Boxing, Horizontal, Overhead)
    /// animation assets cleanly into Assets/ElevenEleven/Echo/Locomotion/ without mutating walk-v1 or colliders.
    /// </summary>
    internal static class ChapterMotionBakery
    {
        private const string ScenePath = "Assets/ElevenEleven/Scenes/ChapterRoom01.unity";
        private const string LocomotionDir = "Assets/ElevenEleven/Echo/Locomotion/";
        private const string ReviewDir = "Assets/ElevenEleven/MotionReview/";
        private const string SchoolGlb = "Assets/ElevenEleven/Echo/School/EchoSchool-Tripo-Original.glb";
        private const string PactGlb = ReviewDir + "echo_pact72_candidate.glb";
        private const string ExistingPactStrike = LocomotionDir + "PactStrike.anim";

        [Serializable]
        private struct TimelineJson
        {
            public float[] times;
            public int fps;
            public int sample_count;
        }

        [MenuItem("11.11/Bake Six Authored Motions")]
        public static void BakeAll()
        {
            var glbs = new[]
            {
                ReviewDir + "SchoolRollSkeleton.glb",
                ReviewDir + "SchoolMantleSkeleton.glb",
                ReviewDir + "SchoolHangSkeleton.glb",
                ReviewDir + "PactStrikeBoxingSkeleton.glb",
                ReviewDir + "PactStrikeHorizontalSkeleton.glb",
                ReviewDir + "PactStrikeOverheadSkeleton.glb",
            };
            foreach (var g in glbs)
                AssetDatabase.ImportAsset(g, ImportAssetOptions.ForceSynchronousImport | ImportAssetOptions.ForceUpdate);

            var roll = BakeSchoolClip("SchoolRoll", ReviewDir + "SchoolRollSkeleton.glb", ReviewDir + "SchoolRollSource.json",
                "Roll", 72, WrapMode.ClampForever, lockX: true, lockY: false, lockZ: true);
            var mantle = BakeSchoolClip("SchoolMantle", ReviewDir + "SchoolMantleSkeleton.glb", ReviewDir + "SchoolMantleSource.json",
                "Mantle", 35, WrapMode.ClampForever, lockX: true, lockY: true, lockZ: true);
            var hang = BakeSchoolClip("SchoolHang", ReviewDir + "SchoolHangSkeleton.glb", ReviewDir + "SchoolHangSource.json",
                "Hang", 29, WrapMode.Loop, lockX: true, lockY: true, lockZ: true);

            var boxing = BakePactClip("PactStrikeBoxing", ReviewDir + "PactStrikeBoxingSkeleton.glb",
                ReviewDir + "PactStrikeBoxingSource.json", 96);
            var horizontal = BakePactClip("PactStrikeHorizontal", ReviewDir + "PactStrikeHorizontalSkeleton.glb",
                ReviewDir + "PactStrikeHorizontalSource.json", 73);
            var overhead = BakePactClip("PactStrikeOverhead", ReviewDir + "PactStrikeOverheadSkeleton.glb",
                ReviewDir + "PactStrikeOverheadSource.json", 56);

            var scene = EditorSceneManager.OpenScene(ScenePath);
            var content = scene.GetRootGameObjects().Single(r => r.name == "Room content").transform;
            var authority = content.GetComponentsInChildren<Collider>(true)
                .ToDictionary(c => c, c => (EditorJsonUtility.ToJson(c), c.transform.localToWorldMatrix));

            var player = scene.GetRootGameObjects().SelectMany(r => r.GetComponentsInChildren<Room01Player>(true)).Single();
            var so = new SerializedObject(player);
            so.FindProperty("schoolRoll").objectReferenceValue = roll;
            so.FindProperty("schoolMantle").objectReferenceValue = mantle;
            so.FindProperty("schoolHang").objectReferenceValue = hang;
            so.FindProperty("pactStrikeBoxing").objectReferenceValue = boxing;
            so.FindProperty("pactStrikeHorizontal").objectReferenceValue = horizontal;
            so.FindProperty("pactStrikeOverhead").objectReferenceValue = overhead;
            so.ApplyModifiedPropertiesWithoutUndo();

            var fx = player.GetComponent<StationActionFx>() ?? player.gameObject.AddComponent<StationActionFx>();
            EditorUtility.SetDirty(fx);
            EditorUtility.SetDirty(player);

            var after = content.GetComponentsInChildren<Collider>(true);
            if (after.Length != authority.Count || after.Any(c =>
                    !authority.TryGetValue(c, out var was) ||
                    was.Item1 != EditorJsonUtility.ToJson(c) ||
                    was.Item2 != c.transform.localToWorldMatrix))
                throw new InvalidDataException("Collider invariant violated during ChapterMotionBakery.");

            EditorSceneManager.MarkSceneDirty(scene);
            AssetDatabase.SaveAssets();
            if (!EditorSceneManager.SaveScene(scene))
                throw new IOException("Could not save ChapterRoom01 after baking 6 motions.");

            Debug.Log($"ECHO_SIX_MOTIONS_BAKED colliders={after.Length} roll={roll.length:F2}s mantle={mantle.length:F2}s hang={hang.length:F2}s boxing={boxing.length:F2}s horiz={horizontal.length:F2}s over={overhead.length:F2}s");
        }

        private static AnimationClip BakeSchoolClip(string clipName, string sourcePath, string jsonPath, string motionLabel,
            int expectedSamples, WrapMode wrapMode, bool lockX, bool lockY, bool lockZ)
        {
            var source = SchoolRunReview.Instantiate(sourcePath);
            var target = SchoolRunReview.Instantiate(SchoolGlb);
            AnimationClip clip;
            try
            {
                clip = SchoolRunReview.CompareAndRemap(source, target, sourcePath, jsonPath, motionLabel, expectedSamples);
                StabilizePelvisRoot(clip, target, jsonPath, lockX, lockY, lockZ, clipName);
            }
            finally
            {
                UnityEngine.Object.DestroyImmediate(source);
                UnityEngine.Object.DestroyImmediate(target);
            }

            return SaveLegacyClip(clip, clipName, wrapMode);
        }

        private static AnimationClip BakePactClip(string clipName, string sourcePath, string jsonPath, int expectedSamples)
        {
            var sourceClips = AssetDatabase.LoadAllAssetsAtPath(sourcePath).OfType<AnimationClip>().ToArray();
            if (sourceClips.Length != 1)
                throw new InvalidDataException($"Expected 1 clip inside {sourcePath}, got {sourceClips.Length}.");
            var sourceClip = sourceClips[0];
            var times = JsonUtility.FromJson<TimelineJson>(File.ReadAllText(jsonPath)).times;
            if (times == null || times.Length != expectedSamples)
                throw new InvalidDataException($"{clipName}: expected {expectedSamples} samples, got {times?.Length ?? 0}.");

            var source = SchoolRunReview.Instantiate(sourcePath);
            var target = SchoolRunReview.Instantiate(PactGlb);
            var retargeted = new AnimationClip { name = clipName, frameRate = sourceClip.frameRate };
            try
            {
                var targetBones = target.GetComponentsInChildren<SkinnedMeshRenderer>()
                    .SelectMany(r => r.bones).Distinct()
                    .ToDictionary(b => b.name, StringComparer.Ordinal);
                var matched = 0;
                var bindings = AnimationUtility.GetCurveBindings(sourceClip);
                var seenJoints = new HashSet<string>(StringComparer.Ordinal);
                foreach (var b in bindings)
                {
                    var bone = source.transform.Find(b.path);
                    if (bone == null || !targetBones.TryGetValue(bone.name, out var targetBone) || b.type != typeof(Transform))
                        throw new InvalidDataException($"{clipName}: unmatched Pact bone {b.path}");
                    if (seenJoints.Add(bone.name)) matched++;
                    var mapped = b;
                    mapped.path = AnimationUtility.CalculateTransformPath(targetBone, target.transform);
                    AnimationUtility.SetEditorCurve(retargeted, mapped, AnimationUtility.GetEditorCurve(sourceClip, b));
                }

                if (matched != 65)
                    throw new InvalidDataException($"{clipName}: expected 65 Mixamo bones matched on Pact72, got {matched}.");

                StabilizePelvisRoot(retargeted, target, jsonPath, true, false, true, clipName);
                AttachWingCurvesFromPactStrike(retargeted, target);
            }
            finally
            {
                UnityEngine.Object.DestroyImmediate(source);
                UnityEngine.Object.DestroyImmediate(target);
            }

            return SaveLegacyClip(retargeted, clipName, WrapMode.ClampForever);
        }

        private static void StabilizePelvisRoot(AnimationClip clip, GameObject rigRoot, string jsonPath,
            bool lockX, bool lockY, bool lockZ, string tag)
        {
            if (!lockX && !lockY && !lockZ) return;
            var times = JsonUtility.FromJson<TimelineJson>(File.ReadAllText(jsonPath)).times;
            var hips = rigRoot.GetComponentsInChildren<SkinnedMeshRenderer>()
                .SelectMany(r => r.bones).Distinct()
                .Single(b => b.name.EndsWith(":Hips", StringComparison.Ordinal));
            var hipsPath = AnimationUtility.CalculateTransformPath(hips, rigRoot.transform);
            clip.SampleAnimation(rigRoot, times[0]);
            var hipsWorld0 = hips.position;

            var deltaLocal = new Vector3[times.Length];
            var maxDelta = 0f;
            for (var i = 0; i < times.Length; i++)
            {
                clip.SampleAnimation(rigRoot, times[i]);
                var diffWorld = hips.position - hipsWorld0;
                var mask = new Vector3(lockX ? diffWorld.x : 0f, lockY ? diffWorld.y : 0f, lockZ ? diffWorld.z : 0f);
                maxDelta = Mathf.Max(maxDelta, mask.magnitude);
                deltaLocal[i] = hips.parent.InverseTransformVector(mask);
            }

            var posBindings = AnimationUtility.GetCurveBindings(clip)
                .Where(b => b.path == hipsPath && b.propertyName.StartsWith("m_LocalPosition.", StringComparison.Ordinal))
                .ToArray();
            if (posBindings.Length != 3)
                throw new InvalidDataException($"{tag}: expected 3 Hips localPosition curves, got {posBindings.Length}.");

            foreach (var b in posBindings)
            {
                var axis = "xyz".IndexOf(b.propertyName[^1]);
                if (axis < 0) continue;
                var curve = AnimationUtility.GetEditorCurve(clip, b);
                var keys = curve.keys;
                var newKeys = new Keyframe[times.Length];
                for (var i = 0; i < times.Length; i++)
                {
                    var val = curve.Evaluate(times[i]) - deltaLocal[i][axis];
                    var inSlope = i > 0 ? (val - newKeys[i - 1].value) / Mathf.Max(0.0001f, times[i] - times[i - 1]) : 0f;
                    newKeys[i] = new Keyframe(times[i], val, inSlope, 0f);
                }
                for (var i = 0; i < newKeys.Length - 1; i++)
                {
                    var outSlope = (newKeys[i + 1].value - newKeys[i].value) / Mathf.Max(0.0001f, newKeys[i + 1].time - newKeys[i].time);
                    var k = newKeys[i];
                    k.outTangent = outSlope;
                    newKeys[i] = k;
                }
                curve.keys = newKeys;
                AnimationUtility.SetEditorCurve(clip, b, curve);
                _ = keys;
            }
            Debug.Log($"{tag}: stabilized pelvis delta_m={maxDelta:F3}");
        }

        private static void AttachWingCurvesFromPactStrike(AnimationClip targetClip, GameObject pactRoot)
        {
            var baseStrike = AssetDatabase.LoadAssetAtPath<AnimationClip>(ExistingPactStrike);
            if (!baseStrike || baseStrike.length <= 0.01f) return;
            var wingBindings = AnimationUtility.GetCurveBindings(baseStrike)
                .Where(b => b.path.Contains("Wing", StringComparison.Ordinal))
                .ToArray();
            var timeScale = Mathf.Max(0.01f, targetClip.length) / baseStrike.length;
            foreach (var wb in wingBindings)
            {
                if (!pactRoot.transform.Find(wb.path)) continue;
                var srcCurve = AnimationUtility.GetEditorCurve(baseStrike, wb);
                var dstKeys = srcCurve.keys;
                for (var i = 0; i < dstKeys.Length; i++)
                {
                    var k = dstKeys[i];
                    k.time *= timeScale;
                    k.inTangent /= timeScale;
                    k.outTangent /= timeScale;
                    dstKeys[i] = k;
                }
                AnimationUtility.SetEditorCurve(targetClip, wb, new AnimationCurve(dstKeys));
            }
        }

        private static AnimationClip SaveLegacyClip(AnimationClip clip, string clipName, WrapMode wrapMode)
        {
            clip.name = clipName;
            clip.legacy = true;
            clip.wrapMode = wrapMode;
            var outPath = LocomotionDir + clipName + ".anim";
            var existing = AssetDatabase.LoadAssetAtPath<AnimationClip>(outPath);
            if (existing)
            {
                EditorUtility.CopySerialized(clip, existing);
                UnityEngine.Object.DestroyImmediate(clip);
                EditorUtility.SetDirty(existing);
                return existing;
            }
            AssetDatabase.CreateAsset(clip, outPath);
            return clip;
        }
    }
}
