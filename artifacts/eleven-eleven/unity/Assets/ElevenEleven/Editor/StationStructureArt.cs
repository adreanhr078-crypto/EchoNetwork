using System.Linq;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using static ElevenEleven.Editor.GodotRoomAssembly;

namespace ElevenEleven.Editor
{
    internal static class StationStructureArt
    {
        internal const string PylonAsset = "Assets/ElevenEleven/Opening/Stormworks/StationFinishes/ObservationPylon-Tripo.glb";

        internal static void Dress(Transform assembly, Transform original, Material body, Material steel, Material copper,
            Material gasket, Material teal, Material amber)
        {
            var root = Node(assembly, "Rebuilt station infrastructure", Vector3.zero);
            foreach (var name in new[] {
                "Chronostat headwall", "Intake superstructure", "Observation superstructure", "West resonator tower",
                "East resonator tower", "West turbine bank", "East turbine bank", "Overhead crossfeed",
                "Lab suspended pipes", "Left pump riser"
            })
                foreach (var renderer in original.Find(name).GetComponentsInChildren<Renderer>())
                    renderer.enabled = false;

            var pylon = AssetDatabase.LoadAssetAtPath<GameObject>(PylonAsset);
            BuildPortal(root, "Intake gantry", new Vector3(-15.0f, 0f, 44f), 6.4f, 9.3f, body, steel, gasket, teal, pylon);
            BuildPortal(root, "Observation gantry", new Vector3(15.0f, 0f, 45f), 9.5f, 10.75f, body, steel, gasket, amber, pylon);
            BuildStationHeadwall(root, body, steel, copper, teal);

            BuildResonator(root, new Vector3(-9.8f, -2.2f, 61.4f), body, steel, copper, teal);
            BuildResonator(root, new Vector3(22.6f, -2.2f, 61.8f), body, steel, copper, teal);
            BuildTurbine(root, new Vector3(-19.0f, -1.12f, 59.5f), body, steel, gasket, amber);
            BuildTurbine(root, new Vector3(20.15f, -1.12f, 53.4f), body, steel, gasket, teal);
            BuildLabFace(root, body, steel, copper, gasket, teal);

            for (var rail = 0; rail < 3; rail++)
            {
                var offset = rail * 0.41f;
                Pipe(root, "Reservoir pressure crossfeed", rail == 0 ? copper : steel,
                    new Vector3(-6.0f, -1.78f - offset, 76.6f + offset), new Vector3(6.0f, -1.78f - offset, 76.6f + offset),
                    0.26f);
                Pipe(root, "Suspended laboratory supply pipe", rail == 1 ? copper : steel,
                    new Vector3(11.05f, 5.55f + offset, 68.7f), new Vector3(18.98f, 5.55f + offset, 68.7f),
                    0.16f);
            }
            Pipe(root, "Vertical intake return", steel, new Vector3(-6.1f, -4.4f, 61.1f), new Vector3(-6.1f, 6.8f, 61.1f), 0.34f);
            Pipe(root, "Vertical return service sleeve", body, new Vector3(-6.1f, 1.7f, 61.1f), new Vector3(-6.1f, 4.8f, 61.1f), 0.51f);
            Box(root, "Intake return inspection hatch", gasket, new Vector3(-6.07f, 3.00f, 60.57f), new Vector3(0.65f, 1.06f, 0.14f));
        }

