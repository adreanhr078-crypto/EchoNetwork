using System;
using System.Collections.Generic;
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
    internal static class MemoryObservatoryArt
    {
        private const string Scene = "Assets/ElevenEleven/Scenes/ChapterRoom01.unity";
        private const string Opening = "Assets/ElevenEleven/Opening/";
        internal const string Folder = Opening + "Stormworks/Observatory/";
        private const string ArtRoot = "Memory Observatory";
        private static readonly string[] Names = { "observatory-cliff", "observatory-archive-jamb",
            "observatory-broken-astrolabe", "observatory-rotor", "observatory-memory-fragment" };

        internal static bool Ready => Names.All(name => AssetDatabase.LoadAssetAtPath<GameObject>(Folder + name + ".glb") != null);

        [MenuItem("11.11/Build Memory Observatory")]
        public static void Upgrade()
        {
            if (!Application.isBatchMode && !EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo()) return;
            if (!Ready) throw new InvalidOperationException("The five qualified Observatory GLBs are required.");
            var scene = EditorSceneManager.OpenScene(Scene);
            var station = scene.GetRootGameObjects().Single(item => item.name == "Room content").transform.Find("Echo Station");
            Dress(station);
            if (!EditorSceneManager.SaveScene(scene)) throw new InvalidOperationException("Could not save Memory Observatory.");
            Debug.Log("ECHO_MEMORY_OBSERVATORY_SAVED");
        }

        public static void UpgradeAndReview()
        {
            Upgrade();
            StormworksSmoke.Run();
        }

        public static void WarmAndReview()
        {
            WarmShaders();
            StormworksSmoke.Run();
        }

        public static void UpgradeEntrancesAndReview()
        {
            WarmShaders();
            Upgrade();
            StormworksSmoke.Run();
        }

        internal static void WarmShaders()
        {
            EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            EditorUtility.UnloadUnusedAssetsImmediate();
            const string fog = "FOG_EXP2";
            var previousFog = Shader.IsKeywordEnabled(fog);
            Shader.EnableKeyword(fog);
            try
            {
                foreach (var name in new[] { "Station Reservoir", "Station Atmosphere", "Memory Inside Fracture", "Observatory Clock Digits" })
                {
                    var shader = Shader.Find("ElevenEleven/" + name);
                    if (shader == null) throw new InvalidOperationException("Missing observatory shader " + name);
                    var material = new Material(shader);
                    try
                    {
                        ShaderUtil.CompilePass(material,0,true);
                        if (ShaderUtil.ShaderHasError(shader))
                            throw new InvalidOperationException("Could not compile observatory shader " + name);
                        Debug.Log("ECHO_OBSERVATORY_SHADER_READY " + name);
                    }
                    finally
                    {
                        Object.DestroyImmediate(material);
                    }
                }
            }
            finally
            {
                if (!previousFog) Shader.DisableKeyword(fog);
            }
        }

        internal static void Dress(Transform station)
        {
            var prior = station.Find(ArtRoot);
            if (prior != null) Object.DestroyImmediate(prior.gameObject);
            var art = Node(station, ArtRoot, Vector3.zero);
            var sources = Names.Select(name => AssetDatabase.LoadAssetAtPath<GameObject>(Folder + name + ".glb")).ToArray();
            RemoveOldSilhouette(station);

            var sky = GameObject.CreatePrimitive(PrimitiveType.Sphere);
            sky.name = "Deep star field";
            sky.transform.SetParent(art, false);
            sky.transform.localPosition = new Vector3(0f, 5.5f, 58f);
            sky.transform.localScale = Vector3.one * 148f;
            Object.DestroyImmediate(sky.GetComponent<Collider>());
            var stars = sky.GetComponent<Renderer>();
            stars.sharedMaterial = GetMaterial("Observatory star aperture", "ElevenEleven/Observatory Stars");
            stars.shadowCastingMode = ShadowCastingMode.Off;
            stars.receiveShadows = false;
            stars.enabled = false;

            DressRift(art);
            Place(art, sources[0], "West bedrock reinforcement", new Vector3(-21.7f,-5.2f,59f), 18.5f, 10.3f, 14f);
            Place(art, sources[0], "East bedrock reinforcement", new Vector3(25.0f,-6f,71.5f), 17.5f, 11.5f, -44f);
            Place(art, sources[0], "Distant stepped pier west", new Vector3(-18.9f,-5.5f,89.0f), 17.4f, 13.2f, 176f);
            Place(art, sources[0], "Distant stepped pier east", new Vector3(20.5f,-4.8f,91.7f), 19.1f, 13.3f, 61f);

            FitArchivePortal(art, sources[1]);
            Place(art, sources[1], "West relay canopy support", new Vector3(-17.8f,-.65f,57.2f), 5.85f, 4.2f, -79f, true);

            var floating = new List<Transform>();
            var instrument = Node(art, "Broken astrolabe drift pivot", new Vector3(0f, 13.7f, 84f));
            instrument.localRotation = Quaternion.Euler(-7f, -7f, 1f);
            Place(instrument, sources[2], "Machined crescent astrolabe", new Vector3(0,-10.0f,0), 22f, 23.4f, 3f);

            var rotor = Node(art, "Floating gimbal drift pivot", new Vector3(-5.9f, 10.4f,60.2f));
            rotor.localRotation = Quaternion.Euler(11f,-12f,-19f);
            var gyro = Place(rotor, sources[3], "Suspended fractured gyroscope", new Vector3(0,-1.8f,0), 3.65f, 5.0f, -90f, true);
            floating.Add(rotor);

            var shard = AssetDatabase.LoadAssetAtPath<GameObject>(Folder + "observatory-asymmetric-shard.glb");
            AddMemory(art, shard != null ? shard : sources[4], floating, 0, "Flow-school-poster.png", "School memory shard",
                new Vector3(-8.5f, 7.6f, 53.1f), new Vector3(-6,-8,12), 3.6f, shard != null);
            AddMemory(art, shard != null ? shard : sources[4], floating, 1, "Flow-memory-poster.png", "Rain memory shard",
                new Vector3(10.15f, 9.2f, 56.8f), new Vector3(5,-15,-15), 3.85f, shard != null);
            AddMemory(art, sources[4], floating, 2, "MemoryFriendsPoster.png", "Friends memory shard",
                new Vector3(13.75f, 6.85f, 65.85f), new Vector3(-7,-17,14), 2.92f);
            AddMemory(art, sources[4], floating, 3, null, "Unlit broken memory shard",
                new Vector3(-3.82f, 15.55f, 66.5f), new Vector3(22,30,-24), 1.6f);
            AddFloatingFragments(art, floating, "West rift rock fragments", new Vector3(-10.4f,8.9f,57.4f), 101);
            AddFloatingFragments(art, floating, "East rift rock fragments", new Vector3(12.1f,10.6f,59.7f), 731);

            var readout = station.Cast<Transform>().Single(item => item.name == "Clock" && item.localPosition.z > 76f);
            readout.localPosition = new Vector3(0, 13.4f, 77.9f);
            var clockGraphic = readout.GetComponent<Renderer>();
            var clockMaterial = GetMaterial("Animated chronostat readout", "ElevenEleven/Observatory Clock Digits");
            clockMaterial.SetTexture("_BaseMap", AssetDatabase.LoadAssetAtPath<Texture2D>(Opening + "Stormworks/Clock.png"));
            clockMaterial.SetColor("_BaseColor", new Color(.864f,1.566f,1.8f,1f));
            EditorUtility.SetDirty(clockMaterial);
            AssetDatabase.SaveAssetIfDirty(clockMaterial);
            clockGraphic.sharedMaterial = clockMaterial;
            LightKey(art, "Wet amber maintenance key", new Vector3(-14.5f, 6.72f,50.5f),
                new Vector3(-15f, .92f,55.25f), new Color(1f,.63f,.32f), 32f,16f,74f, true);
            LightKey(art, "Archive cyan spill", new Vector3(17.4f, 7.4f,57.5f),
                new Vector3(15.0f, 2.3f, 62.0f), new Color(.30f,.84f,.97f), 82f,19f,63f, true);
            LightKey(art, "Warm relay rock bounce", new Vector3(-13.3f,4.25f,50.3f),
                new Vector3(-20.3f,7.6f,57.8f), new Color(1f,.51f,.21f), 103f,19f,75f);
            LightKey(art, "Violet memory shaft", new Vector3(-6.2f,20.1f,62.3f),
                new Vector3(0f,12.0f,83.9f), new Color(.63f,.52f,.96f), 105f,38f,61f);
            LightKey(art, "Warm broken ring rim", new Vector3(10.1f,12.0f,76.0f),
                new Vector3(0f,13.6f,84f), new Color(1f,.72f,.48f), 67f,25f,52f);
            StormworksConstruction.Effect(art, "Observatory low chasm mist", new Vector3(-8.4f,-2.41f,66.1f),
                new Vector2(10.8f, 4.1f), 0, .22f, new Color(.55f,.66f,.81f), 12f, false, 37f);

            DressCorridorScenery(art);
            ObservatoryCatwalkArt.Dress(art,station);
            ObservatoryEntranceArt.Dress(art,station);
            ClearSecurityEnvelope(art);
            StormworksConstruction.Effect(art, "West cliff water runnel", new Vector3(-17.9f,-1.55f,54.2f),
                new Vector2(1.45f,5.7f), 3, .49f, new Color(.51f,.62f,.70f), 31f, false, 31f);
            StormworksConstruction.Effect(art, "East cliff water runnel", new Vector3(19.05f,-1.82f,62.6f),
                new Vector2(1.33f,5.02f), 3, .43f, new Color(.28f,.63f,.73f), 49f, false, 22f);


            var component = art.gameObject.AddComponent<StationMemoryObservatory>();
            var fields = new SerializedObject(component);
            fields.FindProperty("sky").objectReferenceValue = stars;
            fields.FindProperty("clockRotor").objectReferenceValue = instrument;
            fields.FindProperty("gyroRotor").objectReferenceValue = gyro;
            fields.FindProperty("clockReadout").objectReferenceValue = clockGraphic;
            var array = fields.FindProperty("driftingMemories");
            array.arraySize = floating.Count;
            for (var i = 0; i < floating.Count; i++)
                array.GetArrayElementAtIndex(i).objectReferenceValue = floating[i];
            fields.ApplyModifiedPropertiesWithoutUndo();
        }

        internal static void ClearSecurityEnvelope(Transform art)
        {
            var corridor = SecurityEnvelope(art);
            foreach (var piece in SecurityScenery(art))
            {
                var bounds = SceneryBounds(piece);
                if (bounds.Intersects(corridor))
                    piece.position += Vector3.right * (corridor.max.x - bounds.min.x + .3f);
            }
        }

        internal static bool SecurityEnvelopeIsClear(Transform art)
        {
            var corridor = SecurityEnvelope(art);
            return SecurityScenery(art).All(piece => !SceneryBounds(piece).Intersects(corridor));
        }

        private static Bounds SecurityEnvelope(Transform art) => new Bounds(
            art.TransformPoint(new Vector3(StationSecurityWing.CenterX, 2.35f, StationSecurityWing.EntranceZ + 9.1f)),
            new Vector3(9.25f, 5.1f, 18.6f));

        private static IEnumerable<Transform> SecurityScenery(Transform art)
        {
            foreach (var name in new[] { "Clock foundation over the rift", "West submerged viaduct",
                "East submerged viaduct", "Distant stepped pier west", "Distant stepped pier east" })
            {
                var piece = art.Find(name);
                if (piece != null) yield return piece;
            }

            var strata = art.Find("Rebuilt station entrances/Layered basalt around entrances");
            if (strata != null)
                foreach (Transform piece in strata)
                    yield return piece;
        }

        private static Bounds SceneryBounds(Transform piece) =>
            piece.GetComponentsInChildren<MeshRenderer>().Select(renderer => renderer.bounds)
                .Aggregate((bounds, next) => { bounds.Encapsulate(next); return bounds; });

        private static void DressCorridorScenery(Transform art)
        {
            var plinth = AssetDatabase.LoadAssetAtPath<GameObject>(Folder + "observatory-clock-plinth.glb");
            if (plinth != null)
            {
                Place(art, plinth, "Clock foundation over the rift", new Vector3(0.6f,-11.4f,88.1f), 17.6f, 19f, -21f, true);
                LightKey(art, "Clock foundation wet sandstone", new Vector3(-8.0f,8.1f,77.4f), new Vector3(0,-.65f,88.0f),
                    new Color(.99f,.62f,.37f), 125f,26f,61f);
            }

            var viaduct = AssetDatabase.LoadAssetAtPath<GameObject>(Folder + "observatory-viaduct-arch.glb");
            if (viaduct != null)
            {
                Place(art, viaduct, "West submerged viaduct", new Vector3(-13.4f,-8.1f,86.3f), 12.35f, 16f, -79f);
                Place(art, viaduct, "East submerged viaduct", new Vector3(14.35f,-8.5f,91.9f), 12.7f, 17.5f, 88f);
            }

            var rock = AssetDatabase.LoadAssetAtPath<GameObject>(Folder + "observatory-bedrock-face.glb");
            if (rock != null)
            {
                // Different rotations mask the straight bedding edges of the scanned-looking strata.
                Place(art, rock, "West eroded bedrock strata", new Vector3(-25.7f,-7.4f,51.9f), 20.3f, 15.8f, 54f, true);
                Place(art, rock, "West vertical shale escarpment", new Vector3(-24.5f,-8.0f,71.9f), 20.3f, 18.5f, -63f);
                Place(art, rock, "East eroded bedrock strata", new Vector3(28.3f,-8.1f,62.3f), 23.1f, 17.5f, -64f, true);
                Place(art, rock, "East vertical shale escarpment", new Vector3(28.7f,-7.7f,77.3f), 24.0f, 15.4f, 58f);
            }

            var bay = AssetDatabase.LoadAssetAtPath<GameObject>(Folder + "observatory-relay-maintenance.glb");
            if (bay != null)
            {
                Hide(art.Find("West relay canopy support"));
                Place(art, bay, "West relay service workshop", new Vector3(-18.65f,.23f,60.05f), 5.6f, 8.8f, -84f, true);
                LightKey(art, "Workshop amber service bounce", new Vector3(-15.8f,4.15f,56.7f), new Vector3(-19.2f,2.62f,59.1f),
                    new Color(1f,.52f,.23f), 68f,11f,79f, true);
            }
        }

        private static void FitArchivePortal(Transform art, GameObject source)
        {
            // The imported entrance is X-facing. Its opening is about 0.17 units wide along Z.
            // Stretch the opening and compress the outer wings to fit the existing 2.55 m shutter.
            var sourceMesh = source.GetComponentInChildren<MeshFilter>().sharedMesh;
            const string path = Folder + "Archive portal fit.asset";
            var mesh = AssetDatabase.LoadAssetAtPath<Mesh>(path);
            if (mesh == null)
            {
                mesh = Object.Instantiate(sourceMesh);
                mesh.name = "Archive portal fitted to shutter";
                var vertices = mesh.vertices;
                var normals = mesh.normals;
                const float openingHalfWidth = .084f;
                for (var i = 0; i < vertices.Length; i++)
                {
                    var v = vertices[i];
                    var lateral = -v.z - .03f;
                    var magnitude = Mathf.Abs(lateral);
                    var x = Mathf.Min(magnitude, openingHalfWidth) * 18.2f +
                        Mathf.Max(0, magnitude - openingHalfWidth) * 6.45f;
                    // Keep the top service trim from projecting into the vertical shutter track.
                    var zScale = 3.65f;
                    vertices[i] = new Vector3(Mathf.Sign(lateral) * x, v.y * 6.90f + 2.61f, v.x * zScale);
                    var n = normals[i];
                    normals[i] = new Vector3(-n.z / (magnitude <= openingHalfWidth ? 18.2f : 6.45f),
                        n.y / 6.90f, n.x / zScale).normalized;
                }
                mesh.vertices = vertices;
                mesh.normals = normals;
                mesh.RecalculateTangents();
                mesh.RecalculateBounds();
                AssetDatabase.CreateAsset(mesh,path);
            }

            var frame = Node(art, "Archive fitted steel portal", new Vector3(15f,0f,62.16f));
            frame.gameObject.AddComponent<MeshFilter>().sharedMesh = mesh;
            frame.gameObject.AddComponent<MeshRenderer>().sharedMaterials =
                source.GetComponentInChildren<MeshRenderer>().sharedMaterials;
        }

        private static void DressRift(Transform art)
        {
            const string normalPath = Folder + "Basalt tangent normal.png";
            var normal = (TextureImporter)AssetImporter.GetAtPath(normalPath);
            if (normal.textureType != TextureImporterType.NormalMap)
            {
                normal.textureType = TextureImporterType.NormalMap;
                normal.SaveAndReimport();
            }

            var material = GetMaterial("Fractured basalt", "Universal Render Pipeline/Lit");
            material.SetTexture("_BaseMap", AssetDatabase.LoadAssetAtPath<Texture2D>(Folder + "Basalt strata.png"));
            material.SetTexture("_BumpMap", AssetDatabase.LoadAssetAtPath<Texture2D>(normalPath));
            material.SetFloat("_BumpScale", .88f);
            material.SetFloat("_Smoothness", .29f);
            material.EnableKeyword("_NORMALMAP");
            EditorUtility.SetDirty(material);
            AssetDatabase.SaveAssetIfDirty(material);

            var beds = new (Vector3 center, Vector3 scale, float yaw)[]
            {
                (new Vector3(-25,-5,44), new Vector3(6.5f,19,9), -28),
                (new Vector3(-23,0,59), new Vector3(4.5f,28,7), 22),
                (new Vector3(-31,11,64), new Vector3(9,25,12), -11),
                (new Vector3(-22,-7,76), new Vector3(7,13,12), 12),
                (new Vector3(-26,2,95), new Vector3(9,24,11), 37),
                (new Vector3(25,-7,50), new Vector3(6.5f,15,9), 19),
                (new Vector3(28,2,65), new Vector3(7,23,12), -17),
                (new Vector3(33,9,77), new Vector3(10,23,14), -25),
                (new Vector3(21,-5,83), new Vector3(5.5f,16,11), 31),
                (new Vector3(29,1,96), new Vector3(9,25,14), 16)
            };
            for (var i = 0; i < beds.Length; i++)
            {
                var (center, scale, yaw) = beds[i];
                var outcrop = Node(art, $"Sheared basalt outcrop {i + 1}", center);
                outcrop.localRotation = Quaternion.Euler(0,yaw,0);
                outcrop.gameObject.AddComponent<MeshFilter>().sharedMesh = RiftMesh(i, scale);
                outcrop.gameObject.AddComponent<MeshRenderer>().sharedMaterial = material;
            }
        }

        private static void AddFloatingFragments(Transform art, List<Transform> moving, string name, Vector3 center, int seed)
        {
            var root = Node(art, name, center);
            var basalt = GetMaterial("Fractured basalt", "Universal Render Pipeline/Lit");
            var random = new System.Random(seed);
            for (var i = 0; i < 7; i++)
            {
                var offset = new Vector3((float)(random.NextDouble() - .5) * 6.0f, (float)(random.NextDouble() - .5) * 4.3f,
                    (float)(random.NextDouble() - .5) * 6.0f);
                var shard = Node(root, "Broken slate", offset);
                shard.localRotation = Quaternion.Euler(23f*i,57f*i,31f*i);
                var scale = .014f + (float)random.NextDouble() * .034f;
                shard.localScale = new Vector3(scale * 1.45f, scale * .68f, scale * 1.37f);
                shard.gameObject.AddComponent<MeshFilter>().sharedMesh =
                    AssetDatabase.LoadAssetAtPath<Mesh>(Folder + $"Basalt outcrop {i + 1}.asset");
                var renderer = shard.gameObject.AddComponent<MeshRenderer>();
                renderer.sharedMaterial = basalt;
                renderer.shadowCastingMode = ShadowCastingMode.Off;
            }
            moving.Add(root);
        }

        private static Mesh RiftMesh(int index, Vector3 scale)
        {
            const int sides = 11;
            var levels = new[] { -.64f, -.45f, -.24f, -.11f, .11f, .25f, .46f, .65f };
            var path = Folder + $"Basalt outcrop {index + 1}.asset";
            var old = AssetDatabase.LoadAssetAtPath<Mesh>(path);
            if (old != null) return old;
            var random = new System.Random(3386 + 177 * index);
            var profile = new Vector3[levels.Length, sides];
            for (var row = 0; row < levels.Length; row++)
            {
                var edge = row == 0 || row == levels.Length - 1;
                var shift = Mathf.Sin(row * .72f + index) * .37f;
                for (var side = 0; side < sides; side++)
                {
                    var angle = (side + .13f * row + (float)random.NextDouble() * .17f) * Mathf.PI * 2f / sides;
                    var radius = (edge ? .48f : .88f) * (.69f + (float)random.NextDouble() * .49f);
                    var y = levels[row] + ((float)random.NextDouble() - .5f) * .16f + Mathf.Sin(angle) * .10f;
                    profile[row,side] = Vector3.Scale(new Vector3(Mathf.Cos(angle)*radius+shift,y,
                        Mathf.Sin(angle)*radius),scale);
                }
            }

            var vertices = new List<Vector3>();
            var uv = new List<Vector2>();
            void Face(Vector3 a, Vector3 b, Vector3 c, Vector3 outward)
            {
                var normal = Vector3.Cross(b - a, c - a).normalized;
                if (Vector3.Dot(normal, outward) < 0)
                {
                    (b,c) = (c,b);
                    normal = -normal;
                }
                var horizontal = Vector3.Cross(Vector3.up, normal).normalized;
                if (horizontal.sqrMagnitude < .1f) horizontal = Vector3.right;
                var vertical = Vector3.Cross(normal, horizontal);
                foreach (var point in new[] { a,b,c })
                {
                    vertices.Add(point);
                    uv.Add(new Vector2(Vector3.Dot(point,horizontal), Vector3.Dot(point,vertical)) * .38f);
                }
            }
            for (var side = 0; side < sides; side++)
            {
                var next = (side + 1) % sides;
                for (var row = 0; row < levels.Length - 1; row++)
                {
                    var a = profile[row,side];
                    var b = profile[row,next];
                    var c = profile[row + 1,side];
                    var d = profile[row + 1,next];
                    var angle = (side + .5f) * Mathf.PI * 2f / sides;
                    var outward = new Vector3(Mathf.Cos(angle), 0, Mathf.Sin(angle));
                    Face(a,b,c,outward);
                    Face(b,d,c,outward);
                }
                Face(profile[0,side], profile[0,next], Vector3.down * scale.y * .68f, Vector3.down);
                var last = levels.Length - 1;
                Face(profile[last,side], profile[last,next], Vector3.up * scale.y * .69f, Vector3.up);
            }

            var mesh = new Mesh { name = $"Basalt fracture {index + 1}" };
            mesh.SetVertices(vertices);
            mesh.SetUVs(0,uv);
            mesh.SetTriangles(Enumerable.Range(0,vertices.Count).ToArray(),0);
            mesh.RecalculateNormals();
            mesh.RecalculateTangents();
            AssetDatabase.CreateAsset(mesh,path);
            return mesh;
        }

        private static void RemoveOldSilhouette(Transform station)
        {
            foreach (Transform item in station)
            {
                if (item.name == "Distant buttress" || item.name == "Lift machine housing" ||
                    item.name == "Lift service beacon" || item.name == "Suspended cable bridge" ||
                    item.name == "Phase antenna rib" || item.name == "Phase antenna glass")
                    Hide(item);
            }
            var clock = station.Find("Chronostat machinery finish");
            foreach (Transform item in clock)
            {
                if (item.name == "Rebuilt station infrastructure")
                {
                    foreach (Transform prop in item)
                    {
                        if (prop.name.StartsWith("Laboratory", StringComparison.Ordinal) ||
                            prop.name.StartsWith("Facade", StringComparison.Ordinal))
                        {
                            foreach (var renderer in prop.GetComponentsInChildren<Renderer>())
                                renderer.enabled = true;
                            continue;
                        }
                        Hide(prop);
                    }
                }
                if (item.name == "Radial clock assembly" || item.name == "Lift tower service fascia" ||
                    item.name.StartsWith("Clock assembly lower", StringComparison.Ordinal) ||
                    item.name.StartsWith("Clock support", StringComparison.Ordinal) || item.name == "Bearing base isolation stack")
                    Hide(item);
            }
        }

        internal static void Hide(Transform root)
        {
            foreach (var renderer in root.GetComponentsInChildren<Renderer>())
                renderer.enabled = false;
        }

        private static void AddMemory(Transform art, GameObject source, List<Transform> moving, int index, string still,
            string name, Vector3 at, Vector3 euler, float height, bool fitGlass = false)
        {
            var pivot = Node(art, name, at);
            pivot.localRotation = Quaternion.Euler(euler);
            var shell = (GameObject)PrefabUtility.InstantiatePrefab(source, pivot);
            shell.name = "Fractured memory shell";
            var shellMesh = shell.GetComponentInChildren<MeshFilter>().sharedMesh;
            var dimensions = shellMesh.bounds.size;
            var turn = dimensions.x < dimensions.z;
            var rotation = Quaternion.Euler(0,turn ? -90f : 0f,0);
            var scale = Mathf.Min(height / dimensions.y, 5.7f / (turn ? dimensions.z : dimensions.x));
            shell.transform.localScale *= scale;
            shell.transform.localRotation = rotation;
            moving.Add(pivot);
            if (still == null) return;

            var screen = Node(pivot, "Projected memory image", Vector3.zero);
            var projection = screen.gameObject.AddComponent<MeshFilter>();
            if (fitGlass)
            {
                screen.localRotation = rotation;
                screen.localScale = Vector3.one * scale;
                projection.sharedMesh = FittedGlassProjection(shellMesh,rotation);
            }
            else
            {
                screen.localPosition = new Vector3(.023f,-.012f,-.151f)*scale;
                screen.localScale = new Vector3(scale,scale,1);
                projection.sharedMesh = ProjectionMesh(index,.65f,.64f);
            }

            var surface = GetMaterial(name + " projection", "ElevenEleven/Memory Inside Fracture");
            surface.SetTexture("_Memory", AssetDatabase.LoadAssetAtPath<Texture2D>(Opening + "Media/" + still));
            surface.SetColor("_Color", index == 1 ? new Color(.71f,.75f,1f,.88f) : new Color(.90f,.65f,1f,.90f));
            surface.SetFloat("_FollowsGlass",fitGlass ? 1f : 0f);
            EditorUtility.SetDirty(surface);
            AssetDatabase.SaveAssetIfDirty(surface);
            var renderer = screen.gameObject.AddComponent<MeshRenderer>();
            renderer.sharedMaterial = surface;
            renderer.shadowCastingMode = ShadowCastingMode.Off;
        }

        private static Mesh FittedGlassProjection(Mesh shard, Quaternion rotation)
        {
            const string path = Folder + "Asymmetric shard projection.asset";
            var old = AssetDatabase.LoadAssetAtPath<Mesh>(path);
            if (old != null) return old;
            var vertices = shard.vertices;
            var oriented = vertices.Select(vertex => rotation * vertex).ToArray();
            var orientedBounds = new Bounds(oriented[0],Vector3.zero);
            foreach (var point in oriented) orientedBounds.Encapsulate(point);
            var uv = new Vector2[vertices.Length];
            var front = Quaternion.Inverse(rotation)*Vector3.back;
            for (var i = 0; i < vertices.Length; i++)
            {
                var v = oriented[i];
                uv[i] = new Vector2(Mathf.InverseLerp(orientedBounds.min.x,orientedBounds.max.x,v.x),
                    Mathf.InverseLerp(orientedBounds.min.y,orientedBounds.max.y,v.y));
                vertices[i] += front*.0022f;
            }

            var faces = new List<int>();
            var normals = shard.normals;
            for (var submesh = 0; submesh < shard.subMeshCount; submesh++)
            {
                var sourceFaces = shard.GetTriangles(submesh);
                for (var i = 0; i < sourceFaces.Length; i += 3)
                {
                    var a = sourceFaces[i];
                    var b = sourceFaces[i+1];
                    var c = sourceFaces[i+2];
                    if (Vector3.Dot(normals[a]+normals[b]+normals[c],front) < 1.84f) continue;
                    if ((oriented[a].z+oriented[b].z+oriented[c].z)/3f > orientedBounds.center.z) continue;
                    faces.Add(a);
                    faces.Add(b);
                    faces.Add(c);
                }
            }
            if (faces.Count < 90) throw new InvalidOperationException("The memory shard has no viewer-facing glass to project onto.");
            var mesh = new Mesh { name = "Projection aligned to the fractured glass", indexFormat=shard.indexFormat };
            mesh.vertices = vertices;
            mesh.uv = uv;
            mesh.SetTriangles(faces,0);
            mesh.RecalculateBounds();
            AssetDatabase.CreateAsset(mesh,path);
            return mesh;
        }

        private static Mesh ProjectionMesh(int index, float width, float height)
        {
            var path = Folder + $"Glass projection {index}.asset";
            var mesh = AssetDatabase.LoadAssetAtPath<Mesh>(path);
            if (mesh != null) return mesh;
            var points = new[] { new Vector2(0,0), new Vector2(-.50f,-.22f), new Vector2(-.31f,-.49f),
                new Vector2(.18f,-.43f), new Vector2(.44f,-.16f), new Vector2(.48f,.29f),
                new Vector2(.07f,.48f), new Vector2(-.42f,.34f) };
            var vertices = new Vector3[points.Length];
            var uv = new Vector2[points.Length];
            var faces = new int[(points.Length - 1) * 3];
            for (var j = 0; j < points.Length; j++)
            {
                var point = points[j];
                if (index == 1) point.x *= -1f;
                if (index == 2 && j == 5) point.y -= .20f;
                vertices[j] = new Vector3(point.x*width,point.y*height,0f);
                uv[j] = point + Vector2.one*.5f;
                if (j == 0) continue;
                faces[(j-1)*3] = 0;
                faces[(j-1)*3+1] = j;
                faces[(j-1)*3+2] = j+1 == points.Length ? 1 : j+1;
            }
            mesh = new Mesh { name = $"Memory fracture projection {index}", vertices=vertices,uv=uv,triangles=faces };
            mesh.RecalculateNormals();
            AssetDatabase.CreateAsset(mesh,path);
            return mesh;
        }

        internal static Transform Place(Transform root, GameObject asset, string name, Vector3 floor,
            float height, float maximumWidth, float rotation, bool castShadows = false)
        {
            var instance = (GameObject)PrefabUtility.InstantiatePrefab(asset, root);
            var model = instance.transform;
            instance.name = name;
            model.localRotation = Quaternion.Euler(0f, rotation, 0f);
            var renderers = instance.GetComponentsInChildren<MeshRenderer>();
            var bounds = renderers.Select(item => item.bounds).Aggregate((a,b) => { a.Encapsulate(b); return a; });
            var amount = Mathf.Min(height / bounds.size.y, maximumWidth / bounds.size.x);
            var anchor = root.TransformPoint(floor);
            var contact = new Vector3(bounds.center.x,bounds.min.y,bounds.center.z);
            model.localScale *= amount;
            model.position += anchor - (model.position + (contact - model.position) * amount);
            foreach (var collider in instance.GetComponentsInChildren<Collider>(true))
                Object.DestroyImmediate(collider);
            foreach (var renderer in renderers)
            {
                renderer.shadowCastingMode = castShadows ? ShadowCastingMode.On : ShadowCastingMode.Off;
                renderer.receiveShadows = true;
            }
            return model;
        }

        internal static void LightKey(Transform parent, string name, Vector3 at, Vector3 goal, Color color, float intensity,
            float range, float angle, bool castShadows = false)
        {
            var anchor = Node(parent,name,at);
            anchor.localRotation = Quaternion.LookRotation(goal-at);
            var light = anchor.gameObject.AddComponent<Light>();
            light.type = LightType.Spot;
            light.color = color;
            light.intensity = intensity;
            light.range = range;
            light.spotAngle = angle;
            light.innerSpotAngle = angle*.65f;
            if (castShadows) light.shadows = LightShadows.Soft;
        }

        private static Material GetMaterial(string name, string shader)
        {
            var path = Folder + name + ".mat";
            var old = AssetDatabase.LoadAssetAtPath<Material>(path);
            if (old != null) return old;
            var mat = new Material(Shader.Find(shader));
            AssetDatabase.CreateAsset(mat,path);
            return mat;
        }
    }
}
