using System;
using Unity.Animations.SpringBones;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

[InitializeOnLoad]
internal static class SpringBoneReview
{
    private const string Running = "EchoVitality.SpringBoneReview";
    private const float Length = 0.08f;
    private static float deadline;
    private static SpringManager manager;
    private static SpringBone[] bones;
    private static int settleFrames;

    static SpringBoneReview()
    {
        if (SessionState.GetBool(Running, false)) EditorApplication.update += Tick;
    }

    public static void Run()
    {
        EditorSceneManager.NewScene(NewSceneSetup.EmptyScene);
        SessionState.SetBool(Running, true);
        EditorApplication.update += Tick;
        EditorApplication.EnterPlaymode();
    }

    private static void Tick()
    {
        if (!EditorApplication.isPlaying) return;
        try
        {
            if (deadline == 0f) deadline = (float)EditorApplication.timeSinceStartup + 45f;
            if (EditorApplication.timeSinceStartup > deadline)
                throw new TimeoutException("The isolated SpringBone review timed out.");
            if (manager == null)
            {
                Build();
                return;
            }

            if (++settleFrames < 4) return;
            var largestDeflection = 0f;
            var peakLengthError = 0f;
            var finalDeflection = 0f;
            for (var step = 0; step < 300; step++)
            {
                var turn = Mathf.SmoothStep(0f, 90f, (step - 60) / 12f);
                manager.transform.rotation = Quaternion.Euler(0f, turn, 0f);
                manager.UpdateDynamics();
                foreach (var bone in bones)
                {
                    var tip = bone.CurrentTipPosition;
                    var lengthError = Mathf.Abs(Vector3.Distance(bone.transform.position, tip) - Length);
                    Require(float.IsFinite(lengthError), "The solver produced a non-finite tip.");
                    peakLengthError = Mathf.Max(peakLengthError, lengthError);
                    var deflection = Quaternion.Angle(Quaternion.identity, bone.transform.localRotation);
                    largestDeflection = Mathf.Max(largestDeflection, deflection);
                    if (step == 299) finalDeflection = Mathf.Max(finalDeflection, deflection);
                }
            }

            var heldTip = bones[0].CurrentTipPosition;
            manager.isPaused = true;
            manager.transform.Rotate(Vector3.up, 40f);
            manager.UpdateDynamics();
            Require(Vector3.Distance(heldTip, bones[0].CurrentTipPosition) < 1e-6f, "The paused solver advanced.");
            Require(peakLengthError < 0.0001f, "A strand changed length.");
            Require(largestDeflection > 5f && largestDeflection < 45f, "The turn did not produce a bounded response.");
            Require(finalDeflection < 4f, "The strands did not settle.");
            Debug.Log($"ECHO_SPRINGBONE_PASS strands={bones.Length} peakLengthErrorM={peakLengthError:G4} peakAngleDeg={largestDeflection:F3} finalAngleDeg={finalDeflection:F3}");
            Finish(0);
        }
        catch (Exception error)
        {
            Debug.LogException(error);
            Finish(1);
        }
    }

    private static void Build()
    {
        var rig = new GameObject("Three-strand solver fixture");
        rig.SetActive(false);
        bones = new SpringBone[3];
        for (var i = 0; i < bones.Length; i++)
        {
            var root = new GameObject($"Strand {i}").transform;
            root.SetParent(rig.transform, false);
            root.localPosition = new Vector3((i - 1) * 0.035f, 1.55f, 0f);
            var tip = new GameObject("Tip").transform;
            tip.SetParent(root, false);
            tip.localPosition = new Vector3(0f, -0.02f, Mathf.Sqrt(Length * Length - 0.02f * 0.02f));

            var spring = root.gameObject.AddComponent<SpringBone>();
            spring.stiffnessForce = 800f;
            spring.dragForce = 0.23f;
            spring.springForce = Vector3.zero;
            spring.lengthLimitTargets = Array.Empty<Transform>();
            spring.sphereColliders = Array.Empty<SpringSphereCollider>();
            spring.capsuleColliders = Array.Empty<SpringCapsuleCollider>();
            spring.panelColliders = Array.Empty<SpringPanelCollider>();
            bones[i] = spring;
        }

        manager = rig.AddComponent<SpringManager>();
        manager.automaticUpdates = false;
        manager.collideWithGround = false;
        manager.enableCollision = false;
        manager.enableAngleLimits = false;
        manager.gravity = new Vector3(0f, -0.5f, 0f);
        rig.SetActive(true);
    }

    private static void Require(bool condition, string message)
    {
        if (!condition) throw new InvalidOperationException(message);
    }

    private static void Finish(int code)
    {
        SessionState.EraseBool(Running);
        EditorApplication.update -= Tick;
        EditorApplication.Exit(code);
    }
}

