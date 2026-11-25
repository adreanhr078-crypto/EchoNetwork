using System.IO;
using System.Linq;
using ElevenEleven.Opening;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using static ElevenEleven.Editor.GodotRoomAssembly;

namespace ElevenEleven.Editor
{
    internal static partial class ChapterWallFabrication
    {
        public static void ClearSurveillanceRecoveryCamera()
        {
            var scene = EditorSceneManager.OpenScene(ScenePath);
            var content = scene.GetRootGameObjects().Single(root => root.name == "Room content").transform;
            var bay = content.Find("Echo Station/Surveillance and mirror");
            var camera = content.GetComponentsInChildren<ChapterCameraFraming>(true).Single();
            var station = bay.parent;
            var colliders = content.GetComponentsInChildren<Collider>(true).ToDictionary(c => c, c => EditorJsonUtility.ToJson(c));
            var wing = bay.GetComponent<StationSurveillanceWing>();
            var route = content.GetComponentInChildren<StormworksRoute>(true);
            var wingState = EditorJsonUtility.ToJson(wing);
            var routeState = EditorJsonUtility.ToJson(route);
            using var layout = new SerializedObject(camera);
            var limits = layout.FindProperty("approachArms");
            if (limits.arraySize != 1 || limits.GetArrayElementAtIndex(0).FindPropertyRelative("reference").objectReferenceValue != bay.parent)
                throw new InvalidDataException("The existing pressure approach is missing or there are already extra volumes.");

            limits.InsertArrayElementAtIndex(1);
            var clearance = limits.GetArrayElementAtIndex(1);
            clearance.FindPropertyRelative("reference").objectReferenceValue = bay;
            clearance.FindPropertyRelative("center").vector3Value = new Vector3(0f, .17f, 2.20f);
            clearance.FindPropertyRelative("size").vector3Value = new Vector3(2.9f, 3.0f, 1.20f);
            clearance.FindPropertyRelative("blendMargin").floatValue = .77f;
            clearance.FindPropertyRelative("maximumArm").floatValue = 1.15f;
            layout.ApplyModifiedPropertiesWithoutUndo();

            var exterior = FitObservatoryExteriors(station);

            var after = content.GetComponentsInChildren<Collider>(true);
            if (after.Length != colliders.Count || after.Any(c => !colliders.TryGetValue(c, out var was) || was != EditorJsonUtility.ToJson(c)) ||
                wingState != EditorJsonUtility.ToJson(wing) || routeState != EditorJsonUtility.ToJson(route))
                throw new InvalidDataException("Recovery framing changed scanner authority or physical collisions.");
            AssetDatabase.SaveAssets();
            if (!EditorSceneManager.SaveScene(scene)) throw new IOException("Could not save the recovery framing and observatory exteriors.");
            Debug.Log($"ECHO_R45_SURVEILLANCE_SAVED approach_arms={limits.arraySize} colliders={colliders.Count} exterior_panels={exterior}");
        }

        private static int FitObservatoryExteriors(Transform station)
        {
            const string specimen = "Specimen containment/Native Godot specimen geometry/";
            const string archive = "Memory archive wing/Native Godot archive geometry/";
            const string security = "Security wing/Native Godot security geometry/";
            var targets = new[]
            {
                (specimen + "SouthWallWest/_MeshInstance3D_184", "Specimen west lower exterior", Vector3.back),
                (specimen + "SouthWallEast/_MeshInstance3D_185", "Specimen east jamb exterior", Vector3.back),
                (security + "Wall/_MeshInstance3D_3", "Security corridor outer hull", Vector3.left),
                (archive + "EastWallSouth/_MeshInstance3D_260", "Archive outer hull", Vector3.right)
            };
            var root = ResetNamed(station.Find("Memory Observatory"), "Observatory exterior shell cladding");
            var template = AssetDatabase.LoadAssetAtPath<Material>(Art + "StationFinishes/Chronostat oxide-filled steel.mat");
            var powder = FinishAt(template, "R45 exterior dark ceramic steel", new Color(.25f, .28f, .31f), .33f);
            var panels = FinishAt(template, "R45 exterior folded gunmetal", new Color(.45f, .48f, .49f), .47f);
            var trim = FinishAt(template, "R45 exterior tarnished flange", new Color(.57f, .49f, .38f), .55f);
            var count = 0;
            foreach (var (path, name, outward) in targets)
            {
                var renderer = station.Find(path)?.GetComponent<MeshRenderer>();
                if (!renderer || !renderer.enabled) throw new InvalidDataException("Could not find the surveyed exterior face: " + path);
                var bounds = renderer.bounds;
                var across = Vector3.Cross(Vector3.up, outward);
                var position = bounds.center + outward * (Vector3.Dot(bounds.extents, Abs(outward)) + .019f);
                var width = Vector3.Dot(bounds.size, Abs(across));
                var height = bounds.size.y;
                var face = Node(root, name, root.InverseTransformPoint(position));
                face.rotation = Quaternion.LookRotation(outward, Vector3.up);
                face.gameObject.AddComponent<MeshFilter>().sharedMesh = ExteriorPanelMesh(name, width, height);
                var finish = face.gameObject.AddComponent<MeshRenderer>();
                finish.sharedMaterials = new[] { powder, panels, trim };
                finish.shadowCastingMode = ShadowCastingMode.Off;
                count++;
            }
            return count;
        }

        private static Mesh ExteriorPanelMesh(string name, float width, float height)
        {
            var plates = new Plates(3);
            plates.Raised(0f, 0f, width - .025f, height - .024f, .060f, .020f, .009f, 0);
            var count = Mathf.Clamp(Mathf.CeilToInt(width / 3.05f), 1, 12);
            var bayWidth = width / count;
            var web = Mathf.Min(bayWidth * .11f, .16f);
            for (var i = 0; i < count; i++)
            {
                var x = -width * .5f + (i + .5f) * bayWidth;
                plates.Raised(x, height * -.297f, bayWidth - web * 1.8f, height * .306f, .135f, .079f, .038f, 1);
                plates.Raised(x, height * .064f, bayWidth - web * 1.8f, height * .376f, .172f, .096f, .048f, 1);
                plates.Raised(x, height * .344f, bayWidth - web * 1.8f, height * .104f, .064f, .060f, .016f, 1);
                plates.Raised(x, height * .366f, bayWidth * .44f, height * .018f, .035f, .093f, .008f, 2);
                if (i > 0)
                    plates.Raised(x - bayWidth * .5f, 0f, web, height * .93f, .021f, .105f, .012f, 2);
            }
            foreach (var y in new[] { -.462f, .442f })
                plates.Raised(0f, height * y, width - .031f, height * .039f, .052f, .095f, .014f, 2);
            var designed = plates.Build(name);
            var path = Folder + "R45 " + name + ".asset";
            var saved = AssetDatabase.LoadAssetAtPath<Mesh>(path);
            if (!saved)
            {
                AssetDatabase.CreateAsset(designed, path);
                return designed;
            }
            EditorUtility.CopySerialized(designed, saved);
            UnityEngine.Object.DestroyImmediate(designed);
            EditorUtility.SetDirty(saved);
            return saved;
        }

        private static Vector3 Abs(Vector3 value) => new Vector3(Mathf.Abs(value.x), Mathf.Abs(value.y), Mathf.Abs(value.z));
    }
}
