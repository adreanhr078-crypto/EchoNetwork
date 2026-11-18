using ElevenEleven.Opening;
using UnityEditor;
using UnityEngine;
using static ElevenEleven.Editor.GodotRoomAssembly;

namespace ElevenEleven.Editor
{
    internal static class StationQuarantineConstruction
    {
        private const string Folder = "Assets/ElevenEleven/Opening/Stormworks/";
        private const float LineX = -35.5f;
        private const float LineY = 4f;
        internal const float QuarantineZ = 201f;
        internal const float SurveillanceZ = 242f;
        private static readonly Color Teal = new Color(0.06f, 0.87f, 0.78f);
        private static readonly Color Purple = new Color(0.50f, 0.22f, 1f);
        private static readonly Color Amber = new Color(1f, 0.42f, 0.09f);

        internal static StationQuarantineWing BuildQuarantine(Transform station, Material frame, Material deck,
            Material cyan, Material amber)
        {
            var root = Node(station, "Decontamination and quarantine", new Vector3(LineX, LineY, QuarantineZ));
            var art = PlaceArt(root, Folder + "Decon-Godot-Art.glb", "Godot quarantine architecture");
            var gate = Find(art, "NorthExitBlastGate");
            Collisions(root, "decontamination_quarantine_wing", name => name == "NorthExitBlastGate" ? gate : null);
            Link(root, -10.04f, 0.03f, frame, deck, cyan, "Reactor extraction link");
            StationWallDressing.Quarantine(root, cyan);
            var console = Node(root, "Quarantine console reach", new Vector3(0, 3.68f, 16f));
            var status = Pool(root, "Quarantine console status", new Vector3(0, 5.1f, 16f), Amber, 5.9f, 8f);
            var mist = Node(root, "Atmospheric extraction standpipes", Vector3.zero);
            var positions = new[] { new Vector3(-1.62f, 1.35f, 3.5f), new Vector3(1.62f, 1.35f, 3.5f),
                new Vector3(1.62f, 1.35f, 6.5f), new Vector3(-1.62f, 1.35f, 6.5f) };
            for (var i = 0; i < positions.Length; ++i)
                StormworksConstruction.Effect(mist, "Quarantine vapor", positions[i], new Vector2(1.42f, 2.6f),
                    0, 0.56f, Purple * 1.6f, i * 2.1f, false, i % 2 == 0 ? 33f : -32f);
            foreach (var z in new[] { 3.5f, 6.5f })
            {
                Pool(root, "Quarantine gate spill", new Vector3(0, 3.64f, z), Purple, 7f, 7f);
                Trim(root, "Gate optic", new Vector3(0f, 3.69f, z - 0.17f),
                    new Vector3(3.12f, 0.042f, 0.08f), cyan);
            }
            for (var z = 10f; z < 14.4f; z += 1.1f)
            {
                var rampY = Mathf.Lerp(0.38f, 3.0f, Mathf.InverseLerp(9.1f, 14.35f, z));
                Trim(root, "West ramp step marker", new Vector3(-9.23f, rampY, z),
                    new Vector3(0.10f, 0.038f, 0.22f), amber);
            }
            Pool(root, "West approach flood", new Vector3(-8.3f, 4.2f, 10f), Amber, 6.0f, 12f);
            Pool(root, "Pod banks", new Vector3(6.2f, 5.36f, 17f), Teal, 8.1f, 15f);
            Pool(root, "Exit bulkhead", new Vector3(0, 3.3f, 30.8f), Teal, 5.8f, 8f);
            var extraction = Node(root, "Vapor extraction sound", new Vector3(0, 2.65f, 5f)).gameObject.AddComponent<AudioSource>();
            extraction.clip = AssetDatabase.LoadAssetAtPath<AudioClip>("Assets/ElevenEleven/Opening/Media/PressureAir.wav");
            extraction.playOnAwake = false;
            extraction.loop = true;
            extraction.spatialBlend = 1f;
            extraction.dopplerLevel = 0f;
            extraction.minDistance = 1.5f;
            extraction.maxDistance = 18f;
            extraction.volume = 0.17f;

            var wing = root.gameObject.AddComponent<StationQuarantineWing>();
            StormworksConstruction.Wire(wing, ("gate", gate), ("console", console), ("status", status),
                ("mist", mist.gameObject), ("extraction", extraction));
            return wing;
        }

