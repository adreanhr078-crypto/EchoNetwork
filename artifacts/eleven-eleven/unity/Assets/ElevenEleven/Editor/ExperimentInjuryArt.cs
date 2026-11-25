using System.Collections.Generic;
using System.Linq;
using ElevenEleven.Opening;
using UnityEditor;
using UnityEngine;
using static ElevenEleven.Editor.StormworksConstruction;

namespace ElevenEleven.Editor
{
    internal static class ExperimentInjuryArt
    {
        internal static void Build(Room01Player player)
        {
            var record = player.GetComponent<EchoExperimentInjuries>();
            if (record != null) Object.DestroyImmediate(record);
            record = player.gameObject.AddComponent<EchoExperimentInjuries>();
            var marks = new List<GameObject>();
            var bruising = WardMirageArt.MarkMaterial("Echo persistent injury", "WardBloodTrace.png", new Color(0.29f, 0.024f, 0.053f, 0.82f));
            foreach (var rootName in new[] { "School65 facing", "Pact72 facing" })
            {
                var viewer = player.transform.Find(rootName);
                var bones = viewer.GetComponentsInChildren<SkinnedMeshRenderer>(true).SelectMany(skin => skin.bones).Distinct().ToArray();
                foreach (var bone in bones)
                {
                    var end = bone.name.Split(':').Last();
                    var finger = end.Contains("Hand") && end.EndsWith("3", System.StringComparison.Ordinal) && !end.Contains("Thumb");
                    var cheek = end == "Head";
                    var knuckle = end == "RightHand" || end == "LeftHand";
                    if (!finger && !cheek && !knuckle) continue;
                    var old = bone.Find("Persistent experiment trace");
                    if (old != null) Object.DestroyImmediate(old.gameObject);
                    var offset = viewer.forward * (cheek ? 0.088f : knuckle ? 0.020f : 0.007f);
                    if (cheek) offset += viewer.right * 0.05f + Vector3.up * 0.019f;
                    var size = cheek ? new Vector2(0.065f, 0.058f) :
                        knuckle ? new Vector2(0.078f, 0.063f) : new Vector2(0.017f, 0.013f);
                    var mark = WardMirageArt.Trace(bone, "Persistent experiment trace", bruising,
                        bone.position + offset, viewer.forward, size, -21f);
                    mark.SetActive(false);
                    marks.Add(mark);
                }
            }
            var settings = new SerializedObject(record);
            var list = settings.FindProperty("marks");
            list.arraySize = marks.Count;
            for (var i = 0; i < marks.Count; i++) list.GetArrayElementAtIndex(i).objectReferenceValue = marks[i];
            settings.ApplyModifiedPropertiesWithoutUndo();
        }
    }
}
