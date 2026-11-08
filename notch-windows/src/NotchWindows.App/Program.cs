using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using WinRT;

namespace NotchWindows.App;

/// <summary>Entry point untuk WinUI3 unpackaged app (WindowsPackageType=None), lihat NotchWindows.App.csproj.</summary>
public static class Program
{
    [global::System.STAThreadAttribute]
    private static void Main(string[] args)
    {
        try
        {
            ComWrappersSupport.InitializeComWrappers();
            Application.Start(p =>
            {
                var context = new DispatcherQueueSynchronizationContext(DispatcherQueue.GetForCurrentThread());
                System.Threading.SynchronizationContext.SetSynchronizationContext(context);
                _ = new App();
            });
        }
        catch (Exception ex) { LogStartupFailure(ex); throw; }
    }

    internal static void LogStartupFailure(Exception exception)
    {
        var path = Environment.GetEnvironmentVariable("NOCUI_STARTUP_LOG");
        if (string.IsNullOrWhiteSpace(path)) return;
        try { File.AppendAllText(path, exception + Environment.NewLine); }
        catch (Exception) { /* Diagnostics must not hide the original failure. */ }
    }
}
