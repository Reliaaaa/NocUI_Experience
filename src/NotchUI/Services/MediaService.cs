using Microsoft.UI.Dispatching;
using NotchUI.Models;
using Windows.Media.Control;

namespace NotchUI.Services;

public interface IMediaService : IDisposable
{
    MediaState State { get; }
    event EventHandler? Changed;
    void Start();
    void Stop();
    Task<bool> TogglePlayPauseAsync();
    Task<bool> PreviousAsync();
    Task<bool> NextAsync();
}

public sealed class MediaService(DispatcherQueue dispatcher) : IMediaService
{
    private GlobalSystemMediaTransportControlsSessionManager? _manager;
    private GlobalSystemMediaTransportControlsSession? _session;
    private int _generation;
    private int _refreshVersion;
    private bool _running;
    private bool _commandBusy;
    private int _commandTicket;
    public MediaState State { get; private set; } = new(MediaAvailability.Disabled);
    public event EventHandler? Changed;
    public async void Start()
    {
        if (_running) return;
        _running = true;
        int generation = ++_generation;
        Publish(new(MediaAvailability.Loading));
        try
        {
            var manager = await GlobalSystemMediaTransportControlsSessionManager.RequestAsync();
            if (!_running || generation != _generation) return;
            _manager = manager;
            manager.CurrentSessionChanged += OnSessionChanged;
            SelectSession();
        }
        catch (Exception) { if (_running && generation == _generation) Publish(new(MediaAvailability.Error)); }
    }
    public void Stop()
    {
        _running = false;
        _commandBusy = false;
        ++_commandTicket;
        ++_generation;
        ++_refreshVersion;
        if (_manager is not null) _manager.CurrentSessionChanged -= OnSessionChanged;
        Detach();
        _manager = null;
        Publish(new(MediaAvailability.Disabled));
    }
    private void OnSessionChanged(GlobalSystemMediaTransportControlsSessionManager sender, CurrentSessionChangedEventArgs args)
        => dispatcher.TryEnqueue(() => { if (_running) SelectSession(); });
    private void SelectSession()
    {
        Detach();
        ++_generation;
        try
        {
            _session = _manager?.GetCurrentSession();
            if (_session is null) { Publish(new(MediaAvailability.NoSession)); return; }
            _session.MediaPropertiesChanged += OnPropertiesChanged;
            _session.PlaybackInfoChanged += OnPlaybackChanged;
            Publish(new(MediaAvailability.Loading));
            Refresh();
        }
        catch (Exception) { Detach(); Publish(new(MediaAvailability.Error)); }
    }
    private void Detach()
    {
        if (_session is null) return;
        _session.MediaPropertiesChanged -= OnPropertiesChanged;
        _session.PlaybackInfoChanged -= OnPlaybackChanged;
        _session = null;
    }
    private void OnPropertiesChanged(GlobalSystemMediaTransportControlsSession sender, MediaPropertiesChangedEventArgs args)
        => dispatcher.TryEnqueue(Refresh);
    private void OnPlaybackChanged(GlobalSystemMediaTransportControlsSession sender, PlaybackInfoChangedEventArgs args)
        => dispatcher.TryEnqueue(Refresh);
    public async void Refresh()
    {
        var session = _session;
        if (!_running || session is null) return;
        int generation = _generation, version = ++_refreshVersion;
        try
        {
            var properties = await session.TryGetMediaPropertiesAsync();
            if (!_running || generation != _generation || version != _refreshVersion) return;
            var playback = session.GetPlaybackInfo();
            var controls = playback.Controls;
            Publish(new(MediaAvailability.Active, properties.Title, properties.Artist,
                playback.PlaybackStatus == GlobalSystemMediaTransportControlsSessionPlaybackStatus.Playing,
                controls.IsPlayPauseToggleEnabled, controls.IsPreviousEnabled, controls.IsNextEnabled, State.IsBusy));
        }
        catch (Exception) { if (_running && generation == _generation && version == _refreshVersion) Publish(new(MediaAvailability.Error)); }
    }
    public Task<bool> TogglePlayPauseAsync() => ExecuteAsync(0);
    public Task<bool> PreviousAsync() => ExecuteAsync(1);
    public Task<bool> NextAsync() => ExecuteAsync(2);
    private async Task<bool> ExecuteAsync(int command)
    {
        var session = _session;
        if (session is null || _commandBusy || !(command == 0 ? State.CanTogglePlayPause : command == 1 ? State.CanPrevious : State.CanNext)) return false;
        int generation = _generation;
        int ticket = ++_commandTicket;
        _commandBusy = true;
        Publish(State with { IsBusy = true, Error = null });
        bool success = false;
        try
        {
            success = command == 0 ? await session.TryTogglePlayPauseAsync()
                : command == 1 ? await session.TrySkipPreviousAsync() : await session.TrySkipNextAsync();
        }
        catch (Exception) { success = false; }
        finally
        {
            if (ticket == _commandTicket)
            {
                _commandBusy = false;
                Publish(State with { IsBusy = false,
                    Error = _running && generation == _generation && !success ? "Kontrol media gagal. Coba lagi." : State.Error });
            }
        }
        if (success && _running && generation == _generation) Refresh();
        return success && generation == _generation;
    }
    private void Publish(MediaState state) { State = state with { IsBusy = _commandBusy }; Changed?.Invoke(this, EventArgs.Empty); }
    public void Dispose() => Stop();
}
