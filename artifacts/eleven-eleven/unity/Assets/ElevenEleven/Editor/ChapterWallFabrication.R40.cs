using System;
using System.IO;
using System.Linq;
using System.Reflection;
using ElevenEleven.Opening;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using static ElevenEleven.Editor.GodotRoomAssembly;
using Object = UnityEngine.Object;

namespace ElevenEleven.Editor
{
    internal static partial class ChapterWallFabrication
    {
        private const string AssemblyFinish = "R40 fitted architectural finish";
        private static readonly Color TaskLight = new Color(1f, .83f, .64f);

        [MenuItem("11.11/Fit Station Architectural Details")]
        public static void FitStationDetails()
        {
            if (!Application.isBatchMode && !EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo()) return;
            var scene = EditorSceneManager.OpenScene(ScenePath);
            var content = scene.GetRootGameObjects().Single(root => root.name == "Room content").transform;
            var station = content.Find("Echo Station");
            var route = station.GetComponent<StormworksRoute>() ?? content.GetComponentInChildren<StormworksRoute>(true);
            var authority = content.GetComponentsInChildren<Collider>(true)
                .ToDictionary(collider => collider, collider => EditorJsonUtility.ToJson(collider));
            var routeBefore = EditorJsonUtility.ToJson(route);
            var finish = new StationFinish(route);
            var windows = finish.Surveillance(station.Find("Surveillance and mirror"));
            var security = finish.Security(station.Find("Security wing"));
            finish.Pressure(station);
            var specimen = finish.Specimens(station.Find("Specimen containment"));
            var archive = finish.Archive(station.Find("Memory archive wing"));
            finish.Reactor(station.Find("Reserve reactor wing"));
            var quarantine = finish.Quarantine(station.Find("Decontamination and quarantine"));
            var cueCount = station.GetComponentsInChildren<RoomSystemCue>(true).Length;

            var after = content.GetComponentsInChildren<Collider>(true);
            if (after.Length != authority.Count || after.Any(c => !authority.TryGetValue(c, out var state) ||
                state != EditorJsonUtility.ToJson(c)) || routeBefore != EditorJsonUtility.ToJson(route))
                throw new InvalidDataException("Architectural work changed the station route or collision.");
            if (windows != 16 || security == 0 || specimen != 6 || archive != 6 || quarantine != 6 || cueCount != 5)
                throw new InvalidDataException($"Unexpected finish coverage: {windows}/{security}/{specimen}/{archive}/{quarantine}/{cueCount}");
            AssetDatabase.SaveAssets();
            if (!EditorSceneManager.SaveScene(scene)) throw new IOException("Could not save the R40 station finish.");
            Debug.Log($"ECHO_R40_STATION_SAVED glazed_panes={windows} security_finishes={security} specimen_bays={specimen} archive_racks={archive} quarantine_pods={quarantine} live_cues={cueCount} colliders={after.Length}");
        }

