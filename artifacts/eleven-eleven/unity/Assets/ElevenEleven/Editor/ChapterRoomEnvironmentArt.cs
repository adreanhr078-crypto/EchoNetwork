using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using ElevenEleven.Opening;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using Object = UnityEngine.Object;

namespace ElevenEleven.Editor
{
    internal sealed class ChapterRoomEnvironmentArt
    {
        private const string ScenePath = "Assets/ElevenEleven/Scenes/ChapterRoom01.unity";
        private const string AssetRoot = "Assets/ElevenEleven/Opening/Stormworks/";
        private const string Folder = AssetRoot + "ChapterRoomArt/";
        private const string LayerName = "Chapter room environment art";
        private static readonly Color Ice = new Color(.32f, .85f, .98f);
        private static readonly Color Amber = new Color(1f, .52f, .14f);
        private static readonly Color Violet = new Color(.69f, .43f, .97f);
        private static readonly Color Dawn = new Color(.98f, .84f, .62f);

        private readonly Transform player;
        private readonly Mesh box;
        private readonly Mesh cylinder;
        private readonly Mesh shard;
        private readonly Material steel;
        private readonly Material casing;
        private readonly Material copper;
        private readonly Material ceramic;
        private readonly Material glass;
        private readonly Material coldGlass;
        private readonly Material warmLens;
        private readonly Material coldLens;
        private readonly Material violetLens;
        private readonly Material effects;

        private ChapterRoomEnvironmentArt(Transform player)
        {
            this.player = player;
            if (!AssetDatabase.IsValidFolder(Folder.TrimEnd('/')))
                AssetDatabase.CreateFolder(AssetRoot.TrimEnd('/'), "ChapterRoomArt");
            box = PrimitiveMesh(PrimitiveType.Cube);
            cylinder = PrimitiveMesh(PrimitiveType.Cylinder);
            shard = ShardMesh();
            steel = Existing("Echo Station brushed frame");
            casing = Existing("Casing recess");
            copper = Existing("Coolant copper collars");
            ceramic = Existing("Ceramic steel");
            warmLens = Existing("Echo Station amber lens");
            coldLens = Existing("Echo Station aqua lens");
            violetLens = Existing("Examination violet indicator");
            glass = Glass("Violet fractured laminate", new Color(.075f, .052f, .155f), Violet);
            coldGlass = Glass("Blue fractured laminate", new Color(.046f, .143f, .185f), Ice);
            effects = LoadOrCreate<Material>("Air and electrical light.mat",
                () => new Material(Shader.Find("ElevenEleven/Room Ambient Light")));
        }

        [MenuItem("11.11/Apply Chapter Room Environment Art")]
        public static void Upgrade()
        {
            if (!Application.isBatchMode && !EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo()) return;
            var scene = EditorSceneManager.OpenScene(ScenePath);
            var content = scene.GetRootGameObjects().Single(root => root.name == "Room content").transform;
            var station = content.Find("Echo Station");
            var player = content.GetComponentInChildren<Room01Player>(true).transform;
            new ChapterRoomEnvironmentArt(player).Dress(station);
            AssetDatabase.SaveAssets();
            if (!EditorSceneManager.SaveScene(scene)) throw new IOException("Could not save the chapter environment artwork.");
            Debug.Log("ECHO_CHAPTER_ROOM_ART_SAVED");
        }

        public static void UpgradeAndReview()
        {
            Upgrade();
            ChapterR01Smoke.RunConnected();
        }

