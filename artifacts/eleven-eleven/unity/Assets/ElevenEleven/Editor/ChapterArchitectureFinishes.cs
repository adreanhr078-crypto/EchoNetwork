using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using Object = UnityEngine.Object;

namespace ElevenEleven.Editor
{
    internal sealed class ChapterArchitectureFinishes
    {
        private const string Opening = "Assets/ElevenEleven/Opening/";
        private const string Stormworks = Opening + "Stormworks/";
        private const string Folder = Stormworks + "ChapterArchitectureFinishes";
        private const string StationSteel = Stormworks + "StationFinishes/Chronostat oxide-filled steel.mat";
        private const string SteelChannels = Stormworks + "StationFinishes/Station-BrushedSteel-MetalSmooth.png";
        private const string ClinicalDeck = Stormworks + "ChapterRoomPolish/Clinical deck.mat";

        private enum Surface { None, Deck, Wall, Overhead }

        private static readonly Regex Deck = new Regex(
            @"floor|deck|tread|walkway|landing|grating|gantry|catwalk|plaza", RegexOptions.IgnoreCase);
        private static readonly Regex Wall = new Regex(
            @"wall|bulkhead|cladding|facade|abutment|blast partition|service panel|servicepanel|sector11servicemodule",
            RegexOptions.IgnoreCase);
        private static readonly Regex Roof = new Regex(
            @"ceiling|roof|canopy|soffit", RegexOptions.IgnoreCase);
        private static readonly Regex Detail = new Regex(
            @"instrument|screen|display|readout|indicator|marker|status|telemetry lens|optics|optical|portal|guide|trim|stripe|" +
            @"inlay|light|practical|luminaire|fixture|diffuser|glass|window|mirror|curtain|specimen|projection|hologram|shard|" +
            @"debris|warning|rail|beacon|flange|collar|gasket|plate mount|desk|shelf|suspension|fittings|utility post|duct|service bank",
            RegexOptions.IgnoreCase);
        private static readonly Regex NearWallKit = new Regex(
            @"signal wall cassette|security wall diagnostics|smoked-glass monitoring bay|pressure telemetry bank", RegexOptions.IgnoreCase);
        private static readonly Regex ProtectedMaterial = new Regex(
            @"lens|optic|screen|diffuser|indicator|status|projection|puddle|water|liquid|mirror|warning|light strip|guide enamel",
            RegexOptions.IgnoreCase);
        private static readonly Regex FlatSurface = new Regex(
            @"^wall enamel$|^ceramic steel$|^containment$|^bulkhead$|^containmentwallfinish$|^station mineral enamel$",
            RegexOptions.IgnoreCase);

        private readonly Dictionary<(Material, Surface, bool), Material> variants =
            new Dictionary<(Material, Surface, bool), Material>();
        private readonly Dictionary<(Texture, Surface), Texture> bases =
            new Dictionary<(Texture, Surface), Texture>();
        private readonly Material steel = AssetDatabase.LoadAssetAtPath<Material>(StationSteel);
        private readonly Texture2D steelChannels = AssetDatabase.LoadAssetAtPath<Texture2D>(SteelChannels);
        private readonly Material ceramic = AssetDatabase.LoadAssetAtPath<Material>(ClinicalDeck);

        internal static int Apply(Transform content, Transform station)
        {
            if (!content || !station || !station.IsChildOf(content))
                throw new ArgumentException("The architecture pass requires the room content and its Echo Station.");

            if (!AssetDatabase.IsValidFolder(Folder))
                AssetDatabase.CreateFolder(Stormworks.TrimEnd('/'), "ChapterArchitectureFinishes");

            var pass = new ChapterArchitectureFinishes();
            if (!pass.steel || !pass.steelChannels || !pass.ceramic)
                throw new InvalidDataException("The cached chapter PBR finish materials must be imported.");

            var renderers = 0;
            var slots = 0;
            foreach (var renderer in content.GetComponentsInChildren<MeshRenderer>(true))
            {
                if (!renderer.enabled) continue;
                var materials = renderer.sharedMaterials;
                var kind = Classify(renderer.transform, content);
                if (kind == Surface.None) continue;
                var changed = false;
                for (var i = 0; i < materials.Length; ++i)
                {
                    var source = materials[i];
                    if (!source) continue;
                    var finish = pass.Finish(source, kind, renderer.transform);
                    if (finish == source) continue;
                    materials[i] = finish;
                    changed = true;
                    ++slots;
                }
                if (!changed) continue;
                renderer.sharedMaterials = materials;
                EditorUtility.SetDirty(renderer);
                if (PrefabUtility.IsPartOfPrefabInstance(renderer))
                    PrefabUtility.RecordPrefabInstancePropertyModifications(renderer);
                ++renderers;
            }

            AssetDatabase.SaveAssets();
            Debug.Log($"ECHO_NEUTRAL_ARCHITECTURE renderers={renderers} slots={slots} " +
                $"convertedMaterials={pass.variants.Count} albedoProfiles={pass.bases.Count}");
            return renderers;
        }

