using System.Runtime.InteropServices;
using Microsoft.UI.Dispatching;
using NotchUI.Models;

namespace NotchUI.Services;

public sealed class BatteryService : IDisposable
{
    private readonly DispatcherQueueTimer _timer;
    public BatteryState State { get; private set; } = BatteryState.Unknown;
    public event EventHandler? Changed;
    public BatteryService(DispatcherQueue dispatcher)
    {
        _timer = dispatcher.CreateTimer();
        _timer.Interval = TimeSpan.FromSeconds(30);
        _timer.Tick += OnTick;
    }
    public void Start() { Refresh(); _timer.Start(); }
    public void Stop() => _timer.Stop();
    public void Refresh()
    {
        State = !GetSystemPowerStatus(out var power) ? BatteryState.Unknown
            : power.BatteryFlag == 255 ? BatteryState.Unknown
            : (power.BatteryFlag & 128) != 0 ? new(BatteryAvailability.Unavailable, null, false)
            : power.BatteryLifePercent == 255 ? BatteryState.Unknown
            : new(BatteryAvailability.Available, Math.Clamp((int)power.BatteryLifePercent, 0, 100), (power.BatteryFlag & 8) != 0);
        Changed?.Invoke(this, EventArgs.Empty);
    }
    private void OnTick(DispatcherQueueTimer sender, object args) => Refresh();
    public void Dispose() { Stop(); _timer.Tick -= OnTick; }
    [StructLayout(LayoutKind.Sequential)]
    private struct PowerStatus
    {
        public byte AcLineStatus, BatteryFlag, BatteryLifePercent, SystemStatusFlag;
        public uint BatteryLifeTime, BatteryFullLifeTime;
    }
    [DllImport("kernel32.dll")][return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GetSystemPowerStatus(out PowerStatus status);
}
