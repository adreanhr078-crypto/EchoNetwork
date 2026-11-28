using System;
using System.Collections.Generic;
using System.Linq;
using UnityEditor;
using UnityEngine;

namespace ElevenEleven.Editor
{
    internal static partial class ChapterWallFabrication
    {
        private const string PactHeadMaterialAsset = "Ward Pact72 head material";
        private const string SchoolSuitMaterialAsset = "Ward school suit anime material";
        // Auto-computed clean skin UV from upper-neck/lower-chin triangles so UV Y-flip never mis-samples suit stripes

        private static (SkinnedMeshRenderer body, Mesh wardBody, GameObject wardHead) FitWardPostPactHead(Transform school, Transform pact)
        {
            var built = BuildWardPostPactHeadAndEye(school, pact);
            return (built.body, built.wardBody, null);
        }

        internal static (SkinnedMeshRenderer body, Mesh wardBody, Material originalMaterial, Material schoolAnimeMaterial, Material postPactMaterial, Vector3 alignedLeftEyeWorld, Vector3[] alignedHeadVerts, int[] alignedHeadTris)
            BuildWardPostPactHeadAndEye(Transform school, Transform pact)
        {
            var target = school.GetComponentsInChildren<SkinnedMeshRenderer>(true).Single();
            var donor = pact.GetComponentsInChildren<SkinnedMeshRenderer>(true).Single();
            var schoolHead = Joint(target, "Head");
            var schoolNeck = Joint(target, "Neck");
            var legacyHead = schoolHead.Find("Ward original Pact72 head and hair");
            if (legacyHead) UnityEngine.Object.DestroyImmediate(legacyHead.gameObject);

            // Sample canonical idle poses before reading bone matrices so School65 and Pact72 rest frames align accurately
            var schoolAnim = school.GetComponentInChildren<Animation>(true);
            var idleClip = schoolAnim ? schoolAnim.GetClip("Idle") : null;
            if (idleClip) idleClip.SampleAnimation(schoolAnim.gameObject, 0f);
            var pactAnim = pact.GetComponentInChildren<Animation>(true);
            var pactIdle = pactAnim ? pactAnim.GetClip("Idle") : null;
            if (pactIdle) pactIdle.SampleAnimation(pactAnim.gameObject, 0.15f);

            var pactHead = Joint(donor, "Head");
            var pactNeck = Joint(donor, "Neck");
            var originalBody = target.sharedMesh;
            var originalHead = donor.sharedMesh;
            var originalMaterial = target.sharedMaterials != null && target.sharedMaterials.Length > 0
                ? target.sharedMaterials[0]
                : target.sharedMaterial;

            // Compute exact world positions directly from Unity skinning matrices (immune to BakeMesh scale quirks)
            var schoolBindposes = originalBody.bindposes;
            var targetBoneMats = new Matrix4x4[target.bones.Length];
            for (var bi = 0; bi < target.bones.Length; bi++)
                targetBoneMats[bi] = target.bones[bi].localToWorldMatrix * schoolBindposes[bi];

            var schoolOrigVerts = originalBody.vertices;
            var schoolOrigWeights = originalBody.boneWeights;
            var schoolTriangles = originalBody.triangles;
            var targetBoneMap = IndexBonesBySuffix(target.bones);
            var schoolHeadIdx = targetBoneMap["Head"];
            var schoolNeckIdx = targetBoneMap["Neck"];
            var schoolCrownIdx = targetBoneMap.TryGetValue("HeadTop_End", out var cIdx) ? cIdx : -1;

            var schoolWorld = new Vector3[schoolOrigVerts.Length];
            for (var i = 0; i < schoolOrigVerts.Length; i++)
                schoolWorld[i] = ComputeSkinMatrix(schoolOrigWeights[i], targetBoneMats).MultiplyPoint3x4(schoolOrigVerts[i]);

            var sNeckPos = schoolNeck.position;
            var sHeadPos = schoolHead.position;
            var sAxis = sHeadPos - sNeckPos;
            var sLen2 = Mathf.Max(1e-6f, sAxis.sqrMagnitude);
            var sUp = sAxis.normalized;

            var schoolTrimmedTriangles = new List<int>(schoolTriangles.Length);
            for (var i = 0; i < schoolTriangles.Length; i += 3)
            {
                var a = schoolTriangles[i];
                var b = schoolTriangles[i + 1];
                var c = schoolTriangles[i + 2];
                var centroid = (schoolWorld[a] + schoolWorld[b] + schoolWorld[c]) / 3f;
                var t = Vector3.Dot(centroid - sNeckPos, sAxis) / sLen2;
                if (t >= 0.455f) continue;

                if (t >= 0.36f)
                {
                    var radial = Vector3.Distance(centroid, sNeckPos + t * sAxis);
                    var innerLimit = Mathf.Lerp(0.036f, 0.043f, Mathf.InverseLerp(0.36f, 0.455f, t));
                    if (radial < innerLimit) continue;
                }

                schoolTrimmedTriangles.Add(a);
                schoolTrimmedTriangles.Add(b);
                schoolTrimmedTriangles.Add(c);
            }

            // Donor skinning directly from donor bone matrices
            var donorBindposes = originalHead.bindposes;
            var donorBoneMats = new Matrix4x4[donor.bones.Length];
            for (var bi = 0; bi < donor.bones.Length; bi++)
                donorBoneMats[bi] = donor.bones[bi].localToWorldMatrix * donorBindposes[bi];

            var dLocalPos = originalHead.vertices;
            var dLocalNorm = originalHead.normals;
            var dTris = originalHead.triangles;
            var dWeights = originalHead.boneWeights;
            var dUvs = originalHead.uv;

            var dWorld = new Vector3[dLocalPos.Length];
            var dWorldNormal = new Vector3[dLocalPos.Length];
            for (var i = 0; i < dLocalPos.Length; i++)
            {
                var skinMat = ComputeSkinMatrix(dWeights[i], donorBoneMats);
                dWorld[i] = skinMat.MultiplyPoint3x4(dLocalPos[i]);
                dWorldNormal[i] = (i < dLocalNorm.Length ? skinMat.MultiplyVector(dLocalNorm[i]) : Vector3.up).normalized;
            }

            var dBoneMap = IndexBonesBySuffix(donor.bones);
            var dHeadIdx = dBoneMap["Head"];
            var dNeckIdx = dBoneMap["Neck"];
            var dCrownIdx = dBoneMap.TryGetValue("HeadTop_End", out var dcIdx) ? dcIdx : -1;
            var dLeftShIdx = dBoneMap.TryGetValue("LeftShoulder", out var lsh) ? lsh : -1;
            var dRightShIdx = dBoneMap.TryGetValue("RightShoulder", out var rsh) ? rsh : -1;

            var (uqId, origComp, origCompCount) = BuildWeldedComponents(dWorld, dTris);
            var compCount = new int[origCompCount];
            var compNhcSum = new float[origCompCount];
            var compShMax = new float[origCompCount];
            var compMaxY = new float[origCompCount];
            var compMinY = new float[origCompCount];
            for (var i = 0; i < origCompCount; i++)
            {
                compMaxY[i] = float.NegativeInfinity;
                compMinY[i] = float.PositiveInfinity;
            }

            for (var v = 0; v < dWorld.Length; v++)
            {
                var comp = origComp[uqId[v]];
                compCount[comp]++;
                compNhcSum[comp] += HeadWeight(dWeights[v], dHeadIdx, dNeckIdx, dCrownIdx);
                var shW = ShoulderWeight(dWeights[v], dLeftShIdx, dRightShIdx);
                if (shW > compShMax[comp]) compShMax[comp] = shW;
                if (dWorld[v].y > compMaxY[comp]) compMaxY[comp] = dWorld[v].y;
                if (dWorld[v].y < compMinY[comp]) compMinY[comp] = dWorld[v].y;
            }

            var mainOrigComp = 0;
            for (var c = 1; c < origCompCount; c++)
                if (compCount[c] > compCount[mainOrigComp]) mainOrigComp = c;

            var pNeckPos = pactNeck.position;
            var pHeadPos = pactHead.position;
            var pAxis = pHeadPos - pNeckPos;
            var pLen2 = Mathf.Max(1e-6f, pAxis.sqrMagnitude);
            var pUp = pAxis.normalized;

            var keepOrigComp = new bool[origCompCount];
            var eyeComps = new List<(int comp, int count, float lateralLeft, Vector3 meanWorld)>();
            for (var c = 0; c < origCompCount; c++)
            {
                if (compCount[c] == 0) continue;
                var meanNhc = compNhcSum[c] / compCount[c];
                var isSkullIsland = meanNhc > 0.92f && compShMax[c] < 0.05f && compMaxY[c] >= pHeadPos.y + 0.015f;
                keepOrigComp[c] = (c == mainOrigComp) || isSkullIsland;
                if (isSkullIsland && compCount[c] >= 24 && compCount[c] <= 180)
                {
                    var meanPos = Vector3.zero;
                    var n = 0;
                    for (var v = 0; v < dWorld.Length; v++)
                    {
                        if (origComp[uqId[v]] != c) continue;
                        meanPos += dWorld[v];
                        n++;
                    }
                    if (n > 0)
                    {
                        meanPos /= n;
                        // Eye islands sit forward of Head center and near pHeadPos.y + 0.02..0.055m
                        var fwdDot = Vector3.Dot(meanPos - pHeadPos, pact.forward);
                        var upOff = Vector3.Dot(meanPos - pHeadPos, pUp);
                        if (fwdDot > 0.05f && upOff > 0.015f && upOff < 0.075f)
                            eyeComps.Add((c, n, Vector3.Dot(meanPos - pHeadPos, -pact.right), meanPos));
                    }
                }
            }

            // Filter donor triangles along the clean anatomical neck envelope
            var tVert = new float[dWorld.Length];
            var rVert = new float[dWorld.Length];
            var rVecVert = new Vector3[dWorld.Length];
            for (var v = 0; v < dWorld.Length; v++)
            {
                var t = Vector3.Dot(dWorld[v] - pNeckPos, pAxis) / pLen2;
                tVert[v] = t;
                rVecVert[v] = dWorld[v] - (pNeckPos + t * pAxis);
                rVert[v] = rVecVert[v].magnitude;
            }

            var preFilteredTris = new List<int>(16000);
            for (var i = 0; i < dTris.Length; i += 3)
            {
                var a = dTris[i];
                var b = dTris[i + 1];
                var c = dTris[i + 2];
                if (!keepOrigComp[origComp[uqId[a]]]) continue;

                var tAvg = (tVert[a] + tVert[b] + tVert[c]) / 3f;
                if (tAvg < 0.24f) continue;

                if (tAvg < 0.72f)
                {
                    var rAvg = (rVert[a] + rVert[b] + rVert[c]) / 3f;
                    var rVecAvg = (rVecVert[a] + rVecVert[b] + rVecVert[c]) / 3f;
                    var zCentroidFwd = Vector3.Dot(rVecAvg, pact.forward);
                    var xCentroidAbs = Mathf.Abs(Vector3.Dot(rVecAvg, pact.right));
                    // Preserve sharp front anime chin while cleanly excluding left-neck vein tendrils & collar borders
                    var isCenterChin = tAvg >= 0.49f && zCentroidFwd > 0.026f && xCentroidAbs < 0.042f;
                    var maxR = isCenterChin
                        ? 0.082f
                        : tAvg < 0.38f && xCentroidAbs > 0.032f
                            ? 0.0415f
                            : tAvg < 0.58f && xCentroidAbs > 0.036f
                                ? 0.0435f
                                : tAvg < 0.60f
                                    ? Mathf.Lerp(0.0430f, 0.0462f, Mathf.InverseLerp(0.24f, 0.60f, tAvg))
                                    : Mathf.Lerp(0.0462f, 0.0650f, Mathf.InverseLerp(0.60f, 0.72f, tAvg));
                    if (rAvg > maxR) continue;
                }

                preFilteredTris.Add(a);
                preFilteredTris.Add(b);
                preFilteredTris.Add(c);
            }

            // Post-cut connected components: keep only islands linked to the upper skull/eyes
            var preTrisArr = preFilteredTris.ToArray();
            var (postUq, postComp, postCompCount) = BuildWeldedComponents(dWorld, preTrisArr, uqId);
            var postMaxY = new float[postCompCount];
            for (var i = 0; i < postCompCount; i++) postMaxY[i] = float.NegativeInfinity;
            for (var i = 0; i < preTrisArr.Length; i++)
            {
                var v = preTrisArr[i];
                var pc = postComp[postUq[v]];
                if (dWorld[v].y > postMaxY[pc]) postMaxY[pc] = dWorld[v].y;
            }

            // Crease-preserving smooth skin normals across entire head without horizontal shading seams
            var smoothedDonorNormal = BuildSmoothedFaceNormals(dWorld, dWorldNormal, uqId, dWorld.Length, preTrisArr, pNeckPos, pHeadPos, pAxis, pact.forward);

            // Alignment transform: orient Pact72 Neck->Head onto School65 Neck->Head at matched eye elevation
            var alignRot = Quaternion.FromToRotation(pUp, sUp);
            var targetPivot = Vector3.Lerp(sNeckPos, sHeadPos, 0.95f);

            var leftEyeCenter = sHeadPos + sUp * 0.040f + school.forward * 0.070f - school.right * 0.031f;
            if (eyeComps.Count > 0)
            {
                var best = eyeComps.OrderByDescending(e => e.lateralLeft).First();
                if (best.lateralLeft > 0.015f)
                    leftEyeCenter = targetPivot + alignRot * (best.meanWorld - pHeadPos);
            }

            var dToTargetBone = MapDonorBonesToTarget(donor.bones, targetBoneMap, schoolHeadIdx, schoolNeckIdx, schoolCrownIdx);

            // Combine original School65 vertices + aligned Pact72 head/neck vertices preserving original Pact72 skin UVs
            var remap = new Dictionary<int, int>();
            var schoolVertexCount = originalBody.vertexCount;
            var combinedVertices = new List<Vector3>(schoolVertexCount + 5000);
            combinedVertices.AddRange(schoolOrigVerts);
            var combinedNormals = new List<Vector3>(schoolVertexCount + 5000);
            combinedNormals.AddRange(originalBody.normals);
            var combinedUvs = new List<Vector2>(schoolVertexCount + 5000);
            combinedUvs.AddRange(originalBody.uv);
            var combinedWeights = new List<BoneWeight>(schoolVertexCount + 5000);
            combinedWeights.AddRange(schoolOrigWeights);

            var alignedHeadWorldVerts = new List<Vector3>(6000);
            var alignedHeadLocalTris = new List<int>(preTrisArr.Length);
            var pactLocalRemap = new Dictionary<int, int>();
            var pactFinalTris = new List<int>(preTrisArr.Length);
            var pactFwd = pact.forward;
            for (var i = 0; i < preTrisArr.Length; i += 3)
            {
                var a = preTrisArr[i];
                if (postMaxY[postComp[postUq[a]]] < pHeadPos.y + 0.015f) continue;

                for (var corner = 0; corner < 3; corner++)
                {
                    var dv = preTrisArr[i + corner];
                    if (!remap.TryGetValue(dv, out var newIdx))
                    {
                        newIdx = combinedVertices.Count;
                        remap[dv] = newIdx;

                        var worldP = dWorld[dv];
                        var worldN = smoothedDonorNormal[dv];
                        var uv = dUvs[dv];
                        var t = tVert[dv];

                        // Gently tuck only the hidden sub-collar neck skirt (<0.30, inside shirt collar) without altering UVs
                        if (t < 0.31f)
                        {
                            var zFwd = Vector3.Dot(rVecVert[dv], pactFwd);
                            if (zFwd > -0.025f)
                            {
                                var smoothT = Mathf.Lerp(0.16f, 0.31f, Mathf.InverseLerp(0.24f, 0.31f, t));
                                var clampR = Mathf.Lerp(0.0365f, 0.0435f, Mathf.InverseLerp(0.24f, 0.31f, t));
                                var rVec = rVecVert[dv];
                                if (rVec.magnitude > clampR)
                                    rVec = rVec.normalized * clampR;
                                worldP = pNeckPos + smoothT * pAxis + rVec;
                            }
                        }

                        var alignedWPos = targetPivot + alignRot * (worldP - pHeadPos);
                        var alignedWNorm = (alignRot * worldN).normalized;

                        var localHeadIdx = alignedHeadWorldVerts.Count;
                        pactLocalRemap[dv] = localHeadIdx;
                        alignedHeadWorldVerts.Add(alignedWPos);

                        var spineIdx = targetBoneMap.TryGetValue("Spine2", out var sp2) ? sp2 : schoolNeckIdx;
                        var targetBw = RemapAndSanitizeWeight(dWeights[dv], dToTargetBone, schoolHeadIdx, schoolNeckIdx, spineIdx, t);
                        var invSkin = ComputeSkinMatrix(targetBw, targetBoneMats).inverse;

                        combinedVertices.Add(invSkin.MultiplyPoint3x4(alignedWPos));
                        combinedNormals.Add(invSkin.MultiplyVector(alignedWNorm).normalized);
                        combinedUvs.Add(uv);
                        combinedWeights.Add(targetBw);
                    }
                    pactFinalTris.Add(newIdx);
                    alignedHeadLocalTris.Add(pactLocalRemap[dv]);
                }
            }

            var wardBody = new Mesh
            {
                name = "Ward school body with fitted neck opening",
                indexFormat = combinedVertices.Count > 65000
                    ? UnityEngine.Rendering.IndexFormat.UInt32
                    : UnityEngine.Rendering.IndexFormat.UInt16,
                subMeshCount = 2,
            };
            wardBody.SetVertices(combinedVertices);
            wardBody.SetNormals(combinedNormals);
            wardBody.SetUVs(0, combinedUvs);
            wardBody.boneWeights = combinedWeights.ToArray();
            wardBody.bindposes = schoolBindposes;
            wardBody.SetTriangles(schoolTrimmedTriangles, 0, false);
            wardBody.SetTriangles(pactFinalTris, 1, false);
            wardBody.RecalculateTangents();
            wardBody.RecalculateBounds();
            wardBody = SaveInductorMesh("Ward school body with fitted neck opening", wardBody);

            var animeShader = AssetDatabase.LoadAssetAtPath<Shader>("Assets/ElevenEleven/Opening/Hospital/HyperAnimeCharacter.shader");
            if (!animeShader || ShaderUtil.ShaderHasError(animeShader))
                throw new InvalidOperationException("HyperAnimeCharacter.shader failed to compile.");

            var schoolAnimeMat = BuildHyperAnimeMaterial(SchoolSuitMaterialAsset, originalMaterial, animeShader,
                new Color(.96f, .95f, .96f, 1f), new Color(.70f, .70f, .78f, 1f), -.03f, .18f, .30f, .24f, .24f);
            var postPactMat = BuildHyperAnimeMaterial(PactHeadMaterialAsset, donor.sharedMaterial, animeShader,
                new Color(.97f, .95f, .95f, 1f), new Color(.76f, .71f, .80f, 1f), -.06f, .22f, .36f, .24f, .18f);

            target.sharedMesh = originalBody;
            target.sharedMaterials = originalMaterial ? new[] { originalMaterial } : target.sharedMaterials;

            var sMinY = schoolWorld.Min(v => v.y);
            var sMaxY = schoolWorld.Max(v => v.y);
            Debug.Log($"ECHO_WARD_PACT_HEAD school_verts={schoolVertexCount} school_y=[{sMinY:F3}..{sMaxY:F3}] school_tris={schoolTrimmedTriangles.Count / 3} pact_verts={remap.Count} pact_tris={pactFinalTris.Count / 3} left_eye_local={schoolHead.InverseTransformPoint(leftEyeCenter)}");
            Debug.Log($"WARD_UNIFIED_HEAD school_verts={schoolVertexCount} school_y=[{sMinY:F3}..{sMaxY:F3}] school_tris={schoolTrimmedTriangles.Count / 3} pact_verts={remap.Count} pact_tris={pactFinalTris.Count / 3} left_eye_local={schoolHead.InverseTransformPoint(leftEyeCenter)}");
            return (target, wardBody, originalMaterial, schoolAnimeMat, postPactMat, leftEyeCenter, alignedHeadWorldVerts.ToArray(), alignedHeadLocalTris.ToArray());
        }

