using ElevenEleven.Opening;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using static ElevenEleven.Editor.GodotRoomAssembly;

namespace ElevenEleven.Editor
{
    internal static class StationReservoirArt
    {
        private const string Folder = "Assets/ElevenEleven/Opening/Stormworks/StationFinishes/";

        internal static void Dress(Transform assembly, Transform station, Material body, Material metal, Material amber)
        {
            var root = Node(assembly, "Station reservoir and field effects", Vector3.zero);
            var oldWater = station.Find("Water below").GetComponent<MeshRenderer>();
            oldWater.enabled = false;
            var waterMaterial = StormworksConstruction.PersistentMaterial("Station Gerstner reservoir", "StationReservoir.shader");

            var water = Node(root, "Boat Attack reservoir surface", new Vector3(0f, -4.34f, 57.8f));
            water.gameObject.AddComponent<MeshFilter>().sharedMesh = WaterGrid();
            var waterRenderer = water.gameObject.AddComponent<MeshRenderer>();
            waterRenderer.sharedMaterial = waterMaterial;
            waterRenderer.shadowCastingMode = ShadowCastingMode.Off;

            var glow = ParticlesMaterial();
            var drain = new[] {
                BuildDrain(root, body, metal, glow, new Vector3(-5.2f,-1.32f,48.4f), -1),
                BuildDrain(root, body, metal, glow, new Vector3(8.65f,-1.30f,61.6f), 1)
            };
            var pilot = Emitter(root, "Pilot embers", new Vector3(-13.59f,.20f,43.65f), glow,
                new Color(1f,.36f,.10f,.85f), 3.5f, .46f, .76f, .028f, .12f, 32);
            var conduit = Emitter(root, "Relay housing sparks", new Vector3(-17.2f,1.45f,57.20f), glow,
                new Color(.47f,.84f,1f,.93f), 6f, .16f, 2.2f, .024f, .85f, 28);
            var arc = Emitter(root, "Lab conduit pin sparks", new Vector3(17.62f,2.83f,62.53f), glow,
                new Color(.42f,.83f,1f,.82f), 3.8f, .13f, 1.42f, .021f, .70f, 24);
            var fragments = Emitter(root, "Relay startup fragments", new Vector3(-17.24f,1.32f,57.22f), glow,
                new Color(.88f,.65f,.36f,1f), 0f, .52f, 1.7f, .045f, .80f, 14);
            var fragmentsRenderer = fragments.GetComponent<ParticleSystemRenderer>();
            var prism = GameObject.CreatePrimitive(PrimitiveType.Cube);
            fragmentsRenderer.renderMode = ParticleSystemRenderMode.Mesh;
            fragmentsRenderer.mesh = prism.GetComponent<MeshFilter>().sharedMesh;
            UnityEngine.Object.DestroyImmediate(prism);
            var rotation = fragments.rotationOverLifetime;
            rotation.enabled = true;
            rotation.z = new ParticleSystem.MinMaxCurve(-7f, 7f);

            var markers = new[] {
                WindMarker(root, body, amber, new Vector3(-11.80f,3.06f,44.02f)),
                WindMarker(root, body, amber, new Vector3(19.72f,3.11f,45f))
            };
            var fields = new SerializedObject(root.gameObject.AddComponent<StationReservoirEffects>());
            fields.FindProperty("burst").objectReferenceValue = fragments;
            AssignArray(fields, "drift", drain[0], drain[1], pilot);
            AssignArray(fields, "powered", conduit, arc);
            AssignArray(fields, "windMarkers", markers);
            fields.ApplyModifiedPropertiesWithoutUndo();
        }

        private static void AssignArray(SerializedObject fields, string name, params Object[] items)
        {
            var array = fields.FindProperty(name);
            array.arraySize = items.Length;
            for (var index = 0; index < items.Length; index++)
                array.GetArrayElementAtIndex(index).objectReferenceValue = items[index];
        }

        private static Mesh WaterGrid()
        {
            var path = Folder + "Reservoir tessellation.asset";
            var mesh = AssetDatabase.LoadAssetAtPath<Mesh>(path);
            if (mesh != null) return mesh;
            const int horizontal = 118, vertical = 104;
            var vertices = new Vector3[(horizontal + 1) * (vertical + 1)];
            var indices = new int[horizontal * vertical * 6];
            for (var z = 0; z <= vertical; z++)
            for (var x = 0; x <= horizontal; x++)
                vertices[z*(horizontal+1)+x] = new Vector3((x/(float)horizontal-.5f)*70f, 0f, (z/(float)vertical-.5f)*62f);
            var i = 0;
            for (var z = 0; z < vertical; z++)
            for (var x = 0; x < horizontal; x++)
            {
                var a = z * (horizontal + 1) + x;
                var b = a + horizontal + 1;
                indices[i++] = a;
                indices[i++] = b;
                indices[i++] = a + 1;
                indices[i++] = a + 1;
                indices[i++] = b;
                indices[i++] = b + 1;
            }
            mesh = new Mesh { name = "Station reservoir Gerstner grid", vertices = vertices, triangles = indices };
            mesh.RecalculateNormals();
            mesh.bounds = new Bounds(Vector3.zero, new Vector3(70.6f, .7f, 62.6f));
            AssetDatabase.CreateAsset(mesh, path);
            return mesh;
        }

