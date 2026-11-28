using System;
using System.IO;
using System.Linq;
using System.Reflection;
using ElevenEleven.Opening;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using static ElevenEleven.Editor.GodotRoomAssembly;

namespace ElevenEleven.Editor
{
    internal static partial class ChapterWallFabrication
    {
        public static void FitWardEyeCompress() => BuildWardEyeSetup(null, false);

        private static void BuildWardEyeSetup(Vector3? alignedLeftEyeWorld, bool withPostPactHead)
        {
            var scene = EditorSceneManager.OpenScene(ScenePath);
            var content = scene.GetRootGameObjects().Single(root => root.name == "Room content").transform;
            var ward = content.Find("Echo Station/Hospital transfer/Awakening ward");
            var controller = ward.GetComponentInParent<StationHospitalWard>(true);
            var player = content.GetComponentInChildren<Room01Player>(true);
            var school = player.transform.Find("School65 facing");
            var sky = player.transform.Find("Pact72 facing");
            if (!ward || !controller || !school || !sky) throw new InvalidDataException("The original Ward and both avatar rigs are required.");

            SkinnedMeshRenderer headSkin = null;
            Mesh fittedBody = null;
            Material originalMat = null;
            Material schoolAnimeMat = null;
            Material postPactMat = null;
            Vector3[] headVerts = null;
            int[] headTris = null;
            if (withPostPactHead)
            {
                (headSkin, fittedBody, originalMat, schoolAnimeMat, postPactMat, alignedLeftEyeWorld, headVerts, headTris) = BuildWardPostPactHeadAndEye(school, sky);
            }

            var head = school.GetComponentsInChildren<SkinnedMeshRenderer>(true).SelectMany(skin => skin.bones).Distinct()
                .Single(bone => bone.name.EndsWith(":Head", StringComparison.Ordinal));
            var sourceFlare = ward.GetComponentsInChildren<Renderer>(true).Single(item => item.name == "Left eye flare");
            var removed = controller.GetComponent<WardEyeDressing>();
            if (removed) UnityEngine.Object.DestroyImmediate(removed);
            var dressing = controller.gameObject.AddComponent<WardEyeDressing>();
            var pad = ResetNamed(head, "Hospital left eye compress");
            var eye = alignedLeftEyeWorld ?? (head.position + Vector3.up * .040f + school.forward * .070f - school.right * .031f);
            var neck = Joint(school.GetComponentInChildren<SkinnedMeshRenderer>(true), "Neck");
            var headUp = (head.position - neck.position).normalized;
            var outward = (school.forward - school.right * .20f).normalized;
            pad.SetParent(null, true);
            pad.localScale = Vector3.one;
            var padCenter = eye + outward * .0112f - headUp * .0028f;
            var padRot = Quaternion.LookRotation(outward, headUp) * Quaternion.Euler(0f, 0f, -8f);
            pad.SetPositionAndRotation(padCenter, padRot);
            pad.SetParent(head, true);

            var cloth = HospitalFinish("Ward eggshell enamel");
            var hem = HospitalFinish("Ward green enamel");
            var paper = HospitalFinish("Ward satin steel");
            var gauzeMesh = BuildGauzeMesh(pad, headVerts, headTris, eye);
            pad.gameObject.AddComponent<MeshFilter>().sharedMesh = gauzeMesh;
            var surface = pad.gameObject.AddComponent<MeshRenderer>();
            surface.sharedMaterial = CompressCloth();
            surface.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            pad.gameObject.AddComponent<WardGauzeCloth>();
            pad.gameObject.SetActive(false);

            var oldFlare = head.Find("Ward live left-eye flare");
            if (oldFlare) UnityEngine.Object.DestroyImmediate(oldFlare.gameObject);
            var flare = WardMirageArt.Trace(head, "Ward live left-eye flare", sourceFlare.sharedMaterial, eye + outward * .0065f + headUp * .002f,
                outward, new Vector2(.022f, .014f), 0f).GetComponent<Renderer>();
            flare.gameObject.SetActive(false);

            var oldPulseLight = head.Find("Ward left-eye pulse light");
            if (oldPulseLight) UnityEngine.Object.DestroyImmediate(oldPulseLight.gameObject);
            var pulseLight = new GameObject("Ward left-eye pulse light").AddComponent<Light>();
            pulseLight.transform.SetParent(head, false);
            pulseLight.transform.position = eye + outward * .16f;
            pulseLight.type = LightType.Point;
            pulseLight.color = new Color(.70f, .22f, 1f);
            pulseLight.intensity = 0f;
            pulseLight.range = .95f;
            pulseLight.enabled = false;

            var shot = ResetNamed(head, "Ward left-eye wake shot");
            var cameraEye = padCenter + school.forward * .64f - school.right * .33f + Vector3.up * .005f;
            shot.SetPositionAndRotation(cameraEye, Quaternion.LookRotation(padCenter + school.right * .022f + Vector3.down * .065f - cameraEye));
            FixWardRoomDistortions(ward, school, head);
            DressWardWakeLighting(ward, school, head.position);
            WardEyeCompressWireTape(pad, headVerts, headTris, gauzeMesh, eye);

            var packet = ResetNamed(ward, "Doctor's eye compress packet");
            packet.position = WardMattressContact(ward);
            packet.localRotation = Quaternion.LookRotation(Vector3.up, Vector3.forward);
            var envelope = new Plates(3);
            envelope.Raised(0f, 0f, .25f, .15f, .014f, .016f, .006f, 0);
            envelope.Raised(0f, .021f, .22f, .010f, .003f, .020f, .002f, 1);
            envelope.Raised(0f, -.055f, .18f, .015f, .004f, .020f, .002f, 1);
            SetPanel(packet, "Sterile eye compress packet mesh", envelope, new[] { cloth, hem, paper });
            AddLegend(packet, "EYE COMPRESS", new Vector3(0f, -.012f, .022f), .0031f, new Color(.08f, .22f, .22f));
            packet.gameObject.SetActive(false);

            using var visual = new SerializedObject(dressing);
            visual.FindProperty("packet").objectReferenceValue = packet;
            visual.FindProperty("wornCompress").objectReferenceValue = pad.gameObject;
            visual.FindProperty("flare").objectReferenceValue = flare;
            visual.FindProperty("pulseLight").objectReferenceValue = pulseLight;
            visual.FindProperty("wakeShot").objectReferenceValue = shot;
            if (withPostPactHead && headSkin != null)
            {
                visual.FindProperty("wardBody").objectReferenceValue = headSkin;
                visual.FindProperty("originalBody").objectReferenceValue = headSkin.sharedMesh;
                visual.FindProperty("fittedBody").objectReferenceValue = fittedBody;
                visual.FindProperty("originalMaterial").objectReferenceValue = originalMat;
                visual.FindProperty("schoolAnimeMaterial").objectReferenceValue = schoolAnimeMat;
                visual.FindProperty("postPactHeadMaterial").objectReferenceValue = postPactMat;
                visual.FindProperty("postPactHead").objectReferenceValue = null;
            }
            visual.ApplyModifiedPropertiesWithoutUndo();
            using var authority = new SerializedObject(controller);
            authority.FindProperty("eyeDressing").objectReferenceValue = dressing;
            authority.ApplyModifiedPropertiesWithoutUndo();
            AssetDatabase.SaveAssets();
            if (!EditorSceneManager.SaveScene(scene)) throw new IOException("Could not save the staged Ward eye pickup.");
            Debug.Log("ECHO_WARD_EYE_PICKUP_SAVED original_side=Left");
        }