        private static void BuildPortal(Transform root, string name, Vector3 at, float width, float height,
            Material body, Material steel, Material seal, Material indicator, GameObject donor)
        {
            var portal = Node(root, name, at);
            for (var side = -1; side <= 1; side += 2)
            {
                var x = side * width * 0.5f;
                Box(portal, "Cast isolation shoe", seal, new Vector3(x, -0.25f, 0), new Vector3(1.70f, 0.57f, 1.95f));
                Box(portal, "Steel load path", body, new Vector3(x, height * .5f, 0), new Vector3(1.21f, height, 1.48f));
                if (donor != null)
                    PlacePylon(portal, donor, new Vector3(x, 0.06f, -0.78f), height * 0.77f, 2.00f);
                Box(portal, "High gusset plate", steel, new Vector3(x, height - .29f, -.43f),
                    new Vector3(1.57f, .64f, .73f));
                Pipe(portal, "Gantry external cable carrier", steel, new Vector3(x + side * .68f, .22f, -.31f),
                    new Vector3(x + side * .68f, height - .2f, -.31f), .091f);
                Box(portal, "Locator light recess", seal, new Vector3(x, height * 0.90f, -.77f), new Vector3(.61f, .30f, .11f));
                Box(portal, "Locator light", indicator, new Vector3(x, height * 0.90f, -.835f), new Vector3(.45f, .095f, .041f));
            }
            Box(portal, "Welded gantry cap beam", body, new Vector3(0, height + .08f, 0), new Vector3(width + 1.90f, 1.05f, 1.67f));
            Box(portal, "Cap beam maintenance liner", steel, new Vector3(0, height + .08f, -.86f), new Vector3(width + .57f, .46f, .09f));
            Box(portal, "Cap beam recessed joint", seal, new Vector3(0, height - .14f, -.915f), new Vector3(width + .25f, .10f, .07f));
            Box(portal, "Under-beam wayfinding lens", indicator, new Vector3(0, height - .47f, -.25f), new Vector3(width * .80f, .06f, .16f));
        }

        private static void PlacePylon(Transform parent, GameObject prefab, Vector3 foot, float height, float width)
        {
            var instance = (GameObject)PrefabUtility.InstantiatePrefab(prefab, parent);
            instance.name = "Tripo observation pylon cladding";
            // The donor's status lenses lie on its +X side in glTF, or -X after import.
            instance.transform.localRotation = Quaternion.Euler(0f, -90f, 0f);
            var renderers = instance.GetComponentsInChildren<Renderer>();
            var bounds = renderers.Select(item => item.bounds).Aggregate((a, b) => { a.Encapsulate(b); return a; });
            var scale = Mathf.Min(height / bounds.size.y, width / bounds.size.x);
            instance.transform.localScale *= scale;
            var worldAnchor = parent.TransformPoint(foot);
            var localAttachment = new Vector3(bounds.center.x, bounds.min.y, bounds.max.z);
            instance.transform.position += worldAnchor - (instance.transform.position + (localAttachment - instance.transform.position) * scale);
            foreach (var collider in instance.GetComponentsInChildren<Collider>(true))
                Object.DestroyImmediate(collider);
            foreach (var item in renderers)
                item.shadowCastingMode = ShadowCastingMode.Off;
        }

        private static void BuildStationHeadwall(Transform root, Material body, Material steel, Material copper, Material guide)
        {
            Box(root, "Chronostat foundation shell", body, new Vector3(0, 2.00f, 84.4f), new Vector3(24.0f, 5.28f, 2.26f));
            Box(root, "Reinforced foundation header", steel, new Vector3(0, 4.25f, 83.24f), new Vector3(21.7f, 0.42f, 0.25f));
            for (var index = -4; index <= 4; index++)
            {
                var x = index * 2.32f;
                Box(root, "Foundation galvanised seam", steel, new Vector3(x, 2.10f, 83.249f), new Vector3(.095f, 3.72f, .10f));
                if (Mathf.Abs(index) < 2) continue;
                Pipe(root, "Foundation riser return", copper, new Vector3(x + .38f, -.38f, 83.078f),
                    new Vector3(x + .38f, 4.12f, 83.078f), .126f);
                Box(root, "Foundation status inset", guide, new Vector3(x-.45f, 3.56f, 83.20f), new Vector3(.22f,.06f,.03f));
            }
        }

        private static void BuildResonator(Transform root, Vector3 at, Material body, Material steel, Material copper, Material light)
        {
            var machine = Node(root, "Aeration resonator", at);
            Pipe(machine, "Resonator pressure drum", body, new Vector3(0f, .52f, 0f), new Vector3(0f, 8.96f, 0f), .88f);
            foreach (var y in new[] { 0.54f, 2.14f, 6.70f, 8.66f })
                Pipe(machine, "Resonator machined flange", steel, new Vector3(0f, y, 0f), new Vector3(0f, y + .26f, 0f), 1.11f);
            Box(machine, "Resonator access hatch", steel, new Vector3(0f, 4.2f, -.911f), new Vector3(.83f, 2f, .23f));
            Box(machine, "Resonator cycle lamp", light, new Vector3(0f, 4.97f, -1.04f), new Vector3(.48f,.09f,.055f));
            foreach (var x in new[] { -1.30f, 1.30f })
                Pipe(machine, "Vent return conduit", copper, new Vector3(x, .22f, .11f), new Vector3(x, 7.2f, .11f), .17f);
        }