        public static void RefineSpecimenDeck()
        {
            var scene = EditorSceneManager.OpenScene(ScenePath);
            var content = scene.GetRootGameObjects().Single(root => root.name == "Room content").transform;
            var room = content.Find("Echo Station/Specimen containment");
            var collision = content.GetComponentsInChildren<Collider>(true).ToDictionary(c => c, c => EditorJsonUtility.ToJson(c));
            var deck = new DeckPlates();
            var bays = new[] {(-29.94f,-22.31f), (-21.895f,-15.05f), (-15.02f,-8.21f), (-7.795f,-.06f)};
            var seams = new[] {-5.94f,-1.65f,2.1f,5.05f,8.1f,12.5f,17.94f};
            var count = 0;
            foreach (var (left, right) in bays)
            for (var i = 0; i + 1 < seams.Length; i++)
            {
                deck.Slab(left+.012f, right-.012f, seams[i]+.014f, seams[i+1]-.014f, i is 2 or 3 ? 1 : 0);
                ++count;
            }
            foreach (var width in new[] {-22.106f,-8.006f})
                deck.Drain(width,-5.92f,17.9f);

            const string name = "Specimen recessed service deck";
            var mesh = AssetDatabase.LoadAssetAtPath<Mesh>(Folder+name+".asset");
            var draft = deck.Build(name);
            if (!mesh)
            {
                mesh = draft;
                AssetDatabase.CreateAsset(mesh,Folder+name+".asset");
            }
            else
            {
                EditorUtility.CopySerialized(draft,mesh);
                Object.DestroyImmediate(draft);
                EditorUtility.SetDirty(mesh);
            }
            var before = room.Find("Containment architectural cassettes").GetComponentsInChildren<MeshRenderer>(true)
                .Where(renderer => renderer.name == "Sealed floor cassette").ToArray();
            foreach (var cassette in before) cassette.enabled = false;

            var layer = ResetNamed(room, "Coherent specimen service deck");
            var node = Node(layer, "Recessed cassette plate faces and open grates", Vector3.up * .008f);
            node.gameObject.AddComponent<MeshFilter>().sharedMesh = mesh;
            node.gameObject.AddComponent<MeshRenderer>().sharedMaterials = new[]
                {
                    "Surveillance aggregate grip steel", "Surveillance worn graphite slabs",
                    "Surveillance recessed drain well", "Surveillance polished slab bevel",
                    "Surveillance countersunk hardware", "Surveillance grate and screw heads"
                }.Select(material => AssetDatabase.LoadAssetAtPath<Material>(Folder+material+".mat")).ToArray();
            var finish = room.Find(AssemblyFinish);
            var dark = AssetDatabase.LoadAssetAtPath<Material>(Folder+"Station carbonized structural metal.mat");
            var checkpoint = content.Find("Echo Station/Security wing/Native Godot security geometry");
            var coverEdges = checkpoint.GetComponentsInChildren<MeshRenderer>(true).Where(renderer =>
            {
                var size = renderer.bounds.size;
                return renderer.enabled && Mathf.Abs(size.x-1.48f)<.025f && Mathf.Abs(size.z-1.03f)<.025f &&
                       Mathf.Abs(size.y-.025f)<.008f;
            }).ToArray();
            foreach (var edge in coverEdges)
            {
                edge.sharedMaterial = dark;
                PrefabUtility.RecordPrefabInstancePropertyModifications(edge);
            }
            if (coverEdges.Length != 6) throw new InvalidDataException("Could not identify all six measured checkpoint cover plates.");
            var rings = new[] { "Specimen servicing deck edge", "Specimen service footer" };
            foreach (var trim in finish.Cast<Transform>().Where(trim => rings.Contains(trim.name)))
            {
                var position = trim.localPosition;
                position.y = trim.name == "Specimen servicing deck edge" ? .015f : .022f;
                trim.localPosition = position;
                trim.GetComponent<MeshRenderer>().sharedMaterial = dark;
            }
            var after = content.GetComponentsInChildren<Collider>(true);
            if (after.Length != collision.Count ||
                after.Any(collider => !collision.TryGetValue(collider, out var original) || original != EditorJsonUtility.ToJson(collider)))
                throw new InvalidDataException("Specimen visual deck changed collision authority.");
            AssetDatabase.SaveAssets();
            if (!EditorSceneManager.SaveScene(scene)) throw new IOException("Could not save the specimen deck.");
            Debug.Log($"ECHO_R40_DECK_SAVED plates={count} superseded_cassettes={before.Length} drains=2 security_cover_plates={coverEdges.Length} colliders={after.Length}");
        }

        public static void FinishPressureValve()
        {
            var scene = EditorSceneManager.OpenScene(ScenePath);
            var content = scene.GetRootGameObjects().Single(root => root.name == "Room content").transform;
            var station = content.Find("Echo Station");
            var collision = content.GetComponentsInChildren<Collider>(true).ToDictionary(c => c, c => EditorJsonUtility.ToJson(c));
            var route = content.GetComponentInChildren<StormworksRoute>(true);
            var routeBefore = EditorJsonUtility.ToJson(route);
            var body = station.Find("Valve face");
            body.GetComponent<MeshRenderer>().enabled = false;
            new StationFinish(route).FinishValveBody(station.Find(AssemblyFinish),body.localPosition);
            var after = content.GetComponentsInChildren<Collider>(true);
            if (after.Length != collision.Count || routeBefore != EditorJsonUtility.ToJson(route) ||
                after.Any(collider => !collision.TryGetValue(collider,out var original) || original != EditorJsonUtility.ToJson(collider)))
                throw new InvalidDataException("The visual gland block changed the pressure interaction.");
            AssetDatabase.SaveAssets();
            if (!EditorSceneManager.SaveScene(scene)) throw new IOException("Could not save the valve finish.");
            Debug.Log($"ECHO_R40_VALVE_SAVED colliders={after.Length} interaction=unchanged");
        }

