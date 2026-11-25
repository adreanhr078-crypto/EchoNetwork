using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using static ElevenEleven.Editor.GodotRoomAssembly;
using Object = UnityEngine.Object;

namespace ElevenEleven.Editor
{
    internal static class FlowReferenceStructuralFit
    {
        private const string Art = "Assets/ElevenEleven/Opening/Stormworks/";
        private const string Folder = Art + "ChapterRoomPolish/";
        private const string Layer = "Flow measured structural fit";

        internal static void Apply(Transform content, Transform station)
        {
            var shell = content.Find("Sector 11");
            var layer = Reset(station, Layer);
            var metal = LoadMaterial("Warm forged bulkhead steel", new Color(.47f,.437f,.386f), .72f);
            var ribs = LoadMaterial("Charcoal folded steel wall skin", new Color(.379f,.364f,.334f), .62f);
            var rim = LoadMaterial("Lightly polished rings and rivets", new Color(.58f,.548f,.475f), .81f);
            var outer = LoadMesh("Pressure full-size rolled sections",
                () => Annulus(3.19f,2.55f,3.55f,2.75f,.32f));
            var lining = LoadMesh("Pressure dual rolled finish bead",
                () => Annulus(3.22f,2.59f,3.30f,2.67f,.065f));
            var ribbed = LoadMesh("Cold formed fluted panel", FlutedSheet);
            foreach (var z in new[] { 25f, 29.2f })
            {
                foreach (var item in station.Cast<Transform>().Where(item =>
                    Mathf.Abs(item.localPosition.z-z)<.015f &&
                    (item.name == "Service portal header" || item.name == "Service portal column")))
                    Hide(item);
                var arch = Node(layer, "Mounted circular bulkhead", new Vector3(0f,2.55f,z));
                Render(arch, "Rolled pressure frame body", outer, metal, Vector3.zero, Vector3.one);
                Render(arch, "Front locking bead", lining, rim, Vector3.back*.17f, Vector3.one);
                Render(arch, "Rear locking bead", lining, rim, Vector3.forward*.17f, Vector3.one);
            }
            foreach (var bumper in station.Cast<Transform>().Where(item => item.name == "Plenum bumper"))
                bumper.GetComponent<MeshRenderer>().sharedMaterial = ribs;
            Render(layer, "West fluted wall beside the workstation", ribbed, ribs,
                new Vector3(-11.20f,2.93f,3.52f), new Vector3(2.42f,5.68f,1f), 90f);
            Render(layer, "East long fluted return", ribbed, ribs,
                new Vector3(11.20f,2.97f,8.75f), new Vector3(4.17f,5.79f,1f), -90f);
            Render(layer, "Blast door outer return port", ribbed, ribs,
                new Vector3(-6.92f,3.0f,17.27f), new Vector3(.51f,5.81f,1f), 180f);
            Render(layer, "Blast door outer return starboard", ribbed, ribs,
                new Vector3(6.92f,3.0f,17.27f), new Vector3(.51f,5.81f,1f), 180f);

            var leaf = shell.Find("Blast gate/Sliding door");
            var flatVisual = leaf.Find("Gate panel");
            var trim = Reset(leaf, "Measured hydraulic door facade");
            flatVisual.GetComponent<MeshRenderer>().enabled = true;
            flatVisual.GetComponent<MeshRenderer>().sharedMaterial = ribs;
            StormworksConstruction.FittedProp(trim, "Segmented hydraulic leaf", "stormworks_precision_bulkhead_v1.glb",
                new Vector3(0f,0f,-.37f), new Vector3(6.94f,6.28f,.49f), 180f);
            var security = Reset(station.Find("Security wing"), Layer);
            Render(security, "Right service walkway inner wall return", ribbed, ribs,
                new Vector3(4.38f,2.45f,11.34f), new Vector3(2.50f,3.99f,1f), -90f);
            var surveillance = station.Find("Surveillance and mirror");
            var monitor = Reset(surveillance, Layer);
            foreach (var z in new[] { 7.6f, 11.9f, 16.2f, 20.5f })
                Render(monitor, "Monitoring aisle folded backing", ribbed, ribs,
                    new Vector3(-13.92f,3.82f,z), new Vector3(4.22f,6.68f,1f), 90f);
            var contacts = FinishVisibleSeams(content, station);
            Debug.Log($"ECHO_FLOW_STRUCTURAL_FIT circular_bulkheads=2 fluted_panels=9 segmented_gate=true wall_seams={contacts}");
        }

