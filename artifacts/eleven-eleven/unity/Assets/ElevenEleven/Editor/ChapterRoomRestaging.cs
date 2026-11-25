using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using ElevenEleven.Opening;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using static ElevenEleven.Editor.GodotRoomAssembly;
using Object = UnityEngine.Object;

namespace ElevenEleven.Editor
{
    internal static class ChapterRoomRestaging
    {
        private const string ScenePath = "Assets/ElevenEleven/Scenes/ChapterRoom01.unity";
        private const string Stormworks = "Assets/ElevenEleven/Opening/Stormworks/";
        private const string Folder = Stormworks + "ChapterRoomPolish/";
        private const string Layout = "Flow R37 fitted architecture";
        private static readonly Color Warm = new Color(1f, .83f, .65f);

        [MenuItem("11.11/Fit the Flow Room Redesigns")]
        public static void Apply()
        {
            if (!Application.isBatchMode && !EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo()) return;
            var scene = EditorSceneManager.OpenScene(ScenePath);
            var content = scene.GetRootGameObjects().Single(root => root.name == "Room content").transform;
            var station = content.Find("Echo Station");
            var authority = content.GetComponentsInChildren<Collider>(true)
                .ToDictionary(collider => collider, collider => EditorJsonUtility.ToJson(collider));

            FitSignal(content.Find("Sector 11"), station);
            FitPressure(station);
            FitSecurity(station.Find("Security wing"));
            FitSurveillance(station.Find("Surveillance and mirror"));
            Grade(content, station);
            var finishes = ChapterArchitectureFinishes.Apply(content, station);
            ChapterUtilityEffectsArt.Apply(content, station);

            var colliders = content.GetComponentsInChildren<Collider>(true);
            if (authority.Count != colliders.Length || colliders.Any(item =>
                !authority.TryGetValue(item, out var state) || state != EditorJsonUtility.ToJson(item)))
                throw new InvalidDataException("The room layout changed collider identities or shapes.");
            var motion = station.GetComponentsInChildren<RoomEnvironmentMotion>(true);
            if (motion.Length != 16 || motion.Sum(room => room.PieceCount) < 389)
                throw new InvalidDataException("The room redesign dropped previously authored motion.");

            AssetDatabase.SaveAssets();
            if (!EditorSceneManager.SaveScene(scene)) throw new IOException("The Flow room redesign did not save.");
            Debug.Log($"ECHO_R37_RESTAGING_SAVED colliders={colliders.Length} zones={motion.Length} " +
                $"moving_elements={motion.Sum(room => room.PieceCount)} finishes={finishes}");
            if (Environment.GetEnvironmentVariable("ECHO_STATION_CAPTURE") != null)
                ChapterRoomTripoKit.CaptureChapter(content, station, "R37");
        }

        public static void ApplyAndReview()
        {
            Apply();
            Environment.SetEnvironmentVariable("ECHO_STATION_CAPTURE",
                Environment.GetEnvironmentVariable("ECHO_R37_PLAY_CAPTURE"));
            Environment.SetEnvironmentVariable("ECHO_STATION_CAPTURE_ONLY", "12,65,66,67");
            EditorSceneManager.NewScene(NewSceneSetup.EmptyScene);
            ChapterR01Smoke.RunFromRoomAndContinue();
        }

