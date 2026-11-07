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
    private const double ExpandedHeight = 218;
    private readonly NotchCoordinator _coordinator;
    private readonly OverlayWindowHost _host;
    private readonly Microsoft.UI.Dispatching.DispatcherQueueTimer _geometryTimer;
    private readonly Microsoft.UI.Dispatching.DispatcherQueueTimer _hoverTimer;
    private readonly Microsoft.UI.Dispatching.DispatcherQueueTimer _leaveTimer;
    private readonly Pomodoro _pomodoro = new();
    private readonly Microsoft.UI.Dispatching.DispatcherQueueTimer _pomodoroTimer;
    private bool _pointerInside;
    private bool _windowActive;
    private bool _closed;
    private Storyboard? _transition;
    private bool _changingState;
    public OverlayWindow(NotchCoordinator coordinator)
    {
        InitializeComponent();
        _coordinator = coordinator;
        _host = new OverlayWindowHost(this);
        _host.SystemStateChanged += OnSystemStateChanged;
        _host.DisplayChanged += OnDisplayChanged;
        _coordinator.Changed += OnCoordinatorChanged;
        _pomodoroTimer = DispatcherQueue.CreateTimer();
        _pomodoroTimer.Interval = TimeSpan.FromSeconds(1);
        _pomodoroTimer.Tick += OnPomodoroTick;
        _geometryTimer = DispatcherQueue.CreateTimer();
        _geometryTimer.Interval = TimeSpan.FromMilliseconds(16);
        _geometryTimer.Tick += OnGeometryTick;
        _hoverTimer = DispatcherQueue.CreateTimer();
        _hoverTimer.IsRepeating = false;
        _hoverTimer.Interval = TimeSpan.FromMilliseconds(350);
        _hoverTimer.Tick += OnHoverTimer;
        _leaveTimer = DispatcherQueue.CreateTimer();
        _leaveTimer.IsRepeating = false;
        _leaveTimer.Interval = TimeSpan.FromMilliseconds(320);
        _leaveTimer.Tick += OnLeaveTimer;
        Activated += OnWindowActivated;
        Closed += OnClosed;
        Pill.AddHandler(UIElement.KeyDownEvent, new KeyEventHandler(OnOverlayKeyDown), true);
        UpdateVisuals();
    }

    public void ApplyGeometry()
    {
        if (_closed) return;
        _host.SetGeometry(
        _transition is not null && Pill.ActualWidth > 0 ? Pill.ActualWidth : Pill.Width,
        _transition is not null && Pill.ActualHeight > 0 ? Pill.ActualHeight : Pill.Height,
        _coordinator.Settings.CornerRadius);
    }
    private void OnCoordinatorChanged(object? sender, EventArgs args) => UpdateVisuals();
    private void UpdateVisuals()
    {
        if (_closed) return;
        Microsoft.UI.Xaml.Automation.AutomationProperties.SetName(HeaderButton,
            _coordinator.IsExpanded ? "Close notch" : "Open notch");
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
        MediaArtistText.Foreground = foreground;
        PomodoroText.Foreground = foreground;
        UpdatePomodoro();
        Pill.CornerRadius = new CornerRadius(settings.CornerRadius);
        SummaryText.Text = settings.MediaEnabled && _coordinator.Media.Availability == MediaAvailability.Active
            ? _coordinator.Media.Title : "NocUI Experience";
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
            MediaAvailability.Active => string.IsNullOrWhiteSpace(_coordinator.Media.Title) ? "Unknown title" : _coordinator.Media.Title,
            MediaAvailability.Loading => "Loading media…",
            MediaAvailability.Error => "Media unavailable. Disable and re-enable the module to retry.",
            _ => "No active media session"
        });
        MediaArtistText.Text = _coordinator.Media.Artist;
        MediaArtistText.Visibility = settings.MediaEnabled && _coordinator.Media.Availability == MediaAvailability.Active
            && !string.IsNullOrWhiteSpace(_coordinator.Media.Artist) ? Visibility.Visible : Visibility.Collapsed;
        PreviousButton.IsEnabled = _coordinator.IsExpanded && _coordinator.Media.CanPrevious && !_coordinator.Media.IsBusy;
        PlayPauseIcon.Glyph = _coordinator.Media.IsPlaying ? "\uE769" : "\uE768";
        Microsoft.UI.Xaml.Automation.AutomationProperties.SetName(PlayPauseButton, _coordinator.Media.IsPlaying ? "Pause" : "Play");
        PlayPauseButton.IsEnabled = _coordinator.IsExpanded && _coordinator.Media.CanTogglePlayPause && !_coordinator.Media.IsBusy;
        NextButton.IsEnabled = _coordinator.IsExpanded && _coordinator.Media.CanNext && !_coordinator.Media.IsBusy;
        if (_transition is null && !_changingState)
        {
            Pill.Width = Math.Min(_coordinator.IsExpanded ? Math.Max(settings.Width, 430) : settings.Width, _host.PrimaryWidthDip);
            Pill.Height = _coordinator.IsExpanded ? ExpandedHeight : settings.Height;
        }
        ApplyGeometry();
    }
    private void UpdatePomodoro()
    {
        var remaining = _pomodoro.Remaining(DateTimeOffset.UtcNow);
        var seconds = (int)Math.Ceiling(remaining.TotalSeconds);
        var phase = _pomodoro.Phase switch
        {
            PomodoroPhase.Focus => "Focus",
            PomodoroPhase.ShortBreak => "Break",
            _ => "Long break"
        };
        PomodoroText.Text = $"{phase}  {seconds / 60:00}:{seconds % 60:00}";
        PomodoroToggle.Content = _pomodoro.IsRunning ? "Pause" : "Start";
        PomodoroToggle.IsEnabled = _coordinator.IsExpanded;
        PomodoroReset.IsEnabled = _coordinator.IsExpanded;
    }

    private void OnPomodoroToggle(object sender, RoutedEventArgs args)
    {
        if (_pomodoro.IsRunning) { _pomodoro.Pause(DateTimeOffset.UtcNow); _pomodoroTimer.Stop(); }
        else { _pomodoro.Start(DateTimeOffset.UtcNow); _pomodoroTimer.Start(); }
        UpdatePomodoro();
    }

    private void OnPomodoroReset(object sender, RoutedEventArgs args)
    {
        _pomodoro.Reset();
        _pomodoroTimer.Stop();
        UpdatePomodoro();
    }

    private void OnPomodoroTick(Microsoft.UI.Dispatching.DispatcherQueueTimer sender, object args)
    {
        if (_pomodoro.Tick(DateTimeOffset.UtcNow)) _pomodoroTimer.Stop();
        UpdatePomodoro();
    }

    private void OnPointerEntered(object sender, PointerRoutedEventArgs args)
    {
        if (_closed) return;
        _pointerInside = true;
        _leaveTimer.Stop();
        if (_coordinator.Settings.OpenOnHover && !_coordinator.IsExpanded) _hoverTimer.Start();
    }
    private void OnPointerExited(object sender, PointerRoutedEventArgs args)
    {
        if (_closed) return;
        _pointerInside = false;
        _hoverTimer.Stop();
        if (_coordinator.Settings.OpenOnHover && _coordinator.IsExpanded) _leaveTimer.Start();
    }
    private void OnHoverTimer(Microsoft.UI.Dispatching.DispatcherQueueTimer sender, object args)
    {
        if (!_closed && _pointerInside && _coordinator.Settings.OpenOnHover) SetExpanded(true);
    }
    private void OnLeaveTimer(Microsoft.UI.Dispatching.DispatcherQueueTimer sender, object args)
    {
        if (!_closed && !_pointerInside && _coordinator.Settings.OpenOnHover && !HasKeyboardFocus()) SetExpanded(false);
    }
    private bool HasKeyboardFocus()
    {
        if (!_windowActive || Pill.XamlRoot is null) return false;
        var focused = FocusManager.GetFocusedElement(Pill.XamlRoot) as DependencyObject;
        while (focused is not null)
        {
            if (focused == Pill) return true;
            focused = VisualTreeHelper.GetParent(focused);
        }
        return false;
    }
    private void OnWindowActivated(object sender, WindowActivatedEventArgs args)
    {
        if (_closed) return;
        _windowActive = args.WindowActivationState != WindowActivationState.Deactivated;
        if (!_windowActive && !_pointerInside && _coordinator.Settings.OpenOnHover && _coordinator.IsExpanded)
            _leaveTimer.Start();
    }
    private void OnHeaderClicked(object sender, RoutedEventArgs args)
    {
        if (_closed) return;
        _hoverTimer.Stop();
        _leaveTimer.Stop();
        SetExpanded(!_coordinator.IsExpanded);
    }
    public void OpenForKeyboard()
    {
        if (_closed) return;
        _hoverTimer.Stop();
        _leaveTimer.Stop();
        SetExpanded(true);
        Activate();
        HeaderButton.Focus(FocusState.Keyboard);
    }
    private void SetExpanded(bool expanded)
    {
        if (_closed || _coordinator.IsExpanded == expanded) return;
        if (!expanded && Pill.XamlRoot is not null)
        {
            var focused = FocusManager.GetFocusedElement(Pill.XamlRoot) as DependencyObject;
            while (focused is not null)
            {
                if (focused == ExpandedContent)
                {
                    if (!HeaderButton.Focus(FocusState.Keyboard)) return;
                    break;
                }
                focused = VisualTreeHelper.GetParent(focused);
            }
        }
        // Actual size reflects the current animated layout; Width/Height may still hold base values.
        var startWidth = Pill.ActualWidth > 0 ? Pill.ActualWidth : Pill.Width;
        var startHeight = Pill.ActualHeight > 0 ? Pill.ActualHeight : Pill.Height;
        var startContentOpacity = ExpandedContent.Visibility == Visibility.Visible ? ExpandedContent.Opacity : 0;
        Pill.Width = startWidth;
        Pill.Height = startHeight;
        ExpandedContent.Opacity = startContentOpacity;
        _transition?.Stop();
        _transition = null;
        _changingState = true;
        _coordinator.SetExpanded(expanded);
        _changingState = false;
        // Keep the content visible while closing so it fades with the shrinking surface.
        // The media buttons are disabled by UpdateVisuals when collapsed; also
        // exclude the fading content from pointer interaction immediately.
        ExpandedContent.Visibility = Visibility.Visible;
        ExpandedContent.IsHitTestVisible = expanded;
        if (_coordinator.Settings.AnimationDurationMs == 0)
        {
            Pill.Width = Math.Min(expanded ? Math.Max(_coordinator.Settings.Width, 430) : _coordinator.Settings.Width, _host.PrimaryWidthDip);
            Pill.Height = expanded ? ExpandedHeight : _coordinator.Settings.Height;
            ExpandedContent.Opacity = expanded ? 1 : 0;
            ExpandedContent.Visibility = expanded ? Visibility.Visible : Visibility.Collapsed;
            _geometryTimer.Stop();
            ApplyGeometry();
            return;
        }
        var animation = new DoubleAnimation
        {
            From = startHeight, To = expanded ? ExpandedHeight : _coordinator.Settings.Height,
            Duration = new Duration(TimeSpan.FromMilliseconds(_coordinator.Settings.AnimationDurationMs)),
            EnableDependentAnimation = true,
            EasingFunction = new QuadraticEase { EasingMode = EasingMode.EaseInOut }
        };
        var widthAnimation = new DoubleAnimation
        {
            From = startWidth,
            To = Math.Min(expanded ? Math.Max(_coordinator.Settings.Width, 430) : _coordinator.Settings.Width, _host.PrimaryWidthDip),
            Duration = new Duration(TimeSpan.FromMilliseconds(_coordinator.Settings.AnimationDurationMs)),
            EnableDependentAnimation = true,
            EasingFunction = new QuadraticEase { EasingMode = EasingMode.EaseInOut }
        };
        var contentAnimation = new DoubleAnimation
        {
            From = startContentOpacity,
            To = expanded ? 1 : 0,
            // Let the surface lead the content on entry; clear the content
            // sooner on exit. Both phases stay within the configured duration.
            BeginTime = TimeSpan.FromMilliseconds(expanded ? _coordinator.Settings.AnimationDurationMs * 0.2 : 0),
            Duration = new Duration(TimeSpan.FromMilliseconds(_coordinator.Settings.AnimationDurationMs * (expanded ? 0.8 : 0.65))),
            EasingFunction = new QuadraticEase { EasingMode = EasingMode.EaseInOut }
        };
        Storyboard.SetTarget(animation, Pill);
        Storyboard.SetTargetProperty(animation, "Height");
        Storyboard.SetTarget(widthAnimation, Pill);
        Storyboard.SetTargetProperty(widthAnimation, "Width");
        Storyboard.SetTarget(contentAnimation, ExpandedContent);
        Storyboard.SetTargetProperty(contentAnimation, "Opacity");
        var storyboard = new Storyboard();
        _transition = storyboard;
        storyboard.Children.Add(animation);
        storyboard.Children.Add(widthAnimation);
        storyboard.Children.Add(contentAnimation);
        storyboard.Completed += (_, _) =>
        {
            if (_closed || !ReferenceEquals(_transition, storyboard)) return;
            Pill.Width = widthAnimation.To!.Value;
            Pill.Height = animation.To!.Value;
            ExpandedContent.Opacity = contentAnimation.To!.Value;
            storyboard.Stop();
            _transition = null;
            ExpandedContent.Visibility = expanded ? Visibility.Visible : Visibility.Collapsed;
            _geometryTimer.Stop();
            // Settings can change while the transition is running; apply the current
            // dimensions instead of leaving the snapshot taken when it started.
            UpdateVisuals();
        };
        _geometryTimer.Start();
        storyboard.Begin();
    }
    private void OnGeometryTick(Microsoft.UI.Dispatching.DispatcherQueueTimer sender, object args) => ApplyGeometry();
    private void OnOverlayKeyDown(object sender, KeyRoutedEventArgs args)
    {
        if (_closed || args.Key != Windows.System.VirtualKey.Escape || !_coordinator.IsExpanded) return;
        _hoverTimer.Stop();
        _leaveTimer.Stop();
        SetExpanded(false);
        args.Handled = true;
    }
    private void OnSystemStateChanged(object? sender, EventArgs args)
    {
        if (!_closed) _coordinator.RefreshSystemState();
    }
    private void OnDisplayChanged(object? sender, EventArgs args)
    {
        if (_closed) return;
        DispatcherQueue.TryEnqueue(() =>
        {
            if (_closed) return;
            var transition = _transition;
            _transition = null;
            transition?.Stop();
            _geometryTimer.Stop();
            ExpandedContent.Opacity = _coordinator.IsExpanded ? 1 : 0;
            ExpandedContent.Visibility = _coordinator.IsExpanded ? Visibility.Visible : Visibility.Collapsed;
            ExpandedContent.IsHitTestVisible = _coordinator.IsExpanded;
            UpdateVisuals();
        });
    }
    private async void OnPreviousClicked(object sender, RoutedEventArgs args)
    {
        if (!_closed) await _coordinator.PreviousAsync();
    }
    private async void OnPlayPauseClicked(object sender, RoutedEventArgs args)
    {
        if (!_closed) await _coordinator.TogglePlayPauseAsync();
    }
    private async void OnNextClicked(object sender, RoutedEventArgs args)
    {
        if (!_closed) await _coordinator.NextAsync();
    }
    private void OnClosed(object sender, WindowEventArgs args)
    {
        if (_closed) return;
        _closed = true;
        Pill.RemoveHandler(UIElement.KeyDownEvent, new KeyEventHandler(OnOverlayKeyDown));
        Activated -= OnWindowActivated;
        var transition = _transition;
        _transition = null;
        transition?.Stop();
        _coordinator.Changed -= OnCoordinatorChanged;
        _host.SystemStateChanged -= OnSystemStateChanged;
        _host.DisplayChanged -= OnDisplayChanged;
        _pomodoroTimer.Stop();
        _pomodoroTimer.Tick -= OnPomodoroTick;
        _geometryTimer.Stop();
        _geometryTimer.Tick -= OnGeometryTick;
        _hoverTimer.Stop();
        _hoverTimer.Tick -= OnHoverTimer;
        _leaveTimer.Stop();
        _leaveTimer.Tick -= OnLeaveTimer;
        _host.Dispose();
    }
}