        private sealed partial class StationFinish
        {
            private readonly StormworksRoute route;
            private readonly Mesh cube;
            private readonly Mesh cylinder;
            private readonly Mesh face;
            private readonly Material alloy;
            private readonly Material dark;
            private readonly Material saddle;
            private readonly Material fired;
            private readonly Material glazing;
            private readonly Material lens;
            private readonly Material taskLens;

            internal StationFinish(StormworksRoute route)
            {
                this.route = route;
                cube = PrimitiveMesh(PrimitiveType.Cube);
                cylinder = PrimitiveMesh(PrimitiveType.Cylinder);
                var steel = AssetDatabase.LoadAssetAtPath<Material>(Art + "StationFinishes/Chronostat oxide-filled steel.mat");
                alloy = FinishAt(steel, "Station worked manganese alloy", new Color(.56f,.515f,.441f), .58f);
                dark = FinishAt(steel, "Station carbonized structural metal", new Color(.28f,.255f,.216f), .31f);
                saddle = FinishAt(steel, "Station matte isolation ceramic", new Color(.61f,.551f,.466f), .37f);
                fired = FinishAt(steel, "Station annealed copper fixings", new Color(.61f,.387f,.225f), .56f);
                glazing = Emitter("Station smoked optical laminate", new Color(.124f,.170f,.161f), .075f);
                glazing.SetFloat("_Metallic", .49f);
                glazing.SetFloat("_Smoothness", .87f);
                lens = Emitter("Station actionable state lens", new Color(1f,.32f,.105f), 2.1f);
                taskLens = Emitter("Station recessed work light", TaskLight, 1.15f);
                const string profile = Folder + "Station chamfered face insert.asset";
                face = AssetDatabase.LoadAssetAtPath<Mesh>(profile);
                if (face) return;
                var plates = new Plates(1);
                plates.Raised(0f, 0f, 1f, 1f, .077f, .012f, .008f, 0);
                face = plates.Build("Station chamfered face insert");
                AssetDatabase.CreateAsset(face, profile);
            }

