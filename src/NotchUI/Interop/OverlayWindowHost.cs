using System.ComponentModel;
using System.Runtime.InteropServices;
using Microsoft.UI.Xaml;
using static NotchUI.Interop.NativeMethods;

namespace NotchUI.Interop;

/// <summary>UI-thread HWND adapter. Geometry must be updated on every visual animation frame.</summary>
public sealed class OverlayWindowHost : IDisposable
{
    private readonly nint _hwnd;
    private readonly SubclassProc _callback;
    private double _width, _height, _radius;
    public event EventHandler? SystemStateChanged;
    public event EventHandler? DisplayChanged;
    public OverlayWindowHost(Window window)
    {
        _hwnd = WinRT.Interop.WindowNative.GetWindowHandle(window);
        _callback = WndProc;
        // Keep keyboard activation possible; NOACTIVATE is deliberately not a permanent style.
        SetWindowLongPtr(_hwnd, -16, (nint)(GetWindowLongPtr(_hwnd, -16).ToInt64() & ~0x00CF0000L));
        SetWindowLongPtr(_hwnd, -20, (nint)((GetWindowLongPtr(_hwnd, -20).ToInt64() | 0x00080088L) & ~0x00040000L));
        SetLayeredWindowAttributes(_hwnd, 0, 255, 2);
        if (!SetWindowSubclass(_hwnd, _callback, 1, 0)) throw new Win32Exception(Marshal.GetLastWin32Error());
    }
    public double DpiScale => Math.Max(96, GetDpiForWindow(_hwnd)) / 96d;
    public double PrimaryWidthDip => PrimaryBounds().Right / DpiScale - PrimaryBounds().Left / DpiScale;
    public void SetGeometry(double widthDip, double heightDip, double radiusDip)
    {
        if (!double.IsFinite(widthDip) || !double.IsFinite(heightDip) || !double.IsFinite(radiusDip)) throw new ArgumentOutOfRangeException(nameof(widthDip));
        var bounds = PrimaryBounds();
        var scale = DpiScale;
        _width = Math.Clamp(widthDip * scale, 1, bounds.Right - bounds.Left);
        _height = Math.Clamp(heightDip * scale, 1, bounds.Bottom - bounds.Top);
        _radius = Math.Clamp(radiusDip * scale, 0, Math.Min(_width, _height) / 2);
        int width = (int)Math.Ceiling(_width), height = (int)Math.Ceiling(_height);
        SetWindowPos(_hwnd, -1, bounds.Left + (bounds.Right - bounds.Left - width) / 2, bounds.Top, width, height, 0x0050);
        // Region excludes transparent corners for reliable click-through across processes.
        var region = CreateRoundRectRgn(0, 0, width + 1, height + 1, (int)Math.Round(_radius * 2), (int)Math.Round(_radius * 2));
        if (region != 0 && SetWindowRgn(_hwnd, region, true) == 0) DeleteObject(region);
    }
    private static Rect PrimaryBounds()
    {
        var info = new MonitorInfo { Size = (uint)Marshal.SizeOf<MonitorInfo>() };
        if (!GetMonitorInfo(MonitorFromPoint(default, 1), ref info)) throw new Win32Exception(Marshal.GetLastWin32Error());
        return info.Monitor;
    }
    private nint WndProc(nint hwnd, uint message, nuint wParam, nint lParam, nuint id, nuint data)
    {
        if (message == 0x0084 && GetWindowRect(hwnd, out var rect))
        {
            int screenX = (short)(lParam.ToInt64() & 0xffff), screenY = (short)((lParam.ToInt64() >> 16) & 0xffff);
            double x = screenX - rect.Left, y = screenY - rect.Top;
            if (_radius <= 0) return x >= 0 && y >= 0 && x < _width && y < _height ? 1 : -1;
            double nearestX = Math.Clamp(x, _radius, _width - _radius), nearestY = Math.Clamp(y, _radius, _height - _radius);
            bool inside = x >= 0 && y >= 0 && x < _width && y < _height &&
                ((x - nearestX) * (x - nearestX) + (y - nearestY) * (y - nearestY) <= _radius * _radius);
            return inside ? 1 : -1;
        }
        if (message is 0x001E or 0x0218) SystemStateChanged?.Invoke(this, EventArgs.Empty);
        if (message is 0x007E or 0x02E0) DisplayChanged?.Invoke(this, EventArgs.Empty);
        return DefSubclassProc(hwnd, message, wParam, lParam);
    }
    public void Dispose() => RemoveWindowSubclass(_hwnd, _callback, 1);
}