        private void Dress(Transform station)
        {
            var baseline = station.GetComponentsInChildren<Collider>(true).Length;
            var opening = Reset(station, "Containment and pressure");
            var chamber = Group(opening, "Signal chamber", new Vector3(0, 0, 6f));
            Viewport(chamber, new Vector3(-10.58f, 3.3f, 2.4f), 90f, 1.15f, "West pressure viewport");
            StormworksConstruction.FittedProp(chamber, "East pressure viewport (Tripo)", "PressureViewport-Tripo.glb",
                new Vector3(10.60f, 3.35f, -2.25f), new Vector3(4.5f, 3.6f, .74f), -90f);
            ContainmentGantry(chamber);
            SignalDeck(chamber);
            Pool(chamber, "Grazing practical on the fractured bay", new Vector3(-8.8f, 4.3f, 1.2f), Violet, 5.4f, 8f);
            Pool(chamber, "Warm return from gate manifold", new Vector3(5.4f, 4.3f, 9.3f), Amber, 5.4f, 9f);
            Life(chamber, "Window chips and condensation", new Vector3(-9.65f, 3.1f, 2.4f), new Vector3(.7f, 2.4f, 5.6f), Violet,
                glass, Amber, new Vector3(0f, -.21f, 1.05f), 14, 4, .32f, 35f);

            var airlock = Group(opening, "Pressure service corridor", new Vector3(0f, 0f, 26.8f));
            VentStack(airlock, new Vector3(2.6f, 3.72f, 1.55f), 180f, 1.36f, "Regulator cooling stack");
            VentStack(airlock, new Vector3(-2.8f, 3.62f, -.32f), 90f, .93f, "Extraction channels");
            PressureReturns(airlock);
            Life(airlock, "Condensate and extraction shutters", new Vector3(-2.8f, 3.52f, -.34f), new Vector3(.62f, .85f, 2.24f), Ice,
                coldGlass, Ice, new Vector3(0f, .35f, .41f), 11, 5, .23f, 18f, 90f);

            var observatory = Reset(station.Find("Memory Observatory"), "Observatory");
            Life(observatory, "High orbit glacial shards", new Vector3(3.8f, 6.7f, 71.8f), new Vector3(6f, 3f, 3.6f), Ice,
                coldGlass, null, Vector3.zero, 16, 0, .73f, 36f);
            Life(observatory, "Relay wind and copper cladding chips", new Vector3(-17.5f, 2.9f, 52f), new Vector3(1.3f, 1.5f, 4.3f), Amber,
                coldGlass, null, Vector3.zero, 12, 4, .29f, 18f, 90f);
            Life(observatory, "Laboratory diffraction shelf", new Vector3(17.25f, 3.6f, 61.9f), new Vector3(3f, 1.4f, 1.6f), Ice,
                coldGlass, null, Vector3.zero, 13, 3, .23f, 18f);

            var security = Reset(station.Find("Security wing"), "Security");
            ScannerHousing(security, new Vector3(2.8f, 2.72f, 8.4f), 180f, "Security observation head");
            VentStack(security, new Vector3(-3.5f, 2.8f, 12.5f), 90f, 1.30f, "Security intake");
            Pool(security, "Security contrast light", new Vector3(1.8f, 3.6f, 8.3f), Amber, 4.6f, 6.3f);
            Life(security, "Sensor louvers and dust", new Vector3(2.8f, 2.68f, 8.16f), new Vector3(1.15f, .95f, .95f), Amber,
                coldGlass, null, Vector3.zero, 10, 6, .21f, 19f);

            var specimens = Reset(station.Find("Specimen containment"), "Specimens");
            foreach (var x in new[] { -8f, -14f, -20f })
                VentStack(specimens, new Vector3(x, 3.45f, 11.87f), 180f, 1.4f, $"Sample air return {x}");
            Aperture(specimens, new Vector3(-23.15f, 3.75f, 10.75f), 180f, .85f, coldLens, "EX-011 manifold");
            Pool(specimens, "Clinical cabinet sidelight", new Vector3(-24.3f, 3.18f, 9.10f), Ice, 4.6f, 7.5f);
            Life(specimens, "Sample glass and filter shutters", new Vector3(-23.15f, 3.66f, 10.53f), new Vector3(2.7f, 1.15f, 1.28f), Ice,
                coldGlass, null, Vector3.zero, 12, 4, .27f, 24f);

            var archive = Reset(station.Find("Memory archive wing"), "Archive");
            Aperture(archive, new Vector3(-10.7f, 4.12f, -5.08f), 0f, 1.13f, violetLens, "Archive prism yoke");
            for (var x = -15; x <= -7; x += 4)
                VentStack(archive, new Vector3(x, 4.83f, -6.18f), 0f, 1.6f, $"Prism coolant channel {x}");
            Pool(archive, "Prism grazing light", new Vector3(-13.65f, 4.46f, -4.06f), Violet, 6.2f, 8.2f);
            Life(archive, "Decoder fragments and iris petals", new Vector3(-10.7f, 4.12f, -4.79f), new Vector3(2.5f, 1.7f, 1.5f), Violet,
                glass, null, Vector3.zero, 11, 5, .42f, 26f);

            var reactor = Reset(station.Find("Reserve reactor wing"), "Reactor");
            ReactorFeed(reactor);
            Pool(reactor, "Core ceramic thermal bounce", new Vector3(0f, 1.2f, 17.9f), Amber, 11f, 14f);
            Life(reactor, "Hot debris and regulator plates", new Vector3(2.2f, 2.75f, 18.0f), new Vector3(1.35f, 2f, .95f), Amber,
                glass, Amber, new Vector3(.42f, .87f, .16f), 12, 4, .22f, 32f);

            var quarantine = Reset(station.Find("Decontamination and quarantine"), "Quarantine");
            for (var i = 0; i < 3; i++)
                VentStack(quarantine, new Vector3(6.2f, 5.42f, 12.7f + i * 4.25f), -90f, 1.50f, $"Decon dry-air manifold {i}");
            Aperture(quarantine, new Vector3(6.02f, 4.85f, 17.75f), -90f, .78f, coldLens, "Quarantine pod register");
            Life(quarantine, "Condensate and check valves", new Vector3(5.9f, 5.37f, 17f), new Vector3(1.15f, 1.3f, 5.4f),
                Ice, coldGlass, null, Vector3.zero, 10, 6, .23f, 25f, -90f);

            var surveillance = Reset(station.Find("Surveillance and mirror"), "Surveillance");
            ScannerHousing(surveillance, new Vector3(3.1f, 3.88f, 8.5f), -90f, "Mirror room monitoring optics");
            VentStack(surveillance, new Vector3(-3.37f, 3.78f, 9.9f), 90f, 1.4f, "Scanner recirculation manifold");
            Pool(surveillance, "Optical housing rim", new Vector3(2.1f, 3.56f, 7.8f), Ice, 4.5f, 7f);
            MirrorCollar(surveillance);
            Life(surveillance, "Optical blades and scratched glass", new Vector3(3f, 3.77f, 8.42f), new Vector3(1.05f, 1.35f, 2.25f),
                Ice, coldGlass, null, Vector3.zero, 10, 6, .19f, 22f, -90f);
            Life(surveillance, "Mirror service edge and reflected dust", new Vector3(7.82f, 2.46f, 12.18f),
                new Vector3(.48f, 1.3f, .34f), Dawn, coldGlass, null, Vector3.zero, 15, 0, .041f, 10f, -90f);

            var theatreRoot = Descendant(station, "Kinja examination theatre");
            var theatre = Reset(theatreRoot, "Examination");
            Aperture(theatre, new Vector3(3.85f, 4.82f, 21.65f), -90f, .82f, coldLens, "Examination optical assembly");
            VentStack(theatre, new Vector3(-5.86f, 4.5f, 23.52f), 90f, 1.22f, "Examination air filter");
            Life(theatre, "Examination filtration fins and air", new Vector3(4.45f, 4.58f, 21.4f), new Vector3(1.5f, 1.5f, 3f), Ice,
                coldGlass, null, Vector3.zero, 10, 6, .17f, 22f, -90f);

            var zero = Reset(Descendant(theatreRoot, "Zero encounter"), "Zero");
            ZeroFragments(zero);
            Life(zero, "Detached violet memories", new Vector3(0f, 2.86f, 33.35f), new Vector3(5.4f, 1.9f, 1.5f), Violet,
                glass, null, Vector3.zero, 18, 0, .26f, 20f);

            var confrontation = Reset(Descendant(theatreRoot, "Kinja confrontation"), "Confrontation");
            VentStack(confrontation, new Vector3(-5.65f, 3.8f, 19.65f), 90f, 1.2f, "Observation bay scrubber");
            Life(confrontation, "Observation alcove afterimages", new Vector3(-4.7f, 3.6f, 20.1f), new Vector3(.64f, 1.1f, 2.0f), Violet,
                glass, null, Vector3.zero, 15, 1, .12f, 15f, 90f);

            var wardRoom = Descendant(station, "Awakening ward");
            var ward = Reset(wardRoom, "Ward");
            Life(ward, "Dust drifting across the window reveal", new Vector3(0.1f, 1.94f, -2.23f), new Vector3(2.72f, 1.42f, .62f), Dawn,
                coldGlass, null, Vector3.zero, 16, 0, .032f, 9f,
                mountedPieces: wardRoom.Cast<Transform>().Where(item => item.name == "Pleated curtain"));

            if (station.GetComponentsInChildren<Collider>(true).Length != baseline)
                throw new InvalidDataException("The room artwork changed the station's collider inventory.");
            var motion = station.GetComponentsInChildren<RoomEnvironmentMotion>(true);
            Debug.Log($"ECHO_ROOM_MOTION_AUTHORED zones={motion.Length} moving_elements={motion.Sum(zone => zone.PieceCount)} minimum={motion.Min(zone => zone.PieceCount)} colliders={baseline}");
        }

