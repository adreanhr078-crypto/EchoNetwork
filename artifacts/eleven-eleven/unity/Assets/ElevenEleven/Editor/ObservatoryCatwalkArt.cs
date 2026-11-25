using System;
using System.Collections.Generic;
using System.Linq;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using static ElevenEleven.Editor.GodotRoomAssembly;

namespace ElevenEleven.Editor
{
    internal static class ObservatoryCatwalkArt
    {
        private const string Folder = MemoryObservatoryArt.Folder;
        private static readonly string[] ReplacedFinish =
        {
            "Drainage bridge floor cassette", "Deck longitudinal box girder",
            "Bridge edge reflector seat", "Bridge inset glass guide", "Chronostat buttress",
            "Chronostat buttress plated face", "Chronostat vertical locator", "Chronostat return bracing"
        };

        private enum RailOpening { None, Junction, West, East, Apron }

        internal static void Dress(Transform observatory, Transform station)
        {
            var donor = AssetDatabase.LoadAssetAtPath<GameObject>(Folder + "observatory-catwalk-bay.glb");
            if (donor == null) return;

            var materials = donor.GetComponentInChildren<MeshRenderer>().sharedMaterials;
            var prototype = PrepareCatwalk(donor.GetComponentInChildren<MeshFilter>().sharedMesh);
            var root = Node(observatory, "Fitted Tripo catwalk", Vector3.zero);

            // Crossings stay at the original relay jump and lab branch. They have explicit rail gaps.
            var sections = new (float Start, float End, RailOpening Opening)[]
            {
                (39.80f,45.0f,RailOpening.Junction),
                (45.0f,49.68f,RailOpening.None),
                (49.68f,54.06f,RailOpening.West),
                (54.06f,60.72f,RailOpening.None),
                (60.72f,64.59f,RailOpening.Apron),
                (64.59f,67.45f,RailOpening.West),
                (67.45f,72.90f,RailOpening.None)
            };
            var variants = new Dictionary<RailOpening,Mesh>();
            for (var i = 0; i < sections.Length; i++)
            {
                var (start, end, opening) = sections[i];
                if (!variants.TryGetValue(opening, out var mesh))
                {
                    mesh = SaveVariant(prototype, opening);
                    variants.Add(opening,mesh);
                }
                var section = Node(root, $"Central catwalk bay {i + 1}", new Vector3(0,.013f,(start+end)*.5f));
                section.localScale = new Vector3(5.8f,1,end-start);
                Install(section, mesh, materials);
                AddGuards(root, start, end, opening);
                if (i % 2 == 0)
                {
                    AmberKey(root, new Vector3(-2.47f,.73f,start+.90f));
                    AmberKey(root, new Vector3(2.47f,.73f,end-.85f));
                }
            }
            var apron = variants[RailOpening.Apron];
            UnityEngine.Object.DestroyImmediate(prototype);
            DressSideRoutes(observatory,station,variants[RailOpening.None],apron,materials);

            var branch = Node(root, "Catwalk branch to memory lab", new Vector3(7.16f,.025f,62.65f));
            branch.localRotation = Quaternion.Euler(0,90,0);
            branch.localScale = new Vector3(3.34f,1,8.55f);
            Install(branch,variants[RailOpening.None],materials);
            foreach (var side in new[] { -1,1 })
                Guard(root,"Archive branch guard",new Vector3(7.13f,.55f,62.65f+side*1.65f),new Vector3(8.31f,1.10f,.15f));

            foreach (Transform item in station)
            {
                var position = item.localPosition;
                if (item.name == "Central drainage bridge" || item.name == "Lab access" ||
                    ((item.name == "Walkway marker" || item.name == "Walkway edge") && Mathf.Abs(Mathf.Abs(position.x)-2.9f) < .05f))
                    item.GetComponent<MeshRenderer>().enabled = false;
            }

            var old = station.Find("Echo Station architectural finish");
            foreach (Transform item in old)
                if (ReplacedFinish.Contains(item.name))
                    foreach (var renderer in item.GetComponentsInChildren<Renderer>())
                        renderer.enabled = false;
        }

