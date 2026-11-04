using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Media.Animation;
using NotchUI.Interop;
using NotchUI.Models;
using NotchUI.Services;
using Windows.UI;

namespace NotchUI;

public sealed partial class OverlayWindow : Window
{
    private const double ExpandedHeight = 170;
    private readonly NotchCoordinator _coordinator;
    private readonly OverlayWindowHost _host;
    private readonly Microsoft.UI.Dispatching.DispatcherQueueTimer _geometryTimer;
    private Storyboard? _transition;
    private bool _changingState;
    public OverlayWindow(NotchCoordinator coordinator)
    {
        InitializeComponent();
        _coordinator = coordinator;
        _host = new OverlayWindowHost(this);
        _host.SystemStateChanged += OnSystemStateChanged;
        _coordinator.Changed += OnCoordinatorChanged;
        _geometryTimer = DispatcherQueue.CreateTimer();
        _geometryTimer.Interval = TimeSpan.FromMilliseconds(16);
        _geometryTimer.Tick += OnGeometryTick;
        Closed += OnClosed;
        UpdateVisuals();
    }

    public void ApplyGeometry() => _host.SetGeometry(
        _transition is not null && Pill.ActualWidth > 0 ? Pill.ActualWidth : Pill.Width,
        _transition is not null && Pill.ActualHeight > 0 ? Pill.ActualHeight : Pill.Height,
        _coordinator.Settings.CornerRadius);
    private void OnCoordinatorChanged(object? sender, EventArgs args) => UpdateVisuals();
    private void UpdateVisuals()
    {
        var settings = _coordinator.Settings;
        var color = settings.BackgroundColor;
        Pill.Background = new SolidColorBrush(Color.FromArgb(255, Convert.ToByte(color.Substring(1, 2), 16),
            Convert.ToByte(color.Substring(3, 2), 16), Convert.ToByte(color.Substring(5, 2), 16))) { Opacity = settings.Opacity };
        var red = Convert.ToByte(color.Substring(1, 2), 16);
        var green = Convert.ToByte(color.Substring(3, 2), 16);
        var blue = Convert.ToByte(color.Substring(5, 2), 16);
        static double Linear(byte value)
        {
            var channel = value / 255d;
            return channel <= 0.04045 ? channel / 12.92 : Math.Pow((channel + 0.055) / 1.055, 2.4);
        }
        var luminance = 0.2126 * Linear(red) + 0.7152 * Linear(green) + 0.0722 * Linear(blue);
        var foreground = new SolidColorBrush(luminance >= 0.179
            ? Color.FromArgb(255, 0, 0, 0) : Color.FromArgb(255, 255, 255, 255));
        SummaryText.Foreground = foreground;
        ClockText.Foreground = foreground;
        CompactBatteryText.Foreground = foreground;
        DateText.Foreground = foreground;
        BatteryText.Foreground = foreground;
        MediaText.Foreground = foreground;
        Pill.CornerRadius = new CornerRadius(settings.CornerRadius);
        SummaryText.Text = settings.MediaEnabled && _coordinator.Media.Availability == MediaAvailability.Active
            ? _coordinator.Media.Title : "NotchUI";
        ClockText.Text = settings.ClockEnabled ? _coordinator.Clock.TimeText : "";
        ToolTipService.SetToolTip(ClockText, settings.ClockEnabled ? _coordinator.Clock.DateText : null);
        DateText.Visibility = settings.ClockEnabled ? Visibility.Visible : Visibility.Collapsed;
        DateText.Text = _coordinator.Clock.DateText;
        BatteryText.Visibility = settings.BatteryEnabled ? Visibility.Visible : Visibility.Collapsed;
        CompactBatteryText.Text = settings.BatteryEnabled && _coordinator.Battery.Availability == BatteryAvailability.Available
            ? $"{_coordinator.Battery.Percentage}%{(_coordinator.Battery.IsCharging ? " ⚡" : "")}" : "";
        BatteryText.Text = _coordinator.Battery.Availability switch
        {
            BatteryAvailability.Available => $"Battery: {_coordinator.Battery.Percentage}%{(_coordinator.Battery.IsCharging ? " · Charging" : "")}",
            BatteryAvailability.Unavailable => "No battery detected",
            _ => "Battery status unavailable"
        };
        MediaText.Visibility = settings.MediaEnabled ? Visibility.Visible : Visibility.Collapsed;
        MediaControls.Visibility = settings.MediaEnabled ? Visibility.Visible : Visibility.Collapsed;
        MediaText.Text = _coordinator.Media.Error ?? (_coordinator.Media.Availability switch
        {
            MediaAvailability.Active => $"{_coordinator.Media.Title} — {_coordinator.Media.Artist}",
            MediaAvailability.Loading => "Loading media…",
            MediaAvailability.Error => "Media unavailable. Disable and re-enable the module to retry.",
            _ => "No active media session"
        });
        PreviousButton.IsEnabled = _coordinator.Media.CanPrevious && !_coordinator.Media.IsBusy;
        PlayPauseIcon.Glyph = _coordinator.Media.IsPlaying ? "\uE769" : "\uE768";
        Microsoft.UI.Xaml.Automation.AutomationProperties.SetName(PlayPauseButton, _coordinator.Media.IsPlaying ? "Pause" : "Play");
        PlayPauseButton.IsEnabled = _coordinator.Media.CanTogglePlayPause && !_coordinator.Media.IsBusy;
        NextButton.IsEnabled = _coordinator.Media.CanNext && !_coordinator.Media.IsBusy;
        if (_transition is null && !_changingState)
        {
            Pill.Width = Math.Min(_coordinator.IsExpanded ? Math.Max(settings.Width, 430) : settings.Width, _host.PrimaryWidthDip);
            Pill.Height = _coordinator.IsExpanded ? ExpandedHeight : settings.Height;
        }
        ApplyGeometry();
    }
    private void OnPointerEntered(object sender, PointerRoutedEventArgs args) { if (_coordinator.Settings.OpenOnHover) SetExpanded(true); }
    private void OnPointerExited(object sender, PointerRoutedEventArgs args) { if (_coordinator.Settings.OpenOnHover) SetExpanded(false); }
    private void OnHeaderTapped(object sender, TappedRoutedEventArgs args)
    {
        SetExpanded(!_coordinator.IsExpanded);
        args.Handled = true;
    }
    private void SetExpanded(bool expanded)
    {
        if (_coordinator.IsExpanded == expanded) return;
        // Actual size reflects the current animated layout; Width/Height may still hold base values.
        var startWidth = Pill.ActualWidth > 0 ? Pill.ActualWidth : Pill.Width;
        var startHeight = Pill.ActualHeight > 0 ? Pill.ActualHeight : Pill.Height;
        Pill.Width = startWidth;
        Pill.Height = startHeight;
        _transition?.Stop();
        _transition = null;
        _changingState = true;
        _coordinator.SetExpanded(expanded);
        _changingState = false;
        ExpandedContent.Visibility = expanded ? Visibility.Visible : Visibility.Collapsed;
        if (_coordinator.Settings.AnimationDurationMs == 0)
        {
            Pill.Width = Math.Min(expanded ? Math.Max(_coordinator.Settings.Width, 430) : _coordinator.Settings.Width, _host.PrimaryWidthDip);
            Pill.Height = expanded ? ExpandedHeight : _coordinator.Settings.Height;
            _geometryTimer.Stop();
            ApplyGeometry();
            return;
        }
        var animation = new DoubleAnimation
        {
            From = startHeight, To = expanded ? ExpandedHeight : _coordinator.Settings.Height,
            Duration = new Duration(TimeSpan.FromMilliseconds(_coordinator.Settings.AnimationDurationMs)),
            EnableDependentAnimation = true,
            EasingFunction = new QuadraticEase { EasingMode = EasingMode.EaseOut }
        };
        var widthAnimation = new DoubleAnimation
        {
            From = startWidth,
            To = Math.Min(expanded ? Math.Max(_coordinator.Settings.Width, 430) : _coordinator.Settings.Width, _host.PrimaryWidthDip),
            Duration = new Duration(TimeSpan.FromMilliseconds(_coordinator.Settings.AnimationDurationMs)),
            EnableDependentAnimation = true,
            EasingFunction = new QuadraticEase { EasingMode = EasingMode.EaseOut }
        };
        Storyboard.SetTarget(animation, Pill);
        Storyboard.SetTargetProperty(animation, "Height");
        Storyboard.SetTarget(widthAnimation, Pill);
        Storyboard.SetTargetProperty(widthAnimation, "Width");
        var storyboard = new Storyboard();
        _transition = storyboard;
        storyboard.Children.Add(animation);
        storyboard.Children.Add(widthAnimation);
        storyboard.Completed += (_, _) =>
        {
            if (!ReferenceEquals(_transition, storyboard)) return;
            Pill.Width = widthAnimation.To!.Value;
            Pill.Height = animation.To!.Value;
            storyboard.Stop();
            _transition = null;
            _geometryTimer.Stop();
            ApplyGeometry();
        };
        _geometryTimer.Start();
        storyboard.Begin();
    }
    private void OnGeometryTick(Microsoft.UI.Dispatching.DispatcherQueueTimer sender, object args) => ApplyGeometry();
    private void OnSystemStateChanged(object? sender, EventArgs args) => _coordinator.RefreshSystemState();
    private async void OnPreviousClicked(object sender, RoutedEventArgs args) => await _coordinator.PreviousAsync();
    private async void OnPlayPauseClicked(object sender, RoutedEventArgs args) => await _coordinator.TogglePlayPauseAsync();
    private async void OnNextClicked(object sender, RoutedEventArgs args) => await _coordinator.NextAsync();
    private void OnClosed(object sender, WindowEventArgs args)
    {
        var transition = _transition;
        _transition = null;
        transition?.Stop();
        _coordinator.Changed -= OnCoordinatorChanged;
        _host.SystemStateChanged -= OnSystemStateChanged;
        _geometryTimer.Stop();
        _geometryTimer.Tick -= OnGeometryTick;
        _host.Dispose();
    }
}
