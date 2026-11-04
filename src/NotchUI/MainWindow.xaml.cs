using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Controls.Primitives;
using Microsoft.UI.Xaml.Media;
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
        var color = BackgroundPicker.Color;
        PreviewPill.Background = new SolidColorBrush(color) { Opacity = settings.Opacity };
        PreviewPill.Width = settings.Width;
        PreviewPill.Height = settings.Height;
        PreviewPill.CornerRadius = new CornerRadius(settings.CornerRadius);
        static double Linear(byte c) { var v = c / 255d; return v <= 0.04045 ? v / 12.92 : Math.Pow((v + 0.055) / 1.055, 2.4); }
        var luminance = 0.2126 * Linear(color.R) + 0.7152 * Linear(color.G) + 0.0722 * Linear(color.B);
        PreviewText.Foreground = new SolidColorBrush(luminance >= 0.179 ? Color.FromArgb(255, 0, 0, 0) : Color.FromArgb(255, 255, 255, 255));
        SettingsError.IsOpen = !string.IsNullOrWhiteSpace(_viewModel.Error);
        SettingsError.Message = _viewModel.Error ?? "";
        _loading = false;
    }
    private void OnNavigationChanged(NavigationView sender, NavigationViewSelectionChangedEventArgs args)
    {
        if (AppearancePage is null || args.SelectedItem is not NavigationViewItem item) return;
        var page = item.Tag as string;
        AppearancePage.Visibility = page == "appearance" ? Visibility.Visible : Visibility.Collapsed;
        WidgetsPage.Visibility = page == "widgets" ? Visibility.Visible : Visibility.Collapsed;
        AboutPage.Visibility = page == "about" ? Visibility.Visible : Visibility.Collapsed;
        PageTitle.Text = page switch { "widgets" => "Notch widgets", "about" => "About NotchUI", _ => "Appearance & hardware bounds" };
        PageDescription.Text = page switch { "widgets" => "Choose what appears in your notch.", "about" => "Your desktop, at a glance.", _ => "Personalize your notch. Changes apply immediately." };
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
