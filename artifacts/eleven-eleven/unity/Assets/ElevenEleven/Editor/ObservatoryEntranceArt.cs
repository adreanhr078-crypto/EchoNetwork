using System;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using static ElevenEleven.Editor.GodotRoomAssembly;

namespace ElevenEleven.Editor
{
    internal static class ObservatoryEntranceArt
    {
        private const string Folder = MemoryObservatoryArt.Folder;
        private static readonly string[] DonorNames =
        {
            "east-facade","east-shutter","east-rack","west-shelter","west-tread"
        };

        internal static void Dress(Transform observatory, Transform station)
        {
            var sources = Array.ConvertAll(DonorNames,name => AssetDatabase.LoadAssetAtPath<GameObject>(
                Folder + "observatory-" + name + ".glb"));
            if (Array.IndexOf(sources,null) >= 0) return;
            var root = Node(observatory,"Rebuilt station entrances",Vector3.zero);
            FitEast(Node(root,"East memory laboratory entrance",Vector3.zero),observatory,station,sources[0],sources[1],sources[2]);
            FitWest(Node(root,"West relay workshop entrance",Vector3.zero),observatory,station,sources[3],sources[4]);
            Bedrock(root,observatory);
        }

        private static void FitEast(Transform side, Transform observatory, Transform station,
            GameObject facade, GameObject shutter, GameObject rack)
        {
            var shell = BuildShell(facade,"Laboratory facade fitted clearance",new Vector3(8.95f,6.15f,1.20f),
                point => Mathf.Abs(point.x)<1.42f && point.y>.045f && point.y<3.74f);
            Install(side,"Carved archive facade",new Vector3(15f,-.09f,62.23f),shell,facade);
            Disable(observatory,"Archive fitted steel portal");
            foreach (Transform item in station)
            {
                if (item.name == "Lab frontage" || item.name == "Lab door header")
                    MemoryObservatoryArt.Hide(item);
            }
            var finish = station.Find("Echo Station architectural finish");
            Disable(finish,"Memory lab shutter jamb skin","Shutter inset guide","Shutter threshold toe plate","Memory lab fascia trim");
            var oldInfrastructure = station.Find("Chronostat machinery finish/Rebuilt station infrastructure");
            foreach (Transform item in oldInfrastructure)
                if (item.name.StartsWith("Facade",StringComparison.Ordinal) ||
                    item.name.StartsWith("Laboratory",StringComparison.Ordinal))
                    MemoryObservatoryArt.Hide(item);

            var door = station.Find("Lab isolation shutter");
            var previousFinish = door.Find("Tripo moving shutter cladding");
            if (previousFinish != null) UnityEngine.Object.DestroyImmediate(previousFinish.gameObject);
            MemoryObservatoryArt.Hide(door);
            // The real shutter is the gameplay transform. The new steel face is fitted in its built-in box space.
            var newShutter = BuildShell(shutter,"Laboratory shutter movement fit",new Vector3(.99f,.991f,.85f),
                null);
            Install(door,"Tripo moving shutter cladding",new Vector3(0,-.495f,-.16f),newShutter,shutter);
            var shield = BuildShell(shutter,"Laboratory raised shutter housing fit",new Vector3(3.18f,4.48f,.56f),null);
            Install(side,"Stationary shutter pocket",new Vector3(15f,3.76f,62.17f),shield,shutter);

            DressEastWall(side,station,rack);
            station.Find("Lab").localPosition = new Vector3(15f,3.94f,61.57f);
            var reveal = observatory.Find("Archive cyan spill").GetComponent<Light>();
            reveal.intensity = 44f;
            reveal.color = new Color(.47f,.85f,1f);
            MemoryObservatoryArt.LightKey(side,"Archive aperture warm bounce",new Vector3(13.75f,3.39f,61.26f),
                new Vector3(16.85f,1.2f,65.4f),new Color(.83f,.89f,1f),16f,9f,60f);
            MemoryObservatoryArt.LightKey(side,"Deep cyan laboratory fill",new Vector3(15f,3.82f,66.8f),
                new Vector3(13.9f,.43f,68.8f),new Color(.27f,.69f,.83f),26f,9f,90f);
        }