        private static Vector3[] BuildSmoothedFaceNormals(Vector3[] pos, Vector3[] norm, int[] vertToUq, int vertCount,
            int[] keptTris, Vector3 pNeckPos, Vector3 pHeadPos, Vector3 pAxis, Vector3 headFwd)
        {
            var smoothed = (Vector3[])norm.Clone();
            var len2 = Mathf.Max(1e-6f, pAxis.sqrMagnitude);
            var uqCount = vertToUq.Max() + 1;
            var accum = new Vector3[uqCount];
            var inKeep = new bool[vertCount];
            for (var i = 0; i < keptTris.Length; i++) inKeep[keptTris[i]] = true;

            for (var v = 0; v < vertCount; v++)
            {
                if (!inKeep[v]) continue;
                var rel = pos[v] - pHeadPos;
                var fwd = Vector3.Dot(rel, headFwd);
                var t = Vector3.Dot(pos[v] - pNeckPos, pAxis) / len2;
                if (t >= 0.25f && fwd > -0.025f)
                    accum[vertToUq[v]] += norm[v];
            }

            for (var v = 0; v < vertCount; v++)
            {
                var rel = pos[v] - pHeadPos;
                var t = Vector3.Dot(pos[v] - pNeckPos, pAxis) / len2;
                if (t < 0.25f || Vector3.Dot(rel, headFwd) <= -0.025f) continue;
                var avg = accum[vertToUq[v]];
                if (avg.sqrMagnitude > 1e-6f)
                {
                    var avgN = avg.normalized;
                    // Preserve sharp geometric edges (eyelids, brows, lips, nose ridge) while smoothly uniting continuous skin surfaces
                    if (Vector3.Dot(norm[v], avgN) > 0.78f)
                        smoothed[v] = Vector3.Slerp(norm[v], avgN, 0.74f).normalized;
                }
            }
            return smoothed;
        }

