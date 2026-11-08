using System.Runtime.InteropServices;
using Microsoft.Win32;
using NotchWindows.Core.Abstractions;
using NotchWindows.Core.Models;

namespace NotchWindows.Services.System;

/// <summary>
/// F-020 — orkestrator Dashboard Quick Toggle (Wi-Fi, Bluetooth, Dark Mode, Mute Mic, Lock PC).
/// Wi-Fi/Bluetooth didelegasikan ke INetworkService (Windows.Devices.Radios, sudah real — lihat
/// NetworkToggleService). Dark Mode lewat registry personalize key (tidak butuh admin). Mute Mic
/// lewat Core Audio COM interop (IMMDeviceEnumerator/IAudioEndpointVolume, tidak butuh admin).
/// Lock PC lewat LockWorkStation. Lihat docs/04-services-api.md untuk kontrak dan contoh pemakaian.
/// </summary>
public sealed class QuickToggleService : IQuickToggleService
{
    private readonly INetworkService _networkService;

    public event EventHandler<QuickToggleState>? StateChanged;

    public QuickToggleService(INetworkService networkService) => _networkService = networkService;

    public async Task<QuickToggleState> GetCurrentAsync()
    {
        var wifi = await _networkService.GetWiFiStateAsync();
        var bluetooth = await _networkService.GetBluetoothStateAsync();

        return new QuickToggleState
        {
            WifiEnabled = wifi.IsOn,
            BluetoothEnabled = bluetooth.IsOn,
            DarkModeEnabled = IsDarkModeEnabled(),
            MicMuted = TryGetDefaultMicMuted() ?? false,
        };
    }

    public async Task SetWifiEnabledAsync(bool enabled)
    {
        await _networkService.SetWiFiEnabledAsync(enabled);
        await RaiseChangedAsync();
    }

    public async Task SetBluetoothEnabledAsync(bool enabled)
    {
        await _networkService.SetBluetoothEnabledAsync(enabled);
        await RaiseChangedAsync();
    }

    public async Task SetDarkModeAsync(bool enabled)
    {
        // HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize
        // AppsUseLightTheme: 0 = dark, 1 = light. SystemUsesLightTheme kontrol shell/taskbar terpisah,
        // diset sama supaya tema app & shell konsisten (lihat 03-design.md token tema).
        using var key = Registry.CurrentUser.CreateSubKey(
            @"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", writable: true);
        key?.SetValue("AppsUseLightTheme", enabled ? 0 : 1, RegistryValueKind.DWord);
        key?.SetValue("SystemUsesLightTheme", enabled ? 0 : 1, RegistryValueKind.DWord);
        await RaiseChangedAsync();
    }

    public async Task SetMicMutedAsync(bool muted)
    {
        TrySetDefaultMicMuted(muted);
        await RaiseChangedAsync();
    }

    public Task LockPcAsync()
    {
        // user32!LockWorkStation langsung, tanpa shell-out ke rundll32 (lebih cepat, tidak buka proses baru).
        if (!LockWorkStation())
        {
            // Fallback jarang terjadi (mis. kebijakan grup) -> coba lewat shell command sebagai cadangan.
            global::System.Diagnostics.Process.Start(new global::System.Diagnostics.ProcessStartInfo(
                "rundll32.exe", "user32.dll,LockWorkStation") { UseShellExecute = true });
        }
        return Task.CompletedTask;
    }

    private async Task RaiseChangedAsync() => StateChanged?.Invoke(this, await GetCurrentAsync());

    private static bool IsDarkModeEnabled()
    {
        using var key = Registry.CurrentUser.OpenSubKey(
            @"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize");
        var value = key?.GetValue("AppsUseLightTheme");
        // Default Windows: key tidak ada -> anggap dark (AppsUseLightTheme 0) pada instal bersih Win11.
        return value is int lightTheme ? lightTheme == 0 : true;
    }

    // --- Core Audio COM interop: mute/unmute default microphone (capture) endpoint ---
    // Interface GUID dan layout berikut adalah definisi publik Windows Core Audio API
    // (mmdeviceapi.h / endpointvolume.h, didokumentasikan Microsoft), bukan kode dari aplikasi
    // pihak ketiga manapun — pola yang sama dipakai di banyak contoh resmi/komunitas .NET.

    private static bool? TryGetDefaultMicMuted()
    {
        try
        {
            var enumerator = (IMMDeviceEnumerator)new MMDeviceEnumerator();
            enumerator.GetDefaultAudioEndpoint(EDataFlow.eCapture, ERole.eCommunications, out var device);
            if (device is null) return null;

            var iid = typeof(IAudioEndpointVolume).GUID;
            device.Activate(ref iid, 0, IntPtr.Zero, out var volumeObj);
            var endpointVolume = (IAudioEndpointVolume)volumeObj;
            endpointVolume.GetMute(out var muted);
            return muted;
        }
        catch (COMException)
        {
            return null; // tidak ada mic default terpasang / driver tidak expose endpoint -> toggle disabled di UI
        }
    }

    private static void TrySetDefaultMicMuted(bool muted)
    {
        try
        {
            var enumerator = (IMMDeviceEnumerator)new MMDeviceEnumerator();
            enumerator.GetDefaultAudioEndpoint(EDataFlow.eCapture, ERole.eCommunications, out var device);
            if (device is null) return;

            var iid = typeof(IAudioEndpointVolume).GUID;
            device.Activate(ref iid, 0, IntPtr.Zero, out var volumeObj);
            var endpointVolume = (IAudioEndpointVolume)volumeObj;
            endpointVolume.SetMute(muted, Guid.Empty);
        }
        catch (COMException)
        {
            // lihat TryGetDefaultMicMuted: gagal diam-diam, UI menampilkan toggle sebagai IsAvailable=false
        }
    }

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool LockWorkStation();

    [ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
    private class MMDeviceEnumerator { }

    private enum EDataFlow { eRender, eCapture, eAll }
    private enum ERole { eConsole, eMultimedia, eCommunications }

    [ComImport, Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"),
     InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IMMDeviceEnumerator
    {
        void EnumAudioEndpoints(EDataFlow dataFlow, uint dwStateMask, out IntPtr devices);
        void GetDefaultAudioEndpoint(EDataFlow dataFlow, ERole role, out IMMDevice device);
    }

    [ComImport, Guid("D666063F-1587-4E43-81F1-B948E807363F"),
     InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IMMDevice
    {
        void Activate(ref Guid iid, uint clsCtx, IntPtr activationParams,
            [MarshalAs(UnmanagedType.IUnknown)] out object endpointVolume);
    }

    [ComImport, Guid("5CDF2C82-841E-4546-9722-0CF74078229A"),
     InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IAudioEndpointVolume
    {
        void NotImpl1();
        void NotImpl2();
        void GetChannelCount(out uint channelCount);
        void SetMasterVolumeLevel(float level, Guid eventContext);
        void SetMasterVolumeLevelScalar(float level, Guid eventContext);
        void GetMasterVolumeLevel(out float level);
        void GetMasterVolumeLevelScalar(out float level);
        void SetChannelVolumeLevel(uint channel, float level, Guid eventContext);
        void SetChannelVolumeLevelScalar(uint channel, float level, Guid eventContext);
        void GetChannelVolumeLevel(uint channel, out float level);
        void GetChannelVolumeLevelScalar(uint channel, out float level);
        void SetMute([MarshalAs(UnmanagedType.Bool)] bool mute, Guid eventContext);
        void GetMute([MarshalAs(UnmanagedType.Bool)] out bool mute);
    }
}
