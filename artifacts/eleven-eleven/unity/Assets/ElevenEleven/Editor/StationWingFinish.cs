using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using static ElevenEleven.Editor.GodotRoomAssembly;
using Object = UnityEngine.Object;

namespace ElevenEleven.Editor
{
    internal static class StationWingFinish
    {
        private const string Folder = "Assets/ElevenEleven/Opening/Stormworks/";
        private const string Scene = "Assets/ElevenEleven/Scenes/ChapterRoom01.unity";
        private const string Finish = "Station wing finish";

        public static void UpgradeAndReview()
        {
            var scene = EditorSceneManager.OpenScene(Scene);
            var station = scene.GetRootGameObjects().Single(root => root.name == "Room content").transform.Find("Echo Station");
            var observatory = station.Find("Memory Observatory");
            if (observatory != null) MemoryObservatoryArt.ClearSecurityEnvelope(observatory);
            var specimens = station.Find("Specimen containment/Native Godot specimen geometry");
            var specimenFloor = Find(specimens, "Floor").GetComponentInChildren<MeshRenderer>(true);
            ContainmentMaterials.Specimens(specimens, specimenFloor.sharedMaterial);
            Dress(station);
            if (!EditorSceneManager.SaveScene(scene)) throw new IOException("Could not save the station wing finishes.");
            Debug.Log("ECHO_STATION_WINGS_SAVED");
            MemoryObservatoryArt.WarmShaders();
            if (Environment.GetEnvironmentVariable("ECHO_STATION_WINGS_CONNECTED") == "1")
                ChapterR01Smoke.RunConnected();
            else
                StormworksSmoke.Run();
        }

        internal static void Dress(Transform station)
        {
            var steel = LoadMaterial("Echo Station brushed frame");
            var casing = LoadMaterial("Casing recess");
            var deck = LoadMaterial("Echo Station bridge deck");
            var copper = LoadMaterial("Coolant copper collars");
            var teal = LoadMaterial("Echo Station aqua lens");
            var amber = LoadMaterial("Echo Station amber lens");
            var violet = LoadMaterial("Examination violet indicator");

            Security(station.Find("Security wing"), steel, casing, deck, teal, amber);
            Specimens(station.Find("Specimen containment"), steel, casing, teal, amber);
            Archive(station.Find("Memory archive wing"), steel, casing, copper, violet);
            Reactor(station.Find("Reserve reactor wing"), steel, casing, copper, deck, teal, amber);
            Quarantine(station.Find("Decontamination and quarantine"), steel, casing, deck, teal);
            Surveillance(station.Find("Surveillance and mirror"), steel, casing, deck, teal);
        }

        private static void Security(Transform room, Material steel, Material casing, Material deck, Material teal, Material amber)
        {
            var finish = Reset(room);
            var art = room.Find("Native Godot security geometry");
            Paint(Find(art, "Floor"), deck);
            Paint(Find(art, "SixMeasuredSecurityCoverCabinets"), steel);
            var shutter = room.Find("Security sector shutter");
            Paint(shutter, steel);

            foreach (var x in new[] { -1.12f, 1.12f })
            {
                Cube(finish, "Recessed gate guide", new Vector3(x, 1.43f, 16.37f), new Vector3(.19f, 2.84f, .22f), steel);
                Cube(finish, "Gate guide optic", new Vector3(x, 2.37f, 16.24f), new Vector3(.071f, .51f, .035f), teal);
            }
            Cube(finish, "Security gate lintel", new Vector3(0f, 2.86f, 16.37f), new Vector3(2.48f, .22f, .28f), casing);
            for (var z = 2.65f; z < 15f; z += 2.35f)
            {
                foreach (var x in new[] { -2.48f, 2.48f })
                {
                    Cube(finish, "Recessed scan lane marker bed", new Vector3(x, .012f, z),
                        new Vector3(.23f, .025f, .56f), casing);
                    Cube(finish, "Inset scan lane marker", new Vector3(x, .027f, z),
                        new Vector3(.09f, .014f, .38f), amber);
                }
            }
            var console = room.Find("Scanner diversion console").localPosition;
            Cube(finish, "Diversion console face", console + new Vector3(-.43f, .36f, 0),
                new Vector3(.26f, .67f, .54f), steel);
            Cube(finish, "Diversion console readable optic", console + new Vector3(-.282f, .48f, 0),
                new Vector3(.035f, .13f, .35f), teal);
            MemoryObservatoryArt.LightKey(finish, "Forward checkpoint work light", new Vector3(0f, 4.42f, 5.4f),
                new Vector3(-2.1f, .6f, 10.1f), new Color(.63f,.81f,1f), 16f, 12f, 71f, true);
        }

