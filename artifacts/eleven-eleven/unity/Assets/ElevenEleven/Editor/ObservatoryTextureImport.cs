using UnityEditor;
using UnityEngine;

namespace ElevenEleven.Editor
{
    internal sealed class ObservatoryTextureImport : AssetPostprocessor
    {
        private const string Maps = "Assets/ElevenEleven/Opening/Stormworks/Observatory/Maps/";
        private const string Opening = "Assets/ElevenEleven/Opening/";

        private void OnPreprocessTexture()
        {
            var isWorldMap = assetPath.StartsWith(Opening, System.StringComparison.Ordinal) &&
                assetPath.Contains("/RuntimeMaps/");
            if (!isWorldMap && !assetPath.StartsWith(Maps, System.StringComparison.Ordinal)) return;
            var importer = (TextureImporter)assetImporter;
            importer.sRGBTexture = System.IO.Path.GetFileNameWithoutExtension(assetPath).EndsWith("-srgb",
                System.StringComparison.Ordinal);
            importer.isReadable = false;
            importer.mipmapEnabled = true;
            importer.maxTextureSize = 8192;
            importer.anisoLevel = 4;
            importer.textureCompression = TextureImporterCompression.CompressedHQ;
            var desktop = importer.GetPlatformTextureSettings("Standalone");
            desktop.overridden = true;
            desktop.format = TextureImporterFormat.BC7;
            desktop.maxTextureSize = 8192;
            desktop.compressionQuality = 90;
            importer.SetPlatformTextureSettings(desktop);
        }
    }
}
