namespace NotchWindows.Core.Models;

// QA fix (bug QA-011, P0): model ini sebelumnya TIDAK COCOK dengan 3 consumer independen yang saling
// konsisten satu sama lain (SettingsViewModel, NotchShellViewModel, RunningAppsService) — field hilang
// (PinnedAppPaths), nama beda (NotchPosition string vs Position enum, GlobalShortcut vs
// GlobalToggleShortcut, Theme string vs enum, ClosedNotchLeftMetrics List<string> vs LeftMetric enum
// tunggal) -> ISettingsStore/JsonSettingsStore dan ketiga consumer itu tidak akan compile bersamaan.
// Disamakan dengan bentuk yang sudah dipakai konsisten di 3 file tersebut. Lihat docs/06-qa-report.md §QA-011.

/// <summary>Skema settings versioned yang disimpan ISettingsStore (F-050).</summary>
public sealed class AppSettings
{
    public int SchemaVersion { get; set; } = 1;

    public AppTheme Theme { get; set; } = AppTheme.Dark;
    public NotchPosition Position { get; set; } = NotchPosition.TopCenterAttached;
    public string GlobalToggleShortcut { get; set; } = string.Empty;
    public bool AutoStart { get; set; } = true;

    public ClosedNotchMetric LeftMetric { get; set; } = ClosedNotchMetric.Battery;
    public ClosedNotchMetric RightMetric { get; set; } = ClosedNotchMetric.Cpu;

    public bool Use24HourClock { get; set; } = true;
    public int PreferredMonitorIndex { get; set; } = 0;

    /// <summary>F-040 — path .exe aplikasi yang di-pin ke Dock (lihat RunningAppsService).</summary>
    public List<string> PinnedAppPaths { get; set; } = new();
}

public enum AppTheme
{
    Dark,
    Light,
    Glass,
    FrostedGlass,
}

public enum NotchPosition
{
    TopCenterAttached,
    TopCenterFloating,
}