            internal int Surveillance(Transform room)
            {
                var layer = ResetNamed(room, AssemblyFinish);
                var native = room.Find("Godot surveillance architecture/mirror_chamber_room");
                var dais = ExactRenderer(native.Find("CommandDaisDeck"));
                Set(dais, dark);
                foreach (var z in new[] {13.982f, 22.018f})
                {
                    Part(layer, "Channel beam at dais edge", new Vector3(0f,2.245f,z), new Vector3(8.01f,.235f,.068f), dark);
                    foreach (var y in new[] {2.155f, 2.344f})
                        Part(layer, "Continuous dais flange", new Vector3(0f,y,z), new Vector3(8.06f,.046f,.122f), alloy);
                    foreach (var x in new[] {-3.65f, -2.2f, -.75f, .75f, 2.2f, 3.65f})
                        Part(layer, "Flanged web fixing", new Vector3(x,2.25f,z + (z < 18f ? -.037f : .037f)),
                            new Vector3(.132f,.17f,.040f), fired);
                }
                foreach (var z in new[] {14.8f, 17.7f, 20.72f})
                    Part(layer, "Dais underside transverse stiffener", new Vector3(0f,2.099f,z), new Vector3(7.90f,.07f,.31f), dark);
                var facePlate = native.Find("MasterSecurityTerminal/_MeshInstance3D_610").GetComponent<MeshRenderer>();
                facePlate.enabled = false;
                Insert(layer,"Command terminal folded pedestal cover",new Vector3(0f,3.14f,17.509f),
                    Vector3.back,.89f,.570f,dark);
                Insert(layer,"Recessed terminal access hatch",new Vector3(0f,3.114f,17.488f),
                    Vector3.back,.65f,.19f,alloy);
                foreach (var x in new[] {-.349f,.349f})
                    Part(layer,"Terminal enclosure gasket",new Vector3(x,3.137f,17.48f),new Vector3(.019f,.406f,.022f),fired);
                Cue(layer,"Surveillance discharge authorization",new Vector3(0f,3.329f,17.412f),
                    new Vector3(.30f,.104f,.115f),RoomSystemCue.SystemChannel.Surveillance,false);
                foreach (var side in new[] {-1f, 1f})
                {
                    var support = ExactRenderer(native.Find(side < 0 ? "WestStairSupport" : "EastStairSupport"));
                    Set(support, dark);
                    Strut(layer, "Reinforced stair stringer", new Vector3(side*7.70f,.156f,15.46f),
                        new Vector3(side*4.30f,2.17f,15.46f), .155f,.124f,alloy);
                    Strut(layer, "Stair upper sealing lip", new Vector3(side*7.71f,.206f,15.43f),
                        new Vector3(side*4.40f,2.178f,15.43f), .045f,.092f,fired);
                    foreach (var t in new[] {.38f,.63f,.85f})
                    {
                        var x = side*Mathf.Lerp(7.70f,4.30f,t);
                        var height = Mathf.Lerp(.156f,2.17f,t) - .13f;
                        Part(layer,"Stair stringer attachment plate",new Vector3(x,height*.50f+.045f,15.48f),
                            new Vector3(.185f,height,.064f),dark);
                    }
                    foreach (var part in native.Cast<Transform>().Where(part =>
                                 part.name.StartsWith(side < 0 ? "WestStair_" : "EastStair_", StringComparison.Ordinal)))
                    {
                        var bound = ExactRenderer(part).bounds;
                        var center = room.InverseTransformPoint(bound.center);
                        Part(layer, "Recessed stair riser", center + new Vector3(side * (bound.extents.x + .001f),-.025f,0f),
                            new Vector3(.014f,.109f,bound.size.z*.925f), dark);
                    }
                }

                foreach (Transform socket in room.Find("Surveillance scanner gallery"))
                {
                    if (socket.name != "Scanner socket anchored to deck") continue;
                    foreach (Transform part in socket)
                        if (part.name is "Bolted scanner foot" or "Bushed upright" or "Ceramic isolation collar" or "Hooded high-voltage socket")
                            part.GetComponent<MeshRenderer>().enabled = false;
                    var cast = ResetNamed(socket, "Machined discharge housing");
                    Ring(cast, "Welded anchor shoe", new Vector3(0f,.027f,0f), .147f, .046f, dark);
                    Ring(cast, "Captive anchor collar", new Vector3(0f,.072f,0f), .109f, .055f, alloy);
                    Ring(cast, "Protected feed tube", new Vector3(0f,.576f,0f), .061f, 1.04f, dark);
                    foreach (var y in new[] {.24f,.61f,.985f,1.037f})
                        Ring(cast, "Compression or isolation ferrule", new Vector3(0f,y,0f), .079f, .037f, y > .9f ? saddle : alloy);
                    var inward = socket.localPosition.x < 0f ? Vector3.right : Vector3.left;
                    var head = Node(cast, "Recessed electrical socket", new Vector3(0f,1.20f,0f));
                    head.localRotation = Quaternion.LookRotation(inward);
                    var body = Node(head, "Machined throat", Vector3.back*.003f);
                    body.localRotation = Quaternion.Euler(90f,0f,0f);
                    Ring(body, "Shielded throat", Vector3.zero, .086f, .146f, dark);
                    Ring(body, "Copper retaining collar", Vector3.down*.067f, .074f, .024f, fired);
                    foreach (var z in new[] {-.077f, .077f})
                    foreach (var x in new[] {-.077f, .077f})
                        Ring(cast, "Captive floor bolt", new Vector3(x,.054f,z), .012f, .012f, alloy);
                }

                var fitter = room.Find("Flow R37 fitted architecture");
                var panes = 0;
                foreach (var source in fitter.GetComponentsInChildren<MeshRenderer>()
                             .Where(item => item.enabled && item.name == "SurveillanceCableBay"))
                {
                    var bounds = source.bounds;
                    var center = room.InverseTransformPoint(bounds.center);
                    var outward = center.x < -12f ? Vector3.right : Vector3.back;
                    var across = Vector3.Cross(Vector3.up, outward);
                    var width = Mathf.Abs(across.x)*bounds.size.x + Mathf.Abs(across.z)*bounds.size.z;
                    foreach (var (height, span, tall, shift) in new[] {(.159f,.633f,.213f,.018f), (-.133f,.671f,.174f,.006f)})
                    {
                        var spot = bounds.center + Vector3.up * (height * bounds.size.y) + across*(shift*width);
                        var measured = OpticalDepth(source, spot, outward, across, span * width, tall * bounds.size.y);
                        var panelPosition = room.InverseTransformPoint(spot + outward * measured);
                        Insert(layer, "Recessed planar surveillance glazing", panelPosition, outward,
                            span * width, tall * bounds.size.y, glazing);
                        panes++;
                    }
                }
                GrazingKey(layer, "Dais reflected copper edge light", new Vector3(4.8f,5.73f,11.6f), new Vector3(-1.5f,2.21f,14f),
                    new Color(1f,.77f,.53f), 12f,10f);
                return panes;
            }

