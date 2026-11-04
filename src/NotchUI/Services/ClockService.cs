using Microsoft.UI.Dispatching;
using NotchUI.Models;

namespace NotchUI.Services;

public sealed class ClockService : IDisposable
{
    private readonly DispatcherQueueTimer _timer;
    private bool _running;
    public ClockState State { get; private set; } = new(DateTimeOffset.Now);
    public event EventHandler? Changed;
    public ClockService(DispatcherQueue dispatcher)
    {
        _timer = dispatcher.CreateTimer();
        _timer.IsRepeating = false;
        _timer.Tick += OnTick;
    }
    public void Start() { if (_running) return; _running = true; Refresh(); if (_running) Schedule(); }
    public void Stop() { _running = false; _timer.Stop(); }
    public void Refresh() { State = new(DateTimeOffset.Now); Changed?.Invoke(this, EventArgs.Empty); }
    private void Schedule()
    {
        var now = DateTimeOffset.Now;
        _timer.Interval = TimeSpan.FromMilliseconds(60_000 - now.Second * 1000 - now.Millisecond);
        _timer.Start();
    }
    private void OnTick(DispatcherQueueTimer sender, object args) { if (!_running) return; Refresh(); if (_running) Schedule(); }
    public void Dispose() { Stop(); _timer.Tick -= OnTick; }
}