        private static void BuildTurbine(Transform root, Vector3 at, Material body, Material steel, Material gasket, Material guide)
        {
            var unit = Node(root, "Pump and turbine assembly", at);
            Box(unit, "Pump mounting bed", gasket, new Vector3(0f, .43f, 0f), new Vector3(3.07f, .65f, 3.10f));
            Pipe(unit, "Turbine drum", body, new Vector3(0f, 2.10f, -1.10f), new Vector3(0f, 2.10f, 1.45f), 1.15f);
            Pipe(unit, "Machined turbine front ring", steel, new Vector3(0, 2.1f, -1.29f), new Vector3(0, 2.1f, -1.03f), 1.21f);
            Pipe(unit, "Turbine axle", gasket, new Vector3(0, 2.10f, -1.39f), new Vector3(0, 2.10f, -1.26f), .55f);
            for (var blade = 0; blade < 8; blade++)
            {
                var angle = blade * 45f;
                var direction = Quaternion.Euler(0,0,angle) * Vector3.up;
                Box(unit, "Ribbed turbine grille", steel, new Vector3(0,2.1f,-1.41f) + direction * .77f,
                    new Vector3(.13f,.42f,.12f)).localRotation = Quaternion.Euler(0,0,angle);
            }
            Box(unit, "Pump service indicator", guide, new Vector3(0, .64f, -1.59f), new Vector3(.72f,.096f,.073f));
        }

        private static void BuildLabFace(Transform root, Material body, Material steel, Material copper, Material gasket, Material guide)
        {
            Box(root, "Laboratory canopy edge frame", body, new Vector3(15.0f, 4.68f, 62.67f), new Vector3(7.9f, .47f, .37f));
            Box(root, "Laboratory fascia groove", steel, new Vector3(15f, 4.69f, 62.456f), new Vector3(7.61f, .15f, .072f));
            foreach (var x in new[] { 12.32f, 17.68f })
            {
                Box(root, "Laboratory facade access panel", body, new Vector3(x,2.15f,62.71f), new Vector3(1.31f,3.1f,.17f));
                Box(root, "Laboratory serviced zone liner", gasket, new Vector3(x,2.38f,62.599f), new Vector3(.82f,1.6f,.082f));
                for (var row = 0; row < 7; row++)
                    Box(root, "Facade ventilation louvre", steel, new Vector3(x,1.90f+row*.145f,62.546f),
                        new Vector3(.63f,.052f,.071f)).localRotation = Quaternion.Euler(15f,0f,0f);
                Box(root, "Facade brass service handle", copper, new Vector3(x-.31f,1.18f,62.568f), new Vector3(.11f,.34f,.066f));
                Box(root, "Facade threshold indicator", guide, new Vector3(x,3.30f,62.607f), new Vector3(.64f,.072f,.051f));
            }
        }

        private static Transform Box(Transform root, string name, Material mat, Vector3 position, Vector3 size) =>
            Visual(root, name, PrimitiveType.Cube, mat, position, size);

        private static void Pipe(Transform root, string name, Material mat, Vector3 start, Vector3 end, float radius)
        {
            var span = end - start;
            var pipe = Visual(root, name, PrimitiveType.Cylinder, mat, (start + end) * .5f,
                new Vector3(radius * 2, span.magnitude * .5f, radius * 2));
            pipe.localRotation = Quaternion.FromToRotation(Vector3.up, span.normalized);
        }

        private static Transform Visual(Transform root, string name, PrimitiveType mesh, Material mat, Vector3 position, Vector3 size)
        {
            var item = GameObject.CreatePrimitive(mesh);
            item.name = name;
            item.transform.SetParent(root, false);
            item.transform.localPosition = position;
            item.transform.localScale = size;
            var renderer = item.GetComponent<MeshRenderer>();
            renderer.sharedMaterial = mat;
            renderer.shadowCastingMode = ShadowCastingMode.Off;
            Object.DestroyImmediate(item.GetComponent<Collider>());
            return item.transform;
        }
    }
}
