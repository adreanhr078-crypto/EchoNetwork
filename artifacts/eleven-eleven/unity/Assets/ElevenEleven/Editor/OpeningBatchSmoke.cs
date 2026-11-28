using System;
using System.Linq;
using ElevenEleven.Opening;
using UnityEditor;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.SceneManagement;
using UnityEngine.UI;
using UnityEngine.Video;

internal static class OpeningBatchSmoke
{
    public static void BuildAndVerify()
    {
        ElevenEleven.Editor.OpeningReviewSceneBuilder.Build();
        var scene = SceneManager.GetActiveScene();
        Require(scene.path.EndsWith("/OpeningReview.unity", StringComparison.Ordinal), "opening scene saved");
        var roots = scene.GetRootGameObjects();
        var host = roots.SelectMany(root => root.GetComponentsInChildren<OpeningReviewHost>(true)).Single();
        var cover = host.GetComponentInChildren<CoverRecoveryPresenter>(true);
        var film = host.GetComponentInChildren<OpeningCinematicPresenter>(true);
        Require(cover.gameObject.activeSelf && !film.gameObject.activeSelf, "cover owns first input");
        Require(cover.GetComponentsInChildren<CoverTileInput>(true).Length == 6, "six drag inputs");
        Require(cover.Restored.GetPersistentEventCount() == 1 && cover.Restored.GetPersistentTarget(0) == host, "single film handoff");
        var buttons = host.GetComponentsInChildren<Button>(true);
        Require(buttons.Length == 19 && buttons.All(button => button.onClick.GetPersistentEventCount() == 1), "all controls wired once");
        var data = new SerializedObject(film);
        Require(ClipLength(data, "school", 6) && ClipLength(data, "laboratory", 10.5) && ClipLength(data, "experiment", 11.5), "native film durations");
        Require(data.FindProperty("laboratory.ambience").objectReferenceValue == data.FindProperty("experiment.ambience").objectReferenceValue,
            "laboratory pressure-air source reused");
        var eventSystem = roots.Select(root => root.GetComponent<EventSystem>()).Single(system => system != null);
        Require(eventSystem.firstSelectedGameObject.TryGetComponent<CoverTileInput>(out _), "keyboard focus starts on the board");
        Debug.Log("OPENING_NATIVE_SCENE_BUILD_PASS 8 checks");
    }

    private static bool ClipLength(SerializedObject data, string field, double duration)
    {
        var clip = data.FindProperty(field + ".clip").objectReferenceValue as VideoClip;
        return clip != null && Math.Abs(clip.length - duration) < 0.05;
    }

    private static void Require(bool test, string label)
    {
        if (!test) throw new InvalidOperationException(label);
    }
}