        private static void Specimens(Transform room, Material steel, Material casing, Material teal, Material amber)
        {
            var finish = Reset(room);
            for (var index = 0; index < 6; index++)
            {
                var tank = Node(finish, "Specimen vessel restraints", new Vector3(-8f - index % 3 * 6f, 0, index < 3 ? 0f : 12f));
                var signal = index == 5 ? amber : teal;
                Cylinder(tank, "Isolation foot", new Vector3(0, .095f, 0), 1.13f, .18f, casing);
                Cylinder(tank, "Lower pressure flange", new Vector3(0, .23f, 0), 1.14f, .25f, steel);
                Cylinder(tank, "Upper pressure flange", new Vector3(0, 4.16f, 0), 1.13f, .24f, steel);
                for (var side = -1; side <= 1; side += 2)
                {
                    Cube(tank, "Vessel frame upright", new Vector3(side * 1.035f, 2.18f, -.27f),
                        new Vector3(.135f, 3.74f, .17f), steel);
                    Cube(tank, "Vessel frame latch", new Vector3(side * 1.035f, .57f, -.365f),
                        new Vector3(.157f, .42f, .12f), casing);
                }
                Cube(tank, "Record reader seat", new Vector3(0, .53f, -1.062f), new Vector3(.58f, .38f, .15f), casing);
                Cube(tank, "Record reader signal", new Vector3(0, .61f, -1.145f), new Vector3(.35f, .07f, .035f), signal);
            }
            MemoryObservatoryArt.LightKey(finish, "Containment directional light", new Vector3(-8f, 6.66f, 7.5f),
                new Vector3(-19.25f, 1.7f, 7.48f), new Color(.61f,.79f,.88f), 20f, 21f, 67f, true);
        }

        private static void Archive(Transform room, Material steel, Material casing, Material copper, Material violet)
        {
            var finish = Reset(room);
            var art = room.Find("Native Godot archive geometry");
            foreach (var item in art.GetComponentsInChildren<Transform>(true))
            {
                if (item.name.StartsWith("NorthRack_", StringComparison.Ordinal) ||
                    item.name.StartsWith("SouthRack_", StringComparison.Ordinal))
                    Paint(item, item.name.Contains("_Rung_") ? steel : casing);
            }
            var decoder = room.Find("Memory decoder reach").localPosition;
            Cube(finish, "Decoder cable trench", new Vector3(decoder.x, .019f, 5.3f), new Vector3(.48f,.025f,3.4f), casing);
            foreach (var side in new[] { -1f, 1f })
            {
                Cube(finish, "Decoder power rail", new Vector3(decoder.x + side * .31f, .035f, 5.3f),
                    new Vector3(.09f,.048f,3.4f), copper);
                Cube(finish, "Decoder inlay", new Vector3(decoder.x + side * .54f, .028f, 5.3f),
                    new Vector3(.065f,.032f,2.5f), violet);
                Cube(finish, "Decoder floor mount", new Vector3(decoder.x + side * .65f, .11f, 3.66f),
                    new Vector3(.34f,.22f,.68f), steel);
            }
            MemoryObservatoryArt.LightKey(finish, "Memory decoder cross light", new Vector3(-7f, 6.2f, 6.95f),
                new Vector3(-11f, 1.35f, 1.5f), new Color(.67f,.58f,.84f), 25f, 13f, 62f, true);
        }