        private static void FitSignal(Transform sector, Transform station)
        {
            var layer = ReplaceLayer(station, Layout);
            // These authored stations remain independent interaction targets, with a clear middle aisle.
            Stand(sector, "StoppedClock", new Vector3(-4.45f, 0f, -1.12f));
            Stand(sector, "PersonalTrace", new Vector3(-5.98f, 0f, 1.27f));
            var tuner = sector.Find("SignalTerminal");
            tuner.localPosition = new Vector3(-6.66f, 0f, 5.49f);
            tuner.localRotation = Quaternion.Euler(0f, 87f, 0f);
            Hide(tuner);
            Kit(layer, "Signal tuning console", "SignalConsole",
                new Vector3(-6.66f, .623f, 5.49f), new Vector3(1.27f, 1.245f, .68f), 87f);
            // A second work surface already exists opposite the viewport. Keep the destination readable.
            Hide(station.Find("Flow reference architectural kit/Signal workbench with recessed instruments"));
            station.Find("Flow reference architectural kit/Workbench practical spill").localPosition =
                new Vector3(-6.04f, 1.83f, 5.36f);
            var mounted = station.GetComponentsInChildren<RoomEnvironmentMotion>(true)
                .Single(motion => motion.name == "Window chips and condensation");
            var register = mounted.transform.Find("Fitted room mechanisms");
            register.position = station.TransformPoint(new Vector3(-6.92f, 1.28f, 5.49f));
            register.rotation = station.rotation * Quaternion.Euler(0, 90f, 0);

            foreach (var side in new[] { -1f, 1f })
            {
                // Cladding is measured against the slab in front of the blast gate.
                foreach (var x in new[] { 5.19f, 8.15f, 10.83f })
                    Kit(layer, $"Blast reveal service panel {side * x:0.00}", "SignalWall",
                        new Vector3(side*x, 3.15f, 17.36f), new Vector3(x > 10f ? 2.13f : 2.67f, 5.62f, .14f), 180f);
                // Break up the blank return around the entry instead of blocking the viewport faces.
                foreach (var x in new[] { 4.35f, 7.56f, 10.09f })
                    Kit(layer, $"Rear wall fluted cassette {side * x:0.00}", "SignalWall",
                        new Vector3(side*x, 3.28f, -6.34f), new Vector3(x > 9f ? 1.99f : 2.75f, 5.62f, .13f), 0f);
            }
            Practical(layer, "Local glow above the signal worktop", new Vector3(-6.31f, 2.11f, 5.6f), 3.3f, 5.0f);
            Debug.Log("ECHO_R37_SIGNAL_LAYOUT three preserved puzzle anchors restaged outside the central route");
        }

        private static void Stand(Transform sector, string model, Vector3 floor)
        {
            var station = sector.Find(model + " pedestal");
            var previous = station.localPosition;
            var delta = floor - new Vector3(previous.x, 0f, previous.z);
            station.localPosition += delta;
            sector.Find(model).localPosition += delta;
            sector.Find(model + " pedestal display housing").localPosition += delta;
        }

        private static void FitPressure(Transform station)
        {
            var layer = ReplaceLayer(station, "Flow R37 pressure machinery");
            var previous = station.Find("Flow reference architectural kit");
            foreach (var module in previous.Cast<Transform>().Where(item =>
                item.name.StartsWith("Plenum circulation controls", StringComparison.Ordinal)))
                Hide(module);
            Hide(station.Find("Chapter room environment art/Pressure service corridor/Regulator cooling stack"));
            var rotors = station.Cast<Transform>().Where(item => item.name == "Airlock extractor rotor")
                .OrderBy(item => item.localPosition.x).ToArray();
            if (rotors.Length != 2 || rotors.Any(item => !item.GetComponent<StationRotor>()))
                throw new InvalidDataException("The existing pressure extractor drives were not found.");
            foreach (var recess in station.Cast<Transform>().Where(item => item.name == "Extractor recess")) Hide(recess);
            foreach (var indicator in station.Cast<Transform>().Where(item => item.name == "Pressure beacon"))
            {
                var size = indicator.localScale;
                indicator.localScale = new Vector3(size.x, .69f, .092f);
            }

            var metal = MaterialAt("StationFinishes/Chronostat oxide-filled steel.mat");
            var charcoal = MaterialAt("Casing recess.mat");
            var blades = MeshAt("Pressure extractor swept blades", FanBlades);
            var guard = MeshAt("Pressure extractor welded guard", FanGuard);
            var eye = MeshAt("Pressure extractor rolled flange", () => TubeRings(
                new[] { (.713f, .069f, .042f),
                        (.681f,.035f,-.114f), (.748f,.025f,-.135f) }, 64));
            var back = MeshAt("Pressure extractor recessed shroud", () => TubeRings(
                new[] { (.644f, .070f, -.17f),
                        (.661f,.062f,-.068f), (.657f,.067f,.003f) }, 64));

            for (var i = 0; i < rotors.Length; i++)
            {
                var side = i == 0 ? -1f : 1f;
                var rotor = rotors[i];
                Hide(rotor);
                var rotorArt = ReplaceLayer(rotor, "R37 swept impeller");
                var at = new Vector3(side * 3.445f, i == 0 ? 2.61f : 2.83f, i == 0 ? 30.86f : 27.76f);
                var yaw = side * -90f;
                rotor.SetLocalPositionAndRotation(at, Quaternion.Euler(0, yaw, 0));
                var frame = Node(layer, side < 0 ? "Return extractor mounted frame" : "Main extractor mounted frame", at);
                frame.localRotation = Quaternion.Euler(0, yaw, 0);
                Render(rotorArt, "Seven tapered impeller blades", blades, metal, Vector3.zero, Vector3.one);
                Render(frame, "Rolled steel inlet flange", eye, metal, Vector3.zero, Vector3.one);
                Render(frame, "Recessed charcoal shroud", back, charcoal, Vector3.zero, Vector3.one);
                Render(frame, "Locked wire safety grille", guard, metal, Vector3.forward*.112f, Vector3.one);
                Practical(frame, "Service lamp steel bounce", new Vector3(-.53f, .62f, .31f), 1.4f, 2.65f);
            }
            Debug.Log("ECHO_R37_EXTRACTORS mounted=2 curved_blades=14 existing_station_rotor_drives=2");
        }

