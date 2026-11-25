using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using ElevenEleven.Opening;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using static ElevenEleven.Editor.GodotRoomAssembly;
using Object = UnityEngine.Object;

namespace ElevenEleven.Editor
{
    internal static partial class ChapterWallFabrication
    {
        private const string VisibleLayer = "Measured wall and deck finishes";
        private static readonly Color WarmPractical = new Color(1f, .84f, .67f);

        [MenuItem("11.11/Fit Visible Wall Finishes")]
        public static void FitVisibleFaces()
        {
            if (!Application.isBatchMode && !EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo()) return;
            var scene = EditorSceneManager.OpenScene(ScenePath);
            var content = scene.GetRootGameObjects().Single(root => root.name == "Room content").transform;
            var station = content.Find("Echo Station");
            var sector = content.Find("Sector 11");
            var security = station.Find("Security wing");
            var observatory = station.Find("Memory Observatory");
            var surveillance = station.Find("Surveillance and mirror");
            var fabrication = content.GetComponentsInChildren<MeshRenderer>(true)
                .Count(renderer => renderer.name == "Recessed wall service cassette");
            if (fabrication < 550) throw new InvalidOperationException("Open the saved wall fabrication first.");
            var colliders = content.GetComponentsInChildren<Collider>(true).ToDictionary(c => c, c => EditorJsonUtility.ToJson(c));
            var steel = AssetDatabase.LoadAssetAtPath<Material>(Art + "StationFinishes/Chronostat oxide-filled steel.mat");
            var roomMaterials = new[]
            {
                FinishAt(steel, "Oil-darkened graphite gasket", new Color(.33f,.309f,.274f), .30f),
                FinishAt(steel, "Aged manganese service plates", new Color(.62f,.590f,.541f), .41f),
                FinishAt(steel, "Brushed fasteners and corner shoes", new Color(.70f,.675f,.630f), .57f)
            };
            var signalMesh = FaceMesh("Signal pressed cooling bay", 0);
            var operationsMesh = FaceMesh("Security access bay", 1);
            var envelopeMesh = FaceMesh("Station exterior foundation bay", 2);
            var signalLayer = VisibleRoot(station);
            var securityLayer = VisibleRoot(security);
            var observatoryLayer = VisibleRoot(observatory);
            var surveillanceLayer = VisibleRoot(surveillance);

            var signalPanels = 0;
            var signalArches = station.Find("Flow reference architectural kit").Cast<Transform>()
                .Where(part => part.name.StartsWith("Signal roof frame ", StringComparison.Ordinal))
                .Select(part => station.InverseTransformPoint(part.position).z).OrderBy(z => z).ToArray();
            foreach (var source in sector.GetComponentsInChildren<MeshRenderer>(true)
                         .Where(renderer => renderer.transform.parent == sector &&
                             renderer.name is "ObservationModule" or "ServiceModule"))
            {
                var side = station.InverseTransformPoint(source.bounds.center).x > 0f ? Vector3.left : Vector3.right;
                var inward = station.TransformDirection(side);
                var at = MountOnDominantPlane(source, inward);
                var originalMaterials = source.sharedMaterials;
                for (var slot = 0; slot < originalMaterials.Length; slot++)
                    if (originalMaterials[slot] &&
                        originalMaterials[slot].name.StartsWith("Containment ceramic", StringComparison.Ordinal))
                        originalMaterials[slot] = roomMaterials[0];
                source.sharedMaterials = originalMaterials;
                PrefabUtility.RecordPrefabInstancePropertyModifications(source);
                signalPanels += FitSignalBays(signalLayer, station, source, at, inward, signalArches, signalMesh, roomMaterials);
            }
            if (signalArches.Length != 3 || signalPanels < 6)
                throw new InvalidDataException($"Unexpected Signal bay layout. Arches={signalArches.Length}, finished bays={signalPanels}.");

            var nativeSecurity = security.Find("Native Godot security geometry");
            var securityPanels = 0;
            foreach (var path in new[]
                     {
                         "_StaticBody3D_29/_MeshInstance3D_28", "EntrancePier/_MeshInstance3D_59",
                         "_StaticBody3D_61/_MeshInstance3D_60", "ExitPier/_MeshInstance3D_156",
                         "_StaticBody3D_158/_MeshInstance3D_157", "ExitLintel/_MeshInstance3D_159"
                     })
            {
                var source = nativeSecurity.Find(path)?.GetComponent<MeshRenderer>();
                if (!source || !source.enabled) throw new InvalidDataException($"Missing visible Security shell {path}.");
                var inward = WallNormal(source, security.TransformPoint(new Vector3(0f, 2f, 9f)));
                var at = MountOnDominantPlane(source, inward);
                source.sharedMaterial = roomMaterials[0];
                PrefabUtility.RecordPrefabInstancePropertyModifications(source);
                var count = source.bounds.size.z > 6f ? 6 : 1;
                securityPanels += AttachFace(securityLayer, source, at, inward, operationsMesh, roomMaterials, count, .95f, .91f);
            }

            var stationPanels = 0;
            var lab = station.TransformPoint(new Vector3(15f, 2.4f, 67f));
            foreach (var name in new[] { "Lab west envelope", "Lab east envelope", "Lab rear envelope" })
            {
                var source = station.Find(name)?.GetComponent<MeshRenderer>();
                if (!source || !source.enabled) throw new InvalidDataException($"Missing exposed lab structure {name}.");
                var inside = WallNormal(source, lab);
                var outside = -inside;
                stationPanels += AttachFace(observatoryLayer, source, MountOnDominantPlane(source, outside),
                    outside, envelopeMesh, roomMaterials, 3, .86f, .82f);
                // The exterior retrofit is separate from the existing basalt backing and inner equipment.
            }

            var relievedSurveillanceBays = FitSurveillanceHeaders(surveillance, surveillanceLayer, operationsMesh, roomMaterials);
            var deckTemplates = new Dictionary<Material, Material>();
            var deckUpdates = 0;
            foreach (var renderer in content.GetComponentsInChildren<MeshRenderer>(true))
            {
                if (!renderer.enabled) continue;
                var part = renderer.transform;
                var pressureDeck = (part.IsChildOf(sector) || part.IsChildOf(station)) &&
                    station.InverseTransformPoint(renderer.bounds.center).z is > -9f and < 34f &&
                    !part.IsChildOf(security) && !part.IsChildOf(surveillance);
                if (!pressureDeck && !part.IsChildOf(security) && !part.IsChildOf(surveillance)) continue;
                var materialSlots = renderer.sharedMaterials;
                var changed = false;
                for (var slot = 0; slot < materialSlots.Length; slot++)
                {
                    var template = materialSlots[slot];
                    if (!template) continue;
                    var builtInDeck = template.HasProperty("_BaseMap") && template.GetTexture("_BaseMap") &&
                        (template.name.StartsWith("Pressure deck", StringComparison.Ordinal) ||
                         template.name.StartsWith("Service deck", StringComparison.Ordinal));
                    var tripoDeck = part.name == "WetDeckSection" && template.name.Contains("neutral deck") &&
                        template.HasProperty("baseColorFactor") && template.HasProperty("metallicRoughnessTexture");
                    if (!builtInDeck && !tripoDeck) continue;
                    if (!deckTemplates.TryGetValue(template, out var finish))
                    {
                        finish = tripoDeck ? TripoDeckFinish(template) : NeutralDeckFinish(template);
                        deckTemplates.Add(template, finish);
                    }
                    materialSlots[slot] = finish;
                    changed = true;
                }
                if (!changed) continue;
                renderer.sharedMaterials = materialSlots;
                PrefabUtility.RecordPrefabInstancePropertyModifications(renderer);
                deckUpdates++;
            }
            if (deckUpdates < 15) throw new InvalidDataException("The priority room deck surfaces were not found.");

            GrazingKey(signalLayer, "Entry bay practical reflection", new Vector3(5.75f,5.55f,-2.85f),
                new Vector3(8.1f,2.6f,2.2f), WarmPractical, 21f, 10f);
            GrazingKey(signalLayer, "Viewport and access collar spill", new Vector3(-5.65f,4.6f,7f),
                new Vector3(-8.1f,2.25f,5.3f), new Color(.71f,.89f,.91f), 14f, 8f);
            GrazingKey(signalLayer, "Return wall practical reflection", new Vector3(-6.4f,5.6f,12.7f),
                new Vector3(-8.1f,2.5f,10f), WarmPractical, 18f, 10f);
            GrazingKey(securityLayer, "Checkpoint return reflected practical", new Vector3(-2.45f,4.3f,9.4f),
                new Vector3(-4.27f,1.72f,11.85f), WarmPractical, 13f, 8f);
            GrazingKey(surveillanceLayer, "Upper frame reflection from bay key", new Vector3(-10.65f,6.62f,9.5f),
                new Vector3(-13.4f,3.15f,12.2f), WarmPractical, 14f, 9f);

            var motion = station.GetComponentsInChildren<RoomEnvironmentMotion>(true);
            var moving = motion.Select(zone =>
                (zone.name, count: new SerializedObject(zone).FindProperty("pieces").arraySize)).ToArray();
            if (moving.Length != 16 || moving.Any(zone => zone.count < 15))
                throw new InvalidDataException("The sixteen authored areas require at least fifteen unique motion entries.");
            var after = content.GetComponentsInChildren<Collider>(true);
            if (after.Length != colliders.Count || after.Any(c => !colliders.TryGetValue(c, out var original) ||
                original != EditorJsonUtility.ToJson(c))) throw new InvalidDataException("A wall finish changed gameplay collision.");
            AssetDatabase.SaveAssets();
            if (!EditorSceneManager.SaveScene(scene)) throw new IOException("Could not save the visible wall finish.");
            Debug.Log($"ECHO_VISIBLE_WALL_FINISH signal={signalPanels} security={securityPanels} lab_exterior={stationPanels} surveillance_relief={relievedSurveillanceBays} decks={deckUpdates} colliders={after.Length} zones={moving.Length} targets={moving.Sum(zone => zone.count)} minimum={moving.Min(zone => zone.count)}");
        }

