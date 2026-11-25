using System;
using System.Collections.Generic;
using System.Reflection;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
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
        private const string ScenePath = "Assets/ElevenEleven/Scenes/ChapterRoom01.unity";
        private const string Art = "Assets/ElevenEleven/Opening/Stormworks/";
        private const string Folder = Art + "ChapterWallFabrication/";
        private const string Layer = "Fabricated structural wall skin";
        private const string MainWallBank = "Full-height containment bulkheads";
        private static readonly Regex WallName = new Regex("wall|panel plate|rear envelope|side envelope|sealed backing|bulkhead", RegexOptions.IgnoreCase);
        private static readonly Regex Fixtures = new Regex("rim|lantern|light|indicator|monitor|gate|mirror|window|screen|rail|cabinet|pipe|conduit|manifold|return duct|glass|louvre|keel|utility post|access line|frame|catwalk|brick|cliff", RegexOptions.IgnoreCase);
        private static readonly Regex SecondaryShell = new Regex("plenum wall|outer blast wall|sealed backing|^east wall$|^west wall$|^rear wall$|^southwall|^northwall|^eastwall|^westwall", RegexOptions.IgnoreCase);

        private sealed class Finish
        {
            internal Mesh Geometry;
            internal Material[] Materials;
        }

        private readonly struct WallFace
        {
            internal readonly MeshRenderer Source;
            internal readonly Vector3 Position;
            internal readonly Vector3 Inward;
            internal readonly float Width;
            internal readonly float Height;
            internal readonly bool Primary;

            internal WallFace(MeshRenderer source, Vector3 position, Vector3 inward, float width, float height, bool primary)
            {
                Source = source;
                Position = position;
                Inward = inward;
                Width = width;
                Height = height;
                Primary = primary;
            }
        }

        [MenuItem("11.11/Apply Detailed Wall Fabrication")]
        public static void Apply()
        {
            if (!Application.isBatchMode && !EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo()) return;
            var scene = EditorSceneManager.OpenScene(ScenePath);
            var content = scene.GetRootGameObjects().Single(root => root.name == "Room content").transform;
            var station = content.Find("Echo Station");
            var colliders = content.GetComponentsInChildren<Collider>(true)
                .ToDictionary(collider => collider, collider => EditorJsonUtility.ToJson(collider));
            if (!AssetDatabase.IsValidFolder(Folder.TrimEnd('/')))
                AssetDatabase.CreateFolder(Art.TrimEnd('/'), "ChapterWallFabrication");
            var finishes = PrepareFinishes();

            (string name, Transform root, Vector3 focus, int finish)[] layouts =
            {
                (name:"Signal and pressure", root:station, focus:new Vector3(0, 1.8f, 7f), finish:0),
                ("Observatory and branches",station.Find("Memory Observatory"),new Vector3(0,1.8f,58f),0),
                ("Security",station.Find("Security wing"),new Vector3(0,1.8f,8.8f),1),
                ("Specimen containment",station.Find("Specimen containment"),new Vector3(-14,1.8f,6f),2),
                ("Archive",station.Find("Memory archive wing"),new Vector3(-11,1.8f,0),1),
                ("Reactor",station.Find("Reserve reactor wing"),new Vector3(0,-.9f,22f),0),
                ("Quarantine",station.Find("Decontamination and quarantine"),new Vector3(0,1.8f,16f),2),
                ("Surveillance",station.Find("Surveillance and mirror"),new Vector3(0,1.8f,16f),1),
                ("Examination and Zero",Find(station,"Kinja examination theatre"),new Vector3(0,1.8f,20f),2),
                ("Hospital",Find(station,"Awakening ward"),new Vector3(0,1.4f,0),2)
            };
            var roomRoots = layouts.Select(layout => layout.root).ToHashSet();
            var counts = new Dictionary<string, int>();
            var survey = SurveySignal(content,station);
            foreach (var room in layouts)
            {
                var layer = Reset(room.root);
                // Each runner owns its nested root and leaves door mechanisms and glazed faces intact.
                var focus = room.root.TransformPoint(room.focus);
                var surfaces = room.root.GetComponentsInChildren<MeshRenderer>(true)
                    .Where(candidate => Owns(room.root, candidate.transform, roomRoots))
                    .ToArray();
                var plates = new List<(WallFace face,int finish)>();
                foreach (var renderer in surfaces)
                {
                    if (!TryFace(renderer, focus, out var face))
                        continue;
                    plates.Add((face,room.finish));
                }
                if (room.root == station)
                {
                    foreach (var renderer in content.Find("Sector 11").GetComponentsInChildren<MeshRenderer>(true))
                        if (TryFace(renderer, focus, out var face) && !SecondaryShell.IsMatch(renderer.name))
                            plates.Add((face,room.finish));
                    foreach (var renderer in survey)
                        if (plates.All(plate => plate.face.Source!=renderer) &&
                            TryFace(renderer,focus,out var surveyed,true))
                            plates.Add((surveyed,room.finish));
                }
                var count = 0;
                foreach (var (face, finish) in plates)
                    count += FinishWall(layer,face,finishes[finish]);
                counts[room.name] = count;
                Debug.Log($"ECHO_WALL_CRAFT_ROOM name={room.name} surfaces={plates.Count} cassettes={count}");
            }

            var after = content.GetComponentsInChildren<Collider>(true);
            if (after.Length != colliders.Count || after.Any(collider =>
                !colliders.TryGetValue(collider,out var original) || original != EditorJsonUtility.ToJson(collider)))
                throw new InvalidDataException("A wall finish altered gameplay collision.");
            if (!counts.TryGetValue("Signal and pressure",out var signal) || signal < 14 ||
                !counts.TryGetValue("Surveillance",out var surveillance) || surveillance < 14)
                throw new InvalidDataException("The major blank wall banks were not found.");
            AssetDatabase.SaveAssets();
            if (!EditorSceneManager.SaveScene(scene)) throw new IOException("Could not save the wall fabrication.");
            Debug.Log($"ECHO_WALL_CRAFT_SAVED rooms={counts.Count(pair=>pair.Value>0)} cassettes={counts.Values.Sum()} colliders={after.Length}");
        }

        private static bool Owns(Transform room, Transform surface, HashSet<Transform> roomRoots)
        {
            for (var cursor = surface; cursor && cursor != room; cursor = cursor.parent)
                if (roomRoots.Contains(cursor) || cursor.name == Layer) return false;
            return true;
        }

        private static bool TryFace(MeshRenderer renderer, Vector3 toward, out WallFace face, bool surveyed = false)
        {
            face = default;
            if (!renderer.enabled || renderer.sharedMaterials.Length != 1) return false;
            var model = renderer.GetComponent<MeshFilter>()?.sharedMesh;
            if (!model || model.vertexCount > 48) return false;
            var name = renderer.name;
            var immediate = renderer.transform.parent;
            var assembly = name.StartsWith("_MeshInstance",StringComparison.Ordinal) && immediate ? immediate.name : name;
            if ((!surveyed && !WallName.IsMatch(assembly)) || Fixtures.IsMatch(assembly)) return false;
            var primary = name == "Panel plate";
            var metal = renderer.sharedMaterial;
            if (!metal || metal.renderQueue >= (int)RenderQueue.Transparent ||
                (metal.HasProperty("_EmissionColor") && metal.GetColor("_EmissionColor").maxColorComponent > .075f))
                return false;

            // Covered second shells are already finished by their interior panel bank.
            if (!primary && !surveyed)
            {
                for (var p=renderer.transform.parent;p;p=p.parent)
                    if (p.name == MainWallBank || p.name.StartsWith("Continuous ",StringComparison.Ordinal))
                        return false;
                if (name == "Outer blast wall") return false;
            }

            var t = renderer.transform;
            if (Vector3.Dot(t.up,Vector3.up)<.985f) return false;
            var b = model.bounds;
            var s=t.lossyScale;
            var size=Vector3.Scale(b.size,new Vector3(Mathf.Abs(s.x),Mathf.Abs(s.y),Mathf.Abs(s.z)));
            var normalZ=size.z<=size.x;
            var width=normalZ?size.x:size.z;
            var depth=normalZ?size.z:size.x;
            if (width<1.35f || size.y<1.62f || depth>Mathf.Min(1.1f,width*.32f))
                return false;

            var center=t.TransformPoint(b.center);
            var inward=normalZ?t.forward:t.right;
            if (primary)
                inward=-t.forward;
            else if (Vector3.Dot(toward-center,inward)<0f)
                inward=-inward;
            inward.y=0f;
            face=new WallFace(renderer,center+inward*(depth*.5f+.007f),inward.normalized,width,size.y,primary);
            return true;
        }

        private static MeshRenderer[] SurveySignal(Transform content,Transform station)
        {
            var hitMesh=typeof(HandleUtility).GetMethod("IntersectRayMesh",
                BindingFlags.Static|BindingFlags.Public|BindingFlags.NonPublic,null,
                new[] { typeof(Ray), typeof(Mesh), typeof(Matrix4x4), typeof(RaycastHit).MakeByRefType() },null);
            if (hitMesh == null) return Array.Empty<MeshRenderer>();
            var camera=content.GetComponentsInChildren<Camera>(true).Single(item=>item.name=="Room 01 camera");
            var origin=station.TransformPoint(new Vector3(.75f,1.84f,-5.8f));
            var focus=station.TransformPoint(new Vector3(.25f,2.70f,13.2f));
            var orientation=Quaternion.LookRotation(focus-origin,Vector3.up);
            var tangent=Mathf.Tan(camera.fieldOfView*Mathf.Deg2Rad*.5f);
            var renderers=content.GetComponentsInChildren<MeshRenderer>(true).Where(item=>
                item.enabled && item.sharedMaterial && item.sharedMaterial.renderQueue<(int)RenderQueue.Transparent &&
                item.bounds.SqrDistance(origin)<32f*32f).ToArray();
            var found=new HashSet<MeshRenderer>();
            var pixels=new[]{new Vector2(.87f,.51f),new Vector2(.90f,.65f),new Vector2(.86f,.70f),
                new Vector2(.15f,.73f),new Vector2(.18f,.60f),new Vector2(.13f,.46f)};
            foreach(var point in pixels)
            {
                var cameraRay=new Ray(origin,orientation*new Vector3((point.x*2f-1f)*tangent*16f/9f,
                    (point.y*2f-1f)*tangent,1f).normalized);
                MeshRenderer nearest=null;
                var distance=42f;
                foreach(var candidate in renderers)
                {
                    if (!candidate.bounds.IntersectRay(cameraRay,out var boundDepth) || boundDepth>distance) continue;
                    var mesh=candidate.GetComponent<MeshFilter>()?.sharedMesh;
                    if (!mesh) continue;
                    var args=new object[] {cameraRay,mesh,candidate.transform.localToWorldMatrix,default(RaycastHit)};
                    if (!(bool)hitMesh.Invoke(null,args) || args[3] is not RaycastHit hit || hit.distance>=distance) continue;
                    nearest=candidate;
                    distance=hit.distance;
                }
                if (!nearest) continue;
                Debug.Log($"ECHO_WALL_CRAFT_VIEW x={point.x:F2} y={point.y:F2} surface={nearest.name} parent={nearest.transform.parent.name} material={nearest.sharedMaterial.name}");
                var source=nearest.sharedMaterial;
                var baseMap=source.HasProperty("_BaseMap")?source.GetTexture("_BaseMap"):null;
                if (!baseMap && nearest.GetComponent<MeshFilter>()?.sharedMesh &&
                    nearest.GetComponent<MeshFilter>().sharedMesh.vertexCount<=48) found.Add(nearest);
            }
            return found.ToArray();
        }

        private static int FinishWall(Transform parent, WallFace face, Finish finish)
        {
            var source=face.Source;
            if (face.Primary)
            {
                // These broadly visible plates are the metal substrate underneath the actual recessed panel features.
                source.sharedMaterial=finish.Materials[0];
                var previous=source.transform.parent.Find("Flush pressed wall courses");
                if (previous)
                    foreach (var old in previous.GetComponentsInChildren<MeshRenderer>(true)) old.enabled=false;
            }
            var count=Mathf.Clamp(Mathf.CeilToInt(face.Width/3.1f),1,14);
            var width=face.Width/count;
            var right=Vector3.Cross(Vector3.up,face.Inward).normalized;
            var center=face.Position + Vector3.down*(face.Height*.105f);
            for (var i=0;i<count;i++)
            {
                var node=Node(parent,"Recessed wall service cassette",Vector3.zero);
                node.SetPositionAndRotation(center+right*((i+.5f)*width-face.Width*.5f),Quaternion.LookRotation(face.Inward,Vector3.up));
                node.localScale=new Vector3(width*.963f,face.Height*.705f,1f);
                node.gameObject.AddComponent<MeshFilter>().sharedMesh=finish.Geometry;
                var renderer=node.gameObject.AddComponent<MeshRenderer>();
                renderer.sharedMaterials=finish.Materials;
                renderer.shadowCastingMode=ShadowCastingMode.Off;
                renderer.receiveShadows=true;
                GameObjectUtility.SetStaticEditorFlags(node.gameObject,StaticEditorFlags.BatchingStatic);
            }
            return count;
        }

        private static Finish[] PrepareFinishes()
        {
            var pbr=AssetDatabase.LoadAssetAtPath<Material>(Art+"StationFinishes/Chronostat oxide-filled steel.mat");
            var enamel=AssetDatabase.LoadAssetAtPath<Material>("Assets/ElevenEleven/Opening/Hospital/Finishes/Ward eggshell enamel.mat");
            if (!pbr || !enamel) throw new FileNotFoundException("The authored steel and clinical enamel are missing.");
            return new[]
            {
                new Finish { Geometry=MeshAt("Folded containment cassette",0), Materials=new[]
                {
                    FinishAt(pbr,"Dark neutral iron backing",new Color(.27f,.255f,.224f),.29f),
                    FinishAt(pbr,"Brushed graphite containment plates",new Color(.48f,.443f,.365f),.51f),
                    FinishAt(pbr,"Weathered wall fasteners",new Color(.63f,.59f,.525f),.71f)
                }},
                new Finish { Geometry=MeshAt("Recessed operations cassette",1), Materials=new[]
                {
                    FinishAt(pbr,"Recessed graphite isolation",new Color(.208f,.205f,.188f),.27f),
                    FinishAt(pbr,"Warm grey operations plates",new Color(.449f,.416f,.368f),.43f),
                    FinishAt(pbr,"Warm satin operations corners",new Color(.62f,.591f,.53f),.60f)
                }},
                new Finish { Geometry=MeshAt("Flush clinical cassette",2), Materials=new[]
                {
                    FinishAt(pbr,"Warm dark clinical gasket",new Color(.29f,.272f,.227f),.24f),
                    FinishAt(enamel,"Tactile neutral ivory enamel",new Color(.58f,.558f,.512f),.47f),
                    FinishAt(pbr,"Satin clean-room retainer",new Color(.65f,.618f,.57f),.57f)
                }}
            };
        }

        private static Material FinishAt(Material template,string name,Color tint,float smoothness)
        {
            var path=Folder+name+".mat";
            var mat=AssetDatabase.LoadAssetAtPath<Material>(path);
            if (!mat)
            {
                mat=new Material(template) { name=name };
                AssetDatabase.CreateAsset(mat,path);
            }
            mat.SetColor("_BaseColor",tint);
            mat.SetFloat("_Smoothness",smoothness);
            mat.SetFloat("_BumpScale",.74f);
            EditorUtility.SetDirty(mat);
            return mat;
        }

        private static Mesh MeshAt(string name,int style)
        {
            var path=Folder+name+".asset";
            var mesh=AssetDatabase.LoadAssetAtPath<Mesh>(path);
            if (mesh) return mesh;
            var model=new Plates();
            model.Raised(0f,0f,.984f,.988f,.024f,.012f,.009f,0);
            model.Raised(0f,.460f,.962f,.071f,.018f,.043f,.006f,2);
            model.Raised(0f,-.443f,.958f,.080f,.018f,.043f,.006f,2);
            if (style==2)
            {
                model.Raised(0f,.182f,.906f,.436f,.026f,.050f,.008f,1);
                model.Raised(0f,-.235f,.905f,.284f,.025f,.044f,.007f,1);
                model.Raised(0f,-.067f,.854f,.026f,.008f,.059f,.005f,2);
            }
            else
            {
                model.Raised(-.306f,.031f,.269f,.790f,.018f,.041f,.009f,1);
                model.Raised(.162f,.124f,.584f,.549f,.018f,.055f,.010f,1);
                model.Raised(.162f,-.282f,.586f,.240f,.016f,.045f,.008f,1);
                for (var row=0;row<9;row++)
                {
                    var at=.364f-row*.074f;
                    model.Raised(-.304f,at,.219f,.037f,.008f,.069f,.006f,row%3==0?2:1);
                }
                model.Raised(.171f,.286f,.375f,.155f,.010f,.061f,.004f,0);
                for (var row=0;row<5;row++)
                    model.Raised(.171f,.337f-row*.022f,.336f,.009f,.004f,.072f,.003f,2);
                model.Raised(.161f,-.351f,.404f,.062f,.011f,.052f,.005f,0);
                for(var slot=0;slot<7;slot++)
                    model.Raised(-.003f+slot*.054f,-.351f,.010f,.034f,.004f,.064f,.003f,2);
            }
            foreach (var corner in new[]{-.431f,.431f})
            {
                foreach (var z in new[]{-.442f,-.198f,.179f,.439f})
                    model.Bolt(corner,z,.017f, .035f,.070f);
            }
            mesh=model.Build(name);
            AssetDatabase.CreateAsset(mesh,path);
            return mesh;
        }

        private static Transform Reset(Transform parent)
        {
            var prior=parent.Find(Layer);
            if (prior) Object.DestroyImmediate(prior.gameObject);
            return Node(parent,Layer,Vector3.zero);
        }

        private sealed class Plates
        {
            private readonly List<Vector3> vertices=new();
            private readonly List<Vector2> uv=new();
            private readonly List<int>[] faces;

            internal Plates(int submeshes = 3)
            {
                faces = Enumerable.Range(0, submeshes).Select(_ => new List<int>()).ToArray();
            }

            private static Vector3[] Outline(float x,float y,float w,float h,float cut,float z)
            {
                var a=x-w*.5f; var b=x+w*.5f; var c=y-h*.5f; var d=y+h*.5f;
                return new[]{new Vector3(a+cut,c,z),new Vector3(b-cut,c,z),new Vector3(b,c+cut,z),
                    new Vector3(b,d-cut,z),new Vector3(b-cut,d,z),new Vector3(a+cut,d,z),
                    new Vector3(a,d-cut,z),new Vector3(a,c+cut,z)};
            }

            private void Quad(Vector3 a,Vector3 b,Vector3 c,Vector3 d,int kind)
            {
                var n=vertices.Count;
                foreach(var pt in new[]{a,b,c,d})
                {
                    vertices.Add(pt);
                    uv.Add(new Vector2(pt.x*2.5f+pt.z*.63f,pt.y*3f+pt.z*.71f));
                }
                faces[kind].AddRange(new[]{n,n+1,n+2,n,n+2,n+3});
            }

            private void Fill(Vector3[] outline,float x,float y,float z,int kind)
            {
                var n=vertices.Count;
                vertices.Add(new Vector3(x,y,z));
                uv.Add(new Vector2(x*2.5f+z*.63f,y*3f+z*.71f));
                foreach(var pt in outline)
                {
                    vertices.Add(pt); uv.Add(new Vector2(pt.x*2.5f+pt.z*.63f,pt.y*3f+pt.z*.71f));
                }
                for(var i=0;i<outline.Length;i++)
                    faces[kind].AddRange(new[]{n,n+1+i,n+1+(i+1)%outline.Length});
            }

            internal void Raised(float x,float y,float w,float h,float corner,float depth,float lip,int kind)
            {
                corner=Mathf.Min(corner,Mathf.Min(w,h)*.26f);
                lip=Mathf.Min(lip,Mathf.Min(w,h)*.16f);
                var heel=Outline(x,y,w,h,corner,Mathf.Max(depth-.015f,.002f));
                var top=Outline(x,y,w-2f*lip,h-2f*lip,Mathf.Max(.001f,corner-lip*.7f),depth);
                for(var i=0;i<heel.Length;i++)
                {
                    var k=(i+1)%heel.Length;
                    Quad(heel[i],heel[k],top[k],top[i],kind);
                }
                Fill(top,x,y,depth,kind);
            }

            internal void Bolt(float x,float y,float r,float footZ,float headZ)
            {
                const int sides=6;
                var step=2f*Mathf.PI/sides;
                var ring=new Vector3[sides];
                for(var i=0;i<sides;i++)
                    ring[i]=new Vector3(x+Mathf.Cos(i*step)*r,y+Mathf.Sin(i*step)*r*.69f,headZ);
                for(var i=0;i<sides;i++)
                {
                    var a=ring[i];
                    var b=ring[(i+1)%sides];
                    Quad(new Vector3(a.x,a.y,footZ),new Vector3(b.x,b.y,footZ),b,a,2);
                }
                Fill(ring,x,y,headZ,2);
            }

            internal Mesh Build(string name)
            {
                var m=new Mesh { name=name, subMeshCount=faces.Length };
                m.SetVertices(vertices);
                m.SetUVs(0,uv);
                for(var j=0;j<faces.Length;j++) m.SetTriangles(faces[j],j);
                m.RecalculateBounds();
                m.RecalculateNormals();
                m.RecalculateTangents();
                return m;
            }
        }
    }
}