            internal int Security(Transform room)
            {
                var layer = ResetNamed(room, AssemblyFinish);
                var native = room.Find("Native Godot security geometry");
                var edge = native.Find("CoverEdge");
                var changed = 0;
                foreach (var renderer in native.GetComponentsInChildren<MeshRenderer>(true).Where(renderer => renderer.enabled))
                {
                    var slots = renderer.sharedMaterials;
                    var hit = slots.Any(slot => slot == alloy || slot == dark);
                    for (var i = 0; i < slots.Length; i++)
                    {
                        if (!slots[i] || slots[i].name is not
                            ("Material_34" or "Material_50" or "Material_51" or "Material_52" or "Material_54" or "Material_60")) continue;
                        slots[i] = i == 0 && slots[i].name is not ("Material_34" or "Material_54") ? alloy : dark;
                        hit = true;
                    }
                    if (!hit) continue;
                    renderer.sharedMaterials = slots;
                    PrefabUtility.RecordPrefabInstancePropertyModifications(renderer);
                    changed++;
                }
                var cover = ExactRenderer(edge).bounds;
                var at = room.InverseTransformPoint(cover.center);
                foreach (var side in new[] {-1f, 1f})
                {
                    var x = at.x + side * (cover.extents.x - .081f);
                    Part(layer, "Checkpoint bench load rail", new Vector3(x,at.y-.014f,at.z),
                        new Vector3(.075f,.047f,cover.size.z*.95f), dark);
                    foreach (var z in new[] {at.z - .365f, at.z + .365f})
                        Ring(layer, "Bench captive fixing", new Vector3(x,at.y+.015f,z), .018f,.012f, fired);
                }
                foreach (var x in new[] {-1.03f, 1.03f})
                    Insert(layer, "Security pier shock guard", new Vector3(x,1.13f,16.245f), Vector3.back,.30f,1.84f,dark);
                return changed;
            }

            internal void Pressure(Transform station)
            {
                var layer = ResetNamed(station, AssemblyFinish);
                var apron = station.Find("Receiving apron").GetComponent<MeshRenderer>();
                var front = station.InverseTransformPoint(apron.bounds.center).z - apron.bounds.extents.z;
                var top = apron.bounds.max.y - station.position.y;
                Part(layer, "Apron expansion joint socket", new Vector3(0f,top+.003f,front+.14f),
                    new Vector3(7.05f,.023f,.39f),dark);
                for (var i = -4; i <= 4; i++)
                {
                    var x = i * .76f;
                    Part(layer,"Rebated threshold shoe",new Vector3(x,top+.020f,front+.14f),new Vector3(.727f,.020f,.274f),alloy);
                    Ring(layer,"Threshold flush pin",new Vector3(x,top+.032f,front+.079f),.027f,.012f,dark);
                    Ring(layer,"Threshold flush pin",new Vector3(x,top+.032f,front+.205f),.027f,.012f,dark);
                }
                foreach (var x in new[] {-3.28f,3.28f})
                {
                    Part(layer,"Threshold structural return",new Vector3(x,.13f,front+.27f),new Vector3(.31f,.25f,.69f),dark);
                    Part(layer,"Recessed receiving sill reference",new Vector3(x,.223f,front-.067f),new Vector3(.14f,.045f,.018f),taskLens);
                }
                Cue(layer, "Pressure vent state", new Vector3(-2.16f,1.39f,24.65f), new Vector3(.47f,.64f,.14f),
                    RoomSystemCue.SystemChannel.Pressure, true);
            }