        private static Material NeutralDeckFinish(Material template)
        {
            var service = template.name.StartsWith("Service deck", StringComparison.Ordinal);
            var tint = service ? new Color(.91f,.818f,.775f) : new Color(.89f,.74f,.685f);
            var finish = FinishAt(template, "Neutral " + template.name, tint, service ? .68f : .74f);
            finish.SetFloat("_BumpScale", 1f);
            return finish;
        }

        private static Material TripoDeckFinish(Material template)
        {
            var path = Folder + "Galvanized pressure walkway skin.mat";
            var finish = AssetDatabase.LoadAssetAtPath<Material>(path);
            if (!finish)
            {
                finish = new Material(template) { name = "Galvanized pressure walkway skin" };
                AssetDatabase.CreateAsset(finish, path);
            }
            finish.SetColor("baseColorFactor", new Color(.78f, .70f, .62f));
            if (finish.HasProperty("roughnessFactor")) finish.SetFloat("roughnessFactor", .94f);
            EditorUtility.SetDirty(finish);
            return finish;
        }

        private static int FitSignalBays(Transform layer, Transform station, MeshRenderer source, Vector3 at,
            Vector3 inward, float[] arches, Mesh mesh, Material[] materials)
        {
            const float clearance = .52f;
            var z = station.InverseTransformPoint(source.bounds.center).z;
            var width = source.bounds.size.z;
            var start = z - width * .5f + .14f;
            var end = z + width * .5f - .14f;
            var count = 0;
            foreach (var arch in arches.Where(arch => arch + clearance > start && arch - clearance < end))
            {
                Fit(start, Mathf.Min(end, arch - clearance));
                start = Mathf.Max(start, arch + clearance);
            }
            Fit(start, end);
            return count;

            void Fit(float from, float to)
            {
                var span = to - from;
                if (span < 1.42f) return;
                var position = at + station.forward * ((from + to) * .5f - z);
                PlacePlate(layer, $"{source.name} / fitted cooling bay {count + 1}", position,
                    Quaternion.LookRotation(inward, Vector3.up), new Vector3(span, source.bounds.size.y * .865f, 1f),
                    mesh, materials);
                count++;
            }
        }

