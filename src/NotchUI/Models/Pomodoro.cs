namespace NotchUI.Models;

// Adapted from Gili 1.0's Pomodoro in src/Support.cs; see licenses/Gili-MIT.txt.
public enum PomodoroPhase { Focus, ShortBreak, LongBreak }

public sealed class Pomodoro
{
    public PomodoroPhase Phase { get; private set; } = PomodoroPhase.Focus;
    public bool IsRunning { get; private set; }
    public int CompletedFocusSessions { get; private set; }
    private DateTimeOffset _end;
    private TimeSpan _remaining = TimeSpan.FromMinutes(25);

    public TimeSpan Duration => Phase switch
    {
        PomodoroPhase.Focus => TimeSpan.FromMinutes(25),
        PomodoroPhase.ShortBreak => TimeSpan.FromMinutes(5),
        _ => TimeSpan.FromMinutes(15)
    };

    public TimeSpan Remaining(DateTimeOffset now) =>
        IsRunning ? (_end > now ? _end - now : TimeSpan.Zero) : _remaining;

    public void Start(DateTimeOffset now)
    {
        if (IsRunning) return;
        _end = now + _remaining;
        IsRunning = true;
    }

    public void Pause(DateTimeOffset now)
    {
        if (!IsRunning) return;
        _remaining = Remaining(now);
        IsRunning = false;
    }

    public void Reset()
    {
        IsRunning = false;
        _remaining = Duration;
    }

    public bool Tick(DateTimeOffset now)
    {
        if (!IsRunning || now < _end) return false;
        IsRunning = false;
        if (Phase == PomodoroPhase.Focus)
        {
            CompletedFocusSessions++;
            Phase = CompletedFocusSessions % 4 == 0 ? PomodoroPhase.LongBreak : PomodoroPhase.ShortBreak;
        }
        else Phase = PomodoroPhase.Focus;
        _remaining = Duration;
        return true;
    }
}
