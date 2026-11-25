using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEditor;
using UnityEngine;

namespace ElevenEleven.Editor
{
    internal static class WorldTextureBuildAudit
    {
        private const string Opening = "Assets/ElevenEleven/Opening/";

        public static void Build()
        {
            var manifest = Environment.GetEnvironmentVariable("ECHO_RUNTIME_MAP_MANIFEST");
            var models = JArray.Parse(File.ReadAllText(manifest));
            var textures = 0;
            var bound = 0;
            foreach (var model in models)
            {
                var path = Opening + (string)model["model"];
                if (AssetDatabase.LoadAssetAtPath<GameObject>(path) == null)
                    throw new InvalidDataException($"Could not import {path}");

                var inUse = new HashSet<string>();
                foreach (var material in AssetDatabase.LoadAllAssetsAtPath(path).OfType<Material>())
                {
                    foreach (var property in material.GetTexturePropertyNames())
                    {
                        var map = material.GetTexture(property);
                        if (map != null) inUse.Add(AssetDatabase.GetAssetPath(map));
                    }
                }

                var assigned = 0;
                foreach (var entry in (JArray)model["maps"])
                {
                    var mapPath = Opening + (string)entry["path"];
                    var texture = AssetDatabase.LoadAssetAtPath<Texture2D>(mapPath);
                    var size = (JArray)entry["size"];
                    if (texture == null || texture.width != (int)size[0] ||
                        texture.height != (int)size[1] || texture.format != TextureFormat.BC7)
                        throw new InvalidDataException($"Wrong size or desktop format for {mapPath} ({texture?.format})");
                    if (inUse.Contains(mapPath)) assigned++;
                    textures++;
                }
                if (assigned == 0) throw new InvalidDataException($"No extracted textures were assigned to {path}");
                bound += assigned;
            }
            Debug.Log($"ECHO_WORLD_TEXTURES_PASS models={models.Count} textures={textures} bound={bound} format=BC7");
            EditorUtility.UnloadUnusedAssetsImmediate();
            EntryWindowsBuild.Export(BuildOptions.None);
        }
    }
}