        private static void DressSideRoutes(Transform observatory, Transform station, Mesh full, Mesh apron, Material[] materials)
        {
            var root = Node(observatory,"Fitted lateral catwalks",Vector3.zero);
            var west = Node(root,"West service catwalk",Vector3.zero);
            SideLoop(west,-15f,4.3f,full,apron,materials,new (float Start,float End,bool Open)[]
            {
                (37.30f,42.25f,true),(42.25f,46.05f,false),(46.05f,49.37f,false),
                (49.37f,53.60f,true),(53.60f,57.83f,true),(57.83f,62.60f,false),
                (62.60f,67.45f,true),(67.45f,73f,false)
            });
            Link(west,-12.85f,-2.90f,40f,4.4f,full,materials);
            Link(west,-12.85f,-2.90f,65f,4.7f,full,materials);

            var east = Node(root,"East observation catwalk",Vector3.zero);
            SideLoop(east,15f,7.5f,full,apron,materials,new (float Start,float End,bool Open)[]
            {
                (38.20f,42.25f,true),(42.25f,47.55f,false),(47.55f,52.80f,false),
                (52.80f,57.70f,false),(57.70f,60.70f,true),(60.70f,65.15f,true),
                (65.15f,69.0f,true),(69.0f,73f,true)
            });
            Link(east,2.90f,11.25f,40f,4.4f,full,materials);
            foreach (var z in new[] {44.2f,48.1f,59.2f,70.1f})
                GuideBounce(west,new Vector3(-16.73f,.74f,z),new Color(1f,.53f,.22f),3.8f);
            foreach (var z in new[] {44.3f,49.4f,54.9f,60.2f})
                GuideBounce(east,new Vector3(17.94f,.74f,z),new Color(.43f,.73f,.93f),3.5f);

            foreach (Transform child in station)
            {
                var x = child.localPosition.x;
                var sideMarker = child.name == "Walkway edge" || child.name == "Walkway marker";
                if (child.name == "West service loop" || child.name == "East observation loop" ||
                    child.name == "West access" || child.name == "East access" || child.name == "North relay access" ||
                    (sideMarker && (Mathf.Abs(x+12.85f)<.08f || Mathf.Abs(x+17.15f)<.08f ||
                                      Mathf.Abs(x-11.25f)<.08f || Mathf.Abs(x-18.75f)<.08f)))
                    child.GetComponent<MeshRenderer>().enabled = false;
            }
        }

        private static void SideLoop(Transform parent, float x, float width, Mesh full, Mesh apron, Material[] materials,
            (float Start,float End,bool Open)[] spans)
        {
            foreach (var (start,end,open) in spans)
            {
                var center = (start+end)*.5f;
                var bay = Node(parent,open ? "Open branch deck" : "Guarded branch bay",new Vector3(x,.016f,center));
                bay.localScale = new Vector3(width,1,end-start);
                Install(bay,open ? apron : full,materials);
                if (open) continue;
                for (var side=-1;side<=1;side+=2)
                {
                    var edge = x+side*(width*.5f-.054f);
                    Guard(parent,"Lateral catwalk guard",new Vector3(edge,.54f,center),new Vector3(.16f,1.08f,end-start));
                }
            }
        }

        private static void Link(Transform parent,float start,float end,float z,float width,Mesh mesh,Material[] materials)
        {
            var center = (start+end)*.5f;
            var connector = Node(parent,"Cross-station steel span",new Vector3(center,.026f,z));
            connector.localScale = new Vector3(width,1,end-start);
            connector.localRotation = Quaternion.Euler(0,90,0);
            Install(connector,mesh,materials);
            for (var side=-1;side<=1;side+=2)
                Guard(parent,"Cross-station guard",new Vector3(center,.54f,z+side*(width*.5f-.065f)),
                    new Vector3(end-start-.18f,1.08f,.18f));
        }