        private static Material CompressCloth()
        {
            const string path = ClinicalFinishes + "Ward gauze compress cloth.mat";
            var anime = AssetDatabase.LoadAssetAtPath<Shader>("Assets/ElevenEleven/Opening/Hospital/HyperAnimeCharacter.shader");
            var shader = anime && !ShaderUtil.ShaderHasError(anime) ? anime : Shader.Find("Universal Render Pipeline/Lit");
            var existing = AssetDatabase.LoadAssetAtPath<Material>(path);
            if (existing) AssetDatabase.DeleteAsset(path);
            var material = new Material(shader) { name = "Ward gauze compress cloth" };
            AssetDatabase.CreateAsset(material, path);
            material.SetTexture("_BaseMap", GauzeColor());
            material.SetColor("_BaseColor", new Color(.94f, .95f, .96f, 1f));
            if (material.HasProperty("_ShadowColor"))
            {
                material.SetColor("_ShadowColor", new Color(.80f, .825f, .86f, 1f));
                material.SetFloat("_ShadowOffset", -.08f);
                material.SetFloat("_ShadowFeather", .42f);
                material.SetColor("_RimColor", new Color(.82f, .90f, .98f, 1f));
                material.SetFloat("_RimPower", 3.8f);
                material.SetFloat("_RimStrength", .10f);
                material.SetFloat("_HairSheen", 0f);
                material.SetFloat("_OutlineDarken", .12f);
            }
            EditorUtility.SetDirty(material);
            return material;
        }