        private static void Reactor(Transform room, Material steel, Material casing, Material copper, Material deck,
            Material teal, Material amber)
        {
            var finish = Reset(room);
            var art = room.Find("Native Godot reactor geometry");
            var core = Find(art, "ReactorCore");
            Paint(core, steel);
            Paint(Find(art, "AbyssFloor"), deck);
            Paint(room.Find("Reserve power conduit floor"), deck);
            var shaft = Node(finish, "Reactor field assembly", room.InverseTransformPoint(core.position));
            foreach (var y in new[] { -5.78f, -2.25f, 1.2f, 5.04f })
            {
                var radius = Mathf.Lerp(4.83f, 4.25f, (y + 5.8f) / 10.9f);
                Cylinder(shaft, "Machined reactor pressure collar", new Vector3(0,y,0), radius,.38f,casing);
                Cylinder(shaft, "Reactor pressure collar metal edge", new Vector3(0,y+.21f,0), radius-.035f,.104f,steel);
            }
            for (var index = 0; index < 10; index++)
            {
                var turn = Quaternion.Euler(0, index * 36f, 0);
                var outward = turn * Vector3.forward;
                Tube(shaft, "Reactor external coolant return", outward * 4.58f + Vector3.down * 5.7f,
                    outward * 4.11f + Vector3.up * 4.8f, .17f, index % 2 == 0 ? copper : steel);
                var foot = outward * 4.48f + Vector3.down * 1.7f;
                Cube(shaft, "Reactor thermal pickup backing", foot, new Vector3(.52f,1.67f,.21f), casing).localRotation = turn;
                Cube(shaft, "Reactor thermal pickup optic", foot + outward * .128f, new Vector3(.24f,1.24f,.061f),
                    index % 2 == 0 ? amber : teal).localRotation = turn;
            }
            foreach (var x in new[] { -16.9f, 16.9f })
            {
                for (var z = 4.5f; z < 42f; z += 6.2f)
                    Cube(finish, "Reactor wall structural rib", new Vector3(x,-2.1f,z), new Vector3(.54f,15.8f,.38f), steel);
                foreach (var y in new[] { -7.7f, 1.1f, 4.7f })
                    Tube(finish, "Reactor wall coolant main", new Vector3(x,y,2.45f), new Vector3(x,y,41.95f),
                        y < 0 ? .23f : .14f, y < 0 ? copper : casing);
            }
            MemoryObservatoryArt.LightKey(finish, "Reactor shaft oblique key", new Vector3(-7.5f, 5.7f, 13.1f),
                new Vector3(0f, -2.7f, 22f), new Color(.62f,.77f,.92f), 41f, 25f, 51f, true);
            MemoryObservatoryArt.LightKey(finish, "Reserve core warm return", new Vector3(9.9f, 1.8f, 27.8f),
                new Vector3(0f, -4.4f, 22f), new Color(1f,.52f,.26f), 25f, 17f, 68f);
        }

