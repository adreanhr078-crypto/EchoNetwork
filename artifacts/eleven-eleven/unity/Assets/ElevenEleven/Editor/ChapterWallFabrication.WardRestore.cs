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
        private const string ClinicalFinishes = "Assets/ElevenEleven/Opening/Hospital/Finishes/";

        public static void RestoreClinicalWardSurfaces()
        {
            var scene = EditorSceneManager.OpenScene(ScenePath);
            var content = scene.GetRootGameObjects().Single(root => root.name == "Room content").transform;
            var ward = content.Find("Echo Station/Hospital transfer/Awakening ward");
            var hospital = ward.GetComponentInParent<StationHospitalWard>(true);
            var mirror = ward.Find("Hospital live mirror");
            var reflection = mirror.GetComponent<StationReflection>();
            var industrial = ward.Find("Fabricated structural wall skin");
            var colliders = content.GetComponentsInChildren<Collider>(true)
                .ToDictionary(c => c, c => (settings: EditorJsonUtility.ToJson(c), pose: c.transform.localToWorldMatrix));
            if (!industrial || industrial.GetComponentsInChildren<Collider>(true).Length != 0 || !hospital || !reflection)
                throw new InvalidDataException("The hospital originals and visual-only wall layer are required.");
            var hospitalBefore = EditorJsonUtility.ToJson(hospital);
            var reflectionBefore = EditorJsonUtility.ToJson(reflection);
            industrial.gameObject.SetActive(false);

            var plaster = HospitalFinish("Ward eggshell enamel");
            foreach (var name in new[] { "Headwall", "Vanity wall", "Ward exit wall", "Window lintel", "Window sill",
                                         "Window left pier", "Window right pier", "Vanity counter" })
                ward.Find(name).GetComponent<MeshRenderer>().sharedMaterial = plaster;
            ward.Find("Ward floor").GetComponent<MeshRenderer>().sharedMaterial = HospitalFinish("Ward mottled vinyl");

            var vanity = ResetNamed(ward, "Hospital vanity mirror frame");
            vanity.localPosition = mirror.localPosition + Vector3.right * .008f;
            vanity.localRotation = Quaternion.LookRotation(Vector3.left, Vector3.up);
            var fittings = new Plates(3);
            foreach (var side in new[] { -1f, 1f })
            {
                fittings.Raised(side * .548f, 0f, .074f, 1.56f, .027f, .023f, .012f, 0);
                fittings.Raised(side * .523f, 0f, .016f, 1.47f, .006f, .025f, .003f, 1);
                fittings.Raised(0f, side * .760f, 1.13f, .064f, .026f, .027f, .010f, 0);
                fittings.Bolt(side * .552f, .697f, .014f, .023f, .031f);
                fittings.Bolt(side * .552f, -.696f, .014f, .023f, .031f);
            }
            fittings.Raised(0f, -.771f, .27f, .040f, .012f, .033f, .004f, 1);
            SetPanel(vanity, "Ward clinical vanity trim", fittings, new[] { HospitalFinish("Ward graphite rubber"),
                HospitalFinish("Ward eggshell enamel"), HospitalFinish("Ward satin steel") });

            var after = content.GetComponentsInChildren<Collider>(true);
            if (hospitalBefore != EditorJsonUtility.ToJson(hospital) || reflectionBefore != EditorJsonUtility.ToJson(reflection) ||
                after.Length != colliders.Count || after.Any(c => !colliders.TryGetValue(c, out var prior) ||
                    prior.settings != EditorJsonUtility.ToJson(c) || prior.pose != c.transform.localToWorldMatrix))
                throw new InvalidDataException("Ward surfaces changed an interaction, reflection, or collider.");
            AssetDatabase.SaveAssets();
            if (!EditorSceneManager.SaveScene(scene)) throw new IOException("Could not save the Ward repair candidate.");
            Debug.Log($"ECHO_WARD_CLINICAL_RESTORE_SAVED colliders={after.Length} original_ward_authority=true");
        }

        private static Material HospitalFinish(string name) =>
            AssetDatabase.LoadAssetAtPath<Material>(ClinicalFinishes + name + ".mat") ?? throw new FileNotFoundException(name);
    }
}
