using System.IO;
using System.Linq;
using ElevenEleven.Opening;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using static ElevenEleven.Editor.GodotRoomAssembly;

namespace ElevenEleven.Editor
{
    internal static partial class ChapterWallFabrication
    {
        internal const string ReactorDeckFinish = "Reactor fitted service deck";

        public static void FinishReactorServiceDeck()
        {
            var scene = EditorSceneManager.OpenScene(ScenePath);
            var content = scene.GetRootGameObjects().Single(root => root.name == "Room content").transform;
            var station = content.Find("Echo Station");
            var reactor = station.GetComponentInChildren<StationReactorWing>(true);
            var route = station.GetComponent<StormworksRoute>();
            var authority = new Component[] { route, reactor };
            var authorityBefore = authority.Select(c => EditorJsonUtility.ToJson(c)).ToArray();
            var collision = content.GetComponentsInChildren<Collider>(true)
                .ToDictionary(c => c, c => (data: EditorJsonUtility.ToJson(c), matrix: c.transform.localToWorldMatrix));
            var balcony = reactor.transform.Find("Authored Godot collision/EntryBalconyDeck")?.GetComponent<BoxCollider>();
            var link = reactor.transform.Find("Authored Godot collision/EntryServiceLink")?.GetComponent<BoxCollider>();
            if (!balcony || !link || Mathf.Abs(balcony.size.x - 7f) > .01f || Mathf.Abs(link.size.x - 2.4f) > .01f)
                throw new InvalidDataException("The measured reactor deck collision volumes are required.");

            var palette = new[]
            {
                DeckMaterial("Surveillance worn graphite slabs", true), DeckMaterial("Station worked manganese alloy", true),
                DeckMaterial("Station annealed copper fixings", false), DeckMaterial("Surveillance grate and screw heads", true),
                DeckMaterial("R47 ochre service markers", false), DeckMaterial("Surveillance grit blasted aisle", true),
            };
            var root = ResetNamed(reactor.transform, ReactorDeckFinish);
            var platform = DeckPlane(root, balcony, "Central manganese and two recessed service trenches");
            SetDeckPanel(platform, "Reactor fitted balcony assembly", BalconyPlates(), palette);
            AddLegend(platform, "R-11", new Vector3(0f, -2.12f, .025f), .019f, new Color(.81f, .64f, .38f));
            AddLegend(platform, "SERVICE", new Vector3(0f, 1.98f, .025f), .010f, new Color(.78f, .75f, .63f));

            var connector = DeckPlane(root, link, "Recessed transverse service-link ribs");
            SetDeckPanel(connector, "Reactor fitted service link assembly", LinkPlates(), palette);
            var lamps = new Plates(1);
            lamps.Raised(0f, 0f, .037f, .23f, .013f, .023f, .005f, 0);
            var seed = Node(platform, "West bus lens 1", new Vector3(1.61f, -2f, 0f));
            var lensMaterial = DeckMaterial("R47 specimen status phosphor", false);
            SetPanel(seed, "Reactor fitted bus lens", lamps, new[] { lensMaterial });
            var mesh = seed.GetComponent<MeshFilter>().sharedMesh;
            var west = new Renderer[5];
            var east = new Renderer[5];
            west[0] = seed.GetComponent<Renderer>();
            for (var i = 0; i < 5; i++)
            {
                var z = -2f + i * .93f;
                if (i > 0) west[i] = Lens(platform, "West", i + 1, 1.61f, z, mesh, lensMaterial);
                east[i] = Lens(platform, "East", i + 1, -1.61f, z, mesh, lensMaterial);
            }
            var status = Lens(platform, "Service link", 1, 0f, 2.64f, mesh, lensMaterial);
            status.transform.localRotation = Quaternion.Euler(0f, 0f, 90f);
            using var signalData = new SerializedObject(root.gameObject.AddComponent<StationReactorDeckSignals>());
            signalData.FindProperty("route").objectReferenceValue = route;
            signalData.FindProperty("service").objectReferenceValue = status;
            SetLenses(signalData.FindProperty("west"), west);
            SetLenses(signalData.FindProperty("east"), east);
            signalData.ApplyModifiedPropertiesWithoutUndo();

            var after = content.GetComponentsInChildren<Collider>(true);
            if (!authorityBefore.SequenceEqual(authority.Select(c => EditorJsonUtility.ToJson(c))) || after.Length != collision.Count ||
                after.Any(c => !collision.TryGetValue(c, out var prior) || prior.data != EditorJsonUtility.ToJson(c) ||
                    prior.matrix != c.transform.localToWorldMatrix))
                throw new InvalidDataException("The fitted reactor deck changed route authority or collision.");
            AssetDatabase.SaveAssets();
            if (!EditorSceneManager.SaveScene(scene)) throw new IOException("Could not save the finished reactor deck.");
            Debug.Log($"ECHO_REACTOR_DECK_SAVED colliders={collision.Count} surfaces=2 pbr=4 fitted_signal_lenses=11");
        }