        private static void Quarantine(Transform room, Material steel, Material casing, Material deck, Material teal)
        {
            var finish = Reset(room);
            var art = room.Find("Godot quarantine architecture");
            Paint(Find(art, "Floor"), deck);
            Paint(Find(art, "ObservationCatwalkDeck"), deck);
            foreach (var item in art.GetComponentsInChildren<Transform>(true))
            {
                if (item.name.StartsWith("QuarantinePod_", StringComparison.Ordinal) &&
                    item.name.EndsWith("PreciseVessel", StringComparison.Ordinal))
                    Paint(item, steel);
            }
            for (var z = 13f; z < 28f; z += 3.15f)
            {
                foreach (var x in new[] { -2f, 2f })
                {
                    Cube(finish, "Rinse channel service cover", new Vector3(x,.022f,z), new Vector3(.26f,.04f,1.4f), steel);
                    Cube(finish, "Rinse channel recessed joint", new Vector3(x,.044f,z), new Vector3(.078f,.01f,1.26f), casing);
                }
            }
            Cube(finish, "Decontamination lift position optic", new Vector3(0f,3.83f,16f),
                new Vector3(.74f,.06f,.10f), teal);
            MemoryObservatoryArt.LightKey(finish, "Raised decontamination walkway light", new Vector3(2.7f, 6.45f, 9.6f),
                new Vector3(0f, 1.1f, 18.0f), new Color(.69f,.88f,.87f), 24f, 17f, 68f, true);
        }

        private static void Surveillance(Transform room, Material steel, Material casing, Material deck, Material teal)
        {
            var finish = Reset(room);
            var art = room.Find("Godot surveillance architecture");
            Paint(Find(art, "Floor"), deck);
            Paint(Find(art, "CommandDaisDeck"), deck);
            Paint(Find(art, "MirrorBacking"), casing);
            foreach (var x in new[] { -2.17f, 2.17f })
            {
                Cube(finish, "Command dais casing", new Vector3(x, 2.12f, 17.95f),
                    new Vector3(.42f,.44f,.72f), casing);
                Cube(finish, "Dais retaining frame", new Vector3(x, 2.38f, 17.95f),
                    new Vector3(.48f,.11f,.83f), steel);
                Cube(finish, "Command dais locator optic", new Vector3(x, 2.23f, 17.577f),
                    new Vector3(.31f,.055f,.043f), teal);
            }
            MemoryObservatoryArt.LightKey(finish, "Inspection mirror face light", new Vector3(5.1f, 4.45f, 7.35f),
                new Vector3(7.92f, 1.8f, 10f), new Color(.59f,.78f,.90f), 11f, 8f, 57f, true);
        }

        private static Transform Reset(Transform room)
        {
            var current = room.Find(Finish);
            if (current != null) Object.DestroyImmediate(current.gameObject);
            return Node(room, Finish, Vector3.zero);
        }

        private static Material LoadMaterial(string name) =>
            AssetDatabase.LoadAssetAtPath<Material>(Folder + name + ".mat") ?? throw new FileNotFoundException(name);

        private static void Paint(Transform parent, Material material)
        {
            foreach (var renderer in parent.GetComponentsInChildren<MeshRenderer>(true))
                renderer.sharedMaterial = material;
        }

        private static Transform Cube(Transform root, string name, Vector3 at, Vector3 size, Material material) =>
            Shape(root, name, PrimitiveType.Cube, at, size, material);

        private static Transform Cylinder(Transform root, string name, Vector3 at, float radius, float height, Material material) =>
            Shape(root, name, PrimitiveType.Cylinder, at, new Vector3(radius * 2f, height * .5f, radius * 2f), material);

        private static void Tube(Transform root, string name, Vector3 start, Vector3 end, float radius, Material material)
        {
            var delta = end - start;
            var tube = Cylinder(root, name, (start + end) * .5f, radius, delta.magnitude, material);
            tube.localRotation = Quaternion.FromToRotation(Vector3.up, delta);
        }

        private static Transform Shape(Transform root, string name, PrimitiveType primitive, Vector3 at, Vector3 size, Material material)
        {
            var item = GameObject.CreatePrimitive(primitive);
            item.name = name;
            item.transform.SetParent(root, false);
            item.transform.localPosition = at;
            item.transform.localScale = size;
            Object.DestroyImmediate(item.GetComponent<Collider>());
            var renderer = item.GetComponent<MeshRenderer>();
            renderer.sharedMaterial = material;
            renderer.shadowCastingMode = ShadowCastingMode.Off;
            return item.transform;
        }
    }
}
