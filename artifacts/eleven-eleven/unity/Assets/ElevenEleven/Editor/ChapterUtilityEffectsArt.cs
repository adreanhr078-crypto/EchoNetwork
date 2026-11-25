using System;
using ElevenEleven.Opening;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using Object = UnityEngine.Object;

namespace ElevenEleven.Editor
{
    internal static class ChapterUtilityEffectsArt
    {
        private const string RootName = "Grounded room utility effects";
        private const string Art = "Assets/ElevenEleven/Opening/Stormworks/";

        internal static void Apply(Transform content, Transform station)
        {
            var player = content.GetComponentInChildren<Room01Player>(true);
            var route = station.GetComponent<StormworksRoute>();
            if (!player || !route) throw new InvalidOperationException("Utility effects require the chamber player and station route.");

            var prior = station.Find(RootName);
            if (prior) Object.DestroyImmediate(prior.gameObject);
            var root = Group(station, RootName, Vector3.zero);
            var signal = Group(root, "Signal chamber utilities", Vector3.zero);
            var corridor = Group(root, "Pressure corridor utilities", Vector3.zero);
            var steel = AssetDatabase.LoadAssetAtPath<Material>(Art + "Echo Station brushed frame.mat");
            var ceramic = AssetDatabase.LoadAssetAtPath<Material>(Art + "Ceramic steel.mat");
            var copper = AssetDatabase.LoadAssetAtPath<Material>(Art + "Coolant copper collars.mat");
            var casing = AssetDatabase.LoadAssetAtPath<Material>(Art + "Casing recess.mat");
            var luminousParticles = AssetDatabase.LoadAssetAtPath<Material>(Art + "ChapterRoomArt/Air and electrical light.mat");
            if (!luminousParticles) luminousParticles = StormworksConstruction.PersistentMaterial(
                "Utility spark and water streak", "RoomAmbientLight.shader");
            var water = StormworksConstruction.PersistentMaterial("Shallow utility runoff", "RoomUtilityWater.shader");
            var flame = StormworksConstruction.PersistentMaterial("Local purge flame", "RoomUtilityCombustion.shader");
            var smoke = StormworksConstruction.PersistentMaterial("Local purge smoke", "RoomUtilityCombustion.shader");
            smoke.SetFloat("_Smoke", 1f);
            smoke.EnableKeyword("_UTILITY_SMOKE");
            EditorUtility.SetDirty(smoke);

            BuildConduitFault(signal, player, route, ceramic, copper, casing, luminousParticles);
            BuildWater(signal, player, route, false, steel, copper, water, luminousParticles);
            BuildWater(corridor, player, route, true, steel, copper, water, luminousParticles);
            BuildPilot(signal, player, route, steel, casing, copper, flame, smoke);

            var leakSound = station.Find("Containment leak");
            if (leakSound)
                leakSound.position = signal.Find("West viewport condensate spill/Condensate impact point").position;
        }

