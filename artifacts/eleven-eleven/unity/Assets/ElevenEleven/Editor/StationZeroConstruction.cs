using System;
using System.IO;
using System.Linq;
using ElevenEleven.Opening;
using UnityEditor;
using UnityEditor.Events;
using UnityEngine;
using UnityEngine.UI;
using static ElevenEleven.Editor.GodotRoomAssembly;
using static ElevenEleven.Editor.OpeningReviewSceneBuilder;
using static ElevenEleven.Editor.StormworksConstruction;

namespace ElevenEleven.Editor
{
    internal static class StationZeroConstruction
    {
        private const string Assets = "Assets/ElevenEleven/";
        private const string Room = Assets + "Opening/Stormworks/";
        private const string MotionReview = Assets + "MotionReview/";
        private static readonly Color Violet = new Color(0.52f, 0.26f, 1f);

        internal static StationZeroEncounter Build(Transform theatre, Transform hud, Font font, Room01Player actor, ArchiveVignettes vignettes)
        {
            BindPactAvatar(actor);

            var root = Node(theatre, "Zero encounter", Vector3.zero);
            var altar = Node(root, "Threshold to Zero", new Vector3(0f, 0.045f, 32f));
            var stage = Node(root, "Echo at the threshold", new Vector3(1.64f, 0.045f, 30.66f));
            var model = PlaceArt(root, Room + "ZeroManifestation-Godot.glb", "Zero manifestation");
            model.localPosition = new Vector3(-0.2f, 0.1f, 34.7f);
            model.localRotation = Quaternion.Euler(0f, -90f, 0f);
            model.localScale = Vector3.one * 2.05f;
            var idle = AssetDatabase.LoadAllAssetsAtPath(Room + "ZeroManifestation-Godot.glb").OfType<AnimationClip>().Single();
            if (!idle.legacy) throw new InvalidDataException("Zero idle requires Legacy animation import.");
            var breathing = AddAnimation(model.gameObject);
            breathing.AddClip(idle, "Idle");
            breathing.clip = idle;
            var rim = Node(model, "Violet rim", new Vector3(0.7f, 1.5f, 0.65f)).gameObject.AddComponent<Light>();
            rim.color = Violet;
            rim.type = LightType.Point;
            rim.intensity = 4f;
            rim.range = 5f;
            var aura = Node(root, "Threshold key", new Vector3(1.25f, 3.5f, 32.65f)).gameObject.AddComponent<Light>();
            aura.color = Violet;
            aura.type = LightType.Point;
            aura.intensity = 10f;
            aura.range = 8f;

            var depth = Shot(root, "Depth threshold", new Vector3(1.20f, 1.50f, 27.90f), new Vector3(0f, 1.25f, 33f));
            var shot = Shot(root, "Zero reverse", new Vector3(4.8f, 2.55f, 27.7f), new Vector3(0.2f, 2.22f, 33.7f));
            var choice = Shot(root, "Pact decision close shot", new Vector3(2.47f, 1.88f, 29.39f), new Vector3(0.22f, 1.99f, 34.1f));
            var seal = Shot(root, "Seal and wing silhouette", new Vector3(3.82f, 1.84f, 32.92f), new Vector3(1.48f, 1.24f, 30.76f));
            var bed = Audio(root, "Undertow", "ZeroUndertow.ogg", 0.36f, true);
            var cue = Audio(root, "Contract seal", "ZeroSeal.ogg", 0.58f, false);

            var panel = Element("Zero pact dialogue", hud, 0, 0, 1, 1);
            panel.AddComponent<Image>().color = new Color(0.022f, 0.012f, 0.064f, 0.08f);
            var caption = Element("Decision plate", panel.transform, 0.155f, 0.025f, 0.845f, 0.29f);
            caption.AddComponent<Image>().color = new Color(0.045f, 0.038f, 0.10f, 0.975f);
            CinematicDialogueStyle.Apply(caption, CinematicDialogueStyle.Palette.Zero);
            var accent = Element("Violet rule", caption.transform, 0f, 0.988f, 1f, 1f);
            accent.AddComponent<Image>().color = new Color(0.57f, 0.38f, 0.92f, 1f);
            var speaker = Label("Zero speaker", caption.transform, font, "", 26, 0.045f, 0.76f, 0.955f, 0.98f);
            speaker.color = new Color(0.83f, 0.75f, 1f);
            var line = Label("Zero line", caption.transform, font, "", 23, 0.048f, 0.51f, 0.952f, 0.77f);
            line.resizeTextForBestFit = true;
            line.resizeTextMinSize = 16;
            line.resizeTextMaxSize = 23;
            CinematicDialogueStyle.Story(line);
            var advance = Control("Advance Zero", caption.transform, font, 0.51f, 0.043f, 0.966f, 0.232f);
            var dismiss = Control("Defer Zero", caption.transform, font, 0.035f, 0.043f, 0.49f, 0.232f);
            var questions = new Button[3];
            for (var index = 0; index < questions.Length; index++)
            {
                var left = 0.035f + 0.314f * index;
                questions[index] = Control("Question " + (index + 1), caption.transform, font, left, 0.28f, left + 0.303f, 0.477f);
            }

            var encounter = root.gameObject.AddComponent<StationZeroEncounter>();
            Wire(encounter, ("altar", altar), ("stageMark", stage), ("shadowShot", shot), ("sealShot", seal), ("depthShot", depth), ("decisionShot", choice), ("vignettes", vignettes),
                ("manifestation", model.gameObject), ("breathing", breathing), ("aura", aura), ("ambience", bed),
                ("cue", cue), ("panel", panel), ("speaker", speaker), ("line", line), ("advance", advance), ("dismiss", dismiss));
            var serialized = new SerializedObject(encounter);
            var labels = serialized.FindProperty("questions");
            labels.arraySize = questions.Length;
            for (var index = 0; index < questions.Length; index++)
            {
                labels.GetArrayElementAtIndex(index).objectReferenceValue = questions[index];
                UnityEventTools.AddIntPersistentListener(questions[index].onClick, encounter.Ask, index);
            }
            serialized.ApplyModifiedPropertiesWithoutUndo();
            UnityEventTools.AddPersistentListener(advance.onClick, encounter.Advance);
            UnityEventTools.AddPersistentListener(dismiss.onClick, encounter.Dismiss);
            panel.SetActive(false);
            aura.enabled = false;
            model.gameObject.SetActive(false);
            return encounter;
        }