        private static void FitSecurity(Transform room)
        {
            var layer = ReplaceLayer(room, Layout);
            var art = room.Find("Chapter room environment art");
            Hide(art.Find("Security observation head"));
            Hide(art.Find("Security observation head attenuator"));
            var old = room.Find("Station wing finish");
            Hide(old.Find("Diversion console face"));
            Hide(old.Find("Diversion console readable optic"));

            Kit(layer, "Diversion console bolted touch station", "SignalConsole",
                new Vector3(-3.83f, .69f, 1.82f), new Vector3(.91f, 1.37f, .60f), 90f);
            Kit(layer, "Mechanical check scanner on right service wall", "ExaminationCrown",
                new Vector3(4.16f, 3.48f, 7.28f), new Vector3(1.12f, .79f, .47f), -90f);
            Kit(layer, "Power interlock armature on left wall", "SecurityBulkhead",
                new Vector3(-4.12f, 2.64f, 6.15f), new Vector3(2.51f, 2.64f, .28f), 90f);
            Kit(layer, "Security raceway reinforcement", "SecurityBulkhead",
                new Vector3(4.16f, 2.56f, 13.86f), new Vector3(2.35f, 2.85f, .32f), -90f);
            var gimbal = art.Find("Sensor louvers and dust/Fitted room mechanisms");
            gimbal.position = room.TransformPoint(new Vector3(4.10f, 3.28f, 9.55f));
            Practical(layer, "Warm check-station task lamp", new Vector3(-3.36f, 2.57f, 2.66f), 2.6f, 4.3f);
        }