        private static void DressEastWall(Transform side,Transform station,GameObject source)
        {
            var material = AssetDatabase.LoadAssetAtPath<Material>(Folder + "Fractured basalt.mat");
            foreach (var label in new[] { "Lab east envelope","Lab west envelope","Lab rear envelope","Lab canopy" })
                station.Find(label).GetComponent<MeshRenderer>().sharedMaterial = material;
            var rack = BuildShell(source,"Archive coolant rack fit",new Vector3(1.55f,3.32f,.42f),null);
            foreach (var x in new[] { 11.65f,18.37f })
            {
                foreach (var z in new[] { 64.45f,67.22f,69.18f })
                {
                    var frame = Install(side,"Recessed coolant and relay rack",new Vector3(x,.19f,z),rack,source);
                    frame.localRotation = Quaternion.Euler(0,x>15f ? 90 : -90,0);
                }
            }
            foreach (var x in new[] { 12.21f,17.72f })
                Install(side,"Frontage cooling return",new Vector3(x,.1f,61.77f),rack,source);
        }

        private static void FitWest(Transform side,Transform observatory,Transform station,GameObject donor,GameObject tread)
        {
            Disable(observatory,"West bedrock reinforcement","West relay service workshop","West relay canopy support");
            var shelter = BuildShell(donor,"Relay recessed workbay fit",new Vector3(7.42f,5.70f,4.11f),
                point => point.x > .53f && point.x < 3.47f && point.y < 2.52f && point.y > .03f && point.z < .73f);
            Install(side,"Recessed relay and furnace shelter",new Vector3(-17.35f,1.08f,58.45f),shelter,donor);
            var stairs = BuildShell(tread,"Relay pressed service stair fit",Vector3.one,null,true);
            var finish = station.Find("Echo Station architectural finish");
            foreach (Transform item in finish)
            {
                if (item.name == "Relay entry post" || item.name == "Post impact foot" || item.name == "Relay lane lens" ||
                    item.name == "Relay entry lintel" || item.name == "Relay lintel lens" || item.name == "Stair approach warning inlay" ||
                    item.name == "Suspended maintenance plate tread")
                    MemoryObservatoryArt.Hide(item);
            }
            station.Find("Relay").localPosition = new Vector3(-15.24f,3.46f,56.15f);
            Disable(station,"Relay sign backplate");
            foreach (Transform part in station)
            {
                if (part.name == "Relay tread nosing" || part.name == "Lit anchor edge")
                    MemoryObservatoryArt.Hide(part);
                if (part.name != "Relay access step" && part.name != "Suspended service plate") continue;
                var width = part.localScale.x;
                var depth = part.localScale.z;
                var top = part.localPosition.y + part.localScale.y*.5f;
                var thickness = part.name == "Relay access step" ? Mathf.Min(part.localScale.y,.39f) : .64f;
                var where = part.localPosition;
                where.y = top-thickness+.012f;
                var art = Install(side,"Fabricated service tread",where,stairs,tread);
                art.localScale = new Vector3(width,thickness,depth);
                MemoryObservatoryArt.Hide(part);
            }
            var porch = station.Find("Relay tower porch");
            var landing = Install(side,"Riveted relay landing",new Vector3(porch.localPosition.x,.72f,porch.localPosition.z),
                stairs,tread);
            landing.localScale = new Vector3(4.29f,.38f,3.61f);
            MemoryObservatoryArt.Hide(porch);

            MemoryObservatoryArt.LightKey(side,"Furnace amber task key",new Vector3(-14.85f,4.2f,55.45f),
                new Vector3(-18.8f,2.13f,60.1f),new Color(1f,.57f,.26f),59f,13f,64f,true);
            MemoryObservatoryArt.LightKey(side,"Relay step cool reflected fill",new Vector3(-18.67f,3.38f,51.1f),
                new Vector3(-14.93f,.53f,53.1f),new Color(.66f,.77f,1f),19f,10f,82f);
        }

