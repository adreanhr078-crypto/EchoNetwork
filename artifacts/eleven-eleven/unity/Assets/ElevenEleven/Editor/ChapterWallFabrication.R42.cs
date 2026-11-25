using System.IO;
using System.Linq;
using ElevenEleven.Opening;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using static ElevenEleven.Editor.GodotRoomAssembly;

namespace ElevenEleven.Editor
{
    internal static partial class ChapterWallFabrication
    {
        public static void FitPressureAndSecurityApproach()
        {
            var scene = EditorSceneManager.OpenScene(ScenePath);
            var content = scene.GetRootGameObjects().Single(root => root.name == "Room content").transform;
            var station = content.Find("Echo Station");
            var security = station.Find("Security wing");
            var console = security.Find("Native Godot security geometry/DivertStation/FittedStationCasing");
            var camera = content.GetComponentsInChildren<ChapterCameraFraming>(true).Single();
            var route = content.GetComponentInChildren<StormworksRoute>(true);
            var authority = content.GetComponentsInChildren<Collider>(true).ToDictionary(c => c,
                c => (EditorJsonUtility.ToJson(c), c.transform.localToWorldMatrix));
            var routeState = EditorJsonUtility.ToJson(route);
            var securityState = EditorJsonUtility.ToJson(security.GetComponent<StationSecurityWing>());
            if (!console || console.GetComponentsInChildren<Collider>(true).Length != 0)
                throw new InvalidDataException("The security console needs its separate visual housing.");

            new StationFinish(route).RefitDiversionCabinet(security, console);
            camera.ConfigureApproachArm(new ChapterCameraFraming.ApproachArm(
                station, new Vector3(0f, 0.3f, 24.46f), new Vector3(3.32f, 3f, 1.25f), .72f, 1.25f));
            EditorUtility.SetDirty(camera);

            var after = content.GetComponentsInChildren<Collider>(true);
            if (after.Length != authority.Count || after.Any(c => !authority.TryGetValue(c, out var was) ||
                    was.Item1 != EditorJsonUtility.ToJson(c) || was.Item2 != c.transform.localToWorldMatrix) ||
                EditorJsonUtility.ToJson(route) != routeState ||
                EditorJsonUtility.ToJson(security.GetComponent<StationSecurityWing>()) != securityState)
                throw new InvalidDataException("The approach fit modified a collider or a gameplay binding.");
            if (!EditorSceneManager.SaveScene(scene)) throw new IOException("Could not save the R42 approach fit.");
            Debug.Log($"ECHO_R42_APPROACHES_SAVED colliders={authority.Count} pressure_arm_rear=true recessed_diversion_console=true");
        }

        private sealed partial class StationFinish
        {
            internal void RefitDiversionCabinet(Transform room, Transform housing)
            {
                var renderers = housing.GetComponentsInChildren<MeshRenderer>(true).Where(r => r.enabled).ToArray();
                var bounds = renderers.Select(r => r.bounds).Aggregate((a, b) => { a.Encapsulate(b); return a; });
                if (bounds.size.x < .32f) throw new InvalidDataException("The diversion cabinet has already been recessed.");

                var axis = housing.InverseTransformDirection(room.right);
                var scale = housing.localScale;
                if (Mathf.Abs(axis.x) > .99f) scale.x *= .31f / bounds.size.x;
                else if (Mathf.Abs(axis.z) > .99f) scale.z *= .31f / bounds.size.x;
                else throw new InvalidDataException("The security cabinet is not aligned to the wall.");
                housing.localScale = scale;
                var clearanceEdge = room.TransformPoint(new Vector3(-3.78f, 0f, 0f)).x;
                housing.position += room.right * (clearanceEdge - renderers.Max(r => r.bounds.max.x));
                PrefabUtility.RecordPrefabInstancePropertyModifications(housing);
                var mount = ResetNamed(room, "Wall-mounted diversion cabinet");
                var local = room.InverseTransformPoint(bounds.center);
                Part(mount, "Wall rail behind diversion cabinet", new Vector3(-4.16f, local.y, local.z),
                    new Vector3(.16f, .96f, .82f), dark);
                Part(mount, "Recessed supply duct", new Vector3(-4.115f, .375f, local.z),
                    new Vector3(.112f, .31f, .132f), alloy);
            }
        }
    }
}