            internal void FinishValveBody(Transform layer, Vector3 origin)
            {
                var block = ResetNamed(layer,"Machined pressure valve gland");
                block.localPosition = origin;
                var turned = Node(block,"Pressure cast-body axis",Vector3.zero);
                turned.localRotation = Quaternion.Euler(90f,0f,0f);
                Ring(turned,"Cast valve body",Vector3.zero,.298f,.163f,dark);
                Ring(turned,"Exposed flange",Vector3.down*.088f,.281f,.041f,alloy);
                Ring(turned,"Recessed shaft seat",Vector3.down*.110f,.142f,.038f,dark);
                Ring(turned,"Bronze seal gland",Vector3.down*.137f,.096f,.051f,fired);
                for (var i=0;i<6;i++)
                {
                    var phase = i*2f*Mathf.PI/6f;
                    Ring(turned,"Blind flange fixing",new Vector3(Mathf.Cos(phase)*.221f,-.118f,Mathf.Sin(phase)*.221f),
                        .024f,.028f,fired);
                }
            }

            internal int Specimens(Transform room)
            {
                var layer = ResetNamed(room, AssemblyFinish);
                var floor = ExactRenderer(room.Find("Native Godot specimen geometry/Floor"));
                var template = AssetDatabase.LoadAssetAtPath<Material>(Folder+"Surveillance aggregate grip steel.mat");
                Set(floor, template);
                var centerDeck = AssetDatabase.LoadAssetAtPath<Material>(Folder+"Surveillance worn graphite slabs.mat");
                var cassettes = room.Find("Containment architectural cassettes").GetComponentsInChildren<MeshRenderer>(true)
                    .Where(renderer => renderer.name == "Sealed floor cassette").ToArray();
                foreach (var cassette in cassettes)
                {
                    var materials = cassette.sharedMaterials;
                    var z = room.InverseTransformPoint(cassette.bounds.center).z;
                    materials[0] = z is >1.5f and <10.5f ? centerDeck : template;
                    cassette.sharedMaterials = materials;
                }
                if (cassettes.Length < 30) throw new InvalidDataException("The raised specimen cassettes were not found.");
                var bays = room.Find("Station wing finish").Cast<Transform>()
                    .Where(child => child.name == "Specimen vessel restraints").ToArray();
                foreach (var bay in bays)
                {
                    var at = room.InverseTransformPoint(bay.position);
                    var south = at.z < 6f;
                    var facing = south ? 1f : -1f;
                    foreach (var x in new[] {-1.27f,1.27f})
                        Part(layer,"Specimen servicing deck edge",at+new Vector3(x,.049f, facing*.25f),
                            new Vector3(.067f,.023f,2.71f),alloy);
                    Part(layer,"Specimen service footer",at+new Vector3(0f,.056f,facing*1.58f),
                        new Vector3(2.49f,.035f,.21f),south ? dark : alloy);
                    var stamp = Node(layer,"Recessed vessel service connection",at+new Vector3(0f,.18f, facing*1.21f));
                    Part(stamp,"Service collar",Vector3.zero,new Vector3(.45f,.21f,.18f),dark);
                    Part(stamp,"Machined connector face",Vector3.forward*facing*.102f,new Vector3(.29f,.074f,.021f),fired);
                }
                GrazingKey(layer,"Specimen wall near safety lane",new Vector3(-14f,5.73f,7.8f),
                    new Vector3(-16.4f,.81f,12.3f),TaskLight,13f,12f);
                return bays.Length;
            }

            internal int Archive(Transform room)
            {
                var layer = ResetNamed(room, AssemblyFinish);
                var racks = room.Find("Native Godot archive geometry").Cast<Transform>()
                    .Where(item => (item.name.StartsWith("NorthRack_", StringComparison.Ordinal) ||
                                   item.name.StartsWith("SouthRack_", StringComparison.Ordinal)) &&
                                   item.name.Count(ch => ch == '_') == 1).ToArray();
                foreach (var rack in racks)
                {
                    var at = room.InverseTransformPoint(ExactRenderer(rack).bounds.center);
                    var facing = at.z > 0f ? -1f : 1f;
                    var nose = at.z + facing*.925f;
                    foreach (var x in new[] {at.x-1.03f,at.x+1.03f})
                        Part(layer,"Archive rack load-bearing flange",new Vector3(x,2.13f,nose),
                            new Vector3(.11f,3.95f,.081f),alloy);
                    Part(layer,"Hooded rack service lamp",new Vector3(at.x,3.91f,nose+facing*.091f),
                        new Vector3(1.75f,.16f,.24f),dark);
                    Part(layer,"Shielded archive lighting lens",new Vector3(at.x,3.819f,nose+facing*.098f),
                        new Vector3(1.29f,.038f,.11f),taskLens);
                    GrazingKey(layer, "Rack face graze", new Vector3(at.x,3.79f,nose+facing*.23f),
                        new Vector3(at.x,1.21f,nose), new Color(1f,.86f,.73f), 6.5f,4.6f);
                }
                GrazingKey(layer,"Archive entry crosslight between indexing racks",new Vector3(-4.80f,5.21f,-1.4f),
                    new Vector3(-8.6f,1.5f,-5.5f),new Color(1f,.84f,.69f),13f,10f);
                return racks.Length;
            }