        private static ParticleSystem BuildDrain(Transform root, Material body, Material steel, Material vfx, Vector3 position, int side)
        {
            var mouth = Node(root, "Flood return spout", position);
            Part(mouth, "Drain lip", steel, new Vector3(0,.16f,0), new Vector3(1.13f,.10f,.38f));
            Part(mouth, "Drain sleeve", body, new Vector3(0,.41f,.48f), new Vector3(1.23f,.64f,.88f));
            var drift = Emitter(mouth, "Falling spray and mist", new Vector3(0,.1f,-.22f), vfx,
                new Color(.61f,.79f,.85f,.38f), 16f, .66f, 1.07f, .097f, .55f, 54);
            drift.transform.localRotation = Quaternion.Euler(83f * side, 0f, 0f);
            return drift;
        }

        private static Transform WindMarker(Transform root, Material body, Material amber, Vector3 position)
        {
            var baseJoint = Node(root, "Wind telltale bracket", position);
            Part(baseJoint, "Wind telltale support", body, new Vector3(.17f,0,0), new Vector3(.37f,.11f,.14f));
            var hinge = Node(baseJoint, "Wind telltale swing pivot", Vector3.zero);
            Part(hinge, "Wind telltale foil", amber, new Vector3(0,-.22f,0), new Vector3(.095f,.45f,.021f));
            return hinge;
        }

        private static void Part(Transform parent, string name, Material material, Vector3 position, Vector3 dimensions)
        {
            var visual = GameObject.CreatePrimitive(PrimitiveType.Cube);
            visual.name = name;
            visual.transform.SetParent(parent, false);
            visual.transform.localPosition = position;
            visual.transform.localScale = dimensions;
            visual.GetComponent<MeshRenderer>().sharedMaterial = material;
            UnityEngine.Object.DestroyImmediate(visual.GetComponent<Collider>());
        }

        private static ParticleSystem Emitter(Transform root, string name, Vector3 position, Material material, Color color,
            float rate, float life, float speed, float size, float gravity, int cap)
        {
            var objectRoot = Node(root, name, position);
            var system = objectRoot.gameObject.AddComponent<ParticleSystem>();
            var main = system.main;
            main.playOnAwake = false;
            main.maxParticles = cap;
            main.loop = true;
            main.startLifetime = new ParticleSystem.MinMaxCurve(life * .66f, life);
            main.startSpeed = new ParticleSystem.MinMaxCurve(speed * .40f, speed);
            main.startSize = new ParticleSystem.MinMaxCurve(size * .42f, size);
            main.startColor = color;
            main.gravityModifier = gravity;
            main.simulationSpace = ParticleSystemSimulationSpace.World;
            main.cullingMode = ParticleSystemCullingMode.PauseAndCatchup;
            var emission = system.emission;
            emission.rateOverTime = rate;
            var shape = system.shape;
            shape.shapeType = ParticleSystemShapeType.Cone;
            shape.radius = .075f;
            shape.angle = 28f;
            var drift = system.velocityOverLifetime;
            drift.enabled = true;
            drift.space = ParticleSystemSimulationSpace.World;
            drift.x = .22f;
            var fade = system.colorOverLifetime;
            fade.enabled = true;
            var gradient = new Gradient();
            gradient.SetKeys(new[] { new GradientColorKey(Color.white, 0), new GradientColorKey(Color.white, 1) },
                new[] { new GradientAlphaKey(.05f, 0), new GradientAlphaKey(1f, .16f), new GradientAlphaKey(0f, 1) });
            fade.color = new ParticleSystem.MinMaxGradient(gradient);
            var renderer = system.GetComponent<ParticleSystemRenderer>();
            renderer.sharedMaterial = material;
            renderer.renderMode = ParticleSystemRenderMode.Stretch;
            renderer.velocityScale = .055f;
            renderer.lengthScale = 1.6f;
            renderer.shadowCastingMode = ShadowCastingMode.Off;
            objectRoot.localRotation = Quaternion.Euler(-74f, 0f, 0f);
            return system;
        }

        private static Material ParticlesMaterial()
        {
            const string path = Folder + "Station field particles.mat";
            var material = AssetDatabase.LoadAssetAtPath<Material>(path);
            if (material != null) return material;
            var texture = new Texture2D(32, 32, TextureFormat.RGBA32, false, true) { name = "Radial soft speck" };
            for (var y = 0; y < 32; y++)
            for (var x = 0; x < 32; x++)
            {
                var point = (new Vector2(x + .5f, y + .5f) - Vector2.one * 16f)/16f;
                var alpha = Mathf.Pow(Mathf.Clamp01(1f-point.sqrMagnitude), 2.4f);
                texture.SetPixel(x, y, new Color(1f, 1f, 1f, alpha));
            }
            texture.Apply(false, true);
            AssetDatabase.CreateAsset(texture, Folder + "Station soft speck.asset");
            material = new Material(Shader.Find("Universal Render Pipeline/Particles/Unlit"));
            material.SetTexture("_BaseMap", texture);
            material.SetFloat("_Surface", 1f);
            material.SetFloat("_SrcBlend", (int)BlendMode.SrcAlpha);
            material.SetFloat("_DstBlend", (int)BlendMode.OneMinusSrcAlpha);
            material.SetFloat("_ZWrite", 0f);
            material.SetFloat("_Cull", 0f);
            material.SetOverrideTag("RenderType", "Transparent");
            material.EnableKeyword("_SURFACE_TYPE_TRANSPARENT");
            material.renderQueue = (int)RenderQueue.Transparent;
            AssetDatabase.CreateAsset(material, path);
            return material;
        }
    }
}
