using NotchWindows.Core.Models;

namespace NotchWindows.Core.Abstractions;

// QA fix (bug QA-011, P0): interface ini sebelumnya tidak cocok dengan satu-satunya implementasi
// (JsonSettingsStore) maupun consumer-nya (NotchShellViewModel, SettingsViewModel, RunningAppsService)
// — semuanya memakai properti `Current` sinkron + LoadAsync()/SaveAsync(settings) tanpa CancellationToken
// + event bernama `Changed`. Disamakan dengan kode yang sudah konsisten. Lihat docs/06-qa-report.md §QA-011.

/// <summary>Abstraksi penyimpanan settings lokal (F-050). Implementasi: NotchWindows.Services/Settings/JsonSettingsStore (JSON di LocalAppData).</summary>
public interface ISettingsStore
{
    /// <summary>Settings yang sedang dimuat di memori (default sebelum LoadAsync() dipanggil).</summary>
    AppSettings Current { get; }
    string? LastError { get; }

    Task LoadAsync();
    Task SaveAsync(AppSettings settings);

    event EventHandler<AppSettings>? Changed;
}