        private static Mesh BuildGauzeMesh(Transform pad, Vector3[] headVerts, int[] headTris, Vector3 eyeWorld)
        {
            var columns = WardGauzeCloth.Columns;
            var rows = WardGauzeCloth.Rows;
            var vertices = new Vector3[columns * rows];
            var uv = new Vector2[vertices.Length];
            var triangles = new System.Collections.Generic.List<int>((columns - 1) * (rows - 1) * 6);

            // Convert aligned world head triangles into pad-local space and project radially so outer edges hug temple skin
            var padTris = BuildLocalEyePatchTris(pad, headVerts, headTris, eyeWorld);
            var basePoints = new Vector3[columns * rows];
            var maxCenterZ = -.01f;
            for (var row = 0; row < rows; row++)
            for (var col = 0; col < columns; col++)
            {
                var x = col * 2f / (columns - 1) - 1f;
                var y = row * 2f / (rows - 1) - 1f;
                var angleShrink = Mathf.Pow(1f - .32f * Mathf.Pow(Mathf.Abs(x), 3.6f) * Mathf.Pow(Mathf.Abs(y), 2.4f), .5f);
                var lx = (x > 0f ? .0165f : .0205f) * x * angleShrink;
                var ly = .0122f * y * angleShrink;
                var hit = ProjectCurvedPoint(padTris, lx, ly, .55f, new Vector3(lx, ly, -.0045f - .0035f * (x * x + y * y)));
                basePoints[row * columns + col] = hit;
                if (Mathf.Abs(x) < .65f && Mathf.Abs(y) < .65f && hit.z > maxCenterZ)
                    maxCenterZ = hit.z;
            }

            // Smooth inner Z gently while maintaining upper eyelid/lash clearance across the center socket
            var baseSurfaceZ = new float[columns * rows];
            for (var i = 0; i < basePoints.Length; i++) baseSurfaceZ[i] = basePoints[i].z;
            var smoothZ = (float[])baseSurfaceZ.Clone();
            for (var pass = 0; pass < 2; pass++)
            {
                var next = (float[])smoothZ.Clone();
                for (var r = 1; r < rows - 1; r++)
                for (var c = 1; c < columns - 1; c++)
                {
                    var idx = r * columns + c;
                    next[idx] = (smoothZ[idx] * 2f + smoothZ[idx - 1] + smoothZ[idx + 1] + smoothZ[idx - columns] + smoothZ[idx + columns]) / 6f;
                }
                smoothZ = next;
            }

            var lidFloor = Mathf.Max(.0022f, maxCenterZ + .0016f);
            for (var row = 0; row < rows; row++)
            for (var col = 0; col < columns; col++)
            {
                var x = col * 2f / (columns - 1) - 1f;
                var y = row * 2f / (rows - 1) - 1f;
                var key = row * columns + col;
                var superR = Mathf.Pow(Mathf.Pow(Mathf.Abs(x), 3.6f) + Mathf.Pow(Mathf.Abs(y), 3.6f), 1f / 3.6f);
                var domeMask = Mathf.SmoothStep(0f, 1f, Mathf.Clamp01(1f - superR * .85f));
                var orbitalZ = Mathf.Max(smoothZ[key], baseSurfaceZ[key]);
                orbitalZ = Mathf.Lerp(orbitalZ, Mathf.Max(orbitalZ, lidFloor), domeMask);

                var edgeTuck = 1f - Mathf.SmoothStep(.84f, 1.0f, superR);
                var cushionCore = Mathf.SmoothStep(0f, 1f, Mathf.Clamp01((.84f - superR) / .28f));
                // Non-negative perimeter seating keeps >=0.7mm orbital clearance so temple hair/lash triangles never clip through
                var loft = .0007f + (.0008f + .0027f * cushionCore) * edgeTuck;
                var p = basePoints[key];
                vertices[key] = new Vector3(p.x, p.y, orbitalZ + loft);
                uv[key] = new Vector2((x + 1f) * .5f, (y + 1f) * .5f);
                if (row == rows - 1 || col == columns - 1) continue;
                triangles.Add(key); triangles.Add(key + 1); triangles.Add(key + columns + 1);
                triangles.Add(key); triangles.Add(key + columns + 1); triangles.Add(key + columns);
            }
            var mesh = new Mesh { vertices = vertices, uv = uv };
            mesh.SetTriangles(triangles, 0);
            mesh.RecalculateNormals();
            mesh.RecalculateTangents();
            Debug.Log($"WARD_GAUZE_CONFORM local_tris={padTris.Count} sample_z_range=[{baseSurfaceZ.Min():F4}..{baseSurfaceZ.Max():F4}]");
            return SaveInductorMesh("Hospital left-eye compress mesh", mesh);
        }

