using System;
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
        public static void FitSurveillanceApproaches()
        {
            var scene = EditorSceneManager.OpenScene(ScenePath);
            var content = scene.GetRootGameObjects().Single(root => root.name == "Room content").transform;
            var station = content.Find("Echo Station");
            var room = station.Find("Surveillance and mirror");
            var gallery = room.Find("Surveillance scanner gallery");
            var deck = gallery.Find("Graphite deck and recessed drainage");
            var discharge = room.Find("Surveillance scanner grid/Optical discharge channels");
            var wing = room.GetComponent<StationSurveillanceWing>();
            var route = content.GetComponentInChildren<StormworksRoute>(true);
            if (!deck || !discharge || !wing || !route)
                throw new InvalidDataException("R41 requires the fitted R40 surveillance gallery.");

            var routeBefore = EditorJsonUtility.ToJson(route);
            var wingBefore = EditorJsonUtility.ToJson(wing);
            var collision = content.GetComponentsInChildren<Collider>(true)
                .ToDictionary(collider => collider, collider => EditorJsonUtility.ToJson(collider));
            var targets = content.GetComponentsInChildren<RoomEnvironmentMotion>(true)
                .ToDictionary(motion => motion, motion => EditorJsonUtility.ToJson(motion));

            var finish = new StationFinish(route);
            finish.FitScannerApproaches(gallery, deck, discharge);

            var colliders = content.GetComponentsInChildren<Collider>(true);
            var motions = content.GetComponentsInChildren<RoomEnvironmentMotion>(true);
            if (colliders.Length != collision.Count || colliders.Any(c => !collision.TryGetValue(c, out var prior) ||
                    EditorJsonUtility.ToJson(c) != prior) ||
                motions.Length != targets.Count || motions.Any(m => !targets.TryGetValue(m, out var prior) ||
                    EditorJsonUtility.ToJson(m) != prior) ||
                EditorJsonUtility.ToJson(route) != routeBefore || EditorJsonUtility.ToJson(wing) != wingBefore)
                throw new InvalidDataException("Surveillance fittings changed gameplay authority or room motion bindings.");

            AssetDatabase.SaveAssets();
            if (!EditorSceneManager.SaveScene(scene)) throw new IOException("Could not save the surveillance approaches.");
            Debug.Log($"ECHO_R41_SURVEILLANCE_SAVED crossings=4 recessed_markers=16 flanged_feet=8 colliders={collision.Count} motion_zones={targets.Count}");
        }

        private sealed partial class StationFinish
        {
            internal void FitScannerApproaches(Transform gallery, Transform deck, Transform discharge)
            {
                var mounts = gallery.Cast<Transform>().Where(t => t.name == "Scanner socket anchored to deck").ToArray();
                if (mounts.Length != 8 || discharge.childCount != 4)
                    throw new InvalidDataException("Expected two scanner mounts at each of the four crossings.");

                var layer = ResetNamed(gallery, "Fitted surveillance approach guides");
                var deckTop = deck.localPosition.y;
                var litGuide = Emitter("Surveillance cyan aisle guides", new Color(.16f, .64f, .58f), .80f);
                var hazardFace = Emitter("Surveillance ceramic hazard inserts", new Color(.9f, .42f, .115f), .37f);

                foreach (var socket in mounts)
                {
                    var anchor = ResetNamed(socket, "Flush deck flange");
                    var y = deckTop - socket.localPosition.y;
                    Ring(anchor, "Rebated rubber gasket", new Vector3(0f, y + .008f, 0f), .209f, .022f, dark);
                    Ring(anchor, "Machined deck flange", new Vector3(0f, y + .023f, 0f), .188f, .020f, alloy);
                    foreach (var angle in new[] {45f, 135f, 225f, 315f})
                    {
                        var radians = angle * Mathf.Deg2Rad;
                        Ring(anchor, "Captive flange screw", new Vector3(.162f * Mathf.Sin(radians), y + .033f,
                            .162f * Mathf.Cos(radians)), .014f, .009f, fired);
                    }

                    var side = Mathf.Sign(socket.localPosition.x);
                    var z = socket.localPosition.z;
                    foreach (var direction in new[] {-1f, 1f})
                    {
                        var locator = Node(layer, "Side-aisle inset guide", new Vector3(side * 5.24f, deckTop + .013f,
                            z + direction * .55f));
                        Part(locator, "Inset frame", Vector3.zero, new Vector3(.42f, .011f, .17f), dark);
                        Part(locator, "Diffuse guide lens", Vector3.up * .009f, new Vector3(.30f, .008f, .054f), litGuide);
                    }
                }

                foreach (Transform arc in discharge)
                {
                    var tiles = ResetNamed(arc, "Live crossing threshold");
                    var floorY = deckTop - arc.localPosition.y + .016f;
                    foreach (var side in new[] {-1f, 1f})
                    {
                        // Mark the outside limit only. The central deck remains free of redundant stripes.
                        var x = side * (StationSurveillanceWing.ScannerHalfWidth - .39f);
                        Part(tiles, "Crossing limit inlay", new Vector3(x, floorY, 0f),
                            new Vector3(.64f, .009f, .095f), hazardFace);
                    }
                }
            }
        }
    }
}
