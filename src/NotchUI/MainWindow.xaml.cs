using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Controls.Primitives;
using Microsoft.UI.Xaml.Media;
using NotchUI.Services;
using NotchUI.Models;
using NotchUI.ViewModels;
using Windows.UI;

namespace NotchUI;

public sealed partial class MainWindow : Window
{
    private SettingsViewModel? _viewModel;
    private bool _loading;
    private readonly Action _showNotch;
    public MainWindow(NotchCoordinator coordinator, Action showNotch)
    {
        _showNotch = showNotch;
        InitializeComponent();
        SystemBackdrop = new MicaBackdrop();
        AppWindow.Resize(new Windows.Graphics.SizeInt32(1100, 760));
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
        RadiusSlider.Maximum = Math.Min(NotchSettings.MaximumRadius, Math.Min(settings.Width, settings.Height) / 2);
        RadiusSlider.Value = settings.CornerRadius;
        OpacitySlider.Value = settings.Opacity * 100;
        WidthLabel.Text = $"Notch width · {settings.Width:0} DIP";
        HeightLabel.Text = $"Resting height · {settings.Height:0} DIP";
        RadiusLabel.Text = $"Corner radius · {settings.CornerRadius:0} DIP";
        OpacityLabel.Text = $"Background opacity · {settings.Opacity:P0}";
        ClockToggle.IsOn = settings.ClockEnabled;
        BatteryToggle.IsOn = settings.BatteryEnabled;
        MediaToggle.IsOn = settings.MediaEnabled;
        HoverToggle.IsOn = settings.OpenOnHover;
        DurationSlider.Value = settings.AnimationDurationMs;
        DurationLabel.Text = $"Duration · {settings.AnimationDurationMs:0} ms";
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
    private void OnRestoreDefaults(object sender, RoutedEventArgs args) => _viewModel?.Update(_ => new NotchSettings());
    private void OnOpenNotch(object sender, RoutedEventArgs args) => _showNotch();
    private void OnNavigationChanged(NavigationView sender, NavigationViewSelectionChangedEventArgs args)
    {
        if (AppearancePage is null || args.SelectedItem is not NavigationViewItem item) return;
        var page = item.Tag as string;
        AppearancePage.Visibility = page == "appearance" ? Visibility.Visible : Visibility.Collapsed;
        WidgetsPage.Visibility = page == "widgets" ? Visibility.Visible : Visibility.Collapsed;
        AboutPage.Visibility = page == "about" ? Visibility.Visible : Visibility.Collapsed;
        BehaviorPage.Visibility = page == "behavior" ? Visibility.Visible : Visibility.Collapsed;
        AnimationsPage.Visibility = page == "animations" ? Visibility.Visible : Visibility.Collapsed;
        PageTitle.Text = page switch { "widgets" => "Widgets", "behavior" => "Gestures & behavior", "animations" => "Animations", "about" => "About", _ => "Appearance" };
        PageDescription.Text = page switch { "widgets" => "Choose what appears in your notch.", "behavior" => "Choose how the notch opens and closes.", "animations" => "Adjust motion for a comfortable experience.", "about" => "Information about NocUI Experience.", _ => "Make the notch feel at home on your desktop." };
    }
    private void OnHoverChanged(object sender, RoutedEventArgs args)
    {
        if (!_loading && _viewModel is not null) _viewModel.Update(s => s with { OpenOnHover = HoverToggle.IsOn });
    }
    private void OnDurationChanged(object sender, RangeBaseValueChangedEventArgs args)
    {
        if (!_loading && _viewModel is not null) _viewModel.Update(s => s with { AnimationDurationMs = args.NewValue });
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