            internal void Reactor(Transform room)
            {
                var layer = ResetNamed(room, AssemblyFinish);
                Cue(layer,"West breaker's bus state",new Vector3(-12.47f,-.32f,15.57f),new Vector3(.34f,.32f,.12f),
                    RoomSystemCue.SystemChannel.WestBreaker,false);
                Cue(layer,"East breaker's bus state",new Vector3(12.53f,-.32f,27.57f),new Vector3(.34f,.32f,.12f),
                    RoomSystemCue.SystemChannel.EastBreaker,false);
                foreach (var x in new[] {-11.21f, 11.21f})
                    Part(layer,"Lower coolant sleeve bracket",new Vector3(x,-.61f,x < 0f ? 16f : 28f),
                        new Vector3(.49f,.087f,.56f),alloy);
            }

            internal int Quarantine(Transform room)
            {
                var layer = ResetNamed(room, AssemblyFinish);
                var podRoot = room.Find("Godot quarantine architecture/DeconTripoArchitecture/PrecisionSurfaceRefinement");
                var pods = podRoot.Cast<Transform>()
                    .Where(item => item.name.StartsWith("QuarantinePod_", StringComparison.Ordinal) &&
                                   item.name.EndsWith("PreciseVessel", StringComparison.Ordinal)).ToArray();
                foreach (var pod in pods)
                {
                    var at = room.InverseTransformPoint(ExactRenderer(pod).bounds.center);
                    var direction = at.x < 0f ? Vector3.right : Vector3.left;
                    var bracket = Node(layer,"Quarantine vessel service saddle",new Vector3(at.x,1.36f,at.z)+direction*1.252f);
                    bracket.localRotation = Quaternion.LookRotation(direction);
                    Insert(bracket,"Gasketed pod access cover",Vector3.zero,Vector3.forward,.61f,1.38f,dark);
                    Insert(bracket,"Pod material data plate",new Vector3(0f,.18f,.044f),Vector3.forward,.49f,.62f,saddle);
                    foreach (var x in new[] {-.215f,.215f})
                    foreach (var y in new[] {-.52f,.52f})
                    {
                        var bolt = Node(bracket,"Retention bolt seat",new Vector3(x,y,.05f));
                        bolt.localRotation = Quaternion.Euler(90f,0f,0f);
                        Ring(bolt,"Retention bolt",Vector3.zero,.026f,.024f,alloy);
                    }
                    Part(bracket,"Vessel relief socket",new Vector3(0f,-.047f,.061f),new Vector3(.29f,.093f,.071f),fired);
                }
                Cue(layer,"Quarantine extraction state",new Vector3(-.3f,4.08f,15.38f),new Vector3(.35f,.29f,.11f),
                    RoomSystemCue.SystemChannel.Quarantine,false);
                Part(layer,"Quarantine catwalk cable enclosure",new Vector3(0f,2.68f,13.84f),new Vector3(6.3f,.19f,.29f),dark);
                return pods.Length;
            }

