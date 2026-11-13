using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.Rendering;

namespace ElevenEleven.Editor
{
    internal static class EchoSchoolImportReview
    {
        private const string Root = "Assets/ElevenEleven";
        private const string RigPath = Root + "/Echo/School/EchoSchool-Tripo-Original.glb";
        private const string MotionFolder = Root + "/Echo/Tripo Motions/";
        private const string ScenePath = Root + "/Scenes/EchoSchoolReview.unity";

        [MenuItem("11.11/Open Echo School import review")]
        public static void Build()
        {
            var school = AssetDatabase.LoadAssetAtPath<GameObject>(RigPath);
            if (school == null)
                throw new InvalidOperationException("The original School GLB must be imported before the review.");

            ValidateMotion("Wake", 119f / 24f);
            ValidateMotion("Boxing", 95f / 24f);

            if (AssetDatabase.LoadAssetAtPath<SceneAsset>(ScenePath) != null)
            {
                var current = SceneManager.GetActiveScene();
                if (current.path != ScenePath)
                {
                    if (!EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo()) return;
                    current = EditorSceneManager.OpenScene(ScenePath);
                }
                var rig = current.GetRootGameObjects().Single(root => root.name == "Echo School - Original Tripo");
                var existingCamera = current.GetRootGameObjects().Single(root => root.name == "Review Camera").GetComponent<Camera>();
                FrameCharacter(rig, existingCamera);
                EditorSceneManager.SaveScene(current);
                return;
            }

            var previous = SceneManager.GetActiveScene();
            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Additive);
            SceneManager.SetActiveScene(scene);
            try
            {
                var character = (GameObject)PrefabUtility.InstantiatePrefab(school, scene);
                character.name = "Echo School - Original Tripo";
                var skins = character.GetComponentsInChildren<SkinnedMeshRenderer>();
                var bones = skins.SelectMany(skin => skin.bones).Distinct().ToArray();
                if (skins.Length == 0 || bones.Length != 65 || bones.Any(bone => bone == null))
                    throw new InvalidOperationException($"Expected the complete School65 skin. Found {bones.Length} unique bones.");

                var materials = skins.SelectMany(skin => skin.sharedMaterials).Distinct().ToArray();
                if (materials.Length == 0 || materials.Any(material => material == null || material.shader == null || !material.shader.isSupported))
                    throw new InvalidOperationException("A School skin material is missing or unsupported.");

                var camera = new GameObject("Review Camera").AddComponent<Camera>();
                camera.tag = "MainCamera";
                camera.clearFlags = CameraClearFlags.SolidColor;
                camera.backgroundColor = new Color(0.13f, 0.17f, 0.22f);
                camera.fieldOfView = 34f;
                AddLighting(FrameCharacter(character, camera));

                if (!AssetDatabase.IsValidFolder(Root + "/Scenes"))
                    AssetDatabase.CreateFolder(Root, "Scenes");
                if (!EditorSceneManager.SaveScene(scene, ScenePath))
                    throw new IOException("Unity failed to save the School review scene.");

                Debug.Log($"ECHO_SCHOOL_IMPORT_PASS bones={bones.Length} skins={skins.Length} " +
                          $"materials={string.Join(",", materials.Select(m => m.shader.name))}");
                if (previous.IsValid() && !previous.isDirty)
                    EditorSceneManager.CloseScene(previous, true);
                Selection.activeGameObject = character;
                SceneView.lastActiveSceneView?.FrameSelected();
            }
            catch
            {
                EditorSceneManager.CloseScene(scene, true);
                throw;
            }
        }

        private static Vector3 FrameCharacter(GameObject character, Camera camera)
        {
            const float height = 1.76f;
            character.transform.localScale = Vector3.one;
            character.transform.position = Vector3.zero;
            var skins = character.GetComponentsInChildren<SkinnedMeshRenderer>();
            var sourceBounds = MeasureSkinnedBounds(skins);
            var sourceHeight = sourceBounds.size.y;
            if (Mathf.Abs(sourceHeight - 1f) > 0.02f)
                throw new InvalidOperationException($"Unexpected School source height in Unity metres: {sourceHeight:F3}.");

            var bones = skins.SelectMany(skin => skin.bones).Distinct().ToArray();
            var left = Array.Find(bones, bone => bone.name.EndsWith("LeftShoulder", StringComparison.Ordinal));
            var right = Array.Find(bones, bone => bone.name.EndsWith("RightShoulder", StringComparison.Ordinal));
            if (left == null || right == null)
                throw new InvalidOperationException("The original shoulder joints were not found.");
            var front = Vector3.Cross(Vector3.up, left.position - right.position).normalized;

            var scale = height / sourceHeight;
            var groundOffset = Vector3.down * (sourceBounds.min.y * scale);
            character.transform.localScale = Vector3.one * scale;
            character.transform.position = groundOffset;
            var focus = sourceBounds.center * scale + groundOffset + Vector3.up * (0.04f * height);
            camera.transform.position = focus + front * (2.15f * height) + Vector3.up * (0.1f * height);
            camera.transform.LookAt(focus);
            Debug.Log($"ECHO_SCHOOL_REVIEW_FRAMED source_height_m={sourceHeight:F3} preview_height_m={height:F3}");
            return front;
        }

        internal static Bounds MeasureSkinnedBounds(SkinnedMeshRenderer[] skins)
        {
            var mesh = new Mesh();
            var min = Vector3.one * float.PositiveInfinity;
            var max = Vector3.one * float.NegativeInfinity;
            try
            {
                foreach (var skin in skins)
                {
                    skin.BakeMesh(mesh);
                    foreach (var vertex in mesh.vertices)
                    {
                        var world = skin.transform.TransformPoint(vertex);
                        min = Vector3.Min(min, world);
                        max = Vector3.Max(max, world);
                    }
                }
            }
            finally
            {
                UnityEngine.Object.DestroyImmediate(mesh);
            }

            var bounds = new Bounds();
            bounds.SetMinMax(min, max);
            return bounds;
        }

        private static void ValidateMotion(string name, float expectedDuration)
        {
            var assets = AssetDatabase.LoadAllAssetsAtPath(MotionFolder + name + "-Original.glb");
            var clips = assets.OfType<AnimationClip>().ToArray();
            if (clips.Length != 1 || Mathf.Abs(clips[0].length - expectedDuration) > 0.002f)
                throw new InvalidOperationException($"{name} did not import as one clip of {expectedDuration:F4} seconds.");
            Debug.Log($"ECHO_TRIPO_MOTION_IMPORT_PASS {name} duration_s={clips[0].length:F6}");
        }

        private static void AddLighting(Vector3 front)
        {
            RenderSettings.ambientMode = AmbientMode.Flat;
            RenderSettings.ambientLight = new Color(0.36f, 0.38f, 0.43f);
            var key = new GameObject("Review Key").AddComponent<Light>();
            key.type = LightType.Directional;
            key.intensity = 1.15f;
            key.transform.rotation = Quaternion.LookRotation((-front + Vector3.down * 0.7f).normalized);
            var fill = new GameObject("Review Fill").AddComponent<Light>();
            fill.type = LightType.Directional;
            fill.intensity = 0.35f;
            fill.color = new Color(0.71f, 0.82f, 1f);
            fill.transform.rotation = Quaternion.LookRotation((front + Vector3.down * 0.25f).normalized);
        }
    }
}
