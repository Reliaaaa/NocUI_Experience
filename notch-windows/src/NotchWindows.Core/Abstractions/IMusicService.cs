using NotchWindows.Core.Models;

namespace NotchWindows.Core.Abstractions;

// QA fix (bug QA-010, P0): kontrak interface ini sebelumnya TIDAK COCOK dengan satu-satunya
// implementasi nyata (SmtcMusicService, di NotchWindows.Services/Music) maupun dengan pemakainya
// (MusicViewModel, NotchShellViewModel) — nama & tanda tangan method berbeda total, jadi
// `SmtcMusicService : IMusicService` tidak akan compile. Disamakan dengan kode yang sudah konsisten
// dipakai di 3 file lain. Lihat docs/06-qa-report.md §Bug QA-010.

/// <summary>Abstraksi kontrol media (F-010/F-011/F-012). Implementasi nyata: NotchWindows.Services/Music/SmtcMusicService.</summary>
public interface IMusicService : IDisposable
{
    TrackInfo Current { get; }

    event EventHandler<TrackInfo>? TrackChanged;

    Task InitializeAsync(CancellationToken ct = default);

    Task PlayPauseAsync();
    Task NextAsync();
    Task PreviousAsync();
    Task SeekAsync(TimeSpan position);
}
