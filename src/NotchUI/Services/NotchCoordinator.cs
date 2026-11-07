using Microsoft.UI.Dispatching;
using NotchUI.Models;

namespace NotchUI.Services;

/// <summary>Shared state between the dashboard and overlay on the UI thread.</summary>
public sealed class NotchCoordinator : IDisposable
{
    private readonly ISettingsService _store;
    private readonly ClockService _clock;
    private readonly BatteryService _battery;
    private readonly IMediaService _media;
    private readonly DispatcherQueueTimer _saveTimer;
    private bool _settingsDirty;
    public NotchSettings Settings { get; private set; }
    public ClockState Clock => _clock.State;
    public BatteryState Battery => _battery.State;
    public MediaState Media => _media.State;
    public bool IsExpanded { get; private set; }
    public string? SettingsError => _store.LastError;
    public event EventHandler? Changed;

    public NotchCoordinator(ISettingsService store, DispatcherQueue dispatcher)
    {
        _store = store;
        _saveTimer = dispatcher.CreateTimer();
        _saveTimer.Interval = TimeSpan.FromMilliseconds(400);
        _saveTimer.IsRepeating = false;
        _saveTimer.Tick += OnSaveTick;
        Settings = store.Load().Normalize();
        _clock = new ClockService(dispatcher);
        _battery = new BatteryService(dispatcher);
        _media = new MediaService(dispatcher);
        _clock.Changed += OnChanged;
        _battery.Changed += OnChanged;
        _media.Changed += OnChanged;
        ApplyModules();
    }

    public void UpdateSettings(NotchSettings settings)
    {
        Settings = settings.Normalize();
        ApplyModules();
        _settingsDirty = true;
        _saveTimer.Stop();
        _saveTimer.Start();
        Changed?.Invoke(this, EventArgs.Empty);
    }

    private void OnSaveTick(DispatcherQueueTimer sender, object args)
    {
        FlushSettings();
        Changed?.Invoke(this, EventArgs.Empty);
    }

    private void FlushSettings()
    {
        _saveTimer.Stop();
        if (!_settingsDirty) return;
        _settingsDirty = !_store.Save(Settings);
    }

    public void SetExpanded(bool expanded)
    {
        if (IsExpanded == expanded) return;
        IsExpanded = expanded;
        Changed?.Invoke(this, EventArgs.Empty);
    }

    public Task<bool> TogglePlayPauseAsync() => _media.TogglePlayPauseAsync();
    public Task<bool> PreviousAsync() => _media.PreviousAsync();
    public Task<bool> NextAsync() => _media.NextAsync();
    public void RefreshSystemState() { _clock.Refresh(); _battery.Refresh(); _media.Refresh(); }
    private void OnChanged(object? sender, EventArgs args) => Changed?.Invoke(this, EventArgs.Empty);
    private void ApplyModules()
    {
        if (Settings.ClockEnabled) _clock.Start(); else _clock.Stop();
        if (Settings.BatteryEnabled) _battery.Start(); else _battery.Stop();
        if (Settings.MediaEnabled) _media.Start(); else _media.Stop();
    }
    public void Dispose()
    {
        FlushSettings();
        _saveTimer.Tick -= OnSaveTick;
        _clock.Changed -= OnChanged;
        _battery.Changed -= OnChanged;
        _media.Changed -= OnChanged;
        _clock.Dispose(); _battery.Dispose(); _media.Dispose();
    }
}
