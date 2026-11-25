using System.IO;
using System.Linq;
using UnityEditor;
using UnityEngine;
using static ElevenEleven.Editor.GodotRoomAssembly;

namespace ElevenEleven.Editor
{
    internal static class WardMirageArt
    {
        private const string Folder = "Assets/ElevenEleven/Opening/Hospital/";

        internal static GameObject Build(Transform room, Transform pact)
        {
            var duplicate = Object.Instantiate(pact.gameObject, room);
            duplicate.name = "Mirror-only Pact72";
            duplicate.SetActive(true);
            duplicate.transform.SetPositionAndRotation(pact.position, pact.rotation);

            var motion = duplicate.GetComponentInChildren<Animation>();
            motion.GetClip("Idle").SampleAnimation(motion.gameObject, 0.15f);
            motion.enabled = false;
            var skins = duplicate.GetComponentsInChildren<SkinnedMeshRenderer>();
            var bones = skins.SelectMany(item => item.bones).Distinct().ToArray();
            foreach (var skin in skins) skin.updateWhenOffscreen = true;
            Transform Joint(string suffix) => bones.Single(item => item.name.EndsWith(":" + suffix, System.StringComparison.Ordinal));
            var body = duplicate.transform;
            var head = Joint("Head");
            var spine = Joint("Spine2");
            var forward = body.forward;
            var right = body.right;
            var eye = MarkMaterial("Ward eye light", "WardEyeGlow.png", new Color(6.1f, 1.25f, 3.75f, 1f));
            var stain = MarkMaterial("Ward blood trace", "WardBloodTrace.png", new Color(0.52f, 0.032f, 0.075f, 0.91f));
            Trace(head, "Left eye flare", eye, head.position + Vector3.up * 0.076f + forward * 0.098f - right * 0.035f,
                forward, new Vector2(0.054f, 0.034f), 0f);
            Trace(head, "Cheek residue", stain, head.position + Vector3.up * 0.019f + forward * 0.086f + right * 0.046f,
                forward, new Vector2(0.078f, 0.075f), -17f);
            Trace(spine, "Shirt and lapel residue", stain, spine.position + Vector3.up * 0.033f + forward * 0.119f + right * 0.048f,
                forward, new Vector2(0.24f, 0.20f), 11f);
            var hand = Joint("RightHand");
            Trace(hand, "Cuff residue", stain, hand.position + forward * 0.025f,
                forward, new Vector2(0.073f, 0.10f), -13f);

            foreach (var renderer in duplicate.GetComponentsInChildren<Renderer>())
                renderer.forceRenderingOff = true;
            return duplicate;
        }

        internal static GameObject Trace(Transform bone, string name, Material surface, Vector3 position,
            Vector3 forward, Vector2 size, float angle)
        {
            var quad = GameObject.CreatePrimitive(PrimitiveType.Quad);
            quad.name = name;
            quad.transform.SetPositionAndRotation(position, Quaternion.LookRotation(forward) * Quaternion.Euler(0f, 0f, angle));
            quad.transform.localScale = new Vector3(size.x, size.y, 1f);
            quad.transform.SetParent(bone, true);
            Object.DestroyImmediate(quad.GetComponent<Collider>());
            var mesh = quad.GetComponent<MeshRenderer>();
            mesh.sharedMaterial = surface;
            mesh.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            return quad;
        }

        internal static Material MarkMaterial(string name, string texture, Color color)
        {
            var path = Folder + name + ".mat";
            var material = AssetDatabase.LoadAssetAtPath<Material>(path);
            if (material == null)
            {
                var shader = AssetDatabase.LoadAssetAtPath<Shader>(Folder + "WardTrace.shader") ??
                    throw new FileNotFoundException("WardTrace.shader");
                material = new Material(shader);
                AssetDatabase.CreateAsset(material, path);
            }
            material.SetTexture("_MainTex", AssetDatabase.LoadAssetAtPath<Texture2D>(Folder + texture));
            material.SetColor("_TraceColor", color);
            EditorUtility.SetDirty(material);
            AssetDatabase.SaveAssetIfDirty(material);
            return material;
        }
    }
}
