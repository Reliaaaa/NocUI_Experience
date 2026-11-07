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
    void Refresh();
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
            manager.SessionsChanged += OnSessionsChanged;
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
        if (_manager is not null)
        {
            _manager.CurrentSessionChanged -= OnSessionChanged;
            _manager.SessionsChanged -= OnSessionsChanged;
        }
        Detach();
        _manager = null;
        Publish(new(MediaAvailability.Disabled));
    }
    private void OnSessionChanged(GlobalSystemMediaTransportControlsSessionManager sender, CurrentSessionChangedEventArgs args)
        => QueueSessionSelection(sender);
    private void OnSessionsChanged(GlobalSystemMediaTransportControlsSessionManager sender, SessionsChangedEventArgs args)
        => QueueSessionSelection(sender);
    private void QueueSessionSelection(GlobalSystemMediaTransportControlsSessionManager sender)
        => dispatcher.TryEnqueue(() => { if (_running && ReferenceEquals(sender, _manager)) SelectSession(); });
    private void SelectSession()
    {
        try
        {
            var selected = _manager?.GetCurrentSession();
            // Some players expose a session before Windows assigns a current one.
            if (selected is null && _manager is not null)
            {
                foreach (var candidate in _manager.GetSessions())
                {
                    try
                    {
                        var playback = candidate.GetPlaybackInfo();
                        selected ??= candidate;
                        if (playback.PlaybackStatus == GlobalSystemMediaTransportControlsSessionPlaybackStatus.Playing)
                        {
                            selected = candidate;
                            break;
                        }
                    }
                    catch (Exception) { /* A closing player must not hide other sessions. */ }
                }
            }
            if (selected is not null && ReferenceEquals(selected, _session)) { Refresh(); return; }
            Detach();
            ++_generation;
            ++_refreshVersion;
            // A command for the previous player may never complete. Its result
            // must neither block nor modify controls for the replacement player.
            ++_commandTicket;
            _commandBusy = false;
            _session = selected;
            if (_session is null) { Publish(new(MediaAvailability.NoSession)); return; }
            _session.MediaPropertiesChanged += OnPropertiesChanged;
            _session.PlaybackInfoChanged += OnPlaybackChanged;
            Publish(new(MediaAvailability.Loading));
            Refresh();
        }
        catch (Exception)
        {
            ++_generation;
            ++_refreshVersion;
            ++_commandTicket;
            _commandBusy = false;
            Detach();
            Publish(new(MediaAvailability.Error));
        }
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
        if (!_running) return;
        if (_manager is null)
        {
            // A failed initial request can be retried by a system resume/refresh.
            // Loading means the initial asynchronous request is still pending.
            if (State.Availability == MediaAvailability.Error) { Stop(); Start(); }
            return;
        }
        if (session is null) { SelectSession(); return; }
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