        private static Material BuildHyperAnimeMaterial(string assetName, Material sourceMat, Shader shader,
            Color baseCol, Color shadowCol, float shadowOffset, float shadowFeather, float rimStrength, float hairSheen, float inkDarken)
        {
            var path = Folder + assetName + ".mat";
            var mat = AssetDatabase.LoadAssetAtPath<Material>(path);
            if (!mat)
            {
                mat = new Material(shader) { name = assetName };
                AssetDatabase.CreateAsset(mat, path);
            }
            else
            {
                mat.shader = shader;
                mat.name = assetName;
            }
            Texture albedo = null;
            if (sourceMat)
            {
                if (sourceMat.HasProperty("baseColorTexture")) albedo = sourceMat.GetTexture("baseColorTexture");
                if (!albedo && sourceMat.HasProperty("_BaseMap")) albedo = sourceMat.GetTexture("_BaseMap");
                if (!albedo) albedo = sourceMat.mainTexture;
            }
            if (albedo) mat.SetTexture("_BaseMap", albedo);
            mat.SetColor("_BaseColor", baseCol);
            mat.SetColor("_ShadowColor", shadowCol);
            mat.SetFloat("_ShadowOffset", shadowOffset);
            mat.SetFloat("_ShadowFeather", shadowFeather);
            mat.SetColor("_RimColor", new Color(.64f, .86f, 1f, 1f));
            mat.SetFloat("_RimPower", 3.6f);
            mat.SetFloat("_RimStrength", rimStrength);
            mat.SetFloat("_HairSheen", hairSheen);
            mat.SetFloat("_OutlineDarken", inkDarken);
            EditorUtility.SetDirty(mat);
            AssetDatabase.SaveAssetIfDirty(mat);
            return mat;
        }

