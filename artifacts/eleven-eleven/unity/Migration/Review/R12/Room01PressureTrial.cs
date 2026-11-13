using System;

namespace ElevenEleven.Opening
{
    internal sealed class Room01PressureTrial
    {
        internal const double HighSeconds = 3.6;
        internal const double LowSeconds = 2.8;
        internal const double VentSeconds = 5.5;
        internal const double PassageLength = 1.4;

        internal enum Choice { None, Cross, Valve }
        internal enum Route { None, Timing, Valve }
        internal enum Crossing { None, Retry, Completed }

        private bool inBand;
        private bool enteredWithValve;
        internal double Elapsed { get; private set; }
        internal double VentRemaining { get; private set; }
        internal int Attempts { get; private set; }
        internal int Failures { get; private set; }
        internal int ValveUses { get; private set; }
        internal Choice FirstChoice { get; private set; }
        internal double? FirstChoiceTime { get; private set; }
        internal Route CompletedRoute { get; private set; }
        internal double? CompletedTime { get; private set; }
        internal bool IsSafe { get { return VentRemaining > 0 || Elapsed % (HighSeconds + LowSeconds) >= HighSeconds; } }

        internal bool TryVent(bool playerCanReachValve, bool paused)
        {
            if (!playerCanReachValve || paused || CompletedRoute != Route.None || VentRemaining > 0)
                return false;

            VentRemaining = VentSeconds;
            ValveUses++;
            RecordChoice(Choice.Valve);
            return true;
        }

        // Distance is signed along the passage. The entrance is zero and the safe near side is negative.
        internal Crossing Advance(double delta, double distance, bool paused)
        {
            if (delta < 0 || double.IsNaN(delta) || double.IsInfinity(delta))
                throw new ArgumentOutOfRangeException("delta");
            if (double.IsNaN(distance) || double.IsInfinity(distance))
                throw new ArgumentOutOfRangeException("distance");
            if (paused || CompletedRoute != Route.None) return Crossing.None;

            Elapsed += delta;
            VentRemaining = Math.Max(0, VentRemaining - delta);
            if (distance < 0)
            {
                inBand = false;
                return Crossing.None;
            }
            if (!inBand)
            {
                inBand = true;
                enteredWithValve = VentRemaining > 0;
                Attempts++;
                RecordChoice(Choice.Cross);
            }
            if (!IsSafe)
            {
                Failures++;
                inBand = false;
                return Crossing.Retry;
            }
            if (distance < PassageLength) return Crossing.None;

            CompletedRoute = enteredWithValve ? Route.Valve : Route.Timing;
            CompletedTime = Elapsed;
            return Crossing.Completed;
        }

        private void RecordChoice(Choice choice)
        {
            if (FirstChoice != Choice.None) return;
            FirstChoice = choice;
            FirstChoiceTime = Elapsed;
        }
    }
}