        private static void BindPactAvatar(Room01Player actor)
        {
            var prior = actor.transform.Find("Pact72 facing");
            if (prior != null) UnityEngine.Object.DestroyImmediate(prior.gameObject);
            var pivot = Node(actor.transform, "Pact72 facing", Vector3.zero);
            var model = PlaceArt(pivot, MotionReview + "echo_pact72_candidate.glb", "Echo after the pact");
            var skins = model.GetComponentsInChildren<SkinnedMeshRenderer>();
            var bones = skins.SelectMany(skin => skin.bones).Distinct().ToArray();
            if (bones.Length != 72 ||
                bones.Count(bone => bone.name.StartsWith("Wing", StringComparison.Ordinal) &&
                    bone.name.EndsWith("Left", StringComparison.Ordinal)) != 7)
                throw new InvalidDataException("Pact72 must have 72 bones with a single anatomical left wing.");
            Transform Joint(string suffix) => bones.Single(bone => bone.name.EndsWith(suffix, StringComparison.Ordinal));
            var head = Joint(":Head");
            var left = Joint(":LeftShoulder");
            var right = Joint(":RightShoulder");
            var front = Vector3.Cross(Vector3.up, left.position - right.position).normalized;
            model.rotation = Quaternion.AngleAxis(-Mathf.Atan2(front.x, front.z) * Mathf.Rad2Deg, Vector3.up) * model.rotation;
            var floor = EchoSchoolImportReview.MeasureSkinnedBounds(skins).min.y;
            var height = head.position.y - floor;
            if (height < 0.8f || head.position.y <= Joint(":Hips").position.y)
                throw new InvalidDataException("Pact72 must stand upright on its authored floor.");
            model.localScale *= 1.60f / height;
            var hips = pivot.InverseTransformPoint(Joint(":Hips").position);
            var sole = EchoSchoolImportReview.MeasureSkinnedBounds(skins).min.y;
            model.localPosition -= new Vector3(hips.x, sole - pivot.position.y, hips.z);

            var package = MotionReview + "Pact72MotionSkeleton.glb";
            var locomotion = AddAnimation(model.gameObject);
            foreach (var name in new[] { "Idle", "Walk", "Run", "Strike" })
            {
                var source = AssetDatabase.LoadAllAssetsAtPath(package).OfType<AnimationClip>().Single(item => item.name == name);
                var clip = BindClip(source, model, bones);
                locomotion.AddClip(clip, name);
            }
            pivot.gameObject.SetActive(false);
            Wire(actor, ("pact", pivot), ("pactMotion", locomotion));
        }