        private static Surface Classify(Transform item, Transform content)
        {
            // Imported named structural nodes often wrap an anonymous mesh child.
            for (var node = item; node && node != content; node = node.parent)
            {
                var label = node.name;
                if (NearWallKit.IsMatch(label)) return Surface.Wall;
                if (Detail.IsMatch(label)) return Surface.None;
                if (Deck.IsMatch(label)) return Surface.Deck;
                if (Roof.IsMatch(label)) return Surface.Overhead;
                if (Wall.IsMatch(label)) return Surface.Wall;
                if (node != item && !label.StartsWith("_MeshInstance", StringComparison.Ordinal) &&
                    !item.name.StartsWith("_MeshInstance", StringComparison.Ordinal) &&
                    !item.name.StartsWith("tripo_node", StringComparison.Ordinal))
                    break;
            }
            return Surface.None;
        }

        private Material Finish(Material source, Surface surface, Transform placement)
        {
            if (ProtectedMaterial.IsMatch(source.name) || !IsOpaque(source) || HasEmission(source))
                return source;

            var path = AssetDatabase.GetAssetPath(source);
            if (path.StartsWith(Folder + "/", StringComparison.Ordinal)) return source;
            var baseMap = Property(source, "_BaseMap", "baseColorTexture", "_MainTex");
            var baseColor = Property(source, "_BaseColor", "baseColorFactor", "_Color");
            if (baseColor == null) return source;
            var color = source.GetColor(baseColor);
            var texture = baseMap == null ? null : source.GetTexture(baseMap);
            var bakedGeometry = path.EndsWith("-Godot-Art.glb", StringComparison.OrdinalIgnoreCase);
            var grayWalls = FlatSurface.IsMatch(source.name) ||
                (bakedGeometry && placement.name.StartsWith("_MeshInstance", StringComparison.Ordinal));
            var key = (source, surface, grayWalls);
            if (variants.TryGetValue(key, out var known)) return known;

            var finish = source;
            if (!texture && (grayWalls || IsCool(color)))
                finish = FlatPbr(source, surface, grayWalls);
            else if (texture)
            {
                var corrected = CorrectBase(texture, surface);
                if (corrected != texture || IsCool(color))
                {
                    finish = new Material(source);
                    finish.SetTexture(baseMap, corrected);
                    if (IsCool(color)) finish.SetColor(baseColor, Neutral(color, surface));
                }
            }

            if (finish != source)
            {
                finish.name = source.name + " neutral " + surface.ToString().ToLowerInvariant();
                var target = Folder + "/" + CleanName(finish.name) + " " + StableId(source) + (grayWalls ? "-shell" : "") + ".mat";
                var saved = AssetDatabase.LoadAssetAtPath<Material>(target);
                if (saved)
                {
                    EditorUtility.CopySerialized(finish, saved);
                    Object.DestroyImmediate(finish);
                    EditorUtility.SetDirty(saved);
                    finish = saved;
                }
                else AssetDatabase.CreateAsset(finish, target);
            }
            variants.Add(key, finish);
            return finish;
        }

        private Material FlatPbr(Material source, Surface surface, bool shell)
        {
            var grayCeramic = surface == Surface.Overhead || source.name.IndexOf("ceramic", StringComparison.OrdinalIgnoreCase) >= 0;
            var output = new Material(steel);
            var sourceColor = source.GetColor(Property(source, "_BaseColor", "baseColorFactor", "_Color"));
            var brightness = Luminance(sourceColor);
            brightness = shell ? Mathf.Clamp(brightness * 1.23f, .29f, .56f) : Mathf.Clamp(brightness, .12f, .65f);
            var tint = Neutral(new Color(brightness, brightness, brightness, 1f), surface);
            // Reuse the ceramic response while keeping the finer brushed grain on broad wall and ceiling surfaces.
            output.SetTexture("_MetallicGlossMap", grayCeramic ? ceramic.GetTexture("_MetallicGlossMap") : steelChannels);
            output.EnableKeyword("_METALLICSPECGLOSSMAP");
            output.SetFloat("_Smoothness", grayCeramic ? .61f : .87f);
            if (source.HasProperty("_Cull")) output.SetFloat("_Cull", source.GetFloat("_Cull"));
            else if (source.HasProperty("cullMode")) output.SetFloat("_Cull", source.GetFloat("cullMode"));
            output.SetColor("_BaseColor", tint);
            output.SetFloat("_BumpScale", surface == Surface.Overhead ? .28f : .58f);
            return output;
        }