        private static void BuildConduitFault(Transform signal, Room01Player player, StormworksRoute route,
            Material ceramic, Material copper, Material casing, Material particlesMaterial)
        {
            var root = Group(signal, "Damaged power conduit contact gap", new Vector3(-3.55f, 1.38f, 3.48f));
            var end = new Vector3(.50f, -.13f, .015f);
            Shape(root, "Recessed breaker carrier", PrimitiveType.Cube, new Vector3(.25f, -.07f, .145f),
                new Vector3(.67f, .33f, .15f), Quaternion.identity, casing);
            foreach (var contact in new[] { Vector3.zero, end })
            {
                Shape(root, "Ceramic contact isolator", PrimitiveType.Cylinder, contact + Vector3.forward * .085f,
                    new Vector3(.156f, .074f, .156f), Quaternion.Euler(90f, 0f, 0f), ceramic);
                Shape(root, "Oxidized copper terminal", PrimitiveType.Cylinder, contact + Vector3.forward * .019f,
                    new Vector3(.09f, .025f, .09f), Quaternion.Euler(90f, 0f, 0f), copper);
            }
            var core = Arc(root, "White ion channel", particlesMaterial, .025f, new Color(1.35f, 1.7f, 2.1f, .99f));
            var glow = Arc(root, "Ionic corona", particlesMaterial, .079f, new Color(.11f, .42f, 1f, .42f));
            var light = Point(root, "Intermittent arc reflection on the conduit", new Vector3(.22f, -.06f, -.10f),
                new Color(.34f, .61f, 1f), 3.45f);

            var sparks = Particles(root, "Expelled hot copper sparks", new Vector3(.18f, -.035f, -.03f), particlesMaterial, 32);
            sparks.transform.localRotation = Quaternion.Euler(-58f, 189f, 0f);
            var main = sparks.main;
            main.startLifetime = new ParticleSystem.MinMaxCurve(.20f, .60f);
            main.startSpeed = new ParticleSystem.MinMaxCurve(.8f, 2.7f);
            main.startSize = new ParticleSystem.MinMaxCurve(.023f, .054f);
            main.gravityModifier = 1.4f;
            var shape = sparks.shape;
            shape.enabled = true;
            shape.shapeType = ParticleSystemShapeType.Cone;
            shape.angle = 51f;
            shape.radius = .026f;
            var streak = sparks.GetComponent<ParticleSystemRenderer>();
            streak.renderMode = ParticleSystemRenderMode.Stretch;
            streak.lengthScale = 1.7f;
            streak.velocityScale = .087f;
            FadeParticles(sparks, new Color(1f, .98f, .83f), new Color(1f, .36f, .06f), .92f);

            root.gameObject.AddComponent<RoomUtilityEffects>().Configure(RoomUtilityEffects.Role.ConduitFault, player,
                route, 17f, Array.Empty<Renderer>(), sparks, light, core, glow, end);
        }

        private static void BuildWater(Transform parent, Room01Player player, StormworksRoute route, bool pressure,
            Material steel, Material copper, Material water, Material waterStreak)
        {
            var origin = pressure ? new Vector3(3.10f, .068f, 24.60f) : new Vector3(-6.65f, .055f, 8.25f);
            var root = Group(parent, pressure ? "Regulator pressure return wash" : "West viewport condensate spill", origin);
            var footprint = pressure ? new Vector2(1.16f, 2.24f) : new Vector2(2.08f, 3.42f);
            var surface = Shape(root, "Shallow water over the steel deck", PrimitiveType.Quad, Vector3.zero,
                new Vector3(footprint.x, footprint.y, 1f), Quaternion.Euler(90f, 0f, 0f), water);
            surface.shadowCastingMode = ShadowCastingMode.Off;

            var outletHeight = pressure ? .88f : 1.42f;
            var nozzle = new Vector3(pressure ? .26f : -.65f, outletHeight, pressure ? .36f : -.52f);
            var wallSide = pressure ? 1f : -1f;
            var body = nozzle + Vector3.right * (wallSide * .19f);
            Shape(root, "Copper condensate outlet", PrimitiveType.Cylinder, body + Vector3.up * .035f,
                new Vector3(.11f, .27f, .11f), Quaternion.Euler(0f, 0f, 90f), copper);
            Shape(root, "Outlet union collar", PrimitiveType.Cylinder, nozzle + Vector3.up * .073f,
                new Vector3(.156f, .068f, .156f), Quaternion.identity, steel);
            Shape(root, "Condensate riser", PrimitiveType.Cylinder,
                new Vector3(body.x + wallSide * .18f, outletHeight * .5f, body.z),
                new Vector3(.103f, outletHeight * .52f, .103f), Quaternion.identity, copper);
            Shape(root, "Recessed grate edge", PrimitiveType.Cube, new Vector3(wallSide * footprint.x * .42f, -.014f, .12f),
                new Vector3(.075f, .025f, footprint.y * .82f), Quaternion.identity, steel);

            var drops = Particles(root, "Falling droplets from the outlet", nozzle, waterStreak, 18);
            var main = drops.main;
            main.startSize = new ParticleSystem.MinMaxCurve(.019f, .036f);
            main.startLifetime = Mathf.Sqrt(2f * outletHeight / Physics.gravity.magnitude);
            main.startSpeed = 0f;
            main.gravityModifier = 1f;
            var shape = drops.shape;
            shape.enabled = true;
            shape.shapeType = ParticleSystemShapeType.Sphere;
            shape.radius = .023f;
            var render = drops.GetComponent<ParticleSystemRenderer>();
            render.renderMode = ParticleSystemRenderMode.Stretch;
            render.lengthScale = 1.3f;
            render.velocityScale = .030f;
            FadeParticles(drops, new Color(.49f, .82f, .93f), new Color(.58f, .90f, 1f), .88f);
            var impact = Group(root, "Condensate impact point", new Vector3(nozzle.x, 0f, nozzle.z));
            root.gameObject.AddComponent<RoomUtilityEffects>().Configure(
                pressure ? RoomUtilityEffects.Role.PressureReturn : RoomUtilityEffects.Role.ViewportRunoff,
                player, route, pressure ? 12f : 18f, new Renderer[] { surface }, drops, outlet: drops.transform,
                impact: impact, wetBounds: footprint * .43f);
        }

