namespace NotchWindows.Core.Models;

/// <summary>Metrik sistem untuk closed-notch info (F-004) dan dashboard (F-020).</summary>
public sealed class SystemStatus
{
    public double CpuUsagePercent { get; init; }
    public double RamUsagePercent { get; init; }
    public double PrimaryDiskUsagePercent { get; init; }
    public BatteryStatus? Battery { get; init; }
    public DateTimeOffset SampledAt { get; init; } = DateTimeOffset.Now;
}

public sealed class BatteryStatus
{
    public int ChargePercent { get; init; }
    public bool IsCharging { get; init; }
    public bool IsPresent { get; init; } = true;
}

public enum ClosedNotchMetric
{
    Clock,
    Battery,
    Date,
    Cpu,
    Ram,
    Disk,
    WiFi,
    Weather,
    MusicProgress,
}
