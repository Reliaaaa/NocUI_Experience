using NotchWindows.Core.Models;

namespace NotchWindows.Core.Abstractions;

/// <summary>F-040 — daftar app pinned + running. Implementasi: RunningAppsService.</summary>
public interface IDockService
{
    IObservable<IReadOnlyList<DockItem>> Items { get; }

    Task LaunchOrActivateAsync(DockItem item);
    Task PinAsync(string executablePath);
    Task UnpinAsync(string appId);
}