        private static AnimationClip BindClip(AnimationClip source, Transform model, Transform[] bones)
        {
            var joints = bones.ToDictionary(bone => bone.name, StringComparer.Ordinal);
            var paths = new System.Collections.Generic.HashSet<string>();
            var destination = Assets + "Echo/Locomotion/Pact" + source.name + ".anim";
            var existing = AssetDatabase.LoadAssetAtPath<AnimationClip>(destination);
            var clip = new AnimationClip
            {
                name = "Pact" + source.name,
                frameRate = source.frameRate,
                legacy = true,
                wrapMode = source.name == "Strike" ? WrapMode.Once : WrapMode.Loop,
            };
            foreach (var input in AnimationUtility.GetCurveBindings(source))
            {
                var joint = input.path.Substring(input.path.LastIndexOf('/') + 1);
                if (input.type != typeof(Transform) || !joints.TryGetValue(joint, out var target))
                    throw new InvalidDataException($"Unmapped {source.name} animation binding {input.path}.");
                var output = input;
                output.path = AnimationUtility.CalculateTransformPath(target, model);
                paths.Add(output.path);
                AnimationUtility.SetEditorCurve(clip, output, AnimationUtility.GetEditorCurve(source, input));
            }
            if (paths.Count != bones.Length)
                throw new InvalidDataException($"{source.name} binds {paths.Count} of {bones.Length} Pact72 joints.");
            if (existing == null)
            {
                AssetDatabase.CreateAsset(clip, destination);
                return clip;
            }
            EditorUtility.CopySerialized(clip, existing);
            UnityEngine.Object.DestroyImmediate(clip);
            EditorUtility.SetDirty(existing);
            AssetDatabase.SaveAssetIfDirty(existing);
            return existing;
        }
        private static Animation AddAnimation(GameObject item)
        {
            var motion = item.GetComponent<Animation>();
            if (motion == null) motion = item.AddComponent<Animation>();
            motion.playAutomatically = false;
            motion.wrapMode = WrapMode.Loop;
            return motion;
        }

        private static Transform Shot(Transform root, string name, Vector3 position, Vector3 target)
        {
            var shot = Node(root, name, position);
            shot.rotation = Quaternion.LookRotation(root.TransformPoint(target) - shot.position);
            return shot;
        }

        private static AudioSource Audio(Transform root, string name, string file, float volume, bool loop)
        {
            var source = Node(root, name, Vector3.zero).gameObject.AddComponent<AudioSource>();
            source.clip = AssetDatabase.LoadAssetAtPath<AudioClip>(Room + file);
            if (source.clip == null) throw new FileNotFoundException(file);
            source.playOnAwake = false;
            source.loop = loop;
            source.volume = volume;
            return source;
        }
    }
}
