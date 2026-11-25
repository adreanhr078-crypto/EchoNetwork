using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
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
        [MenuItem("11.11/Fit Surveillance Scanner Gallery")]
        public static void DirectSurveillance()
        {
            if (!Application.isBatchMode && !EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo()) return;
            var scene = EditorSceneManager.OpenScene(ScenePath);
            var content = scene.GetRootGameObjects().Single(root => root.name == "Room content").transform;
            var room = content.Find("Echo Station/Surveillance and mirror");
            var collision = content.GetComponentsInChildren<Collider>(true)
                .ToDictionary(collider => collider, collider => EditorJsonUtility.ToJson(collider));
            var wing = room.GetComponent<StationSurveillanceWing>();
            var wingState = EditorJsonUtility.ToJson(wing);
            var grid = room.Find("Surveillance scanner grid");
            var arcLayer = ResetNamed(grid, "Optical discharge channels");
            var gallery = ResetNamed(room, "Surveillance scanner gallery");
            var legacy = grid.Cast<Transform>().Where(part => part.name is
                "Scanner optical channel" or "Scanner receiver" or "Scanner emitter").ToArray();
            if (legacy.Length != 12) throw new InvalidDataException("The four authored scanner crossings were not found.");
            foreach (var part in legacy)
                foreach (var old in part.GetComponentsInChildren<MeshRenderer>(true)) old.enabled = false;

            var steel = AssetDatabase.LoadAssetAtPath<Material>(Art + "StationFinishes/Chronostat oxide-filled steel.mat");
            var baseRough = FinishAt(steel, "Surveillance graphite substrate", new Color(.32f,.302f,.276f), .29f);
            var deckCenter = FinishAt(steel, "Surveillance ground zinc", new Color(.64f,.605f,.555f), .62f);
            var deckSide = FinishAt(steel, "Surveillance grit blasted aisle", new Color(.49f,.468f,.428f), .35f);
            var rail = FinishAt(steel, "Surveillance blackened structural alloy", new Color(.49f,.448f,.384f), .47f);
            var nosing = FinishAt(steel, "Surveillance burnished stair edges", new Color(.73f,.675f,.584f), .51f);
            var terminal = FinishAt(steel, "Surveillance copper socket trim", new Color(.64f,.427f,.263f), .58f);
            var lamp = Emitter("Surveillance ivory practical", new Color(1f,.86f,.69f), 1.75f);
            var terminalLamp = Emitter("Surveillance energized socket", new Color(1f,.48f,.12f), 1.82f);
            var arcCore = ArcMaterial("Surveillance arc hot filament", new Color(3.1f,1.63f,.58f));
            var arcHalo = ArcMaterial("Surveillance arc ionized air", new Color(.76f,.22f,.039f));

            var temporary = GameObject.CreatePrimitive(PrimitiveType.Cube);
            var cube = temporary.GetComponent<MeshFilter>().sharedMesh;
            Object.DestroyImmediate(temporary);

            foreach (var depth in StationSurveillanceWing.ScannerDepths)
            {
                var arcRoot = Node(arcLayer, $"Energized scanner crossing {depth:F0}", new Vector3(0f, 1.2f, depth));
                var core = ArcLine(arcRoot, "Hot central discharge", arcCore, SurveillanceScannerArc.CorePoints, .019f);
                var halo = ArcLine(arcRoot, "Soft ionized air", arcHalo, SurveillanceScannerArc.CorePoints, .080f);
                var fork = ArcLine(arcRoot, "Short electrical branch", arcCore, SurveillanceScannerArc.ForkPoints, .012f);
                fork.enabled = false;
                var glow = Node(arcRoot, "Reflected discharge", new Vector3(0f,-.36f,0f)).gameObject.AddComponent<Light>();
                glow.type = LightType.Point;
                glow.color = new Color(1f,.55f,.22f);
                glow.intensity = 1.0f;
                glow.range = 3.45f;
                var arc = arcRoot.gameObject.AddComponent<SurveillanceScannerArc>();
                var binding = new SerializedObject(arc);
                binding.FindProperty("core").objectReferenceValue = core;
                binding.FindProperty("halo").objectReferenceValue = halo;
                binding.FindProperty("fork").objectReferenceValue = fork;
                binding.FindProperty("reflectedLight").objectReferenceValue = glow;
                binding.FindProperty("seed").floatValue = depth * .37f;
                binding.ApplyModifiedPropertiesWithoutUndo();

                foreach (var side in new[] { -1f, 1f })
                {
                    var x = side * (StationSurveillanceWing.ScannerHalfWidth + .082f);
                    var socket = Node(gallery, "Scanner socket anchored to deck", new Vector3(x,0f,depth));
                    Add(socket,"Bolted scanner foot",cube,rail,new Vector3(0f,.026f,0f),new Vector3(.36f,.052f,.35f));
                    Add(socket,"Bushed upright",cube,baseRough,new Vector3(0f,.575f,0f),new Vector3(.14f,1.11f,.15f));
                    Add(socket,"Ceramic isolation collar",cube,terminal,new Vector3(0f,1.06f,0f),new Vector3(.172f,.11f,.176f));
                    Add(socket,"Hooded high-voltage socket",cube,rail,new Vector3(0f,1.20f,0f),new Vector3(.168f,.17f,.23f));
                    Add(arcRoot,"Active recessed emitter lens",cube,terminalLamp,new Vector3(side * StationSurveillanceWing.ScannerHalfWidth,0f,0f),
                        new Vector3(.019f,.048f,.054f));
                }
            }

            var nativeRoom = room.Find("Godot surveillance architecture/mirror_chamber_room");
            var floor = nativeRoom.Find("Floor/_MeshInstance3D_556").GetComponent<MeshRenderer>();
            var ceiling = nativeRoom.Find("Ceiling/_MeshInstance3D_557").GetComponent<MeshRenderer>();
            var deckY = room.InverseTransformPoint(new Vector3(floor.bounds.center.x, floor.bounds.max.y, floor.bounds.center.z)).y;
            var roofY = room.InverseTransformPoint(new Vector3(ceiling.bounds.center.x, ceiling.bounds.min.y, ceiling.bounds.center.z)).y;
            floor.sharedMaterial = baseRough;
            PrefabUtility.RecordPrefabInstancePropertyModifications(floor);
            var walk = Node(gallery, "Graphite deck and recessed drainage", Vector3.up * (deckY + .008f));
            walk.gameObject.AddComponent<MeshFilter>().sharedMesh = GalleryDeck();
            walk.gameObject.AddComponent<MeshRenderer>().sharedMaterials = new[] { deckSide, deckCenter, rail };

            var stairs = 0;
            foreach (var prefix in new[] { "WestStair_", "EastStair_" })
            {
                var steps = nativeRoom.Cast<Transform>().Where(item => item.name.StartsWith(prefix, StringComparison.Ordinal))
                    .Select(item => item.GetComponentInChildren<MeshRenderer>()).Where(item => item).OrderBy(item => item.bounds.center.y).ToArray();
                if (steps.Length < 3) throw new InvalidDataException($"The {prefix} stair could not be measured.");
                var slope = room.InverseTransformDirection(steps[^1].bounds.center - steps[0].bounds.center);
                var xAxis = Mathf.Abs(slope.x) > Mathf.Abs(slope.z);
                var uphill = xAxis ? Vector3.right * Mathf.Sign(slope.x) : Vector3.forward * Mathf.Sign(slope.z);
                foreach (var step in steps)
                {
                    step.sharedMaterial = deckSide;
                    PrefabUtility.RecordPrefabInstancePropertyModifications(step);
                    var box = step.bounds;
                    var at = room.InverseTransformPoint(new Vector3(box.center.x, box.max.y, box.center.z));
                    var dx = xAxis ? box.extents.x : box.extents.z;
                    var size = xAxis ? new Vector3(.071f,.028f,box.size.z*.96f) : new Vector3(box.size.x*.96f,.028f,.071f);
                    Add(gallery, "Recessed stair nosing", cube, nosing, at - uphill * (dx - .037f) + Vector3.down*.004f, size);
                    stairs++;
                }
            }

            var centerZ = room.InverseTransformPoint(ceiling.bounds.center).z;
            foreach (var x in new[] { -7.9f, 7.9f })
                Add(gallery,"Continuous ceiling support",cube,baseRough,new Vector3(x,roofY-.13f,centerZ),new Vector3(.36f,.44f,33.7f));
            foreach (var z in new[] { 3.4f, 8.45f, 13.5f, 18.55f, 23.6f, 28.65f, 33.7f })
            {
                Add(gallery,"Recessed ceiling crossmember",cube,rail,new Vector3(0f,roofY-.135f,z),new Vector3(26.9f,.42f,.32f));
                foreach (var x in new[] { -5.6f, 5.6f })
                {
                    var lightAt = new Vector3(x,roofY-.27f,z+.11f);
                    Add(gallery,"Recessed practical body",cube,baseRough,lightAt,new Vector3(1.74f,.18f,.27f));
                    Add(gallery,"Warm practical lens",cube,lamp,lightAt+Vector3.down*.094f,new Vector3(1.45f,.027f,.116f));
                }
            }
            GrazingKey(gallery,"Ivory crosslight over the scan lane",new Vector3(2.6f,roofY-.42f,10.1f),
                new Vector3(-.4f,deckY,14.8f),new Color(1f,.87f,.72f),24f,11.7f);
            GrazingKey(gallery,"Side stair task lighting",new Vector3(-4.7f,roofY-.41f,14.3f),
                new Vector3(-5.1f,1.7f,17.3f),new Color(1f,.82f,.62f),16f,9.5f);

            var after = content.GetComponentsInChildren<Collider>(true);
            if (after.Length != collision.Count || after.Any(c => !collision.TryGetValue(c, out var expected) ||
                expected != EditorJsonUtility.ToJson(c)) || wingState != EditorJsonUtility.ToJson(wing))
                throw new InvalidDataException("Surveillance presentation changed scan, collider or progression authority.");
            AssetDatabase.SaveAssets();
            if (!EditorSceneManager.SaveScene(scene)) throw new IOException("Could not save the surveillance gallery.");
            Debug.Log($"ECHO_SURVEILLANCE_GALLERY arcs={StationSurveillanceWing.ScannerDepths.Length} optical_boxes_hidden={legacy.Length} stair_nosings={stairs} roof={roofY:F2} floor={deckY:F3} colliders={after.Length}");
        }

        private static Material ArcMaterial(string name, Color radiance)
        {
            var path = Folder + name + ".mat";
            var material = AssetDatabase.LoadAssetAtPath<Material>(path);
            if (!material)
            {
                var shader = Shader.Find("ElevenEleven/Surveillance Scanner Arc");
                if (!shader) throw new FileNotFoundException("Missing URP scanner arc shader.");
                material = new Material(shader) { name = name };
                AssetDatabase.CreateAsset(material,path);
            }
            material.SetColor("_Glow",radiance);
            EditorUtility.SetDirty(material);
            return material;
        }

        private static LineRenderer ArcLine(Transform parent, string label, Material material, int points, float width)
        {
            var line = Node(parent,label,Vector3.zero).gameObject.AddComponent<LineRenderer>();
            line.sharedMaterial = material;
            line.useWorldSpace = false;
            line.shadowCastingMode = ShadowCastingMode.Off;
            line.receiveShadows = false;
            line.positionCount = points;
            line.widthMultiplier = width;
            line.alignment = LineAlignment.View;
            line.textureMode = LineTextureMode.Stretch;
            var half = StationSurveillanceWing.ScannerHalfWidth;
            for (var index=0; index<points; index++)
            {
                var progress=index/(float)(points-1);
                line.SetPosition(index,new Vector3(Mathf.Lerp(-half,half,progress),
                    Mathf.Sin(index * 2.37f) * Mathf.Sin(progress * Mathf.PI) *.035f, 0f));
            }
            return line;
        }

        private static Mesh GalleryDeck()
        {
            const string name = "Surveillance zoned deck geometry";
            var path = Folder + name + ".asset";
            var mesh = AssetDatabase.LoadAssetAtPath<Mesh>(path);
            if (mesh) return mesh;
            var vertices = new List<Vector3>();
            var uv = new List<Vector2>();
            var faces = new[] { new List<int>(), new List<int>(), new List<int>() };
            var edges = new[] { -13.96f, -4.88f, -4.53f, 4.53f, 4.88f, 13.96f };
            var slots = new[] { 0, 2, 1, 2, 0 };
            var seams = new[] { .06f, 5.1f, 10.45f, 16.25f, 22.6f, 29.0f, 35.94f };
            for (var band=0; band<slots.Length; band++)
            for (var index=0; index+1<seams.Length; index++)
            {
                var slot=slots[band];
                var height=slot==2 ? -.005f : 0f;
                var x0=edges[band]+.007f;
                var x1=edges[band+1]-.007f;
                var z0=seams[index]+.009f;
                var z1=seams[index+1]-.009f;
                var first=vertices.Count;
                foreach (var point in new[] {new Vector3(x0,height,z0),new Vector3(x0,height,z1),
                    new Vector3(x1,height,z1),new Vector3(x1,height,z0)})
                {
                    vertices.Add(point);
                    uv.Add(new Vector2(point.x*.55f,point.z*.55f));
                }
                faces[slot].AddRange(new[] {first,first+1,first+2,first,first+2,first+3});
            }
            mesh=new Mesh {name=name,subMeshCount=faces.Length};
            mesh.SetVertices(vertices);
            mesh.SetUVs(0,uv);
            for(var slot=0;slot<faces.Length;slot++)mesh.SetTriangles(faces[slot],slot);
            mesh.RecalculateNormals();
            mesh.RecalculateTangents();
            mesh.RecalculateBounds();
            AssetDatabase.CreateAsset(mesh,path);
            return mesh;
        }
    }
}