        private Transform Reset(Transform room, string displayName)
        {
            if (!room) throw new InvalidDataException($"Unity room missing for {displayName}.");
            var prior = room.Find(LayerName);
            if (prior) Object.DestroyImmediate(prior.gameObject);
            return Group(room, LayerName, Vector3.zero);
        }

        private void Viewport(Transform root, Vector3 at, float yaw, float scale, string name)
        {
            var body = Group(root, name, at, yaw);
            body.localScale = Vector3.one * scale;
            var parts = new Batch(this);
            parts.Block(Vector3.zero, new Vector3(6.8f, 3.18f, .30f), casing);
            parts.Block(new Vector3(0f, 0f, .168f), new Vector3(6.32f, 2.66f, .12f), glass);
            parts.Rim(3.26f, 1.49f, .43f, .23f, .23f, steel);
            parts.Rim(3.03f, 1.26f, .38f, .058f, .32f, violetLens);
            parts.Rim(3.40f, 1.62f, .38f, .08f, .13f, copper);
            for (var i = 0; i < 13; i++)
            {
                var x = -2.87f + i * .478f;
                foreach (var sign in new[] { -1f, 1f })
                {
                    var atBolt = new Vector3(x, sign * 1.42f, .355f);
                    parts.Pipe(atBolt, atBolt + Vector3.forward * .052f, .052f, ceramic);
                }
            }
            foreach (var sign in new[] { -1f, 1f })
            {
                var x = sign * 2.28f;
                parts.Block(new Vector3(x, 1.22f, .39f), new Vector3(.31f, 1.02f, .23f), ceramic);
                parts.Block(new Vector3(x, 1.01f, .52f), new Vector3(.23f, .24f, .095f), steel);
                parts.Pipe(new Vector3(sign * 3.62f, -.99f, .19f), new Vector3(sign * 3.62f, 1.41f, .19f), .105f, copper);
                parts.Pipe(new Vector3(sign * 3.62f, -.99f, .19f), new Vector3(sign * 2.26f, -1.79f, .19f), .105f, copper);
            }
            for (var i = 0; i < 7; i++)
            {
                var x = -1.32f + i * .44f;
                parts.Pipe(new Vector3(x, -1.93f, .15f), new Vector3(x, -1.55f, .15f), .122f, steel);
                parts.Pipe(new Vector3(x, -1.75f, .15f), new Vector3(x, -1.65f, .15f), .15f, copper);
            }
            parts.Block(new Vector3(0f, -1.71f, .17f), new Vector3(3.23f, .16f, .26f), casing);
            parts.Crack(new Vector2(-1.85f, .33f), .232f, 13, steel, violetLens);
            parts.Crack(new Vector2(2.09f, -.46f), .233f, 29, steel, violetLens);
            parts.Commit(body, name);
        }

