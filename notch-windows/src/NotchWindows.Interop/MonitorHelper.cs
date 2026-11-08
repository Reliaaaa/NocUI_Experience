namespace NotchWindows.Interop;

/// <summary>
/// Menghitung posisi/ukuran fisik notch pill di monitor aktif, dengan DPI-aware scaling (F-001 multi-monitor).
/// </summary>
public static class MonitorHelper
{
    /// <summary>Area kerja monitor yang sedang memuat window tertentu (atau monitor terdekat bila null/minimized).</summary>
    public static NativeMethods.RECT GetWorkAreaForWindow(nint referenceHwnd)
    {
        var hMonitor = NativeMethods.MonitorFromWindow(referenceHwnd, NativeMethods.MONITOR_DEFAULTTONEAREST);
        var info = new NativeMethods.MONITORINFO { cbSize = System.Runtime.InteropServices.Marshal.SizeOf<NativeMethods.MONITORINFO>() };
        NativeMethods.GetMonitorInfo(hMonitor, ref info);
        return info.rcMonitor;
    }

    /// <summary>Skala DPI window saat ini (96 DPI = 1.0).</summary>
    public static double GetDpiScale(nint hwnd) => NativeMethods.GetDpiForWindow(hwnd) / 96.0;

    /// <summary>
    /// Hitung metrik fisik notch pill: top-center dari monitor, lebar/tinggi logis dikali skala DPI.
    /// Dipanggil ulang saat WM_DISPLAYCHANGE atau WM_DPICHANGED.
    /// </summary>
    public static WindowMetrics ComputeTopCenterPill(nint hwnd, int logicalWidth, int logicalHeight, int topOffset = 0)
    {
        var monitor = GetWorkAreaForWindow(hwnd);
        var scale = GetDpiScale(hwnd);

        var width = (int)(logicalWidth * scale);
        var height = (int)(logicalHeight * scale);
        var x = monitor.Left + ((monitor.Width - width) / 2);
        var y = monitor.Top + (int)(topOffset * scale);

        return new WindowMetrics(x, y, width, height, scale);
    }
}
