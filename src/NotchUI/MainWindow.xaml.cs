using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Controls.Primitives;
using NotchUI.Services;
using NotchUI.ViewModels;
using Windows.UI;

namespace NotchUI;

public sealed partial class MainWindow : Window
{
    private SettingsViewModel? _viewModel;
    private bool _loading;
    public MainWindow(NotchCoordinator coordinator)
    {
        InitializeComponent();
        _viewModel = new SettingsViewModel(coordinator);
        coordinator.Changed += OnCoordinatorChanged;
        Closed += (_, _) => coordinator.Changed -= OnCoordinatorChanged;
        LoadSettings();
    }

    private void OnCoordinatorChanged(object? sender, EventArgs args) => LoadSettings();
    private void LoadSettings()
    {
        if (_viewModel is null) return;
        _loading = true;
        var settings = _viewModel.Settings;
        WidthSlider.Value = settings.Width;
        HeightSlider.Value = settings.Height;
        RadiusSlider.Value = settings.CornerRadius;
        OpacitySlider.Value = settings.Opacity * 100;
        ClockToggle.IsOn = settings.ClockEnabled;
        BatteryToggle.IsOn = settings.BatteryEnabled;
        MediaToggle.IsOn = settings.MediaEnabled;
        var hex = settings.BackgroundColor;
        BackgroundPicker.Color = Color.FromArgb(255, Convert.ToByte(hex.Substring(1, 2), 16),
            Convert.ToByte(hex.Substring(3, 2), 16), Convert.ToByte(hex.Substring(5, 2), 16));
        SettingsError.IsOpen = !string.IsNullOrWhiteSpace(_viewModel.Error);
        SettingsError.Message = _viewModel.Error ?? "";
        _loading = false;
    }
    private void OnSliderChanged(object sender, RangeBaseValueChangedEventArgs args)
    {
        if (_loading || _viewModel is null) return;
        var width = WidthSlider.Value;
        var height = HeightSlider.Value;
        var radius = RadiusSlider.Value;
        var opacity = OpacitySlider.Value / 100;
        _viewModel.Update(s => s with { Width = width, Height = height, CornerRadius = radius, Opacity = opacity });
    }
    private void OnColorChanged(ColorPicker sender, ColorChangedEventArgs args)
    {
        if (_loading || _viewModel is null) return;
        var color = args.NewColor;
        _viewModel.Update(s => s with { BackgroundColor = $"#{color.R:X2}{color.G:X2}{color.B:X2}" });
    }
    private void OnModulesChanged(object sender, RoutedEventArgs args)
    {
        if (_loading || _viewModel is null) return;
        _viewModel.Update(s => s with
        {
            ClockEnabled = ClockToggle.IsOn, BatteryEnabled = BatteryToggle.IsOn, MediaEnabled = MediaToggle.IsOn
        });
    }
}
