using System;
using ElevenEleven.Opening;

internal static class Room01PressureTrialProbe
{
    private static int checks;

    public static void Main()
    {
        var timing = new Room01PressureTrial();
        Check(!timing.IsSafe && timing.FirstChoiceTime == null && timing.CompletedTime == null, "Fresh passage starts at high pressure.");
        Check(timing.Advance(2, 1, true) == Room01PressureTrial.Crossing.None && timing.Elapsed == 0 && timing.Attempts == 0,
            "Pause preserves the phase and attempt state.");
        Check(timing.Advance(0.2, 0, false) == Room01PressureTrial.Crossing.Retry && timing.Failures == 1 && timing.Attempts == 1,
            "High pressure requests a retry to the safe near side.");
        Check(timing.FirstChoice == Room01PressureTrial.Choice.Cross && timing.FirstChoiceTime == 0.2 && timing.CompletedTime == null,
            "An abandoned crossing preserves its first choice and has no completion time.");
        timing.Advance(3.5, -0.5, false);
        Check(timing.IsSafe && timing.Advance(0.1, 0, false) == Room01PressureTrial.Crossing.None && timing.Attempts == 2,
            "The low-pressure window permits a second attempt.");
        Check(timing.Advance(0.9, 1.4, false) == Room01PressureTrial.Crossing.Completed &&
            timing.CompletedRoute == Room01PressureTrial.Route.Timing && timing.CompletedTime > timing.FirstChoiceTime,
            "Crossing the far edge completes the timing route.");
        Check(timing.Advance(8, 2, false) == Room01PressureTrial.Crossing.None && !timing.TryVent(true, false),
            "A completed route cannot be credited twice.");

        var valve = new Room01PressureTrial();
        Check(!valve.TryVent(false, false) && !valve.TryVent(true, true), "Valve rejects out-of-range and paused use.");
        Check(valve.TryVent(true, false) && valve.VentRemaining == 5.5 && valve.IsSafe && !valve.TryVent(true, false),
            "The valve opens an extended window and blocks duplicate input.");
        valve.Advance(0.8, 0, false);
        Check(valve.Advance(1, 1.4, false) == Room01PressureTrial.Crossing.Completed &&
            valve.FirstChoice == Room01PressureTrial.Choice.Valve && valve.CompletedRoute == Room01PressureTrial.Route.Valve &&
            valve.Failures == 0 && valve.ValveUses == 1, "The valve route records its independent outcome.");

        var late = new Room01PressureTrial();
        late.Advance(6.3, 0.1, false);
        Check(late.Advance(0.2, 1.35, false) == Room01PressureTrial.Crossing.Retry && late.Failures == 1,
            "A window expiring before the far edge returns the player to the near side.");
        Console.WriteLine("R12_PRESSURE_MODEL_PASS {0} checks", checks);
    }

    private static void Check(bool condition, string message)
    {
        if (!condition) throw new InvalidOperationException(message);
        checks++;
    }
}