        private static void BuildPilot(Transform parent, Room01Player player, StormworksRoute route, Material steel,
            Material casing, Material copper, Material flame, Material smokeMaterial)
        {
            var root = Group(parent, "Shielded thermal purge pilot", new Vector3(7.28f, .24f, 13.40f));
            Shape(root, "Charred pilot body", PrimitiveType.Cylinder, new Vector3(0f, -.05f, 0f),
                new Vector3(.68f, .18f, .68f), Quaternion.identity, casing);
            Shape(root, "Flame retention ring", PrimitiveType.Cylinder, new Vector3(0f, .139f, 0f),
                new Vector3(.35f, .039f, .35f), Quaternion.identity, copper);
            Shape(root, "Fuel pipe", PrimitiveType.Cylinder, new Vector3(.51f, -.062f, .01f),
                new Vector3(.11f, .42f, .11f), Quaternion.Euler(0f, 0f, 90f), copper);
            Shape(root, "Refractory back plate", PrimitiveType.Cube, new Vector3(.01f, .25f, .30f),
                new Vector3(.76f, .62f, .14f), Quaternion.Euler(-11f, 0f, 0f), steel);
            var surfaces = new Renderer[2];
            for (var i = 0; i < surfaces.Length; i++)
            {
                surfaces[i] = Shape(root, "Turbulent flame tongue " + (i + 1), PrimitiveType.Quad,
                    new Vector3(0f, .71f, -.02f), new Vector3(.80f, 1.08f, 1f),
                    Quaternion.Euler(0f, 12f + i * 74f, 0f), flame);
                surfaces[i].shadowCastingMode = ShadowCastingMode.Off;
            }
            var light = Point(root, "Warm fire bounce on the purge shield", new Vector3(.003f, .59f, -.16f),
                new Color(1f, .40f, .102f), 4.1f);
            var smoke = Particles(root, "Thermal plume drifting upward", new Vector3(0f, .57f, -.03f), smokeMaterial, 16);
            smoke.transform.localRotation = Quaternion.Euler(-79f, 31f, 0f);
            var main = smoke.main;
            main.loop = true;
            main.startSize = new ParticleSystem.MinMaxCurve(.32f, .55f);
            main.startLifetime = new ParticleSystem.MinMaxCurve(1.2f, 2.2f);
            main.startSpeed = new ParticleSystem.MinMaxCurve(.49f, .78f);
            var emission = smoke.emission;
            emission.rateOverTime = 6f;
            var shape = smoke.shape;
            shape.enabled = true;
            shape.shapeType = ParticleSystemShapeType.Cone;
            shape.angle = 12f;
            shape.radius = .085f;
            var size = smoke.sizeOverLifetime;
            size.enabled = true;
            size.size = new ParticleSystem.MinMaxCurve(1.55f, AnimationCurve.EaseInOut(0f, .30f, 1f, 1f));
            FadeParticles(smoke, new Color(.14f, .129f, .12f), new Color(.21f, .233f, .26f), .64f, .25f);
            root.gameObject.AddComponent<RoomUtilityEffects>().Configure(RoomUtilityEffects.Role.PurgePilot, player,
                route, 26f, surfaces, smoke, light);
        }

