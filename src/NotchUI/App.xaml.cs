using Microsoft.UI.Xaml;
using NotchUI.Interop;
using NotchUI.Services;
using Microsoft.Windows.AppLifecycle;
using System.IO;
using System.Runtime.InteropServices;

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
        try
        {
        var instance = AppInstance.FindOrRegisterForKey("NotchUI.Main");
        if (!instance.IsCurrent)
        {
            await instance.RedirectActivationToAsync(AppInstance.GetCurrent().GetActivatedEventArgs());
            Shutdown();
            return;
        }
        var dispatcher = Microsoft.UI.Dispatching.DispatcherQueue.GetForCurrentThread();
        instance.Activated += (_, _) => dispatcher.TryEnqueue(ShowSettings);
        var settings = new SettingsService();
        _coordinator = new NotchCoordinator(settings, dispatcher);
        _overlayWindow = new OverlayWindow(_coordinator);
        _overlayWindow.Activate();
        _overlayWindow.ApplyGeometry();
        _tray = new TrayIconHost(WinRT.Interop.WindowNative.GetWindowHandle(_overlayWindow), ShowSettings, Shutdown);
        ShowSettings();
        }
        catch (Exception exception)
        {
            var directory = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "NotchUI");
            var logPath = Path.Combine(directory, "startup-error.log");
            try
            {
                Directory.CreateDirectory(directory);
                File.WriteAllText(logPath, exception.ToString());
            }
            catch (Exception) { logPath = "(log tidak dapat disimpan)"; }
            MessageBox(0, $"NocUI Experience gagal dimulai: {exception.Message}\n\nLog: {logPath}", "NocUI Experience", 0x10);
            Shutdown();
        }
    }

    [DllImport("user32.dll", EntryPoint = "MessageBoxW", CharSet = CharSet.Unicode)]
    private static extern int MessageBox(nint hwnd, string text, string caption, uint type);

    private void ShowSettings()
    {
        if (_coordinator is null) return;
        if (_settingsWindow is null)
        {
            _settingsWindow = new MainWindow(_coordinator, ShowNotch);
            _settingsWindow.Closed += (_, _) => _settingsWindow = null;
        }
        _settingsWindow.Activate();
    }

    private void ShowNotch() => _overlayWindow?.OpenForKeyboard();

    private void Shutdown()
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
