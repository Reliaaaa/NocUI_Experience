using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using NotchWindows.Core.Models;
using NotchWindows.Core.Abstractions;

namespace NotchWindows.Core.ViewModels;

/// <summary>F-020 quick toggle, F-021 cuaca, F-022 progress hari.</summary>
public sealed partial class DashboardViewModel : ObservableObject
{
    private readonly INetworkService _networkService;
    private readonly IWeatherService _weatherService;

    public DashboardViewModel(INetworkService networkService, IWeatherService weatherService)
    {
        _networkService = networkService;
        _weatherService = weatherService;
    }

    public ObservableCollection<ToggleState> Toggles { get; } = new();

    [ObservableProperty]
    private WeatherSnapshot? weather;

    /// <summary>F-022 — persentase hari yang sudah lewat (00:00 lokal s/d sekarang).</summary>
    public double DayProgressPercent
    {
        get
        {
            var now = DateTime.Now;
            var startOfDay = now.Date;
            return Math.Clamp((now - startOfDay).TotalMinutes / (24 * 60) * 100.0, 0, 100);
        }
    }

    public async Task InitializeAsync()
    {
        var wifi = await _networkService.GetWiFiStateAsync();
        var bluetooth = await _networkService.GetBluetoothStateAsync();
        Toggles.Clear();
        Toggles.Add(wifi);
        Toggles.Add(bluetooth);
        Toggles.Add(new ToggleState { Id = nameof(QuickToggleId.DarkMode), Label = "Dark Mode", IsOn = true });
        Toggles.Add(new ToggleState { Id = nameof(QuickToggleId.MuteMic), Label = "Mute Mic", IsOn = false });
        Toggles.Add(new ToggleState { Id = nameof(QuickToggleId.LockPc), Label = "Lock", IsOn = false, IsAvailable = true });

        // Do not request weather until the user can enable it and choose a location.
        Weather = null;
    }

    [RelayCommand]
    private async Task ToggleWiFiAsync()
    {
        var state = Toggles.FirstOrDefault(t => t.Id == nameof(QuickToggleId.WiFi));
        if (state is null) return;
        await _networkService.SetWiFiEnabledAsync(!state.IsOn);
        await InitializeAsync();
    }

    [RelayCommand]
    private async Task ToggleBluetoothAsync()
    {
        var state = Toggles.FirstOrDefault(t => t.Id == nameof(QuickToggleId.Bluetooth));
        if (state is null) return;
        await _networkService.SetBluetoothEnabledAsync(!state.IsOn);
        await InitializeAsync();
    }
}
