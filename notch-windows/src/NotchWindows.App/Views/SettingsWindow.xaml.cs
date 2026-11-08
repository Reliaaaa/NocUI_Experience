using Microsoft.UI.Xaml;
using NotchWindows.Core.Models;
using NotchWindows.Core.ViewModels;

namespace NotchWindows.App.Views;

/// <summary>F-050 — window pengaturan terpisah, dibuka dari tray icon / dock (bukan singleton di DI, dibuat on-demand).</summary>
public sealed partial class SettingsWindow : Window
{
    public SettingsViewModel ViewModel { get; }

    public IReadOnlyList<NotchPosition> PositionOptions { get; } = Enum.GetValues<NotchPosition>();
    public IReadOnlyList<ClosedNotchMetric> MetricOptions { get; } = Enum.GetValues<ClosedNotchMetric>();
    public IReadOnlyList<AppTheme> ThemeOptions { get; } = Enum.GetValues<AppTheme>();

    public SettingsWindow(SettingsViewModel viewModel)
    {
        InitializeComponent();
        ViewModel = viewModel;
    }
}