        private void ContainmentGantry(Transform root)
        {
            var parts = new Batch(this);
            for (var z = 1; z <= 9; z += 4)
            {
                parts.Block(new Vector3(0f, 6.66f, z), new Vector3(21f, .44f, .53f), steel);
                parts.Block(new Vector3(0f, 6.40f, z), new Vector3(17.3f, .1f, .62f), casing);
                foreach (var side in new[] { -1f, 1f })
                {
                    parts.Beam(new Vector3(side * 10.1f, 4.75f, z), new Vector3(side * 7.25f, 6.58f, z), .22f, .53f, steel);
                    parts.Block(new Vector3(side * 6.6f, 6.31f, z), new Vector3(2.6f, .06f, .14f), side < 0 ? coldLens : warmLens);
                    parts.Pipe(new Vector3(side * 7.62f, 5.76f, z - 1.6f), new Vector3(side * 7.62f, 5.76f, z + 2.39f), .115f, copper);
                }
            }
            parts.Commit(root, "Containment overhead gantry");
        }

        private void SignalDeck(Transform chamber)
        {
            var parts = new Batch(this);
            foreach (var side in new[] { -1f, 1f })
            {
                var edge = side * 6.2f;
                parts.Block(new Vector3(edge, .016f, .7f), new Vector3(1.28f, .032f, 13.3f), casing);
                parts.Block(new Vector3(edge + side * .59f, .038f, .70f), new Vector3(.054f, .026f, 13.3f), steel);
                for (var index = 0; index < 15; index++)
                {
                    var z = -5.8f + index * .91f;
                    parts.Block(new Vector3(edge, .043f, z), new Vector3(1.18f, .028f, .065f), steel);
                    if (index % 3 == 0)
                        parts.Block(new Vector3(edge - side * .57f, .045f, z + .26f), new Vector3(.086f, .024f, .31f), warmLens);
                }
                parts.Pipe(new Vector3(side * 10.1f, 5.33f, -5f), new Vector3(side * 10.1f, 5.33f, 9f), .15f, copper);
                parts.Pipe(new Vector3(side * 10.1f, 5.33f, 9f), new Vector3(side * 8.4f, 4.84f, 10.8f), .15f, copper);
            }
            parts.Commit(chamber, "Service deck seams and pressure headers");
        }

        private void PressureReturns(Transform corridor)
        {
            var parts = new Batch(this);
            foreach (var side in new[] { -1f, 1f })
            {
                var x = side * 3.49f;
                parts.Pipe(new Vector3(x, 3.06f, -2.8f), new Vector3(x, 3.06f, 4.62f), .085f, copper);
                parts.Pipe(new Vector3(x, 3.25f, -2.8f), new Vector3(x, 3.25f, 4.62f), .058f, steel);
                for (var index = 0; index < 7; index++)
                {
                    var z = -2.6f + index * 1.15f;
                    parts.Block(new Vector3(x, 3.14f, z), new Vector3(.22f, .38f, .105f), casing);
                    parts.Block(new Vector3(x - side * .12f, 3.14f, z), new Vector3(.035f, .11f, .08f), coldLens);
                }
            }
            parts.Commit(corridor, "Twin condensate return pipes");
        }

