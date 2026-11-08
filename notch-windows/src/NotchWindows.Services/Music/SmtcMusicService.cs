using Windows.Foundation;
using Windows.Media.Control;
using Windows.Storage.Streams;
using NotchWindows.Core.Models;
using NotchWindows.Core.Abstractions;

namespace NotchWindows.Services.Music;

/// <summary>
/// F-010, F-011, F-012 — now-playing lintas-app via GlobalSystemMediaTransportControlsSessionManager
/// (Spotify, browser, VLC, dst — app manapun yang mendaftar ke SMTC Windows).
/// </summary>
public sealed class SmtcMusicService : IMusicService
{
    private GlobalSystemMediaTransportControlsSessionManager? _manager;
    private GlobalSystemMediaTransportControlsSession? _session;
    private TypedEventHandler<GlobalSystemMediaTransportControlsSessionManager, CurrentSessionChangedEventArgs>? _currentSessionChangedHandler;
    private readonly SemaphoreSlim _attachLock = new(1, 1);

    public TrackInfo Current { get; private set; } = TrackInfo.Empty;
    public event EventHandler<TrackInfo>? TrackChanged;

    public async Task InitializeAsync(CancellationToken ct = default)
    {
        _manager = await GlobalSystemMediaTransportControlsSessionManager.RequestAsync();
        // QA fix (bug QA-001, P1): handler disimpan di field supaya bisa di-unsubscribe di Dispose().
        // Sebelumnya lambda anonim tidak pernah bisa dilepas -> manager terus memanggil objek yang
        // sudah "disposed" selamanya (event handler leak).
        _currentSessionChangedHandler = async (_, _) => await AttachToCurrentSessionAsync();
        _manager.CurrentSessionChanged += _currentSessionChangedHandler;
        await AttachToCurrentSessionAsync();
    }

    private async Task AttachToCurrentSessionAsync()
    {
        // QA fix (bug QA-002, P1): CurrentSessionChanged bisa fire berkali-kali secara cepat/berurutan
        // (ganti app pemutar musik dengan cepat). Tanpa lock, dua pemanggilan async method ini bisa
        // interleave dan menyebabkan subscribe/unsubscribe event ganda pada _session yang salah.
        await _attachLock.WaitAsync();
        try
        {
            if (_session is not null)
            {
                _session.MediaPropertiesChanged -= OnMediaPropertiesChanged;
                _session.PlaybackInfoChanged -= OnPlaybackInfoChanged;
                _session.TimelinePropertiesChanged -= OnTimelineChanged;
            }

            _session = _manager?.GetCurrentSession();
            if (_session is null)
            {
                Current = TrackInfo.Empty;
                TrackChanged?.Invoke(this, Current);
                return;
            }

            _session.MediaPropertiesChanged += OnMediaPropertiesChanged;
            _session.PlaybackInfoChanged += OnPlaybackInfoChanged;
            _session.TimelinePropertiesChanged += OnTimelineChanged;
            await RefreshAsync();
        }
        finally
        {
            _attachLock.Release();
        }
    }

    private async void OnMediaPropertiesChanged(GlobalSystemMediaTransportControlsSession sender, MediaPropertiesChangedEventArgs args)
        => await RefreshAsync();

    private async void OnPlaybackInfoChanged(GlobalSystemMediaTransportControlsSession sender, PlaybackInfoChangedEventArgs args)
        => await RefreshAsync();

    private async void OnTimelineChanged(GlobalSystemMediaTransportControlsSession sender, TimelinePropertiesChangedEventArgs args)
        => await RefreshAsync();

    private async Task RefreshAsync()
    {
        // QA fix (bug QA-003, P1): _session adalah field mutable yang bisa diganti oleh
        // AttachToCurrentSessionAsync() dari event handler lain selagi RefreshAsync sedang
        // menunggu TryGetMediaPropertiesAsync() (race/TOCTOU) -> NullReferenceException di produksi
        // saat user ganti aplikasi pemutar musik dengan cepat. Ambil salinan lokal sebelum dipakai.
        var session = _session;
        if (session is null) return;

        var props = await session.TryGetMediaPropertiesAsync();
        var playback = session.GetPlaybackInfo();
        var timeline = session.GetTimelineProperties();

        byte[]? albumArt = null;
        if (props.Thumbnail is not null)
        {
            using var stream = await props.Thumbnail.OpenReadAsync();
            using var reader = new DataReader(stream);
            var size = (uint)stream.Size;
            await reader.LoadAsync(size);
            albumArt = new byte[size];
            reader.ReadBytes(albumArt);
        }

        Current = new TrackInfo
        {
            Title = props.Title ?? string.Empty,
            Artist = props.Artist ?? string.Empty,
            AlbumTitle = props.AlbumTitle ?? string.Empty,
            AlbumArt = albumArt,
            SourceAppId = session.SourceAppUserModelId ?? string.Empty,
            Status = MapStatus(playback.PlaybackStatus),
            Position = timeline.Position,
            Duration = timeline.EndTime - timeline.StartTime,
        };

        TrackChanged?.Invoke(this, Current);
    }

    private static PlaybackStatus MapStatus(GlobalSystemMediaTransportControlsSessionPlaybackStatus status) => status switch
    {
        GlobalSystemMediaTransportControlsSessionPlaybackStatus.Playing => PlaybackStatus.Playing,
        GlobalSystemMediaTransportControlsSessionPlaybackStatus.Paused => PlaybackStatus.Paused,
        GlobalSystemMediaTransportControlsSessionPlaybackStatus.Stopped => PlaybackStatus.Stopped,
        GlobalSystemMediaTransportControlsSessionPlaybackStatus.Changing => PlaybackStatus.Changing,
        _ => PlaybackStatus.Closed,
    };

    public Task PlayPauseAsync()
    {
        var session = _session;
        if (session is null) return Task.CompletedTask;
        return Current.Status == PlaybackStatus.Playing
            ? session.TryPauseAsync().AsTask()
            : session.TryPlayAsync().AsTask();
    }

    public Task NextAsync() => _session?.TrySkipNextAsync().AsTask() ?? Task.CompletedTask;

    public Task PreviousAsync() => _session?.TrySkipPreviousAsync().AsTask() ?? Task.CompletedTask;

    public Task SeekAsync(TimeSpan position) =>
        _session?.TryChangePlaybackPositionAsync(position.Ticks).AsTask() ?? Task.CompletedTask;

    public void Dispose()
    {
        // QA fix (bug QA-001, P1): lepas handler level-manager juga, bukan cuma handler per-session.
        if (_manager is not null && _currentSessionChangedHandler is not null)
        {
            _manager.CurrentSessionChanged -= _currentSessionChangedHandler;
        }

        if (_session is not null)
        {
            _session.MediaPropertiesChanged -= OnMediaPropertiesChanged;
            _session.PlaybackInfoChanged -= OnPlaybackInfoChanged;
            _session.TimelinePropertiesChanged -= OnTimelineChanged;
        }

        _attachLock.Dispose();
    }
}
