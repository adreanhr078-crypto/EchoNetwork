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
    internal static class ChapterCinematography
    {
        private const string ScenePath = "Assets/ElevenEleven/Scenes/ChapterRoom01.unity";
        private const string Art = "Assets/ElevenEleven/Opening/Stormworks/ChapterRoomPolish/";
        private const string Rig = "Chapter lighting and atmosphere";
        private static readonly Color Tungsten = new Color(1f,.807f,.59f);
        private static readonly Color Window = new Color(.94f,.963f,1f);
        private static readonly Color Practical = new Color(1f,.91f,.776f);

        [MenuItem("11.11/Apply Chapter Cinematography")]
        public static void Apply()
        {
            if (!Application.isBatchMode && !EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo()) return;
            var scene = EditorSceneManager.OpenScene(ScenePath);
            var content = scene.GetRootGameObjects().Single(root => root.name == "Room content").transform;
            var station = content.Find("Echo Station");
            var colliders = content.GetComponentsInChildren<Collider>(true).ToHashSet();
            var camera = content.GetComponentsInChildren<Camera>(true).Single(cam => cam.name == "Room 01 camera");
            FlowReferenceStructuralFit.Apply(content, station);
            var data = camera.GetUniversalAdditionalCameraData();
            data.requiresDepthTexture = true;
            var tones = CameraGrade(station);

            RenderSettings.ambientMode = AmbientMode.Trilight;
            RenderSettings.ambientSkyColor = new Color(.43f,.423f,.402f);
            RenderSettings.ambientEquatorColor = new Color(.336f,.334f,.321f);
            RenderSettings.ambientGroundColor = new Color(.192f,.186f,.178f);
            RenderSettings.fogColor = new Color(.067f,.064f,.060f);
            var fill = scene.GetRootGameObjects().SelectMany(root => root.GetComponentsInChildren<Light>(true))
                .Single(light => light.name == "Cool overhead fill");
            fill.color = new Color(.96f,.928f,.872f);
            fill.intensity = .59f;
            fill.shadows = LightShadows.Soft;
            fill.shadowStrength = .66f;

            var amberBeam = Atmosphere("Practical amber scattering", new Color(1f,.74f,.46f), .094f);
            var pearlBeam = Atmosphere("Window light scattering", new Color(.92f,.96f,1f), .071f);
            var beamMesh = BeamMesh();
            var rooms = new[] { station, station.Find("Memory Observatory"), station.Find("Security wing"),
                station.Find("Specimen containment"), station.Find("Memory archive wing"),
                station.Find("Reserve reactor wing"), station.Find("Decontamination and quarantine"),
                station.Find("Surveillance and mirror"), Find(station, "Kinja examination theatre"),
                Find(station, "Awakening ward") };
            var groups = rooms.Select(ResetRig).ToArray();

            Key(groups[0], "Evidence worktop lamp", new Vector3(-4.64f,5.20f,.24f), new Vector3(-5.56f,1.02f,1.62f), Tungsten, 16.5f, 8.5f, 42f, true);
            Key(groups[0], "Blast door silver key", new Vector3(0f,6.25f,15.81f), new Vector3(0f,.55f,13.4f), Window, 17f, 10f, 42f, true, beamMesh, pearlBeam, 4.9f);
            Key(groups[0], "Recessed extractor practical", new Vector3(2.60f,4.72f,26.74f), new Vector3(3.06f,2.58f,28.27f), Practical, 11f, 5.6f, 39f, false);
            Key(groups[0], "Pressure exit against the observatory", new Vector3(-.8f,4.95f,32.18f), new Vector3(.55f,0f,29.55f), Tungsten, 14f, 8f, 37f, true, beamMesh, amberBeam, 4.2f);
            Key(groups[1], "Amber relay shoulders", new Vector3(-14.1f,4.95f,51.85f), new Vector3(-15.1f,.88f,54.2f), Tungsten, 11f, 8f, 42f, false);
            Key(groups[1], "Lab service bench key", new Vector3(15.3f,4.75f,64.35f), new Vector3(16.6f,1.03f,67.25f), Window, 12f, 8.4f, 44f, false);
            Key(groups[2], "Checkpoint cross key", new Vector3(-.65f,4.38f,9.44f), new Vector3(1.95f,.87f,13.9f), Practical, 15f, 10.8f, 44f, true, beamMesh, amberBeam, 4.0f);
            Key(groups[3], "Specimen EX-011 aisle rim", new Vector3(-22.2f,5.58f,10.64f), new Vector3(-24.55f,1.02f,8.35f), Window, 14f, 9.1f, 41f, false);
            Key(groups[4], "Archive spindle backlight", new Vector3(-12.4f,5.25f,-6.75f), new Vector3(-10.4f,1.31f,-3.67f), Practical, 12f, 8.7f, 39f, false, beamMesh, pearlBeam, 4.0f);
            Key(groups[5], "Reactor grating warm rim", new Vector3(-4.9f,4.22f,13.65f), new Vector3(-.6f,-2.4f,18.7f), Tungsten, 19f, 13f, 43f, false, beamMesh, amberBeam, 6.4f);
            Key(groups[6], "Quarantine pod return key", new Vector3(4.7f,5.86f,14.3f), new Vector3(3.3f,.92f,18.72f), Window, 15f, 10.6f, 38f, false);
            Key(groups[7], "Command platform ivory rim", new Vector3(2.85f,6.58f,14.71f), new Vector3(0f,2.58f,18.28f), Practical, 19f, 11.5f, 41f, true, beamMesh, pearlBeam, 4.8f);
            Key(groups[7], "Inspection mirror approach", new Vector3(6.26f,3.75f,8.2f), new Vector3(7.21f,1.43f,10.65f), Practical, 10f, 6.1f, 40f, false);
            Key(groups[8], "Examination chair silver falloff", new Vector3(-1.75f,6.14f,17.88f), new Vector3(.42f,2.05f,20.17f), Window, 18f, 10.2f, 36f, false, beamMesh, pearlBeam, 4.7f);
            Key(groups[9], "Ward morning key", new Vector3(-.18f,2.64f,-2.40f), new Vector3(.64f,.62f,.55f), Practical, 8.6f, 6.2f, 44f, false, beamMesh, pearlBeam, 3.1f);

            // Only the hero mesh groups need shadow casting support; retained neutral PBR maps still receive it.
            EnableCaster(station.Find("Flow R37 fitted architecture/Signal tuning console"));
            EnableCaster(station.Find("Flow R37 pressure machinery/Main extractor mounted frame"));
            EnableCaster(station.Find("Security wing/Flow R37 fitted architecture/Mechanical check scanner on right service wall"));

            AuthorFraming(camera, rooms);
            if (!colliders.SetEquals(content.GetComponentsInChildren<Collider>(true)))
                throw new InvalidDataException("Photography altered the gameplay collision layout.");
            if (groups.Sum(group => group.GetComponentsInChildren<Light>(true).Length) != 15 ||
                groups.Sum(group => group.GetComponentsInChildren<MeshRenderer>(true).Length) != 8)
                throw new InvalidDataException("The authored chapter light setup is incomplete.");
            AssetDatabase.SaveAssets();
            if (!EditorSceneManager.SaveScene(scene)) throw new IOException("Could not save chapter cinematography.");
            Debug.Log($"ECHO_PHOTOGRAPHY_SAVED lights=15 shafts=8 collision={colliders.Count} profile={tones.name}");
            if (Environment.GetEnvironmentVariable("ECHO_STATION_CAPTURE") != null)
                ChapterRoomTripoKit.CaptureChapter(content, station, "Lighting");
            var scattering = Shader.Find("ElevenEleven/Practical Light Scattering");
            if (!scattering || ShaderUtil.ShaderHasError(scattering))
                throw new InvalidDataException("The active URP light-scattering shader did not compile.");
        }

        public static void ApplyAndReview()
        {
            Apply();
            Environment.SetEnvironmentVariable("ECHO_STATION_CAPTURE",
                Environment.GetEnvironmentVariable("ECHO_PHOTOGRAPHY_PLAY_CAPTURE"));
            Environment.SetEnvironmentVariable("ECHO_STATION_CAPTURE_ONLY", "12,65,66,67,68");
            EditorSceneManager.NewScene(NewSceneSetup.EmptyScene);
            ChapterR01Smoke.RunFromRoomAndContinue();
        }

        public static void RefineVisibleSeams()
        {
            var scene = EditorSceneManager.OpenScene(ScenePath);
            var content = scene.GetRootGameObjects().Single(root => root.name == "Room content").transform;
            var station = content.Find("Echo Station");
            var colliders = content.GetComponentsInChildren<Collider>(true)
                .ToDictionary(collider=>collider,collider=>EditorJsonUtility.ToJson(collider));
            var count = FlowReferenceStructuralFit.FinishVisibleSeams(content, station);
            var after = content.GetComponentsInChildren<Collider>(true);
            if (after.Length != colliders.Count ||
                after.Any(collider=>!colliders.TryGetValue(collider,out var original) || original!=EditorJsonUtility.ToJson(collider)))
                throw new InvalidDataException("The visual finish changed the room collision authority.");
            AssetDatabase.SaveAssets();
            if (!EditorSceneManager.SaveScene(scene)) throw new IOException("Could not save the architectural seam refinements.");
            Debug.Log($"ECHO_PHOTOGRAPHY_SEAMS_SAVED wall_panels={count} gate_backing=true landing_material=true colliders={colliders.Count}");
            ChapterRoomTripoKit.CaptureChapter(content,station,"Lighting");
        }

        private static void AuthorFraming(Camera camera, Transform[] rooms)
        {
            var framing = camera.GetComponent<ChapterCameraFraming>() ??
                camera.gameObject.AddComponent<ChapterCameraFraming>();
            var station = rooms[0];
            var observatory = rooms[1];
            var surveillance = rooms[7];
            var theatre = rooms[8];
            var ward = rooms[9];

            ChapterCameraFraming.Room Room(string label, Transform root, Vector3 center, Vector3 size,
                float blend, float fov, float arm, float shoulder, float height, float motionFov)
                => new ChapterCameraFraming.Room(label, root, center, size, blend, fov, arm, shoulder, height, motionFov);

            framing.Configure(
                Room("Signal Chamber", station, new Vector3(0f, 1.8f, 5f), new Vector3(24f, 7.2f, 26f),
                    1.55f, 57f, 3.7f, .35f, .05f, 2.8f),
                Room("Pressure Plenum", station, new Vector3(0f, 1.8f, 27.9f), new Vector3(8.4f, 6.2f, 12.6f),
                    1.45f, 55f, 3.0f, .19f, .02f, 2f),
                Room("Observatory", observatory, new Vector3(0f, 1.8f, 56.35f), new Vector3(8.2f, 7.2f, 33.1f),
                    2f, 64f, 4.45f, .31f, .17f, 3f),
                Room("Relay", observatory, new Vector3(-15.1f, 1.8f, 55.6f), new Vector3(6.1f, 7.4f, 11.6f),
                    1.6f, 57f, 3.2f, -.24f, .06f, 2.2f),
                Room("Memory Lab", observatory, new Vector3(16.55f, 1.8f, 64.6f), new Vector3(9.2f, 7.8f, 13.4f),
                    1.5f, 55f, 3.3f, .30f, .05f, 2f),
                Room("Security", station.Find("Security wing"), new Vector3(0f, 1.7f, 9f), new Vector3(8.8f, 7f, 18.4f),
                    1.45f, 55f, 3.4f, .34f, -.04f, 2.75f),
                Room("Specimen Containment", station.Find("Specimen containment"), new Vector3(-15f, 1.7f, 6f),
                    new Vector3(30f, 8f, 24f), 1.6f, 59f, 3.8f, -.33f, .12f, 2.4f),
                Room("Memory Archive", station.Find("Memory archive wing"), new Vector3(-11f, 2.1f, 0f),
                    new Vector3(22f, 9f, 28f), 1.65f, 56f, 3.5f, .32f, .08f, 2f),
                Room("Reserve Reactor", station.Find("Reserve reactor wing"), new Vector3(0f, -2.1f, 22f),
                    new Vector3(36f, 17.3f, 44f), 1.8f, 62f, 4.15f, .34f, .16f, 2.8f),
                Room("Quarantine", station.Find("Decontamination and quarantine"), new Vector3(0f, 2.4f, 16f),
                    new Vector3(24f, 10f, 32f), 1.65f, 57f, 3.5f, .24f, .08f, 2.2f),
                Room("Surveillance", surveillance, new Vector3(0f, 2.7f, 18f), new Vector3(28f, 9.4f, 36f),
                    1.55f, 56f, 3.45f, -.29f, .04f, 2.2f),
                Room("Inspection Mirror", surveillance, new Vector3(7.2f, 1.5f, 10f), new Vector3(4.4f, 6.2f, 6f),
                    1.2f, 54f, 3.0f, .18f, .06f, 1.6f),
                Room("Examination Theatre", theatre, new Vector3(0f, 2.9f, 17f), new Vector3(32f, 10.4f, 34f),
                    1.65f, 57f, 3.65f, -.28f, .10f, 2f),
                Room("Zero Threshold", theatre, new Vector3(0f, 1.5f, 33.1f), new Vector3(12f, 7f, 11f),
                    1.65f, 61f, 4.05f, .28f, .10f, 2f),
                Room("Observation Alcove", theatre, new Vector3(-5.2f, 3f, 20.4f), new Vector3(5.6f, 7.6f, 8.7f),
                    1.25f, 54f, 3.25f, -.32f, .02f, 2f),
                Room("Hospital Ward", ward, new Vector3(0f, 1f, 0f), new Vector3(6.4f, 4.7f, 5.8f),
                    1.15f, 55f, 2.85f, .20f, .06f, 1.25f)); 
            EditorUtility.SetDirty(framing);
            Debug.Log("ECHO_PHOTOGRAPHY_CAMERA_CONFIG profiles=16 reduced_fov=60");

        }

        private static void EnableCaster(Transform item)
        {
            if (!item) return;
            foreach (var renderer in item.GetComponentsInChildren<MeshRenderer>(true))
                if (renderer.enabled) renderer.shadowCastingMode = ShadowCastingMode.On;
        }

        private static Transform ResetRig(Transform room)
        {
            var prior = room.Find(Rig);
            if (prior) Object.DestroyImmediate(prior.gameObject);
            return Node(room, Rig, Vector3.zero);
        }

        private static VolumeProfile CameraGrade(Transform station)
        {
            var volume = station.Find("Station chromatic grade").GetComponent<Volume>();
            var path = Art + "Chapter photographic grade.asset";
            var profile = AssetDatabase.LoadAssetAtPath<VolumeProfile>(path);
            if (!profile)
            {
                profile = ScriptableObject.CreateInstance<VolumeProfile>();
                AssetDatabase.CreateAsset(profile, path);
                foreach (var setting in volume.sharedProfile.components)
                {
                    var copy = Object.Instantiate(setting);
                    copy.name = setting.name;
                    AssetDatabase.AddObjectToAsset(copy, profile);
                    profile.components.Add(copy);
                }
            }
            if (!profile.TryGet<ColorAdjustments>(out var color))
            {
                color = profile.Add<ColorAdjustments>(true);
                AssetDatabase.AddObjectToAsset(color, profile);
            }
            color.postExposure.Override(.085f);
            color.contrast.Override(17f);
            color.saturation.Override(-7f);
            if (profile.TryGet<Bloom>(out var bloom))
            {
                bloom.threshold.Override(1.23f);
                bloom.intensity.Override(.21f);
                bloom.scatter.Override(.62f);
                EditorUtility.SetDirty(bloom);
            }
            if (!profile.TryGet<ShadowsMidtonesHighlights>(out var split))
            {
                split = profile.Add<ShadowsMidtonesHighlights>(true);
                AssetDatabase.AddObjectToAsset(split, profile);
            }
            split.shadows.Override(new Vector4(.978f,1.003f,1.011f,-.026f));
            split.midtones.Override(new Vector4(1.006f,1f,.99f,0f));
            split.highlights.Override(new Vector4(1.04f,1.01f,.961f,.023f));
            EditorUtility.SetDirty(split);
            EditorUtility.SetDirty(color);
            EditorUtility.SetDirty(profile);
            volume.sharedProfile = profile;
            return profile;
        }

        private static void Key(Transform parent, string name, Vector3 position, Vector3 focus,
            Color color, float intensity, float reach, float angle, bool castsShadows,
            Mesh beam = null, Material scattering = null, float visibleLength = 0f)
        {
            var socket = Node(parent, name, position);
            socket.localRotation = Quaternion.LookRotation(focus-position);
            var light = socket.gameObject.AddComponent<Light>();
            light.type = LightType.Spot;
            light.color = color;
            light.intensity = intensity;
            light.range = reach;
            light.spotAngle = angle;
            light.innerSpotAngle = angle*.67f;
            if (castsShadows)
            {
                light.shadows = LightShadows.Soft;
                light.shadowStrength = .83f;
                light.shadowBias = .045f;
                light.shadowNormalBias = .29f;
                light.shadowNearPlane = .17f;
            }
            if (!beam) return;
            var shaft = Node(socket, "Depth-faded scattering", new Vector3(0f,0f,.034f));
            var radius = Mathf.Tan(angle*.5f*Mathf.Deg2Rad)*visibleLength;
            shaft.localScale = new Vector3(radius, radius, visibleLength);
            shaft.gameObject.AddComponent<MeshFilter>().sharedMesh = beam;
            var renderer = shaft.gameObject.AddComponent<MeshRenderer>();
            renderer.sharedMaterial = scattering;
            renderer.shadowCastingMode = ShadowCastingMode.Off;
            renderer.receiveShadows = false;
            renderer.lightProbeUsage = LightProbeUsage.Off;
            renderer.reflectionProbeUsage = ReflectionProbeUsage.Off;
        }

        private static Material Atmosphere(string name, Color tint, float density)
        {
            var path = Art + name + ".mat";
            var material = AssetDatabase.LoadAssetAtPath<Material>(path);
            if (!material)
            {
                var shader = Shader.Find("ElevenEleven/Practical Light Scattering");
                if (!shader) throw new FileNotFoundException("Practical Light Scattering shader");
                material = new Material(shader) { name = name };
                AssetDatabase.CreateAsset(material, path);
            }
            material.SetColor("_Tint", tint);
            material.SetFloat("_Density", density);
            material.SetFloat("_SoftIntersection", .48f);
            EditorUtility.SetDirty(material);
            return material;
        }

        private static Mesh BeamMesh()
        {
            var path = Art + "Light scattering cards.asset";
            var mesh = AssetDatabase.LoadAssetAtPath<Mesh>(path);
            if (mesh) return mesh;
            var vertices = new List<Vector3>();
            var uv = new List<Vector2>();
            var indices = new List<int>();
            foreach (var angle in new[] { -32f, 58f })
            {
                var right = Quaternion.AngleAxis(angle, Vector3.forward) * Vector3.right;
                var i = vertices.Count;
                vertices.AddRange(new[] { -right*.14f, right*.14f, Vector3.forward+right, Vector3.forward-right });
                uv.AddRange(new[] { Vector2.zero, Vector2.right, Vector2.one, Vector2.up });
                indices.AddRange(new[] { i,i+1,i+2,i,i+2,i+3 });
            }
            mesh = new Mesh { name = "Light scattering cards" };
            mesh.SetVertices(vertices);
            mesh.SetUVs(0,uv);
            mesh.SetTriangles(indices,0);
            AssetDatabase.CreateAsset(mesh,path);
            return mesh;
        }
    }
}
