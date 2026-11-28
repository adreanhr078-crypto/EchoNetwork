using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using static ElevenEleven.Editor.GodotRoomAssembly;

namespace ElevenEleven.Editor
{
    internal static partial class ChapterWallFabrication
    {
        private static void RefinePrecisionMechanisms(Transform station)
        {
            var graphite = AssetDatabase.LoadAssetAtPath<Material>(Folder + "R47 sterile graphite housing.mat");
            var enamel = AssetDatabase.LoadAssetAtPath<Material>(Folder + "R47 blue-grey sterile enamel.mat");
            var metal = AssetDatabase.LoadAssetAtPath<Material>(Folder + "Station worked manganese alloy.mat");
            var copper = AssetDatabase.LoadAssetAtPath<Material>(Art + "StationFinishes/Chronostat copper hardware.mat");
            var amber = AssetDatabase.LoadAssetAtPath<Material>(Folder + "R47 ochre service markers.mat");
            var palette = new[] { graphite, enamel, metal, copper, amber };
            var support = station.Find("Specimen containment/" + R47Record + "/Load-bearing recorder mount");
            var inductor = station.Find("Memory Laboratory inductor hardware");
            var reactor = station.Find("Reserve reactor wing");
            if (!support || !inductor || !reactor) throw new InvalidDataException("The approved precision mechanisms are missing.");
            DressRecorderMount(support, palette);
            DressLabInductorFeet(inductor, palette);
            FaceReactorBalconyGuards(reactor, palette);
            SuppressCollapsedReactorExports(reactor);
            Debug.Log("ECHO_R49_PRECISION_MOUNTS recorder=machined_independent_faces coil_feet=two_shared balcony_guards=four");
        }

        private static void SuppressCollapsedReactorExports(Transform reactor)
        {
            var model = reactor.Find("Native Godot reactor geometry");
            var paths = new[]
            {
                "WestPlatform/NativeEnvelopeAmberEdgeNosings", "WestPlatform/NativeDeckMachinedEdges6",
                "WestPlatform/MeasuredWalkableGrating46", "EastPlatform/NativeEnvelopeAmberEdgeNosings4",
                "EastPlatform/NativeDeckMachinedEdges11", "EastPlatform/MeasuredWalkableGrating101",
                "WestServiceAscent/NativeDeckMachinedEdges31", "WestServiceAscent/MeasuredWalkableGrating262",
                "EntryBalconyDeck/NativeDeckMachinedEdges", "EntryBalconyDeck/MeasuredWalkableGrating",
                "EntryServiceLink/NativeDeckMachinedEdges26", "EntryServiceLink/MeasuredWalkableGrating248"
            };
            var total = 0;
            foreach (var path in paths)
            {
                var group = model.Find(path);
                if (!group) throw new InvalidDataException("Missing surveyed glTF group: " + path);
                var meshes = group.GetComponentsInChildren<MeshRenderer>(true);
                if (meshes.Length < 2 || meshes.Any(r => r.transform.localPosition.sqrMagnitude > .0001f ||
                    r.bounds != meshes[0].bounds))
                    throw new InvalidDataException("Expected coincident exported renderers in " + path);
                foreach (var duplicate in meshes) duplicate.enabled = false;
                total += meshes.Length;
            }
            Debug.Log($"ECHO_R49_COLLAPSED_EXPORTS groups={paths.Length} renderers={total}");
        }

