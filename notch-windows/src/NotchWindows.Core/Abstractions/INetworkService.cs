using NotchWindows.Core.Models;

namespace NotchWindows.Core.Abstractions;

/// <summary>
/// Abstraksi toggle Wi-Fi/Bluetooth (F-020), lewat Windows.Devices.Radios. Implementasi:
/// Services/Network/NetworkToggleService. Mute-mic dan Lock PC BUKAN bagian kontrak ini — keduanya
/// ditangani langsung oleh QuickToggleService (Core Audio COM interop / LockWorkStation), yang
/// hanya mendelegasikan Wi-Fi/Bluetooth ke sini. Lihat docs/04-services-api.md §"Dashboard Quick Toggle".
/// QA fix (bug QA-021, P0): signature sebelumnya (IsWifiEnabledAsync/IsBluetoothEnabledAsync bool,
/// plus IsMicMutedAsync/SetMicMutedAsync/LockWorkstation) tidak cocok dengan satu-satunya implementasi
/// nyata (NetworkToggleService, GetWiFiStateAsync/GetBluetoothStateAsync -> ToggleState) maupun dengan
/// pemanggilnya (QuickToggleService) -> CS0535, tidak akan kompilasi. Disamakan ke kontrak yang sungguh
/// dipakai di kedua sisi.
/// </summary>
public interface INetworkService
{
    Task<ToggleState> GetWiFiStateAsync();
    Task SetWiFiEnabledAsync(bool enabled);

    Task<ToggleState> GetBluetoothStateAsync();
    Task SetBluetoothEnabledAsync(bool enabled);
}