        private static Dictionary<string, int> IndexBonesBySuffix(Transform[] bones)
        {
            var dict = new Dictionary<string, int>(bones.Length, StringComparer.Ordinal);
            for (var i = 0; i < bones.Length; i++)
            {
                var name = bones[i] ? bones[i].name : string.Empty;
                var colon = name.LastIndexOf(':');
                var key = colon >= 0 ? name.Substring(colon + 1) : name;
                dict[key] = i;
            }
            return dict;
        }

        private static int[] MapDonorBonesToTarget(Transform[] donorBones, Dictionary<string, int> targetMap, int fallbackHead, int fallbackNeck, int fallbackCrown)
        {
            var result = new int[donorBones.Length];
            for (var i = 0; i < donorBones.Length; i++)
            {
                var name = donorBones[i] ? donorBones[i].name : string.Empty;
                var colon = name.LastIndexOf(':');
                var key = colon >= 0 ? name.Substring(colon + 1) : name;
                if (targetMap.TryGetValue(key, out var idx))
                {
                    result[i] = idx;
                }
                else
                {
                    result[i] = key.Contains("Neck") ? fallbackNeck
                        : (key.Contains("Top") || key.Contains("Crown")) && fallbackCrown >= 0 ? fallbackCrown
                        : fallbackHead;
                }
            }
            return result;
        }