            private void Cue(Transform parent, string label, Vector3 at, Vector3 size, RoomSystemCue.SystemChannel channel, bool timer)
            {
                var dock = Node(parent, label, at);
                Part(dock, "Panel housing", Vector3.zero, size, dark);
                var window = Node(dock, "Status lens", new Vector3(timer ? -.092f : 0f, .025f, -size.z*.5f-.021f));
                Add(window, "Coated status glass", cube, lens, Vector3.zero,
                    new Vector3(timer ? .135f : size.x*.61f,size.y*.39f,.019f));
                var actualLens = window.GetComponentInChildren<MeshRenderer>();
                Transform meter = null;
                if (timer)
                {
                    Part(dock,"Vent gauge recess",new Vector3(.105f,0f,-size.z*.5f-.013f),new Vector3(.074f,.465f,.019f),alloy);
                    Add(dock,"Vent time lens",cube,taskLens,new Vector3(.105f,0f,-size.z*.5f-.026f),new Vector3(.043f,.427f,.009f));
                    meter = dock.Find("Vent time lens");
                }
                var light = Node(dock,"State reflection",new Vector3(0f,0f,-size.z*.5f-.14f)).gameObject.AddComponent<Light>();
                light.type = LightType.Point;
                light.range = 2.4f;
                light.color = new Color(1f,.32f,.105f);
                light.intensity = 1.65f;
                var cue = dock.gameObject.AddComponent<RoomSystemCue>();
                StormworksConstruction.Wire(cue, ("route",route), ("lens",actualLens), ("spill",light), ("ventMeter",meter));
                using var binding = new SerializedObject(cue);
                binding.FindProperty("channel").enumValueIndex = (int)channel;
                binding.ApplyModifiedPropertiesWithoutUndo();
            }

            private static MeshRenderer ExactRenderer(Transform node) => node.GetComponentsInChildren<MeshRenderer>(true)
                .First(renderer => renderer.enabled && renderer.GetComponent<MeshFilter>()?.sharedMesh);

            private static void Set(MeshRenderer renderer, Material material)
            {
                renderer.sharedMaterial = material;
                PrefabUtility.RecordPrefabInstancePropertyModifications(renderer);
            }

            private static Mesh PrimitiveMesh(PrimitiveType type)
            {
                var temporary = GameObject.CreatePrimitive(type);
                var result = temporary.GetComponent<MeshFilter>().sharedMesh;
                Object.DestroyImmediate(temporary);
                return result;
            }

            private void Part(Transform parent, string label, Vector3 position, Vector3 scale, Material material) =>
                Add(parent,label,cube,material,position,scale);

            private void Strut(Transform parent, string label, Vector3 foot, Vector3 head, float height, float depth, Material material)
            {
                var part = Node(parent,label,(foot+head)*.5f);
                part.localRotation = Quaternion.FromToRotation(Vector3.right, (head-foot).normalized);
                Part(part,"Structural section",Vector3.zero,new Vector3(Vector3.Distance(foot,head),height,depth),material);
            }

            private void Ring(Transform parent, string label, Vector3 at, float radius, float height, Material material) =>
                Add(parent,label,cylinder,material,at,new Vector3(radius*2f,height*.5f,radius*2f));

            private void Insert(Transform parent, string label, Vector3 local, Vector3 norm, float width, float height, Material material)
            {
                var unit = Node(parent,label,local);
                unit.localRotation = Quaternion.LookRotation(norm, Vector3.up);
                unit.localScale = new Vector3(width,height,1f);
                unit.gameObject.AddComponent<MeshFilter>().sharedMesh = face;
                unit.gameObject.AddComponent<MeshRenderer>().sharedMaterial = material;
            }

            private static float OpticalDepth(MeshRenderer renderer, Vector3 pivot, Vector3 outward, Vector3 across, float width, float height)
            {
                var intersect = typeof(HandleUtility).GetMethod("IntersectRayMesh", BindingFlags.Static | BindingFlags.Public | BindingFlags.NonPublic,
                    null, new[] { typeof(Ray), typeof(Mesh), typeof(Matrix4x4), typeof(RaycastHit).MakeByRefType() }, null)
                    ?? throw new MissingMethodException("HandleUtility.IntersectRayMesh");
                var depths = new System.Collections.Generic.List<float>();
                var mesh = renderer.GetComponent<MeshFilter>().sharedMesh;
                foreach (var x in new[] {-.4f,-.28f,-.13f,0f,.13f,.28f,.4f})
                foreach (var y in new[] {-.34f, -.18f, 0f, .18f, .34f})
                {
                    var origin = pivot + across*(width*x) + Vector3.up*(height*y) + outward*1.2f;
                    object[] data = {new Ray(origin,-outward), mesh, renderer.transform.localToWorldMatrix, default(RaycastHit)};
                    if ((bool)intersect.Invoke(null,data) && data[3] is RaycastHit hit) depths.Add(1.2f-hit.distance);
                }
                if (depths.Count < 20) throw new InvalidDataException($"Could not fit optical insert in {renderer.name}.");
                depths.Sort();
                return depths[depths.Count * 3 / 4] + .008f;
            }
        }
    }
}