        private static System.Collections.Generic.List<(Vector3 a, Vector3 b, Vector3 c)> BuildLocalEyePatchTris(
            Transform pad, Vector3[] headVerts, int[] headTris, Vector3 eyeWorld)
        {
            var list = new System.Collections.Generic.List<(Vector3, Vector3, Vector3)>(256);
            if (headVerts == null || headTris == null) return list;
            var worldToLocal = pad.worldToLocalMatrix;
            var r2Max = 0.080f * 0.080f;
            for (var i = 0; i < headTris.Length; i += 3)
            {
                var va = headVerts[headTris[i]];
                if ((va - eyeWorld).sqrMagnitude > r2Max) continue;
                var la = worldToLocal.MultiplyPoint3x4(va);
                var lb = worldToLocal.MultiplyPoint3x4(headVerts[headTris[i + 1]]);
                var lc = worldToLocal.MultiplyPoint3x4(headVerts[headTris[i + 2]]);
                if (Vector3.Cross(lb - la, lc - la).z <= -0.15f) continue;
                list.Add((la, lb, lc));
            }
            return list;
        }

        private static Vector3 ProjectCurvedPoint(System.Collections.Generic.List<(Vector3 a, Vector3 b, Vector3 c)> tris,
            float qx, float qy, float curveWeight, Vector3 fallback)
        {
            var origin = new Vector3(qx * (1f + .18f * curveWeight), qy * (1f + .12f * curveWeight), .048f);
            var target = new Vector3(qx * (1f - .52f * curveWeight), qy * (1f - .38f * curveWeight), -.062f);
            var dir = (target - origin).normalized;
            var bestT = float.PositiveInfinity;
            var bestHit = fallback;
            var bestVtxDist2 = float.PositiveInfinity;
            var bestVtx = fallback;

            for (var i = 0; i < tris.Count; i++)
            {
                var (a, b, c) = tris[i];
                var e1 = b - a;
                var e2 = c - a;
                var pvec = Vector3.Cross(dir, e2);
                var det = Vector3.Dot(e1, pvec);
                if (Mathf.Abs(det) > 1e-7f)
                {
                    var invDet = 1f / det;
                    var tvec = origin - a;
                    var u = Vector3.Dot(tvec, pvec) * invDet;
                    if (u >= -.002f && u <= 1.002f)
                    {
                        var qvec = Vector3.Cross(tvec, e1);
                        var v = Vector3.Dot(dir, qvec) * invDet;
                        if (v >= -.002f && u + v <= 1.002f)
                        {
                            var dist = Vector3.Dot(e2, qvec) * invDet;
                            if (dist > .012f && dist < .095f && dist < bestT)
                            {
                                bestT = dist;
                                bestHit = origin + dir * dist;
                            }
                        }
                    }
                }
                // Nearest-vertex XY fallback ensures zero floating corners past cheek edge
                foreach (var pt in new[] { a, b, c })
                {
                    var dx = pt.x - qx;
                    var dy = pt.y - qy;
                    var d2 = dx * dx + dy * dy;
                    if (d2 < bestVtxDist2)
                    {
                        bestVtxDist2 = d2;
                        bestVtx = pt;
                    }
                }
            }
            if (!float.IsPositiveInfinity(bestT)) return bestHit;
            return bestVtxDist2 < .0004f ? bestVtx : fallback;
        }

