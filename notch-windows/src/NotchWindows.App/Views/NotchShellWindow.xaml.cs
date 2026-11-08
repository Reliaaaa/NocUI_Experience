using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Controls;
using Microsoft.Extensions.DependencyInjection;
using NotchWindows.App.Services;
using NotchWindows.App.Views.Panels;
using NotchWindows.Core.Navigation;
using NotchWindows.Core.ViewModels;
using NotchWindows.Interop;
using WinRT.Interop;

namespace NotchWindows.App.Views;

/// <summary>
/// Code-behind notch shell. Menghubungkan WindowStyler/MonitorHelper (Interop, Win32 murni)
/// ke window WinUI3 nyata — satu-satunya tempat P/Invoke "bertemu" XAML (lihat 02-architecture.md §5).
/// </summary>
public sealed partial class NotchShellWindow : Window
{
    public NotchShellViewModel ViewModel { get; }

    private readonly WindowStyler _styler;
    private readonly nint _hwnd;
    private readonly INotchNavigationService _navigation;
    private SettingsWindow? _settingsWindow;
    private ShelfPanel? _shelfPanel;
    private readonly Microsoft.UI.Dispatching.DispatcherQueueTimer _clockTimer;

    public NotchShellWindow(NotchShellViewModel viewModel, INotchNavigationService navigation)
    {
        InitializeComponent();
        ViewModel = viewModel;
        _navigation = navigation;
        _navigation.PanelChanged += OnPanelChanged;

        _clockTimer = DispatcherQueue.CreateTimer();
        _clockTimer.Interval = TimeSpan.FromSeconds(1);
        _clockTimer.Tick += OnClockTick;
        UpdateClock();
        _clockTimer.Start();
        Closed += OnClosed;

        _hwnd = WindowNative.GetWindowHandle(this);
        _styler = new WindowStyler(_hwnd);

        _styler.ApplyBaseNotchStyles();
        _styler.ApplyBorderlessPresenter();
        // Window hanya sebesar pill ketika tertutup; area layar lain berada di luar HWND dan
        // otomatis menerima klik. WS_EX_TRANSPARENT pada seluruh HWND membuat pill sendiri tidak
        // bisa menerima hover maupun klik.
        _styler.SetClickThrough(false);
        _styler.ExtendGlassFrame();

        PositionAtTopCenter();

        // QA fix (bug QA-010, P0): View mengacu ke ViewModel.IsOpen / ViewModel.ToggleCommand yang
        // tidak pernah ada di NotchShellViewModel (nama sebenarnya: IsExpanded / ToggleExpandCommand,
        // lihat NotchWindows.Core/ViewModels/NotchShellViewModel.cs) -> CS1061, file ini gagal kompilasi
        // sama sekali. Window notch adalah fitur inti MVP (F-001/F-002), jadi ini memblokir seluruh build.
        ViewModel.PropertyChanged += (_, e) =>
        {
            if (e.PropertyName == nameof(NotchShellViewModel.IsExpanded))
            {
                _styler.SetClickThrough(false);
                PositionForCurrentState();
                NavigationBar.Visibility = ViewModel.IsExpanded
                    ? Visibility.Visible
                    : Visibility.Collapsed;
                ActivePanelHost.Visibility = ViewModel.IsExpanded
                    ? Visibility.Visible
                    : Visibility.Collapsed;

                if (ViewModel.IsExpanded && _navigation.CurrentPanel == NotchPanelKind.Closed)
                {
                    _navigation.ShowPanel(NotchPanelKind.Dashboard);
                }
                else if (!ViewModel.IsExpanded && _navigation.CurrentPanel != NotchPanelKind.Closed)
                {
                    _navigation.Close();
                }
            }
        };
    }

    private void PositionAtTopCenter()
    {
        PositionForCurrentState();
    }

    private void OnClockTick(Microsoft.UI.Dispatching.DispatcherQueueTimer sender, object args) => UpdateClock();

    private void UpdateClock() => ClockText.Text = DateTime.Now.ToString(
        App.Services.GetRequiredService<NotchWindows.Core.Abstractions.ISettingsStore>().Current.Use24HourClock
            ? "HH:mm" : "h:mm tt");

    private void OnClosed(object sender, WindowEventArgs args)
    {
        _clockTimer.Stop();
        _clockTimer.Tick -= OnClockTick;
        _navigation.PanelChanged -= OnPanelChanged;
        Closed -= OnClosed;
    }

    private void PositionForCurrentState()
    {
        var metrics = ViewModel.IsExpanded
            ? MonitorHelper.ComputeTopCenterPill(_hwnd, logicalWidth: 520, logicalHeight: 360)
            : MonitorHelper.ComputeTopCenterPill(_hwnd, logicalWidth: 180, logicalHeight: 32);
        _styler.MoveTo(metrics.X, metrics.Y, metrics.Width, metrics.Height);
    }

    public void ReassertTopmost() => _styler.ReassertTopmost();

    private void OnPanelChanged(object? sender, NotchPanelKind panel)
    {
        if (panel == NotchPanelKind.Closed)
        {
            ViewModel.IsExpanded = false;
            ActivePanelHost.Content = null;
            return;
        }

        if (panel == NotchPanelKind.Settings)
        {
            OpenSettingsWindow();
            ActivePanelHost.Content = null;
            return;
        }

        ActivePanelHost.Content = panel switch
        {
            NotchPanelKind.Closed => null,
            NotchPanelKind.NowPlaying => new MusicPanel(),
            NotchPanelKind.Dashboard => new DashboardPanel(),
            NotchPanelKind.ControlCenter => new ControlCenterPanel(),
            NotchPanelKind.Shelf => _shelfPanel ??= new ShelfPanel(),
            _ => null,
        };
    }

    private void OpenSettingsWindow()
    {
        if (_settingsWindow is null)
        {
            _settingsWindow = App.Services.GetRequiredService<SettingsWindow>();
            _settingsWindow.Closed += (_, _) => _settingsWindow = null;
        }

        _settingsWindow.Activate();
    }

    private void NotchPillBorder_PointerEntered(object sender, PointerRoutedEventArgs e)
    {
        ExpandShell();
    }

    private void NotchPillBorder_Tapped(object sender, TappedRoutedEventArgs e)
    {
        ExpandShell();
    }

    private void ExpandShell()
    {
        if (!ViewModel.IsExpanded)
        {
            ViewModel.IsExpanded = true;
        }
    }

    private void OnPanelButtonClick(object sender, RoutedEventArgs e)
    {
        if (sender is FrameworkElement { Tag: string panelName } &&
            Enum.TryParse(panelName, out NotchPanelKind panel))
        {
            _navigation.ShowPanel(panel);
        }
    }
}
