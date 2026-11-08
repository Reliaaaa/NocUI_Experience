namespace NotchWindows.Core.Models;

/// <summary>State toggle cepat dashboard (F-020): Wi-Fi, Bluetooth, Dark Mode, Mute Mic, Lock PC.</summary>
public sealed record QuickToggleState
{
    public bool WifiEnabled { get; init; }
    public bool BluetoothEnabled { get; init; }
    public bool DarkModeEnabled { get; init; }
    public bool MicMuted { get; init; }
}