        private static Transform DeckPlane(Transform root, BoxCollider deck, string name)
        {
            var top = deck.transform.TransformPoint(deck.center + Vector3.up * (deck.size.y * .5f + .004f));
            var plane = Node(root, name, root.InverseTransformPoint(top));
            plane.localRotation = Quaternion.LookRotation(Vector3.up, Vector3.forward);
            return plane;
        }

        private static void SetDeckPanel(Transform plane, string name, Plates geometry, Material[] palette)
        {
            SetPanel(plane, name, geometry, palette);
            var mesh = plane.GetComponent<MeshFilter>().sharedMesh;
            mesh.uv = mesh.vertices.Select(point => new Vector2(point.x * .71f + point.z * .3f,
                point.y * .48f + point.z * .24f)).ToArray();
            mesh.RecalculateTangents();
            EditorUtility.SetDirty(mesh);
        }

        private static Plates BalconyPlates()
        {
            var deck = new Plates(6);
            deck.Raised(0f, 0f, 6.94f, 5.93f, .08f, .006f, .008f, 0);
            deck.Raised(0f, -1.48f, 2.91f, 2.76f, .145f, .019f, .018f, 1);
            deck.Raised(0f, .63f, 2.92f, 1.37f, .085f, .019f, .012f, 1);
            deck.Raised(0f, 1.83f, 2.93f, .97f, .075f, .019f, .014f, 5);
            deck.Raised(0f, 2.63f, 2.27f, .60f, .06f, .020f, .009f, 3);
            foreach (var side in new[] { -1f, 1f })
            {
                deck.Raised(side * 1.61f, 0f, .14f, 5.51f, .033f, .012f, .008f, 3);
                deck.Raised(side * 2.53f, -1.25f, 1.65f, 3.20f, .125f, .020f, .024f, 5);
                deck.Raised(side * 2.53f, 1.56f, 1.65f, 2.29f, .125f, .020f, .024f, 5);
                deck.Raised(side * 3.36f, 0f, .152f, 5.79f, .035f, .018f, .010f, 2);
                deck.Raised(side * 2.50f, 1.30f, .79f, .71f, .082f, .025f, .010f, 0);
                for (var i = 0; i < 4; i++)
                {
                    deck.Raised(side * 2.50f, 1.08f + i * .145f, .65f, .070f, .018f, .029f, .007f, 3);
                    deck.Bolt(side * 3.29f, -2.41f + i * 1.60f, .047f, .015f, .027f);
                    deck.Bolt(side * 1.84f, -2.41f + i * 1.60f, .039f, .015f, .025f);
                }
                for (var i = 0; i < 3; i++)
                    deck.Raised(side * (1.19f + .19f * i), 2.65f, .086f, .36f, .02f, .022f, .008f, 4);
            }
            return deck;
        }

        private static Plates LinkPlates()
        {
            var link = new Plates(6);
            link.Raised(0f, 0f, 2.36f, 1.46f, .04f, .009f, .006f, 0);
            for (var rung = -2; rung <= 2; rung++)
                link.Raised(0f, rung * .253f, 1.93f, .188f, .045f, .021f, .013f, 3);
            foreach (var side in new[] { -1f, 1f })
            {
                link.Raised(side * 1.08f, 0f, .16f, 1.43f, .04f, .022f, .012f, 2);
                link.Bolt(side * 1.08f, .48f, .045f, .02f, .028f);
                link.Bolt(side * 1.08f, -.48f, .045f, .02f, .028f);
            }
            return link;
        }

        private static Material DeckMaterial(string name, bool mapped)
        {
            var material = AssetDatabase.LoadAssetAtPath<Material>(Folder + name + ".mat");
            if (!material || mapped && (!material.GetTexture("_BaseMap") || !material.GetTexture("_BumpMap")))
                throw new InvalidDataException("Missing cached reactor deck material or maps: " + name);
            return material;
        }

        private static Renderer Lens(Transform plane, string circuit, int index, float x, float y, Mesh mesh, Material material)
        {
            var node = Node(plane, $"{circuit} bus lens {index}", new Vector3(x, y, 0f));
            node.gameObject.AddComponent<MeshFilter>().sharedMesh = mesh;
            var renderer = node.gameObject.AddComponent<MeshRenderer>();
            renderer.sharedMaterial = material;
            renderer.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            return renderer;
        }

        private static void SetLenses(SerializedProperty property, Renderer[] lenses)
        {
            property.arraySize = lenses.Length;
            for (var i = 0; i < lenses.Length; i++) property.GetArrayElementAtIndex(i).objectReferenceValue = lenses[i];
        }
    }
}
