using System.Diagnostics;
using System.Reactive.Linq;
using NotchWindows.Core.Models;
using NotchWindows.Core.Abstractions;

namespace NotchWindows.Services.System;

/// <summary>
/// F-004 — CPU/RAM/disk via PerformanceCounter (tanpa admin/driver tambahan, lihat 01-features.md).
/// GPU load/temperature direncanakan Rilis 2 (butuh WMI vendor-spesifik atau Setup API tambahan).
/// </summary>
public sealed class SystemStatsService : ISystemStatsService, IDisposable
{
    private readonly PerformanceCounter? _cpuCounter;
    private readonly BatteryService _batteryService;

    public SystemStatsService(BatteryService batteryService)
    {
        _batteryService = batteryService;
        try
        {
            var counter = new PerformanceCounter("Processor", "% Processor Time", "_Total");
            try { counter.NextValue(); _cpuCounter = counter; }
            catch { counter.Dispose(); throw; }
        }
        catch (Exception ex) when (ex is InvalidOperationException or UnauthorizedAccessException or
                                   global::System.ComponentModel.Win32Exception)
        {
            // Performance counters are optional; a broken counter must not block the notch.
            _cpuCounter = null;
        }
        Samples = BuildSamples();
    }

    public IObservable<SystemStatus> Samples { get; }

    private IObservable<SystemStatus> BuildSamples() =>
        Observable.Interval(TimeSpan.FromSeconds(2))
            .SelectMany(_ => Observable.FromAsync(GetSnapshotAsync))
            .Publish()
            .RefCount();

    public Task<SystemStatus> GetSnapshotAsync()
    {
        double cpu;
        try { cpu = _cpuCounter?.NextValue() ?? double.NaN; }
        catch (Exception ex) when (ex is InvalidOperationException or UnauthorizedAccessException or
                                   global::System.ComponentModel.Win32Exception) { cpu = double.NaN; }
        var ram = GetRamUsagePercent();
        var disk = GetPrimaryDiskUsagePercent();
        var battery = _batteryService.GetStatus();

        return Task.FromResult(new SystemStatus
        {
            CpuUsagePercent = Math.Round(cpu, 1),
            RamUsagePercent = Math.Round(ram, 1),
            PrimaryDiskUsagePercent = Math.Round(disk, 1),
            Battery = battery,
        });
    }

    private static double GetRamUsagePercent()
    {
        var info = new Microsoft.VisualBasic.Devices.ComputerInfo();
        var total = (double)info.TotalPhysicalMemory;
        var available = (double)info.AvailablePhysicalMemory;
        return total <= 0 ? 0 : (total - available) / total * 100.0;
    }

    private static double GetPrimaryDiskUsagePercent()
    {
        var drive = new DriveInfo(Path.GetPathRoot(Environment.SystemDirectory) ?? "C:\\");
        if (!drive.IsReady) return 0;
        var used = drive.TotalSize - drive.AvailableFreeSpace;
        return drive.TotalSize <= 0 ? 0 : (double)used / drive.TotalSize * 100.0;
    }

    public void Dispose() => _cpuCounter?.Dispose();
}
