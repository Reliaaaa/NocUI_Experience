using Microsoft.UI.Xaml;
using NotchUI.Interop;
using NotchUI.Services;
using Microsoft.Windows.AppLifecycle;

namespace NotchUI;

public partial class App : Application
{
    private MainWindow? _settingsWindow;
    private OverlayWindow? _overlayWindow;
    private TrayIconHost? _tray;
    private NotchCoordinator? _coordinator;

    public App() => InitializeComponent();

    protected override async void OnLaunched(LaunchActivatedEventArgs args)
    {
        var instance = AppInstance.FindOrRegisterForKey("NotchUI.Main");
        if (!instance.IsCurrent)
        {
            await instance.RedirectActivationToAsync(AppInstance.GetCurrent().GetActivatedEventArgs());
            Exit();
            return;
        }
        var dispatcher = Microsoft.UI.Dispatching.DispatcherQueue.GetForCurrentThread();
        instance.Activated += (_, _) => dispatcher.TryEnqueue(ShowSettings);
        var settings = new SettingsService();
        _coordinator = new NotchCoordinator(settings, dispatcher);
        _overlayWindow = new OverlayWindow(_coordinator);
        _overlayWindow.Activate();
        _overlayWindow.ApplyGeometry();
        _tray = new TrayIconHost(WinRT.Interop.WindowNative.GetWindowHandle(_overlayWindow), ShowSettings, Exit);
        ShowSettings();
    }

    private void ShowSettings()
    {
        if (_coordinator is null) return;
        if (_settingsWindow is null)
        {
            _settingsWindow = new MainWindow(_coordinator);
            _settingsWindow.Closed += (_, _) => _settingsWindow = null;
        }
        _settingsWindow.Activate();
    }

    private void Exit()
    {
        _tray?.Dispose();
        _tray = null;
        _coordinator?.Dispose();
        _coordinator = null;
        _settingsWindow?.Close();
        _overlayWindow?.Close();
        _overlayWindow = null;
        Microsoft.UI.Xaml.Application.Current.Exit();
    }
}
