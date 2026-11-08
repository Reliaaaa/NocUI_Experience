using System.Runtime.InteropServices;
using Microsoft.UI;
using Microsoft.UI.Windowing;

namespace NotchWindows.Interop;

/// <summary>
/// Mengatur gaya window Win32 untuk notch shell: layered + topmost selalu,
/// click-through (WS_EX_TRANSPARENT) di-toggle sesuai state Closed/Open (F-001, F-002).
/// </summary>
public sealed class WindowStyler
{
    private readonly nint _hwnd;
    private bool _isClickThrough;

    public WindowStyler(nint hwnd)
    {
        _hwnd = hwnd;
    }

    /// <summary>Terapkan flag dasar notch shell: layered, tool window (tidak muncul di Alt+Tab/taskbar), no-activate.</summary>
    public void ApplyBaseNotchStyles()
    {
        var ex = NativeMethods.GetWindowLongPtrSafe(_hwnd, NativeMethods.GWL_EXSTYLE);
        var newEx = ex
            | NativeMethods.WS_EX_LAYERED
            | NativeMethods.WS_EX_TOOLWINDOW
            | NativeMethods.WS_EX_NOACTIVATE;
        NativeMethods.SetWindowLongPtrSafe(_hwnd, NativeMethods.GWL_EXSTYLE, newEx);
    }

    /// <summary>
    /// ON saat notch Closed (klik tembus ke app di belakang, hanya area pill kecil yang interaktif
    /// lewat window terpisah). OFF saat notch Open (full interaktif).
    /// </summary>
    public void SetClickThrough(bool enabled)
    {
        if (_isClickThrough == enabled) return;

        var ex = NativeMethods.GetWindowLongPtrSafe(_hwnd, NativeMethods.GWL_EXSTYLE);
        var newEx = enabled
            ? ex | NativeMethods.WS_EX_TRANSPARENT
            : ex & ~(nint)NativeMethods.WS_EX_TRANSPARENT;

        NativeMethods.SetWindowLongPtrSafe(_hwnd, NativeMethods.GWL_EXSTYLE, newEx);
        _isClickThrough = enabled;
    }

    /// <summary>Paksa window tetap di atas semua window lain. Dipanggil ulang tiap ada window lain klaim topmost.</summary>
    public void ReassertTopmost()
    {
        NativeMethods.SetWindowPos(
            _hwnd,
            NativeMethods.HWND_TOPMOST,
            0, 0, 0, 0,
            NativeMethods.SWP_NOMOVE | NativeMethods.SWP_NOSIZE | NativeMethods.SWP_NOACTIVATE);
    }

    /// <summary>Posisikan window notch di koordinat fisik layar yang sudah dihitung (lihat MonitorHelper).</summary>
    public void MoveTo(int x, int y, int width, int height)
    {
        NativeMethods.SetWindowPos(
            _hwnd,
            NativeMethods.HWND_TOPMOST,
            x, y, width, height,
            NativeMethods.SWP_NOACTIVATE | NativeMethods.SWP_SHOWWINDOW);
    }

    /// <summary>Extend frame Mica/acrylic tipis ke tepi pill (efek glass pada tema F-110, dasar sudah disiapkan di MVP).</summary>
    public void ExtendGlassFrame()
    {
        var margins = new NativeMethods.MARGINS { cxLeftWidth = -1, cxRightWidth = -1, cyTopHeight = -1, cyBottomHeight = -1 };
        NativeMethods.DwmExtendFrameIntoClientArea(_hwnd, ref margins);
    }

    /// <summary>
    /// Hapus caption/border dan kunci resize/maximize/minimize lewat AppWindow presenter — dipanggil
    /// sekali saat window notch/dock dibuat, sejalan dengan <see cref="ApplyBaseNotchStyles"/>.
    /// QA fix (bug QA-017, P1): dipindahkan dari App/Interop/Win32Window.cs (yang sudah dihapus — dua
    /// implementasi styling notch-window dikonsolidasikan jadi satu di sini). Lihat 06-qa-report.md §QA-017.
    /// </summary>
    public void ApplyBorderlessPresenter()
    {
        var windowId = Win32Interop.GetWindowIdFromWindow(_hwnd);
        var appWindow = AppWindow.GetFromWindowId(windowId);
        if (appWindow?.Presenter is OverlappedPresenter presenter)
        {
            presenter.IsResizable = false;
            presenter.IsMaximizable = false;
            presenter.IsMinimizable = false;
            presenter.SetBorderAndTitleBar(hasBorder: false, hasTitleBar: false);
        }
    }

    /// <summary>WM_HOTKEY = 0x0312, satu-satunya pesan Win32 mentah yang perlu dicegat dari App saat ini (F-006).</summary>
    public const uint WM_HOTKEY = 0x0312;

    public delegate void WndProcHandler(nint hWnd, uint msg, nint wParam, nint lParam);

    private WndProcHandler? _externalWndProcHook;
    private NativeMethods.WndProcDelegate? _wndProcThunk;
    private nint _previousWndProc;

    /// <summary>
    /// Subclass WndProc window ini (GWLP_WNDPROC) supaya pesan Win32 mentah (mis. WM_HOTKEY) bisa
    /// ditangani dari App tanpa membocorkan NativeMethods (internal ke assembly ini) keluar.
    /// QA fix (bug QA-016, P1): dipakai NotchShellWindow.RegisterGlobalHotkey() untuk F-006 (Alt+N) —
    /// sebelumnya HotkeyManager ada tapi tidak pernah dipanggil di mana pun. Hook selalu dipanggil
    /// dulu lalu WndProc asli tetap diteruskan (hook tidak bisa "menelan" pesan). Lihat 06-qa-report.md §QA-016.
    /// </summary>
    public void InstallWndProcHook(WndProcHandler hook)
    {
        _externalWndProcHook = hook;
        _wndProcThunk = WndProcThunk;
        var ptr = Marshal.GetFunctionPointerForDelegate(_wndProcThunk);
        _previousWndProc = NativeMethods.SetWindowLongPtrSafe(_hwnd, NativeMethods.GWLP_WNDPROC, ptr);
    }

    private nint WndProcThunk(nint hWnd, uint msg, nint wParam, nint lParam)
    {
        _externalWndProcHook?.Invoke(hWnd, msg, wParam, lParam);
        return NativeMethods.CallWindowProc(_previousWndProc, hWnd, msg, wParam, lParam);
    }
}
