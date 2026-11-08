using System.Diagnostics;
using System.Reactive.Linq;
using System.Runtime.InteropServices;
using NotchWindows.Core.Models;
using NotchWindows.Core.Abstractions;

namespace NotchWindows.Services.Dock;

/// <summary>
/// F-040 — gabungan pinned apps (dari ISettingsStore) + proses berjalan dengan jendela utama.
/// Enumerasi window penuh (taskbar shell hook) direncanakan Rilis 2 (F-130); MVP cukup Process-based.
/// </summary>
public sealed class RunningAppsService : IDockService
{
    private readonly ISettingsStore _settingsStore;

    public RunningAppsService(ISettingsStore settingsStore)
    {
        _settingsStore = settingsStore;
        Items = Observable.Interval(TimeSpan.FromSeconds(3))
            .StartWith(0)
            .Select(_ => BuildItems())
            .Publish()
            .RefCount();
    }

    public IObservable<IReadOnlyList<DockItem>> Items { get; }

    private IReadOnlyList<DockItem> BuildItems()
    {
        var pinned = _settingsStore.Current.PinnedAppPaths
            .Select(path => new DockItem
            {
                AppId = path,
                DisplayName = Path.GetFileNameWithoutExtension(path),
                ExecutablePath = path,
                IsPinned = true,
                IsRunning = IsRunning(path),
            });

        // QA fix (bug QA-006, P1): Process.GetProcesses() mengembalikan handle per-proses yang harus
        // di-Dispose(). Sebelumnya tidak pernah di-dispose, dan ini jalan tiap 3 detik selama app hidup
        // (notch berjalan di background terus-menerus) -> handle leak yang terus bertambah hingga
        // akhirnya proses OS kehabisan handle (crash/instability setelah berjam-jam berjalan).
        var running = new List<DockItem>();
        var pinnedPaths = _settingsStore.Current.PinnedAppPaths;
        foreach (var p in Process.GetProcesses())
        {
            try
            {
                if (string.IsNullOrEmpty(TryGetMainWindowTitle(p))) continue;

                var exePath = TryGetExePath(p) ?? string.Empty;
                if (pinnedPaths.Contains(exePath)) continue;

                running.Add(new DockItem
                {
                    AppId = string.IsNullOrEmpty(exePath) ? p.ProcessName : exePath,
                    DisplayName = p.ProcessName,
                    ExecutablePath = exePath,
                    IsPinned = false,
                    IsRunning = true,
                    OpenWindowCount = 1,
                });
            }
            finally
            {
                p.Dispose();
            }
        }

        return pinned.Concat(running).ToList();
    }

    private static bool IsRunning(string executablePath)
    {
        // QA fix (bug QA-006, P1): sama seperti BuildItems — proses yang dikembalikan harus di-dispose.
        var name = Path.GetFileNameWithoutExtension(executablePath);
        var processes = Process.GetProcessesByName(name);
        try
        {
            return processes.Length > 0;
        }
        finally
        {
            foreach (var p in processes) p.Dispose();
        }
    }

    private static string? TryGetMainWindowTitle(Process process)
    {
        try { return process.MainWindowHandle == IntPtr.Zero ? null : process.MainWindowTitle; }
        catch { return null; }
    }

    private static string? TryGetExePath(Process process)
    {
        try { return process.MainModule?.FileName; }
        catch { return null; } // akses ditolak untuk proses sistem -> abaikan
    }

    public Task LaunchOrActivateAsync(DockItem item)
    {
        // QA fix (bug QA-019, P2): sebelumnya no-op untuk app yang sudah berjalan — klik ikon dock
        // tidak melakukan apa-apa. Sekarang cari process-nya (by name, sejalan dengan IsRunning di
        // atas) dan bawa window-nya ke depan via SetForegroundWindow. Enumerasi window penuh/multi-window
        // per app tetap Rilis 2 (F-130), ini hanya window utama pertama yang ditemukan.
        if (item.IsRunning)
        {
            var name = Path.GetFileNameWithoutExtension(
                string.IsNullOrEmpty(item.ExecutablePath) ? item.AppId : item.ExecutablePath);
            var processes = Process.GetProcessesByName(name);
            try
            {
                foreach (var p in processes)
                {
                    if (p.MainWindowHandle != IntPtr.Zero)
                    {
                        SetForegroundWindow(p.MainWindowHandle);
                        break;
                    }
                }
            }
            finally
            {
                foreach (var p in processes) p.Dispose();
            }

            return Task.CompletedTask;
        }

        if (!string.IsNullOrEmpty(item.ExecutablePath) && File.Exists(item.ExecutablePath))
            Process.Start(new ProcessStartInfo(item.ExecutablePath) { UseShellExecute = true });
        return Task.CompletedTask;
    }

    [DllImport("user32.dll")]
    private static extern bool SetForegroundWindow(IntPtr hWnd);

    public Task PinAsync(string executablePath)
    {
        var settings = _settingsStore.Current;
        if (!settings.PinnedAppPaths.Contains(executablePath))
            settings.PinnedAppPaths.Add(executablePath);
        return _settingsStore.SaveAsync(settings);
    }

    public Task UnpinAsync(string appId)
    {
        var settings = _settingsStore.Current;
        settings.PinnedAppPaths.RemoveAll(p => p == appId);
        return _settingsStore.SaveAsync(settings);
    }
}