        private static BoneWeight RemapAndSanitizeWeight(BoneWeight src, int[] boneMap, int headIdx, int neckIdx, int schoolSpineIdx, float t)
        {
            Span<(int idx, float w)> entries = stackalloc (int, float)[4];
            entries[0] = (MapIndex(src.boneIndex0), src.weight0);
            entries[1] = (MapIndex(src.boneIndex1), src.weight1);
            entries[2] = (MapIndex(src.boneIndex2), src.weight2);
            entries[3] = (MapIndex(src.boneIndex3), src.weight3);

            int MapIndex(int dIdx)
            {
                if (dIdx < 0 || dIdx >= boneMap.Length) return t < 0.45f ? neckIdx : headIdx;
                var mapped = boneMap[dIdx];
                if (mapped == headIdx || mapped == neckIdx || mapped == schoolSpineIdx) return mapped;
                return t < 0.45f ? neckIdx : headIdx;
            }

            var sum = entries[0].w + entries[1].w + entries[2].w + entries[3].w;
            if (sum < 1e-5f)
                return new BoneWeight { boneIndex0 = t < 0.45f ? neckIdx : headIdx, weight0 = 1f };

            return new BoneWeight
            {
                boneIndex0 = entries[0].idx, weight0 = entries[0].w / sum,
                boneIndex1 = entries[1].idx, weight1 = entries[1].w / sum,
                boneIndex2 = entries[2].idx, weight2 = entries[2].w / sum,
                boneIndex3 = entries[3].idx, weight3 = entries[3].w / sum,
            };
        }

