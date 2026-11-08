using System.Runtime.InteropServices;
using NotchWindows.Core.Abstractions;

namespace NotchWindows.Services.Window;

/// <summary>
/// F-001 — logika non-UI untuk geometri notch per monitor. Pemanggilan Win32 mentah
/// (SetWindowLong, SetWindowPos, DwmSetWindowAttribute) ada di App/Interop/Win32Window.cs
/// agar HWND (tipe UI) tidak bocor ke Services (lihat docs/02-architecture.md §5).
/// </summary>
public sealed class NotchInteropService : INotchPositionService
{
    private const int DefaultWidth = 220;
    private const int DefaultHeight = 32;

    public event EventHandler? MonitorLayoutChanged;

    public NotchGeometry GetGeometryForActiveMonitor()
    {
        var screenWidth = GetSystemMetrics(SM_CXSCREEN);
        // QA fix (bug QA-018, P2): sebelumnya hardcoded 1.0 — salah di monitor non-96-DPI (mis. 150%/200%
        // scaling), notch jadi salah ukuran/posisi. GetDpiForSystem() dipakai karena kelas ini belum punya
        // HWND (dipanggil sebelum window dibuat); ini DPI sistem (monitor utama), bukan per-monitor-aktif
        // sejati — pelacakan per-monitor saat window sudah ada tetap lewat
        // NotchWindows.Interop.MonitorHelper.GetDpiScale(hwnd), yang dipakai nyata oleh NotchShellWindow.
        // Multi-monitor penuh (DisplayAreaWatcher, lihat docs/02-architecture.md §3.6) masih gap terpisah
        // yang dicatat di docs/06-qa-report.md §QA-018, belum tertutup oleh fix ini.
        var dpiScale = GetDpiForSystem() / 96.0;
        var x = (int)((screenWidth - DefaultWidth * dpiScale) / 2);
        return new NotchGeometry(x, 0, DefaultWidth, DefaultHeight, dpiScale);
    }

    /// <summary>Dipanggil App saat menerima WM_DISPLAYCHANGE.</summary>
    public void NotifyMonitorLayoutChanged() => MonitorLayoutChanged?.Invoke(this, EventArgs.Empty);

    private const int SM_CXSCREEN = 0;

    [DllImport("user32.dll")]
    private static extern int GetSystemMetrics(int nIndex);

    [DllImport("user32.dll")]
    private static extern uint GetDpiForSystem();
}