        private void MirrorCollar(Transform room)
        {
            var collar = Group(room, "Bolted inspection mirror surround", new Vector3(8.27f, 1.60f, 10f), -90f);
            var parts = new Batch(this);
            parts.Rim(2.13f, 1.54f, .09f, .155f, .045f, casing);
            parts.Rim(2.20f, 1.61f, .11f, .064f, .09f, steel);
            foreach (var side in new[] { -1f, 1f })
            {
                var x = side * 2.13f;
                for (var index = 0; index < 5; index++)
                {
                    var pin = new Vector3(x, -1.25f + index * .625f, .12f);
                    parts.Pipe(pin, pin + Vector3.forward * .022f, .037f, steel);
                }
                parts.Block(new Vector3(x, 1.20f, .135f), new Vector3(.055f, .21f, .026f), warmLens);
            }
            parts.Commit(collar, "Recessed gunmetal and service fasteners");
        }

        private void ZeroFragments(Transform root)
        {
            var parts = new Batch(this);
            for (var index = 0; index < 14; index++)
            {
                var angle = index * Mathf.PI * 2f / 14;
                var edge = new Vector3(Mathf.Cos(angle) * 3.25f, .082f, 32.8f + Mathf.Sin(angle) * 2.26f);
                var tangent = new Vector3(-Mathf.Sin(angle), 0f, Mathf.Cos(angle)) * .27f;
                parts.Beam(edge - tangent, edge + tangent, .028f, .073f, glass);
                if (index % 2 == 0)
                    parts.Beam(edge - tangent * .64f + Vector3.up * .019f, edge + tangent * .64f + Vector3.up * .019f,
                        .012f, .018f, violetLens);
            }
            parts.Commit(root, "Fractured memory threshold inlay");
        }

        private void VentStack(Transform root, Vector3 at, float yaw, float size, string name)
        {
            var node = Group(root, name, at, yaw);
            node.localScale = Vector3.one * size;
            var parts = new Batch(this);
            parts.Block(Vector3.zero, new Vector3(1.7f, .74f, .26f), casing);
            parts.Rim(.85f, .38f, .09f, .064f, .161f, steel);
            for (var i = 0; i < 11; i++)
            {
                var x = -.70f + i * .14f;
                var height = i % 4 == 0 ? .48f : .43f;
                parts.Block(new Vector3(x, 0f, .152f), new Vector3(.063f, height, .17f), steel);
            }
            parts.Block(new Vector3(0f, -.29f, .172f), new Vector3(1.27f, .037f, .055f), coldLens);
            foreach (var sign in new[] { -1f, 1f })
            {
                var x = sign * .95f;
                parts.Pipe(new Vector3(x, -.51f, -.09f), new Vector3(x, .54f, -.09f), .081f, copper);
                for (var i = 0; i < 3; i++)
                    parts.Block(new Vector3(x, -.36f + i * .37f, -.03f), new Vector3(.23f, .083f, .25f), casing);
            }
            parts.Commit(node, name);
        }

        private void Aperture(Transform root, Vector3 at, float yaw, float size, Material lens, string name)
        {
            var node = Group(root, name, at, yaw);
            node.localScale = Vector3.one * size;
            var parts = new Batch(this);
            parts.Pipe(new Vector3(0, 0, -.42f), new Vector3(0, 0, .14f), .53f, casing);
            parts.Pipe(new Vector3(0, 0, .08f), new Vector3(0, 0, .188f), .47f, steel);
            parts.Pipe(new Vector3(0, 0, .176f), new Vector3(0, 0, .211f), .32f, lens);
            parts.Pipe(new Vector3(0, 0, .205f), new Vector3(0, 0, .229f), .225f, glass);
            foreach (var side in new[] { -1f, 1f })
            {
                parts.Beam(new Vector3(side * 1.48f, -.64f, -.19f), new Vector3(side * .47f, 0f, -.08f), .23f, .36f, casing);
                parts.Pipe(new Vector3(side * .52f, -.08f, -.13f), new Vector3(side * 1.09f, .73f, -.23f), .088f, copper);
            }
            for (var i = 0; i < 12; i++)
            {
                var angle = 2 * Mathf.PI * i / 12;
                var x = Mathf.Cos(angle);
                var y = Mathf.Sin(angle);
                parts.Beam(new Vector3(x * .41f, y * .41f, .20f), new Vector3(x * .64f, y * .64f, .10f), .076f, .09f, ceramic);
            }
            parts.Commit(node, name);
        }

