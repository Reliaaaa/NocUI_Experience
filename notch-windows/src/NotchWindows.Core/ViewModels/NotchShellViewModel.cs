using System.Reactive.Linq;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using CommunityToolkit.Mvvm.Messaging;
using NotchWindows.Core.Messaging;
using NotchWindows.Core.Models;
using NotchWindows.Core.Abstractions;

namespace NotchWindows.Core.ViewModels;

/// <summary>ViewModel untuk NotchShellWindow: expand/collapse (F-002), closed-notch info (F-004, F-005).</summary>
// QA fix (bug QA-005, P1): Dispose() tidak pernah dipanggil DI container/`using` karena class tidak
// mengimplementasikan IDisposable secara eksplisit -> _statsSubscription bocor selama app hidup.
public sealed partial class NotchShellViewModel : ObservableObject, IDisposable
{
    private readonly ISystemStatsService _systemStatsService;
    private readonly IMusicService _musicService;
    private readonly ISettingsStore _settingsStore;
    private readonly IMessenger _messenger;
    private IDisposable? _statsSubscription;

    public NotchShellViewModel(
        ISystemStatsService systemStatsService,
        IMusicService musicService,
        ISettingsStore settingsStore,
        IMessenger messenger)
    {
        _systemStatsService = systemStatsService;
        _musicService = musicService;
        _settingsStore = settingsStore;
        _messenger = messenger;

        _musicService.TrackChanged += OnTrackChanged;
        CurrentTrack = _musicService.Current;
    }

    [ObservableProperty]
    private bool isExpanded;

    [ObservableProperty]
    private SystemStatus? latestStatus;

    [ObservableProperty]
    private TrackInfo currentTrack = TrackInfo.Empty;

    [ObservableProperty]
    private DateTime clockNow = DateTime.Now;

    public ClosedNotchMetric LeftMetric => _settingsStore.Current.LeftMetric;
    public ClosedNotchMetric RightMetric => _settingsStore.Current.RightMetric;

    public async Task InitializeAsync()
    {
        await _settingsStore.LoadAsync();
        await _musicService.InitializeAsync();
        _statsSubscription = _systemStatsService.Samples.Subscribe(status =>
        {
            LatestStatus = status;
            _messenger.Send(new SystemStatusChangedMessage(status));
        });
    }

    [RelayCommand]
    private void ToggleExpand() => IsExpanded = !IsExpanded;

    [RelayCommand]
    private void Collapse() => IsExpanded = false;

    private void OnTrackChanged(object? sender, TrackInfo track) => CurrentTrack = track;

    public void Dispose()
    {
        _statsSubscription?.Dispose();
        _musicService.TrackChanged -= OnTrackChanged;
    }
}