        internal static int FinishVisibleSeams(Transform content, Transform station)
        {
            var folded = LoadMaterial("Charcoal folded steel wall skin", new Color(.379f,.364f,.334f), .62f);
            var ring = LoadMaterial("Warm forged bulkhead steel", new Color(.47f,.437f,.386f), .72f);
            var mesh = LoadMesh("Cold formed fluted panel", FlutedSheet);
            var shell = content.Find("Sector 11");
            var leaf = shell.Find("Blast gate/Sliding door");
            var backing = leaf.Find("Gate panel").GetComponent<MeshRenderer>();
            backing.enabled = true;
            backing.sharedMaterial = folded;
            leaf.Find("Measured hydraulic door facade/Segmented hydraulic leaf").localPosition = new Vector3(0f,0f,-.37f);

            var deckFolder = Art+"ChapterArchitectureFinishes";
            var source = AssetDatabase.FindAssets("Service deck neutral deck t:Material",new[] {deckFolder})
                .Select(guid => AssetDatabase.LoadAssetAtPath<Material>(AssetDatabase.GUIDToAssetPath(guid)))
                .FirstOrDefault();
            if (!source) source = AssetDatabase.LoadAssetAtPath<Material>(Folder+"Service deck.mat");
            if (!source) throw new FileNotFoundException("The measured service deck material is missing.");
            var apronPath = Folder+"Receiving apron graphite paving.mat";
            var apron = AssetDatabase.LoadAssetAtPath<Material>(apronPath);
            if (!apron)
            {
                apron = new Material(source) {name="Receiving apron graphite paving"};
                AssetDatabase.CreateAsset(apron,apronPath);
            }
            apron.SetColor("_BaseColor", new Color(.73f,.71f,.67f));
            apron.SetTextureScale("_BaseMap",new Vector2(4.5f,2.45f));
            EditorUtility.SetDirty(apron);
            station.Find("Receiving apron").GetComponent<MeshRenderer>().sharedMaterial = apron;
            foreach (var item in station.Cast<Transform>().Where(item => item.name is "Service portal header" or "Service portal column"))
                item.GetComponent<MeshRenderer>().sharedMaterial = ring;

            var aged = 0;
            var banks = station.Find("Full-height containment bulkheads");
            foreach (var plate in banks.GetComponentsInChildren<MeshRenderer>(true).Where(item => item.name=="Panel plate"))
            {
                var panel = plate.transform;
                var parent = panel.parent;
                var old = parent.Find("Flush pressed wall courses");
                if (old) Object.DestroyImmediate(old.gameObject);
                plate.sharedMaterial = folded;
                var size = panel.localScale;
                if (size.x < 1.7f) continue;
                var at = panel.localPosition + new Vector3(0f,-size.y*.10f,-size.z*.5f-.009f);
                Render(parent,"Flush pressed wall courses",mesh,folded,at,
                    new Vector3(size.x*.954f,size.y*.632f,1f),180f);
                aged++;
            }
            return aged;
        }

        private static Material LoadMaterial(string label, Color tint, float smooth)
        {
            var path = Folder + label + ".mat";
            var material = AssetDatabase.LoadAssetAtPath<Material>(path);
            if (!material)
            {
                var source = AssetDatabase.LoadAssetAtPath<Material>(Art + "StationFinishes/Chronostat oxide-filled steel.mat");
                if (!source) throw new FileNotFoundException("The authored brushed steel material is missing.");
                material = new Material(source) { name = label };
                AssetDatabase.CreateAsset(material, path);
            }
            material.SetColor("_BaseColor", tint);
            material.SetFloat("_Smoothness", smooth);
            material.SetFloat("_BumpScale", .75f);
            EditorUtility.SetDirty(material);
            return material;
        }

        private static Mesh LoadMesh(string label, Func<Mesh> build)
        {
            var path = Folder + label + ".asset";
            var result = AssetDatabase.LoadAssetAtPath<Mesh>(path);
            if (result) return result;
            result = build();
            result.name = label;
            AssetDatabase.CreateAsset(result, path);
            return result;
        }