        private static int FitSurveillanceHeaders(Transform room, Transform layer, Mesh mesh, Material[] materials)
        {
            var fitted = room.Find("Flow R37 fitted architecture");
            var windows = fitted.GetComponentsInChildren<MeshRenderer>(true)
                .Where(renderer => renderer.enabled && renderer.name == "SurveillanceCableBay")
                .Select(renderer => renderer.bounds).ToArray();
            var renovation = room.Find(Layer);
            var relieved = 0;
            foreach (var cassette in renovation.GetComponentsInChildren<MeshRenderer>())
            {
                var t = cassette.transform;
                var normal = t.forward;
                var right = t.right;
                var position = t.position;
                var wall = cassette.bounds;
                var contacts = windows.Where(window =>
                {
                    var delta = window.center - wall.center;
                    var extent = window.extents + wall.extents;
                    var lateral = Mathf.Abs(right.x) * extent.x + Mathf.Abs(right.z) * extent.z;
                    return Mathf.Abs(Vector3.Dot(delta, normal)) <= .65f &&
                           Mathf.Abs(Vector3.Dot(delta, right)) + .13f < lateral &&
                           wall.min.y < window.max.y && wall.max.y > window.min.y;
                }).ToArray();
                if (contacts.Length == 0) continue;
                cassette.enabled = false;
                var bottom = contacts.Max(window => window.max.y) + .17f;
                var top = wall.max.y - .08f;
                if (top - bottom > .54f)
                {
                    position.y = (bottom + top) * .5f;
                    PlacePlate(layer, "Clear header above monitoring bay", position, t.rotation,
                        new Vector3(t.lossyScale.x * .97f, top - bottom, 1f), mesh, materials);
                }
                relieved++;
            }
            return relieved;
        }

