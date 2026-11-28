using System;
using System.IO;
using System.Linq;
using ElevenEleven.Opening;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

namespace ElevenEleven.Editor
{
    internal static class SchoolJumpReview
    {
        private const string Root = "Assets/ElevenEleven/";
        private const string Room = Root + "Scenes/ChapterRoom01.unity";
        private const string Source = Root + "MotionReview/SchoolJumpSkeleton.glb";
        private const string Times = Root + "MotionReview/SchoolJumpSource.json";
        private const string BakedPath = Root + "Echo/Locomotion/SchoolJump.anim";
        private const string School = Root + "Echo/School/EchoSchool-Tripo-Original.glb";
        private const int Takeoff = 24;
        private const int Contact = 42;
        private const int SampleCount = 74;
        private const float Rate = 30f;

        public static void Apply()
        {
            if (!Application.isBatchMode) throw new InvalidOperationException("Use Unity batch mode.");
            AssetDatabase.ImportAsset(Source, ImportAssetOptions.ForceSynchronousImport | ImportAssetOptions.ForceUpdate);
            if (AssetDatabase.LoadAssetAtPath<AnimationClip>(BakedPath) != null)
                throw new IOException("An existing SchoolJump asset requires inspection before replacement.");
            var scene = EditorSceneManager.OpenScene(Room);
            var player = scene.GetRootGameObjects().SelectMany(root => root.GetComponentsInChildren<Room01Player>(true)).Single();
            var playerObject = new SerializedObject(player);
            var schoolJump = playerObject.FindProperty("schoolJump");
            if (schoolJump == null || schoolJump.objectReferenceValue != null)
                throw new InvalidDataException("Expected one available School65 jump slot.");
            var source = SchoolRunReview.Instantiate(Source);
            var target = SchoolRunReview.Instantiate(School);
            AnimationClip candidate;
            try
            {
                candidate = SchoolRunReview.CompareAndRemap(source, target, Source, Times, "Jump", SampleCount);
                FitPelvisToCapsule(candidate, target);
            }
            finally
            {
                UnityEngine.Object.DestroyImmediate(source);
                UnityEngine.Object.DestroyImmediate(target);
            }

            candidate.name = "SchoolJump";
            candidate.legacy = true;
            candidate.wrapMode = WrapMode.ClampForever;
            AssetDatabase.CreateAsset(candidate, BakedPath);
            schoolJump.objectReferenceValue = candidate;
            playerObject.ApplyModifiedPropertiesWithoutUndo();
            EditorSceneManager.MarkSceneDirty(scene);
            if (!EditorSceneManager.SaveScene(scene)) throw new IOException("Could not save the jump binding.");
            Debug.Log("SCHOOL_JUMP_ADAPTER_APPLIED");
        }

        private static void FitPelvisToCapsule(AnimationClip clip, GameObject target)
        {
            var hips = target.GetComponentsInChildren<SkinnedMeshRenderer>()
                .SelectMany(renderer => renderer.bones).Distinct()
                .Single(bone => bone.name.EndsWith(":Hips", StringComparison.Ordinal));
            var hipsPath = AnimationUtility.CalculateTransformPath(hips, target.transform);
            var heights = new float[SampleCount];
            for (var frame = Takeoff; frame <= Contact; frame++)
            {
                clip.SampleAnimation(target, frame / Rate);
                heights[frame] = hips.position.y;
            }
            var localUp = hips.parent.InverseTransformVector(Vector3.up);
            var correction = new float[SampleCount];
            for (var frame = Takeoff; frame <= Contact; frame++)
            {
                var amount = (frame - Takeoff) / (float)(Contact - Takeoff);
                correction[frame] = Mathf.Max(0f, heights[frame] - Mathf.Lerp(heights[Takeoff], heights[Contact], amount));
            }
            var maxLift = correction.Max();
            if (maxLift < 0.28f || maxLift > 0.75f)
                throw new InvalidDataException($"Unexpected School65 authored jump lift {maxLift:F3} m.");

            var curves = AnimationUtility.GetCurveBindings(clip).Where(binding =>
                binding.path == hipsPath && binding.propertyName.StartsWith("m_LocalPosition.", StringComparison.Ordinal)).ToArray();
            if (curves.Length != 3) throw new InvalidDataException("Expected three pelvis translation curves.");
            foreach (var binding in curves)
            {
                var axis = "xyz".IndexOf(binding.propertyName[^1]);
                if (axis < 0) throw new InvalidDataException("Unexpected pelvis curve axis.");
                if (Mathf.Abs(localUp[axis]) < 0.000001f) continue;
                var curve = AnimationUtility.GetEditorCurve(clip, binding);
                var frames = 0;
                var keys = curve.keys;
                for (var index = 0; index < keys.Length; index++)
                {
                    var key = keys[index];
                    var frame = Mathf.RoundToInt(key.time * Rate);
                    if (frame < Takeoff || frame > Contact) continue;
                    if (Mathf.Abs(key.time * Rate - frame) > 0.001f)
                        throw new InvalidDataException("A pelvis sample is outside the qualified 30 Hz timeline.");
                    key.value -= localUp[axis] * correction[frame];
                    if (frame > Takeoff)
                        key.inTangent -= localUp[axis] * Rate * (correction[frame] - correction[frame - 1]);
                    if (frame < Contact)
                        key.outTangent -= localUp[axis] * Rate * (correction[frame + 1] - correction[frame]);
                    keys[index] = key;
                    frames++;
                }
                if (frames != Contact - Takeoff + 1)
                    throw new InvalidDataException("A pelvis axis does not contain all qualified airborne samples.");
                curve.keys = keys;
                AnimationUtility.SetEditorCurve(clip, binding, curve);
            }

            var residual = 0f;
            for (var frame = Takeoff; frame <= Contact; frame++)
            {
                clip.SampleAnimation(target, frame / Rate);
                residual = Mathf.Max(residual, Mathf.Abs(hips.position.y - (heights[frame] - correction[frame])));
            }
            if (residual > 0.001f)
                throw new InvalidDataException($"Pelvis adjustment residual {residual:F5} m.");
            Debug.Log(FormattableString.Invariant($"SCHOOL_JUMP_CAPSULE_FIT removed_lift_m={maxLift:F4} residual_m={residual:F6}"));
        }
    }
}