        private void ScannerHousing(Transform root, Vector3 at, float yaw, string name)
        {
            Aperture(root, at, yaw, 1.12f, warmLens, name);
            var frame = Group(root, name + " attenuator", at, yaw);
            var parts = new Batch(this);
            parts.Block(new Vector3(0f, .56f, -.3f), new Vector3(1.82f, .16f, .63f), steel);
            parts.Block(new Vector3(0f, .47f, -.11f), new Vector3(1.54f, .045f, .055f), coldLens);
            parts.Commit(frame, name + " attenuator");
        }

        private void ReactorFeed(Transform reactor)
        {
            var parts = new Batch(this);
            foreach (var side in new[] { -1f, 1f })
            {
                var x = side * 2.0f;
                const float front = 18.65f;
                parts.Pipe(new Vector3(x, .86f, front), new Vector3(x, 3.56f, front), .29f, copper);
                parts.Pipe(new Vector3(x, 3.48f, front), new Vector3(x * .62f, 4.0f, 20.0f), .23f, steel);
                for (var i = 0; i < 8; i++)
                {
                    var y = .82f + i * .32f;
                    var at = new Vector3(x, y, front);
                    parts.Pipe(at, at + Vector3.up * .09f, .39f, ceramic);
                    parts.Block(new Vector3(x, y + .11f, front - .37f), new Vector3(.14f, .08f, .08f), warmLens);
                }
            }
            parts.Commit(reactor, "Reserve reactor ceramic high feed");
        }

        private void Life(Transform room, string name, Vector3 at, Vector3 size, Color tint, Material splinter,
            Color? discharge, Vector3 arcEnd, int chips, int fins, float chipSize, float radius, float yaw = 0f,
            IEnumerable<Transform> mountedPieces = null)
        {
            var root = Group(room, name, at, yaw);
            var random = new System.Random(711 + Mathf.RoundToInt(at.sqrMagnitude * 31f));
            var pieces = new List<RoomEnvironmentMotion.Piece>(chips + fins);
            for (var i = 0; i < chips; i++)
            {
                var position = new Vector3(Unit(random), Unit(random), Unit(random));
                position = Vector3.Scale(position, size);
                var scale = chipSize * Mathf.Lerp(.32f, 1.12f, (float)random.NextDouble());
                var item = Surface(root, $"Fracture chip {i + 1:00}", shard, splinter, position,
                    new Vector3(scale, scale * Mathf.Lerp(.66f, 1.9f, (float)random.NextDouble()), scale * .72f),
                    Quaternion.Euler(Unit(random) * 180f, Unit(random) * 180f, Unit(random) * 180f));
                pieces.Add(new RoomEnvironmentMotion.Piece
                {
                    target = item,
                    movement = RoomEnvironmentMotion.Movement.Drift,
                    direction = new Vector3(Unit(random) * .32f, 1f, Unit(random) * .46f),
                    rate = .36f + .38f * (float)random.NextDouble(),
                    amplitude = .055f + Mathf.Min(size.y * .15f, .23f) * (float)random.NextDouble(),
                    phase = i * 1.47f
                });
            }
            for (var i = 0; i < fins; i++)
            {
                var angle = i * Mathf.PI * 2f / fins;
                var mount = new Vector3(Mathf.Cos(angle) * size.x * .41f, Mathf.Sin(angle) * size.y * .44f, .02f);
                var blade = Surface(root, $"Instrument vane {i + 1:00}", box, i % 3 == 0 ? copper : steel, mount,
                    new Vector3(.20f, .11f, .27f), Quaternion.Euler(0f, 0f, angle * Mathf.Rad2Deg));
                pieces.Add(new RoomEnvironmentMotion.Piece
                {
                    target = blade,
                    movement = i == 0 ? RoomEnvironmentMotion.Movement.Spin :
                        i % 4 == 0 ? RoomEnvironmentMotion.Movement.Slide : RoomEnvironmentMotion.Movement.Hinge,
                    direction = i == 0 ? Vector3.forward : Vector3.right,
                    amplitude = i % 4 == 0 ? .065f : 24f,
                    rate = i == 0 ? 27f : .75f,
                    phase = i * .54f
                });
            }
            if (mountedPieces != null)
            {
                foreach (var item in mountedPieces)
                {
                    pieces.Add(new RoomEnvironmentMotion.Piece
                    {
                        target = item,
                        movement = RoomEnvironmentMotion.Movement.Hinge,
                        direction = Vector3.up,
                        rate = .6f,
                        amplitude = 2.1f,
                        phase = pieces.Count * .85f
                    });
                }
            }

            LineRenderer arc = null;
            if (discharge.HasValue)
            {
                arc = Group(root, "Isolated junction arc", Vector3.zero).gameObject.AddComponent<LineRenderer>();
                arc.enabled = false;
                arc.sharedMaterial = effects;
                arc.useWorldSpace = false;
                arc.startColor = discharge.Value * 1.6f;
                arc.endColor = new Color(.75f, .90f, 1.8f, .85f);
                arc.widthCurve = AnimationCurve.EaseInOut(0f, .022f, 1f, .012f);
                arc.positionCount = 9;
                arc.shadowCastingMode = ShadowCastingMode.Off;
            }

            var air = Group(root, "Airborne flecks", Vector3.zero).gameObject.AddComponent<ParticleSystem>();
            var main = air.main;
            main.loop = true;
            main.playOnAwake = false;
            main.startLifetime = new ParticleSystem.MinMaxCurve(2.1f, 5.0f);
            main.startSpeed = new ParticleSystem.MinMaxCurve(.035f, .12f);
            main.startSize = new ParticleSystem.MinMaxCurve(.012f, .043f);
            main.startColor = new Color(tint.r, tint.g, tint.b, .67f);
            main.maxParticles = 22;
            var emission = air.emission;
            emission.rateOverTime = 4.1f;
            var shape = air.shape;
            shape.shapeType = ParticleSystemShapeType.Box;
            shape.scale = size;
            var fade = new Gradient();
            fade.SetKeys(new[] { new GradientColorKey(Color.white, 0f), new GradientColorKey(Color.white, 1f) },
                new[] { new GradientAlphaKey(0f, 0f), new GradientAlphaKey(.75f, .15f),
                    new GradientAlphaKey(.55f, .70f), new GradientAlphaKey(0f, 1f) });
            var lifetime = air.colorOverLifetime;
            lifetime.enabled = true;
            lifetime.color = new ParticleSystem.MinMaxGradient(fade);
            var render = air.GetComponent<ParticleSystemRenderer>();
            render.sharedMaterial = effects;
            render.shadowCastingMode = ShadowCastingMode.Off;
            render.renderMode = ParticleSystemRenderMode.Billboard;
            render.maxParticleSize = .06f;
            if (pieces.Count < 15) throw new InvalidDataException($"Insufficient moving pieces in {name}.");
            root.gameObject.AddComponent<RoomEnvironmentMotion>().Configure(player, radius, pieces.ToArray(), arc, arcEnd, air);
        }

