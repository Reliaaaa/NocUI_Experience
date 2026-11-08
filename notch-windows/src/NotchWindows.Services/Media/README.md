# Media (SMTC)

Implementasi `ISmtcService` pakai `Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager`
(bagian Windows SDK, tanpa NuGet tambahan). File implementasi: `SmtcService.cs` (dibuat di tahap
implementasi F-010/F-011/F-012, lihat docs/01-features.md).

Poin desain:
- Subscribe `SessionsChanged` + per-session `MediaPropertiesChanged`/`PlaybackInfoChanged`/`TimelinePropertiesChanged`.
- Pilih "current session" dari `GetCurrentSession()`, fallback ke session pertama yang `IsPlaying` bila current null.
- Convert `IRandomAccessStreamReference` album art ke `byte[]` untuk dipakai `BitmapImage` di View.
