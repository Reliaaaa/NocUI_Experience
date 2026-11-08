using NotchWindows.Core.Models;

namespace NotchWindows.Core.Abstractions;

/// <summary>F-004 — CPU/RAM/disk/baterai untuk closed-notch &amp; dashboard. Implementasi: SystemStatsService.</summary>
public interface ISystemStatsService
{
    /// <summary>Emit sampel baru tiap 1-5 detik (lihat kriteria selesai F-004).</summary>
    IObservable<SystemStatus> Samples { get; }

    Task<SystemStatus> GetSnapshotAsync();
}