        private static void Pool(Transform parent, string name, Vector3 position, Color color, float intensity, float range)
        {
            var light = Group(parent, name, position).gameObject.AddComponent<Light>();
            light.type = LightType.Point;
            light.color = color;
            light.range = range;
            light.intensity = intensity;
            light.shadows = LightShadows.None;
        }

        private Material Glass(string name, Color color, Color accent)
        {
            var material = LoadOrCreate<Material>(name + ".mat", () => new Material(Shader.Find("Universal Render Pipeline/Lit")));
            material.SetColor("_BaseColor", color);
            material.SetFloat("_Metallic", .47f);
            material.SetFloat("_Smoothness", .92f);
            material.enableInstancing = true;
            material.EnableKeyword("_EMISSION");
            material.SetColor("_EmissionColor", accent * .135f);
            EditorUtility.SetDirty(material);
            return material;
        }

        private static Mesh ShardMesh()
        {
            return LoadOrCreate<Mesh>("Fractured laminate chip.asset", () =>
            {
                var corners = new[]
                {
                    new Vector3(-.45f, -.23f, .07f), new Vector3(.12f, -.61f, .04f),
                    new Vector3(.56f, .11f, .07f), new Vector3(-.09f, .59f, .04f),
                    new Vector3(-.10f, -.04f, .24f), new Vector3(.08f, .04f, -.12f)
                };
                var indices = new[] { 0, 1, 4, 1, 2, 4, 2, 3, 4, 3, 0, 4, 1, 0, 5, 2, 1, 5, 3, 2, 5, 0, 3, 5 };
                var mesh = new Mesh { name = "Fractured laminate chip", vertices = indices.Select(i => corners[i]).ToArray() };
                mesh.triangles = Enumerable.Range(0, indices.Length).ToArray();
                mesh.RecalculateNormals();
                mesh.RecalculateBounds();
                return mesh;
            });
        }

        private static Transform Surface(Transform parent, string name, Mesh mesh, Material material,
            Vector3 at, Vector3 size, Quaternion rotation)
        {
            var node = Group(parent, name, at);
            node.localScale = size;
            node.localRotation = rotation;
            node.gameObject.AddComponent<MeshFilter>().sharedMesh = mesh;
            var renderer = node.gameObject.AddComponent<MeshRenderer>();
            renderer.sharedMaterial = material;
            renderer.shadowCastingMode = ShadowCastingMode.Off;
            return node;
        }

        private static Transform Group(Transform parent, string name, Vector3 position, float yaw = 0f)
        {
            var node = new GameObject(name).transform;
            node.SetParent(parent, false);
            node.SetLocalPositionAndRotation(position, Quaternion.Euler(0f, yaw, 0f));
            return node;
        }