        private static float SampleLocalSurfaceZ(System.Collections.Generic.List<(Vector3 a, Vector3 b, Vector3 c)> tris,
            float qx, float qy, float fallbackZ) => ProjectCurvedPoint(tris, qx, qy, 0f, new Vector3(qx, qy, fallbackZ)).z;

        private static Vector3 WardMattressContact(Transform ward)
        {
            var bed = ward.Find("Measured hospital bed");
            var rayMesh = typeof(HandleUtility).GetMethod("IntersectRayMesh", BindingFlags.Static | BindingFlags.Public | BindingFlags.NonPublic,
                null, new[] { typeof(Ray), typeof(Mesh), typeof(Matrix4x4), typeof(RaycastHit).MakeByRefType() }, null);
            if (!bed || rayMesh == null) throw new InvalidDataException("The measured bedside contact surface is missing.");
            var ray = new Ray(ward.TransformPoint(new Vector3(-.71f, 1.35f, .13f)), -ward.up);
            var nearest = 1.10f;
            foreach (var visual in bed.GetComponentsInChildren<MeshFilter>(true))
            {
                if (!visual.sharedMesh) continue;
                object[] query = { ray, visual.sharedMesh, visual.transform.localToWorldMatrix, default(RaycastHit) };
                if ((bool)rayMesh.Invoke(null, query) && query[3] is RaycastHit hit && hit.distance < nearest) nearest = hit.distance;
            }
            if (nearest >= 1.10f) throw new InvalidDataException("The eye compress must rest on the original mattress.");
            return ray.GetPoint(nearest) + ward.up * .006f;
        }

        public static void FitWardEyeAndPostPactHair() => BuildWardEyeSetup(null, true);

        private static Texture2D GauzeColor()
        {
            const string path = ClinicalFinishes + "Ward woven gauze base.asset";
            const int size = 256;
            var tex = AssetDatabase.LoadAssetAtPath<Texture2D>(path);
            if (tex && (tex.width != size || tex.height != size))
            {
                AssetDatabase.DeleteAsset(path);
                tex = null;
            }
            if (!tex)
            {
                tex = new Texture2D(size, size, TextureFormat.RGBA32, true, false)
                    { name = "Ward woven gauze base", wrapMode = TextureWrapMode.Clamp, filterMode = FilterMode.Bilinear, anisoLevel = 4 };
                AssetDatabase.CreateAsset(tex, path);
            }
            var pixels = new Color32[size * size];
            for (var py = 0; py < size; py++)
            {
                var v = py / (float)(size - 1) * 2f - 1f;
                for (var px = 0; px < size; px++)
                {
                    var u = px / (float)(size - 1) * 2f - 1f;
                    var r = Mathf.Pow(Mathf.Pow(Mathf.Abs(u), 3.6f) + Mathf.Pow(Mathf.Abs(v), 3.6f), 1f / 3.6f);
                    // Embossed heat-sealed sterile non-woven perimeter stitch frame at r in [0.80..0.90]
                    var dimple = 0.988f + 0.012f * Mathf.Sin(u * Mathf.PI * 26f) * Mathf.Sin(v * Mathf.PI * 26f);
                    var sealRing = Mathf.Exp(-Mathf.Pow((r - 0.85f) / 0.032f, 2f));
                    var dash = 0.5f + 0.5f * Mathf.Sin((Mathf.Atan2(v, u) + Mathf.PI) * 32f);
                    var frame = 1f - 0.10f * sealRing * (0.45f + 0.55f * dash) - 0.08f * Mathf.SmoothStep(0.91f, 1.0f, r);
                    var shade = dimple * frame;
                    var ch = (byte)Mathf.Clamp(Mathf.RoundToInt(shade * 238f), 0, 255);
                    pixels[py * size + px] = new Color32(ch, (byte)Mathf.Min(255, ch + 2), (byte)Mathf.Min(255, ch + 5), 255);
                }
            }
            tex.SetPixels32(pixels);
            tex.Apply(true);
            EditorUtility.SetDirty(tex);
            return tex;
        }