        private static Matrix4x4 ComputeSkinMatrix(BoneWeight bw, Matrix4x4[] boneMats)
        {
            var m = new Matrix4x4();
            AddScaled(ref m, boneMats[bw.boneIndex0], bw.weight0);
            if (bw.weight1 > 0f) AddScaled(ref m, boneMats[bw.boneIndex1], bw.weight1);
            if (bw.weight2 > 0f) AddScaled(ref m, boneMats[bw.boneIndex2], bw.weight2);
            if (bw.weight3 > 0f) AddScaled(ref m, boneMats[bw.boneIndex3], bw.weight3);
            return m;
        }

        private static void AddScaled(ref Matrix4x4 acc, in Matrix4x4 m, float w)
        {
            for (var i = 0; i < 16; i++) acc[i] += m[i] * w;
        }

        private static (int[] vertToUq, int[] uqToComp, int compCount) BuildWeldedComponents(Vector3[] positions, int[] triangles, int[] existingUq = null)
        {
            var vertToUq = existingUq;
            int uqCount;
            if (vertToUq == null)
            {
                vertToUq = new int[positions.Length];
                var seen = new Dictionary<(int, int, int), int>(positions.Length);
                uqCount = 0;
                for (var i = 0; i < positions.Length; i++)
                {
                    var p = positions[i];
                    var key = (Mathf.RoundToInt(p.x * 10000f), Mathf.RoundToInt(p.y * 10000f), Mathf.RoundToInt(p.z * 10000f));
                    if (!seen.TryGetValue(key, out var id))
                    {
                        id = uqCount++;
                        seen[key] = id;
                    }
                    vertToUq[i] = id;
                }
            }
            else
            {
                uqCount = vertToUq.Length == 0 ? 0 : vertToUq.Max() + 1;
            }

            var parent = new int[uqCount];
            for (var i = 0; i < uqCount; i++) parent[i] = i;

            int Find(int x)
            {
                while (parent[x] != x)
                {
                    parent[x] = parent[parent[x]];
                    x = parent[x];
                }
                return x;
            }

            void Union(int x, int y)
            {
                var rx = Find(x);
                var ry = Find(y);
                if (rx != ry) parent[ry] = rx;
            }

            for (var i = 0; i < triangles.Length; i += 3)
            {
                var ua = vertToUq[triangles[i]];
                var ub = vertToUq[triangles[i + 1]];
                var uc = vertToUq[triangles[i + 2]];
                Union(ua, ub);
                Union(ub, uc);
            }

            var rootMap = new Dictionary<int, int>(128);
            var uqToComp = new int[uqCount];
            for (var i = 0; i < uqCount; i++)
            {
                var r = Find(i);
                if (!rootMap.TryGetValue(r, out var cid))
                {
                    cid = rootMap.Count;
                    rootMap[r] = cid;
                }
                uqToComp[i] = cid;
            }

            return (vertToUq, uqToComp, rootMap.Count);
        }

