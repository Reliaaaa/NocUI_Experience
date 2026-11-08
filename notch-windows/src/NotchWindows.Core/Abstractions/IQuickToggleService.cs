using NotchWindows.Core.Models;

namespace NotchWindows.Core.Abstractions;

/// <summary>
/// F-020 — orkestrator 5 quick toggle dashboard (Wi-Fi, Bluetooth, Dark Mode, Mute Mic, Lock PC).
/// Mengomposisi INetworkService (Wi-Fi/Bluetooth) + menambah Dark Mode/Mic/Lock yang tidak
/// dicakup INetworkService. Implementasi: QuickToggleService (NotchWindows.Services/System).
/// </summary>
public interface IQuickToggleService
{
    Task<QuickToggleState> GetCurrentAsync();
    event EventHandler<QuickToggleState>? StateChanged;

    Task SetWifiEnabledAsync(bool enabled);
    Task SetBluetoothEnabledAsync(bool enabled);
    Task SetDarkModeAsync(bool enabled);
    Task SetMicMutedAsync(bool muted);
    Task LockPcAsync();
}