        private static void WardEyeCompressWireTape(Transform pad, Vector3[] headVerts, int[] headTris, Mesh gauzeMesh, Vector3 eyeWorld)
        {
            const string matPath = ClinicalFinishes + "Ward surgical tape.mat";
            var anime = AssetDatabase.LoadAssetAtPath<Shader>("Assets/ElevenEleven/Opening/Hospital/HyperAnimeCharacter.shader");
            var shader = anime && !ShaderUtil.ShaderHasError(anime) ? anime : Shader.Find("Universal Render Pipeline/Lit");
            var existing = AssetDatabase.LoadAssetAtPath<Material>(matPath);
            if (existing) AssetDatabase.DeleteAsset(matPath);
            var tapeMat = new Material(shader) { name = "Ward surgical tape" };
            AssetDatabase.CreateAsset(tapeMat, matPath);
            tapeMat.SetTexture("_BaseMap", Texture2D.whiteTexture);
            tapeMat.SetColor("_BaseColor", new Color(.935f, .94f, .945f, 1f));
            if (tapeMat.HasProperty("_ShadowColor"))
            {
                tapeMat.SetColor("_ShadowColor", new Color(.78f, .80f, .83f, 1f));
                tapeMat.SetFloat("_ShadowOffset", -.06f);
                tapeMat.SetFloat("_ShadowFeather", .38f);
                tapeMat.SetFloat("_RimStrength", .08f);
                tapeMat.SetFloat("_HairSheen", 0f);
                tapeMat.SetFloat("_OutlineDarken", .10f);
            }
            EditorUtility.SetDirty(tapeMat);

            var padTris = BuildLocalEyePatchTris(pad, headVerts, headTris, eyeWorld);
            var gVerts = gauzeMesh.vertices;
            var gTris = gauzeMesh.triangles;
            var padSurfaceTris = new System.Collections.Generic.List<(Vector3 a, Vector3 b, Vector3 c)>(gTris.Length / 3);
            for (var i = 0; i < gTris.Length; i += 3)
                padSurfaceTris.Add((gVerts[gTris[i]], gVerts[gTris[i + 1]], gVerts[gTris[i + 2]]));

            // Two crisp radially conformed surgical micropore strips hugging brow & cheekbone without protruding beyond face
            for (var i = 0; i < 2; i++)
            {
                var name = i == 0 ? "Surgical nasal bridge tape" : "Surgical temple anchor tape";
                var old = pad.Find(name);
                if (old) UnityEngine.Object.DestroyImmediate(old.gameObject);
                var strip = new GameObject(name);
                strip.transform.SetParent(pad, false);

                var center = i == 0 ? new Vector2(-.0035f, .0082f) : new Vector2(.0010f, -.0098f);
                var angle = (i == 0 ? -22f : 14f) * Mathf.Deg2Rad;
                var dirU = new Vector2(Mathf.Cos(angle), Mathf.Sin(angle));
                var dirV = new Vector2(-dirU.y, dirU.x);
                const int cols = 21;
                const int rows = 5;
                var halfLen = i == 0 ? .0175f : .0185f;
                const float halfWid = .0030f;
                var verts = new Vector3[cols * rows];
                var uvs = new Vector2[verts.Length];
                var tris = new System.Collections.Generic.List<int>((cols - 1) * (rows - 1) * 6);
                for (var r = 0; r < rows; r++)
                for (var c = 0; c < cols; c++)
                {
                    var su = c * 2f / (cols - 1) - 1f;
                    var sv = r * 2f / (rows - 1) - 1f;
                    var pt = center + dirU * (su * halfLen) + dirV * (sv * halfWid);
                    var skinPt = ProjectCurvedPoint(padTris, pt.x, pt.y, .55f, new Vector3(pt.x, pt.y, -.005f));
                    var padZ = SampleLocalSurfaceZ(padSurfaceTris, pt.x, pt.y, -1f);
                    var edgePress = 1f - Mathf.SmoothStep(.78f, 1.0f, Mathf.Abs(su));
                    var tapeZ = Mathf.Max(skinPt.z + .00025f + .00020f * edgePress, padZ > -.5f ? padZ + .00030f : -1f);
                    var idx = r * cols + c;
                    verts[idx] = new Vector3(skinPt.x, skinPt.y, tapeZ);
                    uvs[idx] = new Vector2((su + 1f) * .5f, (sv + 1f) * .5f);
                    if (r == rows - 1 || c == cols - 1) continue;
                    tris.Add(idx); tris.Add(idx + 1); tris.Add(idx + cols + 1);
                    tris.Add(idx); tris.Add(idx + cols + 1); tris.Add(idx + cols);
                }
                var stripMesh = new Mesh { vertices = verts, uv = uvs };
                stripMesh.SetTriangles(tris, 0);
                stripMesh.RecalculateNormals();
                stripMesh.RecalculateTangents();
                strip.AddComponent<MeshFilter>().sharedMesh = SaveInductorMesh(name + " mesh", stripMesh);
                var renderer = strip.AddComponent<MeshRenderer>();
                renderer.sharedMaterial = tapeMat;
                renderer.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            }
        }