        private static Transform Descendant(Transform root, string name) =>
            root.GetComponentsInChildren<Transform>(true).Single(item => item.name == name);

        private static Mesh PrimitiveMesh(PrimitiveType type)
        {
            var primitive = GameObject.CreatePrimitive(type);
            var mesh = primitive.GetComponent<MeshFilter>().sharedMesh;
            Object.DestroyImmediate(primitive);
            return mesh;
        }

        private static Material Existing(string name) =>
            AssetDatabase.LoadAssetAtPath<Material>(AssetRoot + name + ".mat") ?? throw new FileNotFoundException(name);

        private static T LoadOrCreate<T>(string name, Func<T> create) where T : Object
        {
            var path = Folder + name;
            var value = AssetDatabase.LoadAssetAtPath<T>(path);
            if (value) return value;
            value = create();
            AssetDatabase.CreateAsset(value, path);
            return value;
        }

        private static float Unit(System.Random random) => (float)random.NextDouble() - .5f;

        private sealed class Batch
        {
            private readonly ChapterRoomEnvironmentArt art;
            private readonly Dictionary<Material, List<CombineInstance>> groups = new();

            internal Batch(ChapterRoomEnvironmentArt art) => this.art = art;

            internal void Block(Vector3 at, Vector3 size, Material material) =>
                Add(art.box, at, size, Quaternion.identity, material);

            internal void Beam(Vector3 start, Vector3 end, float width, float depth, Material material)
            {
                var delta = end - start;
                Add(art.box, (start + end) * .5f, new Vector3(width, delta.magnitude, depth),
                    Quaternion.FromToRotation(Vector3.up, delta), material);
            }

            internal void Pipe(Vector3 start, Vector3 end, float radius, Material material)
            {
                var delta = end - start;
                Add(art.cylinder, (start + end) * .5f, new Vector3(radius * 2f, delta.magnitude * .5f, radius * 2f),
                    Quaternion.FromToRotation(Vector3.up, delta), material);
            }

            internal void Rim(float x, float y, float cut, float width, float z, Material material)
            {
                var outline = new[]
                {
                    new Vector3(-x + cut, -y, z), new Vector3(x - cut, -y, z), new Vector3(x, -y + cut, z),
                    new Vector3(x, y - cut, z), new Vector3(x - cut, y, z), new Vector3(-x + cut, y, z),
                    new Vector3(-x, y - cut, z), new Vector3(-x, -y + cut, z)
                };
                for (var i = 0; i < outline.Length; i++)
                    Beam(outline[i], outline[(i + 1) % outline.Length], width, width, material);
            }

            internal void Crack(Vector2 origin, float z, int seed, Material body, Material bright)
            {
                var rng = new System.Random(seed);
                for (var i = 0; i < 9; i++)
                {
                    var angle = i * Mathf.PI * 2f / 9 + Unit(rng) * .34f;
                    var direction = new Vector2(Mathf.Cos(angle), Mathf.Sin(angle));
                    var a = origin;
                    for (var step = 0; step < 4; step++)
                    {
                        var b = a + direction * (.12f + .22f * (float)rng.NextDouble()) + new Vector2(Unit(rng), Unit(rng)) * .17f;
                        b.x = Mathf.Clamp(b.x, -2.98f, 2.98f);
                        b.y = Mathf.Clamp(b.y, -1.19f, 1.19f);
                        if ((b - a).sqrMagnitude < .001f) break;
                        Beam(new Vector3(a.x, a.y, z), new Vector3(b.x, b.y, z), .012f - step * .0019f,
                            .003f, step == 0 && i % 3 == 0 ? bright : body);
                        a = b;
                    }
                }
            }

            private void Add(Mesh mesh, Vector3 at, Vector3 size, Quaternion rotation, Material material)
            {
                if (!groups.TryGetValue(material, out var pieces))
                    groups.Add(material, pieces = new List<CombineInstance>());
                pieces.Add(new CombineInstance { mesh = mesh, transform = Matrix4x4.TRS(at, rotation, size) });
            }

            internal void Commit(Transform node, string name)
            {
                foreach (var entry in groups)
                {
                    var assetName = new string((name + " " + entry.Key.name).Select(c => char.IsLetterOrDigit(c) ? c : '_').ToArray());
                    var mesh = LoadOrCreate<Mesh>(assetName + ".asset", () => new Mesh { name = name + " " + entry.Key.name });
                    mesh.Clear();
                    mesh.CombineMeshes(entry.Value.ToArray(), true, true);
                    mesh.RecalculateBounds();
                    EditorUtility.SetDirty(mesh);
                    Surface(node, entry.Key.name, mesh, entry.Key, Vector3.zero, Vector3.one, Quaternion.identity);
                }
            }
        }
    }
}
