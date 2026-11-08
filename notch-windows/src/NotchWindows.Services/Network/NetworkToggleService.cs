using Windows.Devices.Radios;
using NotchWindows.Core.Models;
using NotchWindows.Core.Abstractions;

namespace NotchWindows.Services.Network;

/// <summary>F-020 — toggle Wi-Fi/Bluetooth nyata via Windows.Devices.Radios (butuh izin radio capability).</summary>
public sealed class NetworkToggleService : INetworkService
{
    public async Task<ToggleState> GetWiFiStateAsync() => await BuildStateAsync(RadioKind.WiFi, "Wi-Fi");

    public async Task<ToggleState> GetBluetoothStateAsync() => await BuildStateAsync(RadioKind.Bluetooth, "Bluetooth");

    public Task SetWiFiEnabledAsync(bool enabled) => SetRadioAsync(RadioKind.WiFi, enabled);

    public Task SetBluetoothEnabledAsync(bool enabled) => SetRadioAsync(RadioKind.Bluetooth, enabled);

    private static async Task<ToggleState> BuildStateAsync(RadioKind kind, string label)
    {
        var access = await Radio.RequestAccessAsync();
        if (access != RadioAccessStatus.Allowed)
            return new ToggleState { Id = kind.ToString(), Label = label, IsOn = false, IsAvailable = false };

        var radios = await Radio.GetRadiosAsync();
        var radio = radios.FirstOrDefault(r => r.Kind == kind);
        return new ToggleState
        {
            Id = kind.ToString(),
            Label = label,
            IsOn = radio?.State == RadioState.On,
            IsAvailable = radio is not null,
        };
    }

    private static async Task SetRadioAsync(RadioKind kind, bool enabled)
    {
        // QA fix (bug QA-004, P2): sebelumnya tidak memanggil RequestAccessAsync di sini. Bila toggle
        // dipanggil sebelum state pernah di-query, GetRadiosAsync() diam-diam mengembalikan daftar
        // kosong (izin radio belum diberikan) -> toggle user tidak berefek tanpa pesan error apa pun.
        var access = await Radio.RequestAccessAsync();
        if (access != RadioAccessStatus.Allowed) return;

        var radios = await Radio.GetRadiosAsync();
        var radio = radios.FirstOrDefault(r => r.Kind == kind);
        if (radio is null) return;
        await radio.SetStateAsync(enabled ? RadioState.On : RadioState.Off);
    }
}