        private static void FixWardRoomDistortions(Transform ward, Transform school, Transform head)
        {
            // 1. Eliminate dado/guard Z-fighting through Measured headwall service panel
            var headwallPanel = ward.Find("Measured headwall service panel");
            if (headwallPanel)
            {
                var lp = headwallPanel.localPosition;
                lp.x = -3.055f;
                headwallPanel.localPosition = lp;
            }
            var finish = ward.Find("Ward architectural finish");
            if (finish)
            {
                foreach (Transform child in finish)
                {
                    if (child.name == "Wall protection panels" && child.localPosition.x < 0f)
                    {
                        var p = child.localPosition;
                        p.x = -3.135f;
                        child.localPosition = p;
                    }
                    else if (child.name == "Bedside wall guard")
                    {
                        var sign = Mathf.Sign(child.localPosition.z);
                        child.localPosition = new Vector3(-3.095f, .955f, sign * 2.275f);
                        child.localScale = new Vector3(.035f, .05f, 1.65f);
                    }
                }
            }

            // 2. Eliminate black striped self-shadow/Z-fighting on Pleated curtains
            foreach (Transform item in ward)
            {
                if (item.name != "Pleated curtain") continue;
                var sign = item.localPosition.x < 0f ? -1f : 1f;
                var pos = item.localPosition;
                pos.x = sign * 1.56f;
                pos.z = -2.47f;
                item.localPosition = pos;
                foreach (var r in item.GetComponentsInChildren<Renderer>(true))
                    r.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            }

            // 3. Preserve Ward sealed window collider transform byte-for-byte (-2.945f) while offsetting visual quad in a child
            var ext = ward.Find("Ward sealed window");
            if (ext)
            {
                var wp = ext.localPosition;
                wp.z = -2.945f;
                ext.localPosition = wp;
                var extRenderer = ext.GetComponent<MeshRenderer>();
                var extFilter = ext.GetComponent<MeshFilter>();
                if (extRenderer && extFilter)
                {
                    extRenderer.enabled = false;
                    var visual = ResetNamed(ext, "Ward sealed window visual");
                    visual.localPosition = new Vector3(0f, 0f, -1.58f);
                    visual.gameObject.AddComponent<MeshFilter>().sharedMesh = extFilter.sharedMesh;
                    var vr = visual.gameObject.AddComponent<MeshRenderer>();
                    vr.sharedMaterial = extRenderer.sharedMaterial;
                    vr.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
                }
            }

            // 4. Mute Persistent experiment trace renderer on head so EchoExperimentInjuries.Apply never paints midair cheek spots
            foreach (var r in school.GetComponentsInChildren<Renderer>(true))
            {
                if (r.gameObject.name == "Persistent experiment trace" && Vector3.Distance(r.transform.position, head.position) < 0.25f)
                    r.enabled = false;
            }

            // 5. Add clean clinical IV stand & bedside medical cabinet (zero colliders) to eliminate bare ward feel
            var wardProps = ResetNamed(ward, "Ward bedside clinical props");
            var steel = HospitalFinish("Ward satin steel");
            var enamel = HospitalFinish("Ward eggshell enamel");
            var dado = HospitalFinish("Ward green enamel");
            var bag = HospitalFinish("Ward luminaire diffuser");

            void PropBox(string name, Material m, Vector3 pos, Vector3 scale, Quaternion rot = default)
            {
                var p = GameObject.CreatePrimitive(PrimitiveType.Cube);
                p.name = name;
                UnityEngine.Object.DestroyImmediate(p.GetComponent<Collider>());
                p.transform.SetParent(wardProps, false);
                p.transform.localPosition = pos;
                p.transform.localRotation = rot == default ? Quaternion.identity : rot;
                p.transform.localScale = scale;
                p.GetComponent<MeshRenderer>().sharedMaterial = m;
            }
            void PropCyl(string name, Material m, Vector3 pos, Vector3 scale)
            {
                var p = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
                p.name = name;
                UnityEngine.Object.DestroyImmediate(p.GetComponent<Collider>());
                p.transform.SetParent(wardProps, false);
                p.transform.localPosition = pos;
                p.transform.localScale = scale;
                p.GetComponent<MeshRenderer>().sharedMaterial = m;
            }

            // Bedside clinical cabinet beside headboard
            PropBox("Bedside locker carcass", enamel, new Vector3(-2.45f, .34f, -.92f), new Vector3(.44f, .68f, .44f));
            PropBox("Bedside locker top", dado, new Vector3(-2.45f, .69f, -.92f), new Vector3(.47f, .035f, .47f));
            PropBox("Bedside drawer seam", steel, new Vector3(-2.225f, .48f, -.92f), new Vector3(.02f, .025f, .24f));

            // Slim stainless IV drip stand
            PropCyl("IV base hub", steel, new Vector3(-2.30f, .04f, .86f), new Vector3(.06f, .04f, .06f));
            PropBox("IV base leg A", steel, new Vector3(-2.30f, .02f, .86f), new Vector3(.42f, .025f, .035f));
            PropBox("IV base leg B", steel, new Vector3(-2.30f, .02f, .86f), new Vector3(.035f, .025f, .42f));
            PropCyl("IV mast pole", steel, new Vector3(-2.30f, 1.02f, .86f), new Vector3(.024f, 1.0f, .024f));
            PropBox("IV top arm", steel, new Vector3(-2.22f, 2.00f, .86f), new Vector3(.18f, .02f, .02f));
            PropBox("IV saline bag", bag, new Vector3(-2.14f, 1.88f, .86f), new Vector3(.055f, .16f, .095f));
        }