        private static void Bedrock(Transform root, Transform observatory)
        {
            var donor = AssetDatabase.LoadAssetAtPath<GameObject>(Folder + "observatory-bedrock-face.glb");
            if (donor == null) return;
            Disable(observatory,"East bedrock reinforcement","West eroded bedrock strata",
                "East eroded bedrock strata","West vertical shale escarpment","East vertical shale escarpment");
            foreach (Transform item in observatory)
            {
                if (item.name.StartsWith("Sheared basalt outcrop ",StringComparison.Ordinal))
                    MemoryObservatoryArt.Hide(item);
            }

            var strata = Node(root,"Layered basalt around entrances",Vector3.zero);
            var pieces = new (Vector3 at,float height,float width,float yaw,float lean)[]
            {
                (new Vector3(-23.9f,-5.5f,48.5f),12.6f,10.4f,-69,8),
                (new Vector3(-23.5f,-6.4f,57.4f),17.1f,12.3f,-79,-7),
                (new Vector3(-24.8f,3.7f,63.1f),13.6f,10.7f,-75,13),
                (new Vector3(-23.4f,-7.6f,73.0f),16.4f,13.4f,-68,7),
                (new Vector3(-29.0f,2.1f,77.0f),15.7f,15.2f,-72,-10),
                (new Vector3(-32.4f,-7.8f,91.4f),21.2f,24.5f,-51,12),
                (new Vector3(24.2f,-6.6f,50.5f),12.3f,13.8f,54,-8),
                (new Vector3(24.0f,-6.8f,60.5f),16.3f,12.0f,69,9),
                (new Vector3(23.9f,-6.8f,70.2f),16.5f,11.2f,74,-8),
                (new Vector3(28.3f,3.2f,71.8f),13.5f,14.1f,66,14),
                (new Vector3(26.9f,-7.9f,81.6f),17.2f,15.8f,55,-11),
                (new Vector3(33.6f,-7.7f,94.2f),21.5f,22.5f,45,-9)
            };
            foreach (var (at,height,width,yaw,lean) in pieces)
            {
                var piece = MemoryObservatoryArt.Place(strata,donor,"Eroded fractured basalt layer",at,height,width,yaw);
                piece.Rotate(0,0,lean,Space.Self);
            }
        }

        private static Mesh BuildShell(GameObject donor,string name,Vector3 size,Func<Vector3,bool> clip, bool tread = false)
        {
            var path = Folder + name + ".asset";
            var existing = AssetDatabase.LoadAssetAtPath<Mesh>(path);
            if (existing != null) return existing;
            var source = donor.GetComponentInChildren<MeshFilter>().sharedMesh;
            var mesh = UnityEngine.Object.Instantiate(source);
            mesh.name = name;
            var bounds = mesh.bounds;
            var turn = tread ? bounds.size.z > bounds.size.x : bounds.size.x < bounds.size.z;
            var rotation = Quaternion.Euler(0,turn ? -90f : 0f,0);
            var scale = new Vector3(size.x/(turn ? bounds.size.z : bounds.size.x),
                size.y/bounds.size.y,size.z/(turn ? bounds.size.x : bounds.size.z));
            var vertices = mesh.vertices;
            var normals = mesh.normals;
            for (var i=0;i<vertices.Length;i++)
            {
                var vertex = rotation*(vertices[i]-bounds.center);
                vertex.y += bounds.extents.y;
                vertices[i] = Vector3.Scale(vertex,scale);
                var normal = rotation*normals[i];
                normals[i] = new Vector3(normal.x/scale.x,normal.y/scale.y,normal.z/scale.z).normalized;
            }

            mesh.vertices = vertices;
            mesh.normals = normals;
            if (clip != null)
            {
                for (var submesh=0;submesh<mesh.subMeshCount;submesh++)
                {
                    var indices = mesh.GetTriangles(submesh);
                    var kept = new List<int>(indices.Length);
                    for (var index=0;index<indices.Length;index+=3)
                    {
                        var a = indices[index];
                        var b = indices[index+1];
                        var c = indices[index+2];
                        if (clip((vertices[a]+vertices[b]+vertices[c])/3f)) continue;
                        kept.Add(a);
                        kept.Add(b);
                        kept.Add(c);
                    }
                    mesh.SetTriangles(kept,submesh,false);
                }
            }
            mesh.RecalculateTangents();
            mesh.RecalculateBounds();
            AssetDatabase.CreateAsset(mesh,path);
            return mesh;
        }

        private static Transform Install(Transform parent,string name,Vector3 at,Mesh mesh,GameObject donor)
        {
            var prop = Node(parent,name,at);
            prop.gameObject.AddComponent<MeshFilter>().sharedMesh = mesh;
            var renderer = prop.gameObject.AddComponent<MeshRenderer>();
            renderer.sharedMaterials = donor.GetComponentInChildren<MeshRenderer>().sharedMaterials;
            renderer.shadowCastingMode = ShadowCastingMode.On;
            return prop;
        }

        private static void Disable(Transform owner,params string[] names)
        {
            foreach (Transform item in owner)
                if (Array.IndexOf(names,item.name)>=0) MemoryObservatoryArt.Hide(item);
        }
    }
}
