using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using NotchWindows.Core.Models;
using NotchWindows.Core.Abstractions;

namespace NotchWindows.Core.ViewModels;

/// <summary>F-050 — posisi notch, info kiri/kanan, shortcut, tema dasar. Persist lewat ISettingsStore.</summary>
public sealed partial class SettingsViewModel : ObservableObject
{
    private readonly ISettingsStore _settingsStore;

    public SettingsViewModel(ISettingsStore settingsStore)
    {
        _settingsStore = settingsStore;
        var current = settingsStore.Current;
        position = current.Position;
        leftMetric = current.LeftMetric;
        rightMetric = current.RightMetric;
        shortcut = current.GlobalToggleShortcut;
        theme = current.Theme;
        use24HourClock = current.Use24HourClock;
    }

    [ObservableProperty] private NotchPosition position;
    [ObservableProperty] private ClosedNotchMetric leftMetric;
    [ObservableProperty] private ClosedNotchMetric rightMetric;
    [ObservableProperty] private string shortcut;
    [ObservableProperty] private AppTheme theme;
    [ObservableProperty] private bool use24HourClock;

    [RelayCommand]
    private Task SaveAsync()
    {
        var settings = _settingsStore.Current;
        settings.Position = Position;
        settings.LeftMetric = LeftMetric;
        settings.RightMetric = RightMetric;
        settings.GlobalToggleShortcut = Shortcut;
        settings.Theme = Theme;
        settings.Use24HourClock = Use24HourClock;
        return _settingsStore.SaveAsync(settings);
    }
}