        private Texture CorrectBase(Texture source, Surface surface)
        {
            var key = (source, surface);
            if (bases.TryGetValue(key, out var known)) return known;
            var correction = source;
            var aspectScale = Mathf.Min(1f, 1024f / Mathf.Max(source.width, source.height));
            var width = Mathf.Max(1, Mathf.RoundToInt(source.width * aspectScale));
            var height = Mathf.Max(1, Mathf.RoundToInt(source.height * aspectScale));
            var copy = new Texture2D(width, height, TextureFormat.RGBA32, false, false);
            var active = RenderTexture.active;
            var srgbWrite = GL.sRGBWrite;
            var buffer = RenderTexture.GetTemporary(width, height, 0, RenderTextureFormat.ARGB32, RenderTextureReadWrite.sRGB);
            try
            {
                GL.sRGBWrite = QualitySettings.activeColorSpace == ColorSpace.Linear;
                Graphics.Blit(source, buffer);
                RenderTexture.active = buffer;
                copy.ReadPixels(new Rect(0, 0, width, height), 0, 0, false);
                var pixels = copy.GetPixels32();
                var cool = 0;
                foreach (var pixel in pixels)
                    if (IsCool(pixel)) ++cool;
                if (cool * 100 >= pixels.Length * 4)
                {
                    for (var i = 0; i < pixels.Length; ++i)
                    {
                        if (!IsCool(pixels[i])) continue;
                        pixels[i] = Neutral(pixels[i], surface);
                    }
                    copy.SetPixels32(pixels);
                    copy.Apply(false);
                    var path = Folder + "/" + CleanName(source.name) + "-" + StableId(source) +
                        "-" + surface.ToString().ToLowerInvariant() + ".png";
                    var png = copy.EncodeToPNG();
                    var changed = !File.Exists(path) || !File.ReadAllBytes(path).SequenceEqual(png);
                    if (changed)
                    {
                        File.WriteAllBytes(path, png);
                        AssetDatabase.ImportAsset(path, ImportAssetOptions.ForceSynchronousImport);
                    }
                    if (changed && AssetImporter.GetAtPath(path) is TextureImporter importer)
                    {
                        importer.sRGBTexture = true;
                        importer.mipmapEnabled = true;
                        importer.maxTextureSize = 1024;
                        importer.textureCompression = TextureImporterCompression.CompressedHQ;
                        importer.alphaIsTransparency = false;
                        importer.anisoLevel = Mathf.Max(4, source.anisoLevel);
                        importer.wrapModeU = source.wrapModeU;
                        importer.wrapModeV = source.wrapModeV;
                        importer.filterMode = source.filterMode;
                        importer.SaveAndReimport();
                    }
                    correction = AssetDatabase.LoadAssetAtPath<Texture2D>(path);
                }
            }
            finally
            {
                GL.sRGBWrite = srgbWrite;
                RenderTexture.active = active;
                RenderTexture.ReleaseTemporary(buffer);
                Object.DestroyImmediate(copy);
            }
            bases.Add(key, correction);
            return correction;
        }

        private static bool IsOpaque(Material material) =>
            material.renderQueue < (int)RenderQueue.Transparent &&
            (!material.HasProperty("_Surface") || material.GetFloat("_Surface") < .5f);

        private static bool HasEmission(Material material)
        {
            var property = Property(material, "_EmissionColor", "emissiveFactor");
            if (property == null) return false;
            var color = material.GetVector(property);
            return Mathf.Max(color.x, Mathf.Max(color.y, color.z)) > .055f;
        }

        private static string Property(Material material, params string[] names)
        {
            foreach (var name in names)
                if (material.HasProperty(name)) return name;
            return null;
        }

        private static bool IsCool(Color color) =>
            Mathf.Max(color.g, color.b) > color.r + .019f &&
            color.b > color.r + .015f && color.b >= color.g * .93f;

        private static float Luminance(Color color) => .2126f * color.r + .7152f * color.g + .0722f * color.b;

        private static Color Neutral(Color source, Surface surface)
        {
            var gray = Luminance(source);
            var warmth = surface == Surface.Deck ? .039f : .055f;
            return new Color(Mathf.Min(1f, gray * (1f + warmth)), gray, gray * (1f - warmth), source.a);
        }

        private static string StableId(Object asset)
        {
            if (AssetDatabase.TryGetGUIDAndLocalFileIdentifier(asset, out string guid, out long id) && !string.IsNullOrEmpty(guid))
                return guid.Substring(0, Math.Min(8, guid.Length)) + "-" + id;
            return Hash128.Compute(asset.name).ToString().Substring(0, 12);
        }

        private static string CleanName(string name) => Regex.Replace(name, @"[^A-Za-z0-9 _-]", "").Trim();
    }
}
