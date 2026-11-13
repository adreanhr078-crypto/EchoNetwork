using System;

namespace ElevenEleven.Opening
{
    public enum OpeningBeat
    {
        School,
        Laboratory,
        Questions,
        ExperimentReply,
        SafetyReply,
        Experiment,
        Complete,
        Memory,
        SystemWake,
    }

    [Flags]
    public enum OpeningQuestion
    {
        None = 0,
        Experiment = 1,
        Safety = 2,
    }

    public sealed class OpeningSequence
    {
        private const OpeningQuestion AllQuestions = OpeningQuestion.Experiment | OpeningQuestion.Safety;

        public OpeningBeat Beat { get; private set; } = OpeningBeat.School;
        public OpeningQuestion Asked { get; private set; }
        public bool Paused { get; private set; }

        public bool TryRestore(OpeningBeat beat, OpeningQuestion asked)
        {
            if (!Enum.IsDefined(typeof(OpeningBeat), beat) || (asked & ~AllQuestions) != 0 ||
                (beat == OpeningBeat.ExperimentReply && (asked & OpeningQuestion.Experiment) == 0) ||
                (beat == OpeningBeat.SafetyReply && (asked & OpeningQuestion.Safety) == 0))
                return false;

            Beat = beat;
            Asked = asked;
            Paused = false;
            return true;
        }

        public bool AdvanceShot()
        {
            if (Paused) return false;

            switch (Beat)
            {
                case OpeningBeat.School: Beat = OpeningBeat.Laboratory; return true;
                case OpeningBeat.Laboratory: Beat = OpeningBeat.Questions; return true;
                case OpeningBeat.Experiment: Beat = OpeningBeat.Memory; return true;
                case OpeningBeat.Memory: Beat = OpeningBeat.SystemWake; return true;
                case OpeningBeat.SystemWake: Beat = OpeningBeat.Complete; return true;
                default: return false;
            }
        }

        public bool Ask(OpeningQuestion question)
        {
            if (Paused || Beat != OpeningBeat.Questions ||
                (question != OpeningQuestion.Experiment && question != OpeningQuestion.Safety))
                return false;

            Asked |= question;
            Beat = question == OpeningQuestion.Experiment ? OpeningBeat.ExperimentReply : OpeningBeat.SafetyReply;
            return true;
        }

        public bool ReturnToQuestions()
        {
            if (Paused || (Beat != OpeningBeat.ExperimentReply && Beat != OpeningBeat.SafetyReply)) return false;

            Beat = OpeningBeat.Questions;
            return true;
        }

        public bool BeginExperiment()
        {
            if (Paused || Beat != OpeningBeat.Questions) return false;

            Beat = OpeningBeat.Experiment;
            return true;
        }

        public void SetPaused(bool paused)
        {
            if (Beat != OpeningBeat.Complete) Paused = paused;
        }
    }
}
