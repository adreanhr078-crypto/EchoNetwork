using System.Linq;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using static ElevenEleven.Editor.GodotRoomAssembly;

namespace ElevenEleven.Editor
{
    internal static class StationExaminationArt
    {
        private const string Folder = "Assets/ElevenEleven/Opening/Stormworks/";

        internal static Transform Dress(Transform theatre, Transform art)
        {
            var ceramic = StormworksConstruction.PersistentMaterial("Examination ceramic deck", "StormworksSurface.shader");
            ceramic.SetColor("_BaseColor", new Color(0.23f, 0.29f, 0.37f));
            ceramic.SetColor("_ShadowTone", new Color(0.20f, 0.14f, 0.34f));
            ceramic.SetFloat("_PanelScale", 0.53f);
            ceramic.SetFloat("_Wetness", 0.22f);
            Save(ceramic);
            foreach (var surface in new[] { "ClinicalPorcelainFloor", "SurgicalDaisPlatform", "TheaterApproach" })
                foreach (var mesh in Find(art, surface).GetComponentsInChildren<MeshRenderer>())
                    mesh.sharedMaterial = ceramic;
            StationSurfaceDressing.Examination(theatre, ceramic);

            var glass = StormworksConstruction.PersistentMaterial("Examination vitrine optics", "ContainmentOptics.shader");
            glass.SetColor("_Tint", new Color(0.15f, 0.62f, 0.95f, 0.37f));
            glass.SetFloat("_Mode", 0);
            Save(glass);
            foreach (var surface in new[] { "ClinicalVitrineGlass", "_MeshInstance3D_689" })
                Find(art, surface).GetComponent<MeshRenderer>().sharedMaterial = glass;

            SetDisplay(Find(art, "ClinicalDiagnosticReadout").GetComponent<MeshRenderer>(),
                "Examination diagnostic readout", "ExaminationDiagnostic.png");
            var header = GameObject.CreatePrimitive(PrimitiveType.Quad);
            header.name = "Observation display glass";
            header.transform.SetParent(theatre, false);
            header.transform.localPosition = new Vector3(0f, 5f, 39.51f);
            header.transform.localScale = new Vector3(9.76f, 2.22f, 1f);
            Object.DestroyImmediate(header.GetComponent<Collider>());
            SetDisplay(header.GetComponent<MeshRenderer>(),
                "Examination observation panel", "ExaminationObservation.png");

            DressWalls(theatre);
            var altar = Find(art, "ZeroContractAltar");
            foreach (var mesh in altar.GetComponentsInChildren<MeshRenderer>()) mesh.enabled = false;
            var amplifier = PlaceArt(theatre, Folder + "MemoryCore-Tripo.glb", "Memory resonance altar");
            amplifier.localPosition = new Vector3(0f, 0f, 32f);
            FitToFloor(amplifier, 1.62f);

            var kinja = PlaceArt(theatre, Folder + "Kinja-Godot.glb", "Kinja");
            kinja.localPosition = new Vector3(-2.28f, 1.2f, 18.95f);
            kinja.localRotation = Quaternion.Euler(0f, 180f, 0f);
            FitToFloor(kinja, 1.80f);
            var body = Node(theatre, "Kinja body clearance", new Vector3(-2.28f, 2.1f, 18.95f));
            var capsule = body.gameObject.AddComponent<CapsuleCollider>();
            capsule.height = 1.78f;
            capsule.radius = 0.27f;
            return kinja;
        }

        private static void DressWalls(Transform theatre)
        {
            var wall = Node(theatre, "Clinical PBR wall modules", Vector3.zero);
            var tile = AssetDatabase.LoadAssetAtPath<GameObject>(Folder + "ClinicalWall-Tripo.glb");
            foreach (var side in new[] { -1f, 1f })
            {
                foreach (var depth in new[] { 1.6f, 4.6f, 7.6f, 10.6f, 13.6f, 16.6f, 19.6f, 22.6f, 25.6f, 28.6f, 31.6f, 34.6f, 37.6f })
                    for (var row = 0; row < 3; row++)
                        PlaceWall(tile, wall, new Vector3(side * 15.74f, 0.11f + row * 3f, depth), 180f + side * 90f);

                for (var column = 0; column < 5; column++)
                    for (var row = 0; row < 3; row++)
                        PlaceWall(tile, wall, new Vector3(side * (2.7f + column * 3f), 0.11f + row * 3f, 39.76f), 180f);
            }
        }

        private static void PlaceWall(GameObject tile, Transform parent, Vector3 local, float yaw)
        {
            var wall = (GameObject)PrefabUtility.InstantiatePrefab(tile, parent);
            wall.transform.localPosition = local;
            wall.transform.localRotation = Quaternion.Euler(0f, yaw, 0f);
        }

        private static void FitToFloor(Transform model, float height)
        {
            var renderers = model.GetComponentsInChildren<Renderer>();
            var bounds = renderers.Select(item => item.bounds).Aggregate((first, second) =>
            {
                first.Encapsulate(second);
                return first;
            });
            var scale = height / bounds.size.y;
            var anchor = model.position;
            model.localScale *= scale;
            var center = new Vector3(bounds.center.x, bounds.min.y, bounds.center.z);
            model.position += (anchor - center) * scale;
        }

        private static void SetDisplay(MeshRenderer display, string name, string texturePath)
        {
            var path = Folder + name + ".mat";
            var material = AssetDatabase.LoadAssetAtPath<Material>(path);
            if (material == null)
            {
                material = new Material(Shader.Find("Universal Render Pipeline/Unlit"));
                AssetDatabase.CreateAsset(material, path);
            }
            material.SetTexture("_BaseMap", AssetDatabase.LoadAssetAtPath<Texture2D>(Folder + texturePath));
            Save(material);
            display.sharedMaterial = material;
        }

        private static void Save(Material material)
        {
            EditorUtility.SetDirty(material);
            AssetDatabase.SaveAssetIfDirty(material);
        }
    }
}
