namespace NotchWindows.Core.Models;

// QA fix (bug QA-010, P0 — BUG PALING KRITIS yang ditemukan): model TrackInfo ini sebelumnya TIDAK
// COCOK dengan pemakaiannya di SmtcMusicService.cs, MusicViewModel.cs dan NotchShellViewModel.cs
// (yang memakai TrackInfo.Empty, AlbumTitle, AlbumArt, Status bertipe PlaybackStatus) -> seluruh
// fitur Music (F-010/F-011/F-012), salah satu fitur inti MVP, TIDAK AKAN COMPILE sama sekali.
// Model di bawah ini disamakan dengan pemakaian nyata di 3 file tersebut (bentuk yang lebih kaya,
// PlaybackStatus 5-state, lebih sesuai dengan GlobalSystemMediaTransportControlsSessionPlaybackStatus
// daripada bool IsPlaying yang sebelumnya ada di sini). Lihat docs/06-qa-report.md §Bug QA-010.

/// <summary>Snapshot lagu yang sedang aktif di SMTC (F-010/F-011/F-012).</summary>
public sealed record TrackInfo
{
    public string Title { get; init; } = string.Empty;
    public string Artist { get; init; } = string.Empty;
    public string AlbumTitle { get; init; } = string.Empty;
    public byte[]? AlbumArt { get; init; }
    public string SourceAppId { get; init; } = string.Empty;
    public PlaybackStatus Status { get; init; } = PlaybackStatus.Closed;
    public TimeSpan Position { get; init; }
    public TimeSpan Duration { get; init; }

    public static TrackInfo Empty { get; } = new();
}

/// <summary>Dipetakan 1:1 dari GlobalSystemMediaTransportControlsSessionPlaybackStatus (SMTC).</summary>
public enum PlaybackStatus
{
    Closed,
    Changing,
    Stopped,
    Playing,
    Paused,
}