        private static Transform VisibleRoot(Transform room)
        {
            var previous = room.Find(VisibleLayer);
            if (previous) Object.DestroyImmediate(previous.gameObject);
            return Node(room, VisibleLayer, Vector3.zero);
        }

        private static Vector3 WallNormal(MeshRenderer wall, Vector3 roomCenter)
        {
            var bounds = wall.bounds;
            var normal = bounds.size.x < bounds.size.z ? Vector3.right : Vector3.forward;
            return Vector3.Dot(roomCenter - bounds.center, normal) < 0f ? -normal : normal;
        }

        private static Vector3 MountOnDominantPlane(MeshRenderer source, Vector3 inward)
        {
            var intersect = typeof(HandleUtility).GetMethod("IntersectRayMesh",
                BindingFlags.Static | BindingFlags.Public | BindingFlags.NonPublic, null,
                new[] { typeof(Ray), typeof(Mesh), typeof(Matrix4x4), typeof(RaycastHit).MakeByRefType() }, null);
            if (intersect == null) throw new MissingMethodException("HandleUtility.IntersectRayMesh");
            var bounds = source.bounds;
            var mesh = source.GetComponent<MeshFilter>().sharedMesh;
            var right = Vector3.Cross(Vector3.up, inward);
            var halfWidth = Vector3.Dot(bounds.extents, new Vector3(Mathf.Abs(right.x), 0f, Mathf.Abs(right.z)));
            var samples = new List<float>();
            var backing = new List<float>();
            foreach (var horizontal in new[] { -.68f, -.34f, 0f, .34f, .68f })
            foreach (var vertical in new[] { -.65f, -.32f, 0f, .32f, .65f })
            {
                var cast = bounds.center + right * (halfWidth * horizontal) +
                           Vector3.up * (bounds.extents.y * vertical) + inward * 2f;
                object[] arguments = { new Ray(cast, -inward), mesh, source.transform.localToWorldMatrix, default(RaycastHit) };
                if (!(bool)intersect.Invoke(null, arguments) || arguments[3] is not RaycastHit hit) continue;
                var depth = 2f - hit.distance;
                backing.Add(depth);
                if (Mathf.Abs(Vector3.Dot(hit.normal, inward)) > .95f) samples.Add(depth);
            }
            if (backing.Count < 5) throw new InvalidDataException($"Could not find the wall skin of {source.name}.");
            var plane = samples.Count >= 5
                ? samples.GroupBy(depth => Mathf.RoundToInt(depth / .015f))
                    .OrderByDescending(group => group.Count()).ThenByDescending(group => group.Key).First().Average()
                : backing.OrderBy(depth => depth).ElementAt(backing.Count * 3 / 4);
            Debug.Log($"ECHO_VISIBLE_FACE name={source.name} center={bounds.center:F2} size={bounds.size:F2} plane={plane:F3} samples={samples.Count}");
            return bounds.center + inward * (plane + .009f);
        }

