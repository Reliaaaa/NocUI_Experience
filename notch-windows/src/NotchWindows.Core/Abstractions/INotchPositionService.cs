namespace NotchWindows.Core.Abstractions;

/// <summary>F-001, F-003 — geometri notch per monitor + deteksi fullscreen. Implementasi: NotchInteropService + FullscreenDetectionService (Services project; dipanggil dari App/Interop).</summary>
public interface INotchPositionService
{
    NotchGeometry GetGeometryForActiveMonitor();
    event EventHandler? MonitorLayoutChanged;
}

public readonly record struct NotchGeometry(int X, int Y, int Width, int Height, double DpiScale);