        private static Transform Group(Transform parent, string name, Vector3 at)
        {
            var item = new GameObject(name).transform;
            item.SetParent(parent, false);
            item.localPosition = at;
            return item;
        }

        private static MeshRenderer Shape(Transform parent, string name, PrimitiveType form, Vector3 position,
            Vector3 scale, Quaternion rotation, Material material)
        {
            var item = GameObject.CreatePrimitive(form);
            item.name = name;
            Object.DestroyImmediate(item.GetComponent<Collider>());
            item.transform.SetParent(parent, false);
            item.transform.SetLocalPositionAndRotation(position, rotation);
            item.transform.localScale = scale;
            var renderer = item.GetComponent<MeshRenderer>();
            renderer.sharedMaterial = material;
            return renderer;
        }

        private static Light Point(Transform parent, string name, Vector3 position, Color color, float range)
        {
            var light = Group(parent, name, position).gameObject.AddComponent<Light>();
            light.type = LightType.Point;
            light.shadows = LightShadows.None;
            light.range = range;
            light.color = color;
            light.intensity = .32f;
            return light;
        }

        private static LineRenderer Arc(Transform parent, string name, Material material, float width, Color color)
        {
            var renderer = Group(parent, name, Vector3.zero).gameObject.AddComponent<LineRenderer>();
            renderer.sharedMaterial = material;
            renderer.useWorldSpace = false;
            renderer.positionCount = 11;
            renderer.startColor = color;
            renderer.endColor = color;
            renderer.widthCurve = AnimationCurve.EaseInOut(0f, width * .84f, 1f, width);
            renderer.shadowCastingMode = ShadowCastingMode.Off;
            renderer.enabled = false;
            return renderer;
        }

        private static ParticleSystem Particles(Transform parent, string name, Vector3 at, Material material, int capacity)
        {
            var emitter = Group(parent, name, at).gameObject.AddComponent<ParticleSystem>();
            var main = emitter.main;
            main.playOnAwake = false;
            main.simulationSpace = ParticleSystemSimulationSpace.World;
            main.maxParticles = capacity;
            main.useUnscaledTime = false;
            main.startColor = Color.white;
            var emission = emitter.emission;
            emission.rateOverTime = 0f;
            var renderer = emitter.GetComponent<ParticleSystemRenderer>();
            renderer.sharedMaterial = material;
            renderer.shadowCastingMode = ShadowCastingMode.Off;
            renderer.maxParticleSize = .055f;
            return emitter;
        }

        private static void FadeParticles(ParticleSystem emitter, Color start, Color end, float opacity, float fadeIn = .02f)
        {
            var gradient = new Gradient();
            gradient.SetKeys(new[] { new GradientColorKey(start, 0f), new GradientColorKey(end, 1f) },
                new[] { new GradientAlphaKey(0f, 0f), new GradientAlphaKey(opacity, fadeIn),
                    new GradientAlphaKey(opacity * .56f, .61f), new GradientAlphaKey(0f, 1f) });
            var lifetime = emitter.colorOverLifetime;
            lifetime.enabled = true;
            lifetime.color = gradient;
        }
    }
}