        private static Transform Joint(SkinnedMeshRenderer skin, string key) => skin.bones.Single(bone =>
            bone.name.EndsWith(":" + key, StringComparison.Ordinal) || bone.name == key);

        private static float HeadWeight(BoneWeight weight, int head, int neck, int crown = -1)
        {
            var sum = 0f;
            if (weight.boneIndex0 == head || weight.boneIndex0 == neck || weight.boneIndex0 == crown) sum += weight.weight0;
            if (weight.boneIndex1 == head || weight.boneIndex1 == neck || weight.boneIndex1 == crown) sum += weight.weight1;
            if (weight.boneIndex2 == head || weight.boneIndex2 == neck || weight.boneIndex2 == crown) sum += weight.weight2;
            if (weight.boneIndex3 == head || weight.boneIndex3 == neck || weight.boneIndex3 == crown) sum += weight.weight3;
            return sum;
        }

        private static float ShoulderWeight(BoneWeight weight, int leftShoulder, int rightShoulder)
        {
            var sum = 0f;
            if (weight.boneIndex0 == leftShoulder || weight.boneIndex0 == rightShoulder) sum += weight.weight0;
            if (weight.boneIndex1 == leftShoulder || weight.boneIndex1 == rightShoulder) sum += weight.weight1;
            if (weight.boneIndex2 == leftShoulder || weight.boneIndex2 == rightShoulder) sum += weight.weight2;
            if (weight.boneIndex3 == leftShoulder || weight.boneIndex3 == rightShoulder) sum += weight.weight3;
            return sum;
        }
    }
}