        private static void FitSurveillance(Transform room)
        {
            var layer = ReplaceLayer(room, Layout);
            var previous = room.Find("Flow reference architectural kit");
            foreach (var mount in previous.Cast<Transform>().Where(item => item.name.StartsWith("Smoked-glass monitoring bay", StringComparison.Ordinal)))
                Hide(mount);
            var art = room.Find("Chapter room environment art");
            Hide(art.Find("Mirror room monitoring optics"));
            Hide(art.Find("Mirror room monitoring optics attenuator"));
            var geometry = room.Find("Godot surveillance architecture");
            Hide(Find(geometry, "MonitorWallScreens"));

            foreach (var z in new[] { 6.2f, 10.1f, 14.0f, 18.0f })
                Kit(layer, $"Left wall recessed monitoring bay {z:0.0}", "SurveillanceCableBay",
                    new Vector3(-13.57f, 2.04f, z), new Vector3(3.66f, 2.87f, .45f), 90f);
            foreach (var x in new[] { -8.29f, -2.78f, 2.78f, 8.29f })
                Kit(layer, $"Northern telemetry gallery {x:0.00}", "SurveillanceCableBay",
                    new Vector3(x, 5.62f, 35.34f), new Vector3(5.10f, 2.77f, .285f), 180f);

            Kit(layer, "Archive of physical tape diagnostics", "SignalConsole",
                new Vector3(-12.86f, .66f, 12.65f), new Vector3(1.75f, 1.31f, .79f), 90f);
            Kit(layer, "Command dais retained service return", "SecurityBulkhead",
                new Vector3(-3.52f, 2.85f, 21.02f), new Vector3(1.68f, 1.035f, .35f), 180f);
            var motion = art.Find("Optical blades and scratched glass");
            var scan = motion.Find("Fitted room mechanisms");
            scan.position = room.TransformPoint(new Vector3(-13.30f, 2.25f, 10.10f));
            scan.rotation = room.rotation * Quaternion.Euler(0, 90f, 0);
            Practical(layer, "Monitoring desk service lamp", new Vector3(-12.59f, 2.89f, 12f), 3.3f, 6.45f);
            Practical(layer, "Command platform neutral fill", new Vector3(3.5f, 5.45f, 17.5f), 5.4f, 10.5f);
        }

        private static void Grade(Transform content, Transform station)
        {
            RenderSettings.ambientMode = AmbientMode.Trilight;
            RenderSettings.ambientSkyColor = new Color(.50f,.48f,.443f);
            RenderSettings.ambientEquatorColor = new Color(.39f,.382f,.358f);
            RenderSettings.ambientGroundColor = new Color(.245f,.235f,.218f);
            RenderSettings.fogColor = new Color(.073f,.069f,.064f);
            var sceneRoots = content.gameObject.scene.GetRootGameObjects();
            var fill = sceneRoots.FirstOrDefault(root => root.name == "Cool overhead fill");
            if (fill)
            {
                fill.GetComponent<Light>().color = new Color(.93f,.885f,.80f);
                fill.GetComponent<Light>().intensity = .79f;
            }

            var priorityWing = station.Find("Security wing");
            var surveillance = station.Find("Surveillance and mirror");
            var theatrical = Find(surveillance, "Kinja examination theatre");
            foreach (var light in station.GetComponentsInChildren<Light>(true))
            {
                var location = station.InverseTransformPoint(light.transform.position);
                var priority = location.z < 34f || light.transform.IsChildOf(priorityWing) ||
                    light.transform.IsChildOf(surveillance) && !light.transform.IsChildOf(theatrical);
                if (!priority || light.range < 4.5f || light.color.b < light.color.r + .11f ||
                    light.name.Contains("scanner", StringComparison.OrdinalIgnoreCase)) continue;
                var intensity = light.color.maxColorComponent;
                var warmWhite = new Color(intensity,.91f*intensity,.79f*intensity);
                light.color = Color.Lerp(light.color, warmWhite, .81f);
            }
            foreach (var key in new[] { "Recovery glow", "Evidence wash" })
            {
                var root = sceneRoots.FirstOrDefault(item => item.name == key);
                if (root) root.GetComponent<Light>().color = new Color(1f,.88f,.73f);
            }

            var volume = station.Find("Station chromatic grade").GetComponent<Volume>();
            var path = Folder + "Industrial room grade.asset";
            var profile = AssetDatabase.LoadAssetAtPath<VolumeProfile>(path);
            if (!profile)
            {
                profile = ScriptableObject.CreateInstance<VolumeProfile>();
                var reference = volume.sharedProfile;
                AssetDatabase.CreateAsset(profile, path);
                foreach (var setting in reference.components)
                {
                    var copy = Object.Instantiate(setting);
                    copy.name = setting.name;
                    AssetDatabase.AddObjectToAsset(copy, profile);
                    profile.components.Add(copy);
                }
                EditorUtility.SetDirty(profile);
            }
            if (profile.TryGet<ColorAdjustments>(out var grade))
            {
                grade.saturation.Override(-3f);
                grade.contrast.Override(11f);
                grade.postExposure.Override(.14f);
                EditorUtility.SetDirty(grade);
            }
            volume.sharedProfile = profile;
        }

