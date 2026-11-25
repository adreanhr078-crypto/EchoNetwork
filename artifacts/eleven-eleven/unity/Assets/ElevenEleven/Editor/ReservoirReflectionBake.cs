using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using Object = UnityEngine.Object;

namespace ElevenEleven.Editor
{
    internal static class ReservoirReflectionBake
    {
        private const string Room = "Assets/ElevenEleven/Scenes/ChapterRoom01.unity";
        private const string Reservoir = "Assets/ElevenEleven/Opening/Stormworks/";
        private const string Reflection = Reservoir + "StationFinishes/Observatory reservoir reflection.exr";

        public static void Run()
        {
            if (!Application.isBatchMode || SystemInfo.graphicsDeviceType == GraphicsDeviceType.Null)
                throw new InvalidOperationException("Use a graphical Unity batch session.");
            var scene = EditorSceneManager.OpenScene(Room);
            var content = scene.GetRootGameObjects().Single(root => root.name == "Room content");
            var water = content.GetComponentsInChildren<MeshRenderer>(true).Single(r => r.name == "Boat Attack reservoir surface");
            var material = water.sharedMaterial;
            if (!material.HasProperty("_BasinReflection") || ShaderUtil.ShaderHasError(material.shader))
                throw new InvalidDataException("The new reservoir shader is unavailable.");

            var origin = new Vector3(0f, -3.42f, 57.8f);
            var wasActive = content.activeSelf;
            var wasEnabled = water.enabled;
            var node = new GameObject("Reservoir reflection capture");
            try
            {
                content.SetActive(true);
                water.enabled = false;
                node.transform.position = origin;
                var probe = node.AddComponent<ReflectionProbe>();
                probe.mode = ReflectionProbeMode.Baked;
                probe.hdr = true;
                probe.resolution = 128;
                probe.cullingMask = ~(1 << 2);
                probe.nearClipPlane = .16f;
                probe.farClipPlane = 115f;
                probe.clearFlags = ReflectionProbeClearFlags.Skybox;
                if (!Lightmapping.BakeReflectionProbe(probe, Reflection))
                    throw new IOException("Unity failed to bake the still observatory reflection.");
                AssetDatabase.ImportAsset(Reflection, ImportAssetOptions.ForceSynchronousImport);
                var cube = AssetDatabase.LoadAssetAtPath<Cubemap>(Reflection);
                if (!cube || cube.width < 64 || cube.mipmapCount < 2)
                    throw new InvalidDataException("The baked reflection did not import as a mipmapped cubemap.");
                material.SetTexture("_BasinReflection", cube);
                material.SetVector("_ReflectionOrigin", new Vector4(origin.x, origin.y, origin.z, 0f));
                material.SetFloat("_ReflectionBlend", .76f);
                EditorUtility.SetDirty(material);
                AssetDatabase.SaveAssetIfDirty(material);
                Debug.Log($"ECHO_RESERVOIR_REFLECTION_PASS width={cube.width} mips={cube.mipmapCount} path={Reflection}");
            }
            finally
            {
                water.enabled = wasEnabled;
                content.SetActive(wasActive);
                Object.DestroyImmediate(node);
            }
        }
    }
}
