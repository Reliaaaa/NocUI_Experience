namespace NotchWindows.Core.Models;

/// <summary>State satu quick-toggle di dashboard (F-020): Wi-Fi, Bluetooth, Dark Mode, Mute Mic, Lock.</summary>
public sealed class ToggleState
{
    public required string Id { get; init; }
    public required string Label { get; init; }
    public bool IsOn { get; init; }
    public bool IsAvailable { get; init; } = true;
}

public enum QuickToggleId
{
    WiFi,
    Bluetooth,
    DarkMode,
    MuteMic,
    LockPc,
}
