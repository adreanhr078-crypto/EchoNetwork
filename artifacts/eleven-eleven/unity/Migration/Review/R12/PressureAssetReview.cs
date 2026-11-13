using System;
using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

namespace ElevenEleven.Editor
{
    internal static class PressureAssetReview
    {
        public static void Run()
        {
            const string path = "Assets/ElevenEleven/MotionReview/stormworks_precision_wheel_v1.glb";
            if (!Application.isBatchMode) throw new InvalidOperationException("Use the isolated review project.");
            EditorSceneManager.NewScene(NewSceneSetup.EmptyScene);
            var prefab = AssetDatabase.LoadAssetAtPath<GameObject>(path);
            if (prefab == null) throw new InvalidOperationException("Unity could not import the original pressure wheel.");
            var instance = (GameObject)PrefabUtility.InstantiatePrefab(prefab);
            var parts = instance.GetComponentsInChildren<MeshFilter>();
            if (parts.Length == 0 || parts.Any(part => part.sharedMesh == null || part.GetComponent<MeshRenderer>() == null))
                throw new InvalidOperationException("The imported wheel has an incomplete render hierarchy.");
            var bounds = parts.Select(part => part.GetComponent<MeshRenderer>().bounds).Aggregate((first, next) =>
            {
                first.Encapsulate(next);
                return first;
            });
            if (bounds.size.sqrMagnitude <= 0.001f) throw new InvalidOperationException("The valve has no physical extent.");
            Debug.Log($"R12_WHEEL_IMPORT_PASS meshes={parts.Length} bounds_m={bounds.size}");
            EditorApplication.Exit(0);
        }
    }
}
