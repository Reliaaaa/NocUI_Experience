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
        ComWrappersSupport.InitializeComWrappers();
        Application.Start(p =>
        {
            var context = new DispatcherQueueSynchronizationContext(DispatcherQueue.GetForCurrentThread());
            System.Threading.SynchronizationContext.SetSynchronizationContext(context);
            _ = new App();
        });
    }
}