        private static int AttachFace(Transform parent, MeshRenderer source, Vector3 at, Vector3 inward,
            Mesh mesh, Material[] materials, int count, float coverWidth, float coverHeight)
        {
            var bounds = source.bounds;
            var across = Vector3.Cross(Vector3.up, inward).normalized;
            var width = Vector3.Dot(bounds.size, new Vector3(Mathf.Abs(across.x), 0f, Mathf.Abs(across.z))) * coverWidth;
            var height = bounds.size.y * coverHeight;
            for (var panel = 0; panel < count; panel++)
            {
                PlacePlate(parent, $"{source.name} / fitted return {panel + 1}",
                    at + across * (width * ((panel + .5f) / count - .5f)),
                    Quaternion.LookRotation(inward, Vector3.up),
                    new Vector3(width / count * .96f, height, 1f), mesh, materials);
            }
            return count;
        }

        private static void PlacePlate(Transform parent, string name, Vector3 position, Quaternion rotation,
            Vector3 scale, Mesh mesh, Material[] materials)
        {
            var node = Node(parent, name, Vector3.zero);
            node.SetPositionAndRotation(position, rotation);
            node.localScale = scale;
            node.gameObject.AddComponent<MeshFilter>().sharedMesh = mesh;
            var renderer = node.gameObject.AddComponent<MeshRenderer>();
            renderer.sharedMaterials = materials;
            renderer.shadowCastingMode = ShadowCastingMode.Off;
            renderer.receiveShadows = true;
        }

        private static void GrazingKey(Transform layer, string name, Vector3 from, Vector3 target,
            Color color, float intensity, float range)
        {
            var lightPoint = Node(layer, name, from);
            lightPoint.localRotation = Quaternion.LookRotation(target - from);
            var light = lightPoint.gameObject.AddComponent<Light>();
            light.type = LightType.Spot;
            light.color = color;
            light.intensity = intensity;
            light.range = range;
            light.spotAngle = 47f;
            light.innerSpotAngle = 32f;
        }

        private static Mesh FaceMesh(string name, int style)
        {
            var path = Folder + name + ".asset";
            var existing = AssetDatabase.LoadAssetAtPath<Mesh>(path);
            var shape = new Plates();
            shape.Raised(0f, 0f, .993f, .993f, .025f, .020f, .010f, 0);
            shape.Raised(0f, -.451f, .984f, .087f, .017f, .060f, .008f, 2);
            shape.Raised(0f, .458f, .980f, .068f, .016f, .055f, .007f, 2);
            if (style == 0)
            {
                shape.Raised(-.055f,.208f,.785f,.419f,.066f,.049f,.010f,1);
                shape.Raised(-.055f,-.232f,.785f,.365f,.059f,.043f,.009f,1);
                shape.Raised(.398f,.011f,.045f,.772f,.010f,.054f,.004f,2);
                for (var row = 0; row < 4; row++)
                    shape.Raised(-.055f,.062f-row*.032f,.565f,.013f,.003f,.059f,.002f,2);
            }
            else if (style == 1)
            {
                shape.Raised(0f,.202f,.875f,.424f,.072f,.060f,.012f,1);
                shape.Raised(0f,-.237f,.875f,.315f,.057f,.058f,.011f,1);
                shape.Raised(.04f,-.021f,.849f,.095f,.012f,.072f,.007f,0);
                for (var row = 0; row < 3; row++)
                    shape.Raised(.04f,.009f-row*.028f,.755f,.009f,.003f,.091f,.001f,2);
            }
            else
            {
                shape.Raised(0f,.062f,.858f,.693f,.059f,.066f,.018f,1);
                shape.Raised(0f,-.350f,.865f,.092f,.015f,.076f,.013f,2);
                shape.Raised(-.389f,.071f,.053f,.654f,.011f,.096f,.007f,2);
                shape.Raised(.389f,.071f,.053f,.654f,.011f,.096f,.007f,2);
            }
            foreach (var corner in new[] { -.370f, .295f })
            foreach (var y in new[] { -.328f, .339f })
                shape.Bolt(corner, y, .010f, .035f, .064f);
            var mesh = shape.Build(name);
            if (existing)
            {
                EditorUtility.CopySerialized(mesh, existing);
                Object.DestroyImmediate(mesh);
                EditorUtility.SetDirty(existing);
                return existing;
            }
            AssetDatabase.CreateAsset(mesh, path);
            return mesh;
        }
    }
}