        private static void Practical(Transform root, string name, Vector3 at, float intensity, float range)
        {
            var light = Node(root, name, at).gameObject.AddComponent<Light>();
            light.type = LightType.Point;
            light.range = range;
            light.intensity = intensity;
            light.color = Warm;
        }

        private static void Hide(Transform root)
        {
            if (!root) return;
            foreach (var renderer in root.GetComponentsInChildren<MeshRenderer>(true))
            {
                renderer.enabled = false;
                PrefabUtility.RecordPrefabInstancePropertyModifications(renderer);
            }
        }

        private static void Kit(Transform layer, string label, string asset, Vector3 at, Vector3 size, float yaw)
        {
            StormworksConstruction.FittedProp(layer, label, "TripoChapterKit/" + asset + ".glb", at, size, yaw);
            foreach (var renderer in layer.Find(label).GetComponentsInChildren<MeshRenderer>(true))
                renderer.shadowCastingMode = ShadowCastingMode.Off;
        }

        private static Transform ReplaceLayer(Transform parent, string name)
        {
            var prior = parent.Find(name);
            if (prior) Object.DestroyImmediate(prior.gameObject);
            return Node(parent, name, Vector3.zero);
        }

        private static Material MaterialAt(string relative) =>
            AssetDatabase.LoadAssetAtPath<Material>(Stormworks + relative) ?? throw new FileNotFoundException(relative);

        private static Mesh MeshAt(string name, Func<Mesh> create)
        {
            var path = Folder + name + ".asset";
            var mesh = AssetDatabase.LoadAssetAtPath<Mesh>(path);
            if (mesh) return mesh;
            mesh = create();
            mesh.name = name;
            AssetDatabase.CreateAsset(mesh, path);
            return mesh;
        }

        private static void Render(Transform parent, string name, Mesh mesh, Material material, Vector3 at, Vector3 size)
        {
            var item = Node(parent, name, at);
            item.localScale = size;
            item.gameObject.AddComponent<MeshFilter>().sharedMesh = mesh;
            var renderer = item.gameObject.AddComponent<MeshRenderer>();
            renderer.sharedMaterial = material;
            renderer.shadowCastingMode = ShadowCastingMode.Off;
        }

        private static Mesh FanBlades()
        {
            var surface = new SurfaceMesh();
            const int spans = 12;
            const int blades = 7;
            for (var blade = 0; blade < blades; blade++)
            {
                var angle = blade * 2f * Mathf.PI / blades;
                Vector3 Point(float along, float chord, float offset)
                {
                    var radius = Mathf.Lerp(.136f, .644f, along);
                    var width = Mathf.Sin(Mathf.PI * Mathf.Lerp(.12f,.94f,along))*.45f;
                    var turn = angle + .59f * along * along + chord * width;
                    var camber = .023f*Mathf.Sin(along*Mathf.PI) - chord*.085f*(1f-.32f*along);
                    return new Vector3(Mathf.Cos(turn)*radius, Mathf.Sin(turn)*radius, camber+offset);
                }
                for (var span = 0; span < spans; span++)
                {
                    var a = span/(float)spans;
                    var b = (span+1)/(float)spans;
                    var af = Point(a,-.5f,.009f);
                    var bf = Point(b,-.5f,.009f);
                    var cf = Point(b,.5f,.009f);
                    var df = Point(a,.5f,.009f);
                    var ab = Point(a,-.5f,-.009f);
                    var bb = Point(b,-.5f,-.009f);
                    var cb = Point(b,.5f,-.009f);
                    var db = Point(a,.5f,-.009f);
                    surface.Quad(af,bf,cf,df);
                    surface.Quad(db,cb,bb,ab);
                    surface.Quad(ab,bb,bf,af);
                    surface.Quad(df,cf,cb,db);
                    if (span == 0) surface.Quad(af,df,db,ab);
                    if (span == spans-1) surface.Quad(bf,bb,cb,cf);
                }
            }
            surface.Disk(.155f, .078f, 40);
            surface.Disk(.090f, .104f, 32);
            surface.Torus(.136f, .019f, .055f, 40);
            return surface.Bake();
        }