        private static Mesh PrepareCatwalk(Mesh source)
        {
            var mesh = UnityEngine.Object.Instantiate(source);
            mesh.name = "Catwalk measured silhouette";
            var bounds = source.bounds;
            var swap = bounds.size.x > bounds.size.z;
            var vertices = mesh.vertices;
            var normals = mesh.normals;
            var width = swap ? bounds.size.z : bounds.size.x;
            var length = swap ? bounds.size.x : bounds.size.z;

            var heights = new List<float>();
            for (var i = 0; i < vertices.Length; i++)
            {
                var centered = vertices[i] - bounds.center;
                var x = swap ? -centered.z : centered.x;
                var z = swap ? centered.x : centered.z;
                if (Mathf.Abs(x) < .29f*width && Mathf.Abs(z) < .40f*length && normals[i].y > .86f)
                    heights.Add(vertices[i].y);
            }
            if (heights.Count < 40) throw new InvalidOperationException("Tripo catwalk has no measurable horizontal deck.");
            heights.Sort();
            var top = heights[(int)(heights.Count*.66f)];
            var upper = 1.04f / Mathf.Max(.02f, bounds.max.y - top);
            var lower = .61f / Mathf.Max(.02f, top - bounds.min.y);
            for (var i = 0; i < vertices.Length; i++)
            {
                var centered = vertices[i] - bounds.center;
                var y = vertices[i].y - top;
                var heightScale = y > 0 ? upper : lower;
                // Suppress small undulations at the walking surface so rendered steel tracks the floor collider.
                var onDeck = Mathf.Abs(swap ? centered.z : centered.x) < .42f * width;
                if (onDeck && Mathf.Abs(y) <= .025f * bounds.size.y)
                    y *= .16f;
                vertices[i] = new Vector3((swap ? -centered.z : centered.x)/width,
                    y * heightScale, (swap ? centered.x : centered.z)/length);
                var n = normals[i];
                normals[i] = new Vector3((swap ? -n.z : n.x)*width,n.y/heightScale,
                    (swap ? n.x : n.z)*length).normalized;
            }
            mesh.vertices = vertices;
            mesh.normals = normals;
            return mesh;
        }

        private static Mesh SaveVariant(Mesh prototype, RailOpening opening)
        {
            var path = Folder + $"Catwalk {opening} fit.asset";
            var mesh = AssetDatabase.LoadAssetAtPath<Mesh>(path);
            if (mesh != null) return mesh;
            mesh = UnityEngine.Object.Instantiate(prototype);
            mesh.name = $"Tripo wet steel catwalk {opening}";
            var vertices = mesh.vertices;
            if (opening != RailOpening.None)
            {
                for (var submesh = 0; submesh < mesh.subMeshCount; submesh++)
                {
                    var indices = mesh.GetTriangles(submesh);
                    var result = new List<int>(indices.Length);
                    for (var i = 0; i < indices.Length; i += 3)
                    {
                        var a = vertices[indices[i]];
                        var b = vertices[indices[i+1]];
                        var c = vertices[indices[i+2]];
                        var center = (a+b+c)/3f;
                        if (center.y > .15f && InRailOpening(center,opening)) continue;
                        result.Add(indices[i]);
                        result.Add(indices[i+1]);
                        result.Add(indices[i+2]);
                    }
                    mesh.SetTriangles(result,submesh,false);
                }
            }
            mesh.RecalculateTangents();
            mesh.RecalculateBounds();
            AssetDatabase.CreateAsset(mesh,path);
            return mesh;
        }

        private static bool InRailOpening(Vector3 center, RailOpening opening)
        {
            return opening switch
            {
                RailOpening.Junction => center.z < -.04f,
                RailOpening.West => center.x < -.26f,
                RailOpening.East => center.x > .26f,
                RailOpening.Apron => Mathf.Abs(center.x) > .25f,
                _ => false
            };
        }

        private static void Install(Transform section, Mesh mesh, Material[] materials)
        {
            section.gameObject.AddComponent<MeshFilter>().sharedMesh = mesh;
            var renderer = section.gameObject.AddComponent<MeshRenderer>();
            renderer.sharedMaterials = materials;
            renderer.shadowCastingMode = ShadowCastingMode.On;
        }

        private static void AddGuards(Transform root, float start, float end, RailOpening opening)
        {
            if (opening == RailOpening.Apron) return;
            if (opening == RailOpening.Junction)
                start = Mathf.Lerp(start,end,.46f);
            for (var side = -1; side <= 1; side += 2)
            {
                if ((side < 0 && opening == RailOpening.West) || (side > 0 && opening == RailOpening.East)) continue;
                var center = new Vector3(side*2.86f,.54f,(start+end)*.5f);
                Guard(root, "Catwalk side guard",center,new Vector3(.17f,1.08f,end-start));
            }
        }

        private static void Guard(Transform root, string label, Vector3 center, Vector3 size)
        {
            var guard = Node(root,label,center);
            guard.gameObject.AddComponent<BoxCollider>().size = size;
        }

        private static void AmberKey(Transform root, Vector3 center) =>
            GuideBounce(root,center,new Color(1f,.55f,.22f),2.8f);

        private static void GuideBounce(Transform root,Vector3 center,Color color,float intensity)
        {
            var beacon = Node(root,"Catwalk practical bounce",center).gameObject.AddComponent<Light>();
            beacon.type = LightType.Point;
            beacon.color = color;
            beacon.range = 4.1f;
            beacon.intensity = intensity;
        }
    }
}
