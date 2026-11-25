using ElevenEleven.Opening;
using UnityEditor;
using UnityEditor.Events;
using UnityEngine;
using UnityEngine.UI;
using static ElevenEleven.Editor.OpeningReviewSceneBuilder;
using static ElevenEleven.Editor.GodotRoomAssembly;
using static ElevenEleven.Editor.StormworksConstruction;

namespace ElevenEleven.Editor
{
    internal static class StationKinjaConstruction
    {
        internal static StationKinjaConfrontation Build(StationExaminationWing theatre, Transform hud, Font font, Room01Player player)
        {
            var root = Node(theatre.transform, "Kinja confrontation", Vector3.zero);
            var approach = Node(root, "Confrontation resume", new Vector3(-2.28f, 1.235f, 17.55f));
            var shot = Node(root, "Kinja two shot", new Vector3(-4.65f, 2.76f, 17.88f));
            shot.LookAt(theatre.transform.TransformPoint(new Vector3(-2.28f, 2.29f, 18.23f)));
            var key = Node(root, "Confrontation key", new Vector3(-2.1f, 3.30f, 19.95f)).gameObject.AddComponent<Light>();
            key.type = LightType.Point;
            key.intensity = 6.1f;
            key.range = 5.4f;
            key.enabled = false;

            var contactSound = Node(root, "Contact with Kinja", new Vector3(-2.28f, 2.03f, 18.95f))
                .gameObject.AddComponent<AudioSource>();
            contactSound.playOnAwake = false;
            contactSound.volume = 0.55f;
            contactSound.spatialBlend = 0.82f;
            var contacts = new AudioClip[3];
            for (var index = 0; index < contacts.Length; index++)
                contacts[index] = AssetDatabase.LoadAssetAtPath<AudioClip>(
                    $"Assets/ElevenEleven/Opening/Stormworks/KinjaContact{index + 1}.ogg");

            var panel = Element("Kinja decision", hud, 0, 0, 1, 1);
            panel.AddComponent<Image>().color = new Color(0.022f, 0.014f, 0.045f, 0.09f);
            var plate = Element("Kinja caption", panel.transform, 0.145f, 0.025f, 0.855f, 0.30f);
            plate.AddComponent<Image>().color = new Color(0.049f, 0.039f, 0.088f, 0.98f);
            CinematicDialogueStyle.Apply(plate, CinematicDialogueStyle.Palette.Kinja);
            var speaker = Label("Kinja speaker", plate.transform, font, "", 27, 0.04f, 0.76f, 0.96f, 0.98f);
            speaker.color = new Color(0.83f, 0.75f, 1f);
            var line = Label("Kinja line", plate.transform, font, "", 23, 0.05f, 0.27f, 0.95f, 0.77f);
            CinematicDialogueStyle.Story(line);
            var choice = Control("Kinja confirm", plate.transform, font, 0.51f, 0.04f, 0.96f, 0.24f);
            var back = Control("Kinja back", plate.transform, font, 0.04f, 0.04f, 0.49f, 0.24f);
            var strike = Control("Pact strike", hud, font,
                0.78f, 0.37f, 0.95f, 0.48f);

            var scene = root.gameObject.AddComponent<StationKinjaConfrontation>();
            var kinja = Find(theatre.transform, "Kinja");
            var target = Node(root, "Kinja contact mark", new Vector3(-2.28f, 1.20f, 18.95f));
            var reaction = Node(kinja.parent, "Kinja reaction", kinja.localPosition);
            kinja.SetParent(reaction, true);
            Wire(scene, ("target", target), ("reaction", reaction), ("approach", approach), ("shot", shot), ("key", key),
                ("contactSound", contactSound), ("panel", panel), ("speaker", speaker), ("line", line),
                ("choice", choice), ("back", back), ("strike", strike));
            var data = new SerializedObject(scene);
            var sounds = data.FindProperty("contacts");
            sounds.arraySize = contacts.Length;
            for (var index = 0; index < contacts.Length; index++)
                sounds.GetArrayElementAtIndex(index).objectReferenceValue = contacts[index];
            data.ApplyModifiedPropertiesWithoutUndo();
            UnityEventTools.AddPersistentListener(choice.onClick, scene.Confirm);
            UnityEventTools.AddPersistentListener(back.onClick, scene.Close);
            UnityEventTools.AddPersistentListener(strike.onClick, player.RequestPactStrike);
            panel.SetActive(false);
            strike.gameObject.SetActive(false);
            return scene;
        }
    }
}