        private static Mesh FanGuard()
        {
            var surface = new SurfaceMesh();
            foreach (var radius in new[] { .112f, .221f, .335f, .454f, .568f, .673f })
                surface.Torus(radius,.009f,0f,64);
            const int spokes = 16;
            for (var i = 0; i < spokes; i++)
            {
                var angle = 2f*Mathf.PI*i/spokes;
                var direction = new Vector3(Mathf.Cos(angle), Mathf.Sin(angle), 0f);
                surface.Rod(direction*.10f, direction*.682f, .008f);
            }
            surface.Disk(.109f, .012f, 32);
            return surface.Bake();
        }

        private static Mesh TubeRings((float radius,float thickness,float depth)[] rings, int segments)
        {
            var surface = new SurfaceMesh();
            foreach (var (radius,thickness,depth) in rings) surface.Torus(radius, thickness, depth, segments);
            return surface.Bake();
        }

        private sealed class SurfaceMesh
        {
            private readonly List<Vector3> positions = new List<Vector3>();
            private readonly List<Vector2> texels = new List<Vector2>();
            private readonly List<int> triangles = new List<int>();

            internal void Quad(Vector3 a, Vector3 b, Vector3 c, Vector3 d)
            {
                var index = positions.Count;
                positions.AddRange(new[] { a,b,c,d });
                foreach (var p in new[] { a,b,c,d })
                    texels.Add(new Vector2(p.x+.11f*p.z+.5f, p.y+.18f*p.z+.5f));
                triangles.AddRange(new[] { index,index+1,index+2,index,index+2,index+3 });
            }

            internal void Torus(float radius, float tube, float depth, int steps)
            {
                const int cross = 8;
                Vector3 Point(int along,int rim)
                {
                    var angle = 2f*Mathf.PI*along/steps;
                    var profile = 2f*Mathf.PI*rim/cross;
                    var width = radius+tube*Mathf.Cos(profile);
                    return new Vector3(Mathf.Cos(angle)*width,Mathf.Sin(angle)*width,depth+tube*Mathf.Sin(profile));
                }
                for (var i=0;i<steps;i++)
                    for (var k=0;k<cross;k++)
                        Quad(Point(i,k),Point(i+1,k),Point(i+1,k+1),Point(i,k+1));
            }

            internal void Disk(float radius, float depth, int steps)
            {
                var center = Vector3.forward*depth;
                for (var i=0;i<steps;i++)
                {
                    var a=2f*Mathf.PI*i/steps;
                    var b=2f*Mathf.PI*(i+1)/steps;
                    var index = positions.Count;
                    positions.AddRange(new[] { center, center+new Vector3(Mathf.Cos(a),Mathf.Sin(a),0f)*radius,
                        center+new Vector3(Mathf.Cos(b),Mathf.Sin(b),0f)*radius });
                    for (var k = index; k < index + 3; k++)
                        texels.Add(new Vector2(positions[k].x+.5f, positions[k].y+.5f));
                    triangles.AddRange(new[] { index,index+1,index+2 });
                }
            }

            internal void Rod(Vector3 from, Vector3 to, float radius)
            {
                var up = Vector3.Cross(to-from,Vector3.forward).normalized*radius;
                var face = Vector3.forward*radius;
                var profile = new[] { up,face,-up,-face };
                for (var i=0;i<profile.Length;i++)
                {
                    var a=profile[i];
                    var b=profile[(i+1)%profile.Length];
                    Quad(from+a,to+a,to+b,from+b);
                }
            }

            internal Mesh Bake()
            {
                var mesh=new Mesh();
                mesh.SetVertices(positions);
                mesh.SetUVs(0,texels);
                mesh.SetTriangles(triangles,0);
                mesh.RecalculateNormals();
                mesh.RecalculateTangents();
                return mesh;
            }
        }
    }
}