        private static void DressWardWakeLighting(Transform ward, Transform school, Vector3 headPos)
        {
            var rig = ResetNamed(ward, "Ward bedside cinema lights");
            AddWardSpot(rig, "Ward bedside face key", ward.TransformPoint(new Vector3(.68f, 2.02f, -.25f)),
                headPos + Vector3.down * .08f, new Color(.96f, .95f, .94f), 2.3f, 2.8f, 34f);
            AddWardSpot(rig, "Ward bedside hair rim", ward.TransformPoint(new Vector3(-1.05f, 2.52f, -.12f)),
                headPos + Vector3.up * .04f, new Color(.56f, .82f, 1f), 4.8f, 2.9f, 34f);
            var monitorGlow = new GameObject("Ward monitor bokeh accent").AddComponent<Light>();
            monitorGlow.transform.SetParent(rig, false);
            monitorGlow.transform.position = ward.TransformPoint(new Vector3(-2.65f, 1.48f, .18f));
            monitorGlow.type = LightType.Point;
            monitorGlow.color = new Color(.22f, .78f, .96f);
            monitorGlow.intensity = 1.0f;
            monitorGlow.range = 3.2f;
        }

        private static void AddWardSpot(Transform parent, string name, Vector3 pos, Vector3 target, Color color, float intensity, float range, float angle)
        {
            var spot = new GameObject(name).AddComponent<Light>();
            spot.transform.SetParent(parent, false);
            spot.transform.position = pos;
            spot.transform.rotation = Quaternion.LookRotation(target - pos);
            spot.type = LightType.Spot;
            spot.color = color;
            spot.intensity = intensity;
            spot.range = range;
            spot.spotAngle = angle;
            spot.innerSpotAngle = angle * .62f;
            spot.shadows = LightShadows.None;
        }
    }
}
