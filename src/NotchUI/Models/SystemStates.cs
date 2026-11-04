namespace NotchUI.Models;

public sealed record ClockState(DateTimeOffset LocalTime)
{
    public string TimeText => LocalTime.ToString("t");
    public string DateText => LocalTime.ToString("D");
}

public enum BatteryAvailability { Available, Unavailable, Unknown }
public sealed record BatteryState(BatteryAvailability Availability, int? Percentage, bool IsCharging)
{
    public static BatteryState Unknown { get; } = new(BatteryAvailability.Unknown, null, false);
}

public enum MediaAvailability { Loading, Active, NoSession, Error, Disabled }
public sealed record MediaState(MediaAvailability Availability, string Title = "", string Artist = "",
    bool IsPlaying = false, bool CanTogglePlayPause = false, bool CanPrevious = false,
    bool CanNext = false, bool IsBusy = false, string? Error = null);
