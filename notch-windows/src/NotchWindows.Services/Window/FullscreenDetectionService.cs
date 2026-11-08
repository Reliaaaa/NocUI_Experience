using System.Runtime.InteropServices;

namespace NotchWindows.Services.Window;

/// <summary>
/// F-003 — deteksi app fullscreen untuk auto-hide notch, exclude shell windows.
/// QA fix (bug QA-017, P1): konsolidasi dengan NotchWindows.Interop.FullscreenDetector (static, sudah
/// dihapus) yang punya pengecekan tambahan berguna (window tanpa caption/border = fullscreen asli,
/// bukan sekadar dimaksimalkan) — logika itu dipindah ke sini supaya tidak hilang saat duplikasinya
/// dibuang. Lihat docs/06-qa-report.md §QA-017.
/// </summary>
public sealed class FullscreenDetectionService
{
    private const int GWL_STYLE = -16;
    private const int WS_CAPTION = 0x00C00000;
    private const int WS_THICKFRAME = 0x00040000;

    private static readonly HashSet<string> ExcludedClassNames = new(StringComparer.OrdinalIgnoreCase)
    {
        "Progman", "WorkerW", "Shell_TrayWnd", "Shell_SecondaryTrayWnd",
    };

    public bool IsForegroundAppFullscreen()
    {
        var hwnd = GetForegroundWindow();
        if (hwnd == IntPtr.Zero) return false;

        var className = GetClassName(hwnd);
        if (ExcludedClassNames.Contains(className)) return false;

        if (!GetWindowRect(hwnd, out var windowRect)) return false;

        var monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
        var info = new MONITORINFO { cbSize = Marshal.SizeOf<MONITORINFO>() };
        if (!GetMonitorInfo(monitor, ref info)) return false;

        var coversMonitor = windowRect.Left <= info.rcMonitor.Left
            && windowRect.Top <= info.rcMonitor.Top
            && windowRect.Right >= info.rcMonitor.Right
            && windowRect.Bottom >= info.rcMonitor.Bottom;

        if (!coversMonitor) return false;

        // Window tanpa caption/border (borderless fullscreen khas game/video player) dianggap fullscreen
        // asli, bukan sekadar window biasa yang kebetulan dimaksimalkan (yang masih punya caption).
        var style = GetWindowLong(hwnd, GWL_STYLE);
        var hasChrome = (style & (WS_CAPTION | WS_THICKFRAME)) != 0;

        return !hasChrome;
    }

    private static string GetClassName(IntPtr hwnd)
    {
        var buffer = new global::System.Text.StringBuilder(256);
        GetClassName(hwnd, buffer, buffer.Capacity);
        return buffer.ToString();
    }

    private const int MONITOR_DEFAULTTONEAREST = 2;

    [DllImport("user32.dll")] private static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] private static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    [DllImport("user32.dll")] private static extern IntPtr MonitorFromWindow(IntPtr hwnd, int dwFlags);
    [DllImport("user32.dll")] private static extern bool GetMonitorInfo(IntPtr hMonitor, ref MONITORINFO lpmi);
    [DllImport("user32.dll")] private static extern int GetWindowLong(IntPtr hWnd, int nIndex);
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    private static extern int GetClassName(IntPtr hWnd, global::System.Text.StringBuilder lpClassName, int nMaxCount);

    [StructLayout(LayoutKind.Sequential)]
    private struct RECT { public int Left, Top, Right, Bottom; }

    [StructLayout(LayoutKind.Sequential)]
    private struct MONITORINFO
    {
        public int cbSize;
        public RECT rcMonitor;
        public RECT rcWork;
        public int dwFlags;
    }
}