        private static void DressRecorderMount(Transform support, Material[] palette)
        {
            var finish = ResetNamed(support, "Meter leg with service hatch and isolating foot");
            var prefab = AssetDatabase.LoadAssetAtPath<GameObject>(Art + "Specimen-Godot-Art.glb");
            var casting = prefab.GetComponentsInChildren<MeshFilter>(true).Single(item => item.name == "MeasuredTerminalCase2");
            FitCachedDetail(finish, "Original measured terminal casting", casting.sharedMesh,
                new[] { palette[0], palette[1], palette[2] }, new Vector3(0f, -.034f, -.064f), new Vector3(.481f, 1.025f, .418f));
            support.Find("Cast graphite pedestal").GetComponent<MeshRenderer>().enabled = false;
            var faces = new List<(Mesh shape, Matrix4x4 pose)>();
            foreach (var direction in new[] { Vector3.back, Vector3.right, Vector3.forward, Vector3.left })
            {
                var wide = Mathf.Abs(direction.z) > .5f;
                var width = wide ? .427f : .394f;
                var plate = new Plates(palette.Length);
                plate.Raised(0f, -.016f, width, 1.02f, .034f, .012f, .009f, 0);
                plate.Raised(0f, .262f, width - .074f, .396f, .036f, .030f, .013f, 1);
                plate.Raised(0f, -.185f, width - .073f, .404f, .034f, .034f, .018f, 1);
                plate.Raised(0f, -.123f, width - .134f, .222f, .029f, .045f, .010f, 0);
                for (var i = 0; i < 5; i++)
                    plate.Raised(0f, -.046f - .034f * i, width - .165f, .013f, .004f, .052f, .003f, 2);
                foreach (var x in new[] { -.129f, .129f })
                foreach (var y in new[] { .417f, .121f, -.348f })
                    plate.Bolt(x, y, .014f, .027f, .047f);
                plate.Raised(wide ? .053f : 0f, .254f, .121f, .085f, .007f, .039f, .005f, 3);
                plate.Raised(wide ? .053f : 0f, .251f, .091f, .019f, .005f, .042f, .003f, 4);
                var distance = (wide ? .195f : .21f) + .003f;
                var offset = new Vector3(0f, -.036f, -.045f) + direction * distance;
                faces.Add((plate.Build("Meter leg side"), Matrix4x4.TRS(offset, Quaternion.LookRotation(direction, Vector3.up), Vector3.one)));
            }

            var shoe = new Plates(palette.Length);
            shoe.Raised(0f, 0f, .832f, .637f, .053f, .011f, .012f, 0);
            shoe.Raised(0f, 0f, .754f, .557f, .068f, .023f, .013f, 2);
            shoe.Raised(0f, 0f, .594f, .449f, .051f, .034f, .013f, 0);
            foreach (var x in new[] { -.314f, .314f })
            foreach (var z in new[] { -.219f, .219f })
            {
                shoe.Raised(x, z, .083f, .068f, .013f, .029f, .005f, 3);
                shoe.Bolt(x, z, .019f, .029f, .042f);
            }
            faces.Add((shoe.Build("Anchor shoe"), Matrix4x4.TRS(new Vector3(0f, -.516f, -.024f),
                Quaternion.LookRotation(Vector3.up, Vector3.forward), Vector3.one)));
            InstallPackedFaces(finish, "R49 specimen machined recorder mount", faces, palette);
        }

        private static void DressLabInductorFeet(Transform inductor, Material[] palette)
        {
            var feet = inductor.Cast<Transform>().Where(t => t.name == "Packed inductor hardware").ToArray();
            if (feet.Length != 2) throw new InvalidDataException("Expected two existing laboratory inductor housings.");
            var discrete = new List<(Mesh shape, Matrix4x4 pose)>();
            var clamp = new Plates(palette.Length);
            clamp.Raised(0f, 0f, .155f, .284f, .022f, .023f, .012f, 0);
            clamp.Raised(0f, .058f, .130f, .106f, .012f, .034f, .010f, 2);
            clamp.Raised(0f, -.048f, .123f, .094f, .014f, .043f, .009f, 3);
            clamp.Raised(0f, -.05f, .104f, .059f, .009f, .046f, .004f, 1);
            clamp.Raised(0f, -.049f, .089f, .015f, .004f, .046f, .003f, 4);
            clamp.Bolt(0f, .065f, .025f, .036f, .050f);
            clamp.Bolt(0f, -.111f, .017f, .032f, .043f);
            var clampMesh = clamp.Build("Bolted bus coupler");
            for (var i = 0; i < 9; i++)
            {
                var frame = Quaternion.Euler(0f, i * 40f + 12f, 0f);
                var offset = frame * Vector3.forward * .600f + Vector3.down * 1.468f;
                discrete.Add((clampMesh, Matrix4x4.TRS(offset, frame, Vector3.one)));
            }
            var cooling = new Plates(palette.Length);
            cooling.Raised(0f, 0f, .115f, .12f, .018f, .023f, .008f, 2);
            cooling.Bolt(0f, .006f, .028f, .028f, .046f);
            var coolingMesh = cooling.Build("Collar insulated fastener");
            for (var tier = 0; tier < 6; tier++)
            for (var angle = 0; angle < 3; angle++)
            {
                var frame = Quaternion.Euler(0f, 60f + angle * 120f, 0f);
                var offset = frame * Vector3.forward * .486f + Vector3.up * (-1f + tier * .45f);
                discrete.Add((coolingMesh, Matrix4x4.TRS(offset, frame, Vector3.one)));
            }
            var first = ResetNamed(feet[0], "Bus couplers and collar hardware");
            var repeated = InstallPackedFaces(first, "R49 laboratory inductor service hardware", discrete, palette);
            var second = ResetNamed(feet[1], "Bus couplers and collar hardware");
            second.gameObject.AddComponent<MeshFilter>().sharedMesh = repeated;
            var renderer = second.gameObject.AddComponent<MeshRenderer>();
            renderer.sharedMaterials = palette;
            renderer.shadowCastingMode = ShadowCastingMode.Off;
        }

