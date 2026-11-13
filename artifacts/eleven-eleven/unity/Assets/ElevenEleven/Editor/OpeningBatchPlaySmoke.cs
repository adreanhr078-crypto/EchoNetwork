using System;
using System.Linq;
using ElevenEleven.Opening;
using UnityEditor;
using UnityEngine;
using UnityEngine.UI;

[InitializeOnLoad]
internal static class OpeningBatchPlaySmoke
{
    private const string Running = "ElevenEleven.OpeningBatchPlay.Running";
    private const string Deadline = "ElevenEleven.OpeningBatchPlay.Deadline";
    private static int stage;
    private static int checks;

    static OpeningBatchPlaySmoke()
    {
        if (SessionState.GetBool(Running, false)) EditorApplication.update += Advance;
    }

    public static void Run()
    {
        OpeningBatchSmoke.BuildAndVerify();
        SessionState.SetBool(Running, true);
        SessionState.SetFloat(Deadline, (float)EditorApplication.timeSinceStartup + 90f);
        EditorApplication.update += Advance;
        EditorApplication.EnterPlaymode();
    }

    private static void Advance()
    {
        try
        {
            if (EditorApplication.timeSinceStartup > SessionState.GetFloat(Deadline, 0f))
                throw new TimeoutException("The opening Play Mode checks did not finish.");
            if (!EditorApplication.isPlaying) return;

            var host = UnityEngine.Object.FindFirstObjectByType<OpeningReviewHost>();
            var buttons = host.GetComponentsInChildren<Button>(true);
            var film = host.GetComponentInChildren<OpeningCinematicPresenter>(true);
            if (stage == 0)
            {
                host.ToggleMotion();
                Press(buttons, "Piece 1");
                Press(buttons, "Piece 2");
                Require(!film.gameObject.activeSelf, "first swap leaves cover active");
                Press(buttons, "Piece 5");
                Press(buttons, "Piece 6");
                Require(!film.gameObject.activeSelf, "last click cannot start the film in the same frame");
                stage = 1;
                return;
            }

            if (!film.gameObject.activeSelf) return;
            Require(film.Beat == OpeningBeat.School && !film.ShowingVideo, "school poster under reduced motion");
            Press(buttons, "Pause");
            Require(film.Paused && !Button(buttons, "Continue").interactable, "pause disables shot control");
            Press(buttons, "Pause");
            Press(buttons, "Continue");
            Require(film.Beat == OpeningBeat.Laboratory, "school advances to lab");
            Press(buttons, "Continue");
            Require(film.Beat == OpeningBeat.Questions, "lab advances to dialogue");
            Press(buttons, "What is this experiment?");
            Require(film.Beat == OpeningBeat.ExperimentReply, "experiment question routes to reply");
            Press(buttons, "Back to questions");
            Press(buttons, "What about safety?");
            Require(film.Beat == OpeningBeat.SafetyReply, "safety question routes to reply");
            Press(buttons, "Back to questions");
            Press(buttons, "I am ready.");
            Require(film.Beat == OpeningBeat.Experiment, "ready opens experiment");
            Press(buttons, "Continue");
            Require(film.Beat == OpeningBeat.Complete && !Button(buttons, "Continue").gameObject.activeSelf,
                "experiment finishes with no duplicate action");
            Debug.Log($"OPENING_NATIVE_PLAY_PASS {checks} checks");
            Finish(0);
        }
        catch (Exception error)
        {
            Debug.LogException(error);
            Finish(1);
        }
    }

    private static Button Button(Button[] buttons, string name) => buttons.Single(button => button.gameObject.name == name);

    private static void Press(Button[] buttons, string name)
    {
        var button = Button(buttons, name);
        if (!button.gameObject.activeInHierarchy || !button.interactable)
            throw new InvalidOperationException($"Unavailable control: {name}");
        button.onClick.Invoke();
    }

    private static void Require(bool result, string label)
    {
        if (!result) throw new InvalidOperationException(label);
        checks++;
    }

    private static void Finish(int code)
    {
        SessionState.EraseBool(Running);
        EditorApplication.update -= Advance;
        EditorApplication.Exit(code);
    }
}