        internal static StationSurveillanceWing BuildSurveillance(Transform station, Material frame, Material deck,
            Material cyan, Material amber)
        {
            var root = Node(station, "Surveillance and mirror", new Vector3(LineX, LineY, SurveillanceZ));
            var art = PlaceArt(root, Folder + "Mirror-Godot-Art.glb", "Godot surveillance architecture");
            var gate = Find(art, "SurveillanceExitGate");
            Collisions(root, "mirror_chamber_room", name => name == "SurveillanceExitGate" ? gate : null);
            Link(root, QuarantineZ + StationQuarantineWing.Depth - SurveillanceZ - 0.04f, 0.04f,
                frame, deck, cyan, "Filtered connector");
            Link(root, 35.93f, 39.04f, frame, deck, cyan, "Examination wing landing");
            Block(root, "Examination wing interlock", new Vector3(0, 1.56f, 39.05f),
                new Vector3(2.58f, 3.12f, 0.32f), frame);
            var terminal = Node(root, "Surveillance console reach", new Vector3(0f, 2.91f, 18f));
            var mirror = Node(root, "Surveillance mirror reach", new Vector3(7.32f, 0.85f, 10f));

            var grid = Node(root, "Surveillance scanner grid", Vector3.zero);
            foreach (var z in StationSurveillanceWing.ScannerDepths)
            {
                foreach (var renderer in art.GetComponentsInChildren<MeshRenderer>(true))
                {
                    var position = root.InverseTransformPoint(renderer.transform.position);
                    if (Vector3.Distance(position, new Vector3(0f, 1.2f, z)) < 0.018f)
                        renderer.enabled = false;
                }
                Trim(grid, "Scanner optical channel", new Vector3(0, 1.2f, z),
                    new Vector3(2f * StationSurveillanceWing.ScannerHalfWidth, 0.035f, 0.035f), amber);
                Trim(grid, "Scanner receiver", new Vector3(StationSurveillanceWing.ScannerHalfWidth, 1.24f, z),
                    new Vector3(0.12f, 0.27f, 0.12f), amber);
                Trim(grid, "Scanner emitter", new Vector3(-StationSurveillanceWing.ScannerHalfWidth, 1.24f, z),
                    new Vector3(0.12f, 0.27f, 0.12f), amber);
            }
            var mirrorStatus = Pool(root, "Mirror inspection signal", new Vector3(7.62f, 2.78f, 10f), Amber, 2.4f, 7.0f);
            var daisStatus = Pool(root, "Master lockdown signal", new Vector3(0, 4.39f, 18f), Amber, 5.8f, 9f);
            Pool(root, "Approach light", new Vector3(-1.15f, 3.75f, 2f), Teal, 7f, 11f);
            Pool(root, "Command dais north key", new Vector3(-4.7f, 6f, 20.7f), Purple, 8f, 16f);
            Pool(root, "Reflection bounce", new Vector3(4.5f, 3.55f, 10f), Teal, 2.6f, 8.1f);
            Pool(root, "Exit header", new Vector3(1.5f, 4.3f, 34.2f), Teal, 7.3f, 11f);
            StationWallDressing.Surveillance(root, cyan);
            var originalGlass = Find(art, "SurveillanceMirrorChamber");
            foreach (var renderer in originalGlass.GetComponentsInChildren<MeshRenderer>(true))
                renderer.enabled = false;
            BuildMirror(root);

            var wing = root.gameObject.AddComponent<StationSurveillanceWing>();
            StormworksConstruction.Wire(wing, ("mirror", mirror), ("console", terminal), ("gate", gate),
                ("mirrorSignal", mirrorStatus), ("consoleSignal", daisStatus), ("scannerGrid", grid.gameObject));
            return wing;
        }

        private static void BuildMirror(Transform root)
        {
            var surface = GameObject.CreatePrimitive(PrimitiveType.Quad).transform;
            surface.name = "Live two-way inspection mirror";
            surface.SetParent(root, false);
            surface.localPosition = new Vector3(8.295f, 1.6f, 10f);
            surface.localRotation = Quaternion.Euler(0f, 90f, 0f);
            surface.localScale = new Vector3(3.98f, 2.79f, 1f);
            Object.DestroyImmediate(surface.GetComponent<Collider>());
            var reflector = surface.gameObject.AddComponent<StationReflection>();
            var material = StormworksConstruction.PersistentMaterial("Surveillance inspection mirror", "StationReflection.shader");
            surface.GetComponent<MeshRenderer>().sharedMaterial = material;
            StormworksConstruction.Wire(reflector, ("surface", surface.GetComponent<MeshRenderer>()));
        }

        private static void Link(Transform root, float start, float end, Material frame, Material deck,
            Material guide, string name)
        {
            var localZ = (start + end) * 0.5f;
            var length = end - start;
            var connector = Node(root, name, new Vector3(0, 0, localZ));
            Block(connector, "Sealed link floor", new Vector3(0f, -0.24f, 0f), new Vector3(2.76f, 0.48f, length), deck);
            Block(connector, "Service ceiling", new Vector3(0f, 3.36f, 0f), new Vector3(2.88f, 0.32f, length), frame);
            foreach (var sign in new[] { -1f, 1f })
            {
                Block(connector, "Sealed link wall", new Vector3(sign * 1.36f, 1.58f, 0f),
                    new Vector3(0.23f, 3.36f, length), frame);
                Trim(connector, "Continuous route guide", new Vector3(sign * 1.17f, 0.045f, 0f),
                    new Vector3(0.045f, 0.035f, length * 0.95f), guide);
            }
            Pool(connector, "Link approach light", new Vector3(0, 2.83f, -length * 0.24f), Teal, 3.3f, 8f);
            Pool(connector, "Link arrival light", new Vector3(0, 2.83f, length * 0.24f), Teal, 3.3f, 8f);
        }

        private static void Trim(Transform root, string name, Vector3 position, Vector3 size, Material mat)
        {
            var item = Block(root, name, position, size, mat);
            Object.DestroyImmediate(item.GetComponent<Collider>());
        }

        private static Light Pool(Transform root, string name, Vector3 position, Color tint, float intensity, float range)
        {
            var light = Node(root, name, position).gameObject.AddComponent<Light>();
            light.type = LightType.Point;
            light.color = tint;
            light.intensity = intensity;
            light.range = range;
            return light;
        }
    }
}
