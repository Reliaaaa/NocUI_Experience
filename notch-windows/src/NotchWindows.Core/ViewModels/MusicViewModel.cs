using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using NotchWindows.Core.Models;
using NotchWindows.Core.Abstractions;

namespace NotchWindows.Core.ViewModels;

/// <summary>F-010, F-011, F-012 — kartu now-playing di notch terbuka.</summary>
// QA fix (bug QA-005, P1): sama seperti NotchShellViewModel/DockBarViewModel — tanpa IDisposable
// eksplisit + unsubscribe, event TrackChanged bocor seumur hidup IMusicService (singleton).
public sealed partial class MusicViewModel : ObservableObject, IDisposable
{
    private readonly IMusicService _musicService;

    public MusicViewModel(IMusicService musicService)
    {
        _musicService = musicService;
        _musicService.TrackChanged += OnTrackChanged;
        Track = musicService.Current;
    }

    [ObservableProperty]
    private TrackInfo track = TrackInfo.Empty;

    public bool IsPlaying => Track.Status == PlaybackStatus.Playing;

    /// <summary>0..1 untuk ProgressBar (F-012). Dihitung dari Track.Position / Track.Duration.</summary>
    public double ProgressRatio =>
        Track.Duration > TimeSpan.Zero
            ? Math.Clamp(Track.Position.TotalSeconds / Track.Duration.TotalSeconds, 0, 1)
            : 0;

    [RelayCommand]
    private Task PlayPause() => _musicService.PlayPauseAsync();

    [RelayCommand]
    private Task Next() => _musicService.NextAsync();

    [RelayCommand]
    private Task Previous() => _musicService.PreviousAsync();

    public Task SeekAsync(TimeSpan position) => _musicService.SeekAsync(position);

    private void OnTrackChanged(object? sender, TrackInfo track) => Track = track;

    public void Dispose() => _musicService.TrackChanged -= OnTrackChanged;
}