        private static Mesh Annulus(float innerX, float innerY, float outerX, float outerY, float depth)
        {
            var build = new Quads();
            const int segments = 64;
            for (var i=0;i<segments;i++)
            {
                var a = Mathf.PI*2f*i/segments;
                var b = Mathf.PI*2f*(i+1)/segments;
                var innerA = new Vector3(Mathf.Cos(a)*innerX,Mathf.Sin(a)*innerY,0f);
                var innerB = new Vector3(Mathf.Cos(b)*innerX,Mathf.Sin(b)*innerY,0f);
                var outerA = new Vector3(Mathf.Cos(a)*outerX,Mathf.Sin(a)*outerY,0f);
                var outerB = new Vector3(Mathf.Cos(b)*outerX,Mathf.Sin(b)*outerY,0f);
                var inset = Vector3.forward*depth*.5f;
                build.Add(innerA+inset,outerA+inset,outerB+inset,innerB+inset);
                build.Add(innerB-inset,outerB-inset,outerA-inset,innerA-inset);
                build.Add(outerA-inset,outerB-inset,outerB+inset,outerA+inset);
                build.Add(innerB-inset,innerA-inset,innerA+inset,innerB+inset);
            }
            return build.Bake();
        }

        private static Mesh FlutedSheet()
        {
            var build = new Quads();
            (float t, float z)[] edge = { (0f,0f), (.16f,0f), (.39f,.064f), (.74f,.064f), (1f,0f) };
            const int ribs = 18;
            for (var row=0;row<ribs;row++)
            {
                for (var segment=0;segment<edge.Length-1;segment++)
                {
                    var y0=(row+edge[segment].t)/ribs-.5f;
                    var y1=(row+edge[segment+1].t)/ribs-.5f;
                    var z0=edge[segment].z;
                    var z1=edge[segment+1].z;
                    build.Add(new Vector3(-.5f,y0,z0),new Vector3(.5f,y0,z0),
                        new Vector3(.5f,y1,z1),new Vector3(-.5f,y1,z1),new Vector2(2.9f,4.2f));
                }
            }
            return build.Bake();
        }

        private static Transform Reset(Transform host, string name)
        {
            var prior = host.Find(name);
            if (prior) Object.DestroyImmediate(prior.gameObject);
            return Node(host,name,Vector3.zero);
        }

        private static void Hide(Transform item)
        {
            foreach (var renderer in item.GetComponentsInChildren<MeshRenderer>(true))
            {
                renderer.enabled = false;
                if (PrefabUtility.IsPartOfPrefabInstance(renderer))
                    PrefabUtility.RecordPrefabInstancePropertyModifications(renderer);
            }
        }

        private static void Render(Transform parent, string name, Mesh mesh, Material material,
            Vector3 at, Vector3 size, float yaw = 0f)
        {
            var child = Node(parent,name,at);
            child.localRotation = Quaternion.Euler(0f,yaw,0f);
            child.localScale = size;
            child.gameObject.AddComponent<MeshFilter>().sharedMesh = mesh;
            var renderer = child.gameObject.AddComponent<MeshRenderer>();
            renderer.sharedMaterial = material;
            renderer.shadowCastingMode = ShadowCastingMode.On;
        }

        private sealed class Quads
        {
            private readonly List<Vector3> points = new List<Vector3>();
            private readonly List<Vector2> uv = new List<Vector2>();
            private readonly List<int> indices = new List<int>();

            internal void Add(Vector3 a, Vector3 b, Vector3 c, Vector3 d, Vector2 tiling = default)
            {
                var i = points.Count;
                points.AddRange(new[] { a,b,c,d });
                var t = tiling == default ? Vector2.one : tiling;
                for (var v=i;v<i+4;v++) uv.Add(Vector2.Scale(new Vector2(points[v].x+.057f*points[v].z,
                    points[v].y+.063f*points[v].z),t));
                indices.AddRange(new[] {i,i+1,i+2,i,i+2,i+3});
            }

            internal Mesh Bake()
            {
                var mesh = new Mesh();
                mesh.SetVertices(points);
                mesh.SetUVs(0,uv);
                mesh.SetTriangles(indices,0);
                mesh.RecalculateNormals();
                mesh.RecalculateTangents();
                return mesh;
            }
        }
    }
}