        private static void FaceReactorBalconyGuards(Transform reactor, Material[] palette)
        {
            var art = reactor.Find("Native Godot reactor geometry");
            var layer = ResetNamed(reactor, "Bolted reactor balcony reinforcement");
            var donor = reactor.Find("Flow reference architectural kit/Reactor walkway protected power bus -1 28.65")
                .GetComponentInChildren<MeshFilter>(true);
            var shapes = new List<(Mesh shape, Matrix4x4 pose)>();
            foreach (var (name, direction) in new[]
            {
                ("EntryBalconyRailWest", Vector3.right), ("EntryBalconyRailEast", Vector3.left),
                ("EntryBalconyRailNorthL", Vector3.back), ("EntryBalconyRailNorthR", Vector3.back),
            })
            {
                var rail = Find(art, name).GetComponentInChildren<MeshRenderer>(true);
                if (!rail || !rail.enabled) throw new InvalidDataException("An original balcony rail is missing: " + name);
                var bounds = rail.bounds;
                var acrossX = Mathf.Abs(direction.z) > .5f;
                var width = (acrossX ? bounds.size.x : bounds.size.z) - .026f;
                var height = bounds.size.y - .021f;
                var depth = acrossX ? bounds.extents.z : bounds.extents.x;
                var position = layer.InverseTransformPoint(bounds.center + direction * (depth + .0045f));
                var plate = new Plates(palette.Length);
                var count = Mathf.Max(2, Mathf.RoundToInt(width / .80f));
                var bay = width / count;
                plate.Raised(0f, 0f, width, height, .043f, .016f, .009f, 0);
                plate.Raised(0f, height * .40f, width - .031f, height * .128f, .022f, .038f, .011f, 2);
                plate.Raised(0f, height * -.401f, width - .039f, height * .110f, .018f, .038f, .009f, 2);
                for (var i = 0; i < count; i++)
                {
                    var x = (i + .5f) * bay - width * .5f;
                    plate.Raised(x, .001f, bay - .056f, height * .59f, .049f, .037f, .019f, 1);
                    plate.Raised(x, height * -.037f, bay * .52f, height * .19f, .024f, .043f, .010f, 0);
                    plate.Raised(x, height * -.037f, bay * .427f, height * .036f, .008f, .052f, .005f, i % 2 == 0 ? 3 : 4);
                    plate.Bolt(x - bay * .35f, height * .197f, .021f, .034f, .051f);
                    plate.Bolt(x + bay * .35f, height * -.183f, .021f, .034f, .051f);
                }
                var pose = Quaternion.LookRotation(direction, Vector3.up);
                shapes.Add((plate.Build(name), Matrix4x4.TRS(position, pose, Vector3.one)));
                if (acrossX)
                {
                    var recess = Node(layer, "Cached power bus rail terminal", position + Vector3.up * height * .16f);
                    recess.localRotation = pose;
                    FitCachedDetail(recess, "Fitted reactor bus connector", donor.sharedMesh,
                        donor.GetComponent<MeshRenderer>().sharedMaterials, new Vector3(0f, 0f, .065f),
                        new Vector3(Mathf.Min(width * .56f, .64f), height * .31f, .052f));
                }
            }
            InstallPackedFaces(layer, "R49 reactor mezzanine rail skins", shapes, palette);
        }

        private static void FitCachedDetail(Transform parent, string name, Mesh mesh, Material[] materials, Vector3 center, Vector3 size)
        {
            if (!mesh || mesh.subMeshCount != materials.Length)
                throw new InvalidDataException("Cached detail material binding changed: " + name);
            var bounds = mesh.bounds;
            var scale = new Vector3(size.x / bounds.size.x, size.y / bounds.size.y, size.z / bounds.size.z);
            var child = Node(parent, name, center - Vector3.Scale(bounds.center, scale));
            child.localScale = scale;
            child.gameObject.AddComponent<MeshFilter>().sharedMesh = mesh;
            var renderer = child.gameObject.AddComponent<MeshRenderer>();
            renderer.sharedMaterials = materials;
            renderer.shadowCastingMode = ShadowCastingMode.Off;
        }

        private static Mesh InstallPackedFaces(Transform target, string label, List<(Mesh shape, Matrix4x4 pose)> faces, Material[] palette)
        {
            var groups = new List<Mesh>();
            for (var sub = 0; sub < palette.Length; sub++)
            {
                var used = faces.Where(face => face.shape.GetIndexCount(sub) > 0).Select(face => new CombineInstance
                    { mesh = face.shape, subMeshIndex = sub, transform = face.pose }).ToArray();
                if (used.Length == 0) throw new InvalidDataException("Missing detailed finish in " + label);
                var materialGroup = new Mesh { indexFormat = IndexFormat.UInt32 };
                materialGroup.CombineMeshes(used, true, true);
                groups.Add(materialGroup);
            }
            var mesh = new Mesh { indexFormat = IndexFormat.UInt32 };
            mesh.CombineMeshes(groups.Select(group => new CombineInstance { mesh = group }).ToArray(), false, false);
            mesh = SaveInductorMesh(label, mesh);
            foreach (var group in groups.Concat(faces.Select(face => face.shape).Distinct()))
                UnityEngine.Object.DestroyImmediate(group);
            target.gameObject.AddComponent<MeshFilter>().sharedMesh = mesh;
            var renderer = target.gameObject.AddComponent<MeshRenderer>();
            renderer.sharedMaterials = palette;
            renderer.shadowCastingMode = ShadowCastingMode.Off;
            return mesh;
        }
    }
}
