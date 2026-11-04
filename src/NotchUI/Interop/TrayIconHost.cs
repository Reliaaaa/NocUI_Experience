using System.ComponentModel;
using System.Runtime.InteropServices;
using static NotchUI.Interop.NativeMethods;

namespace NotchUI.Interop;

public sealed class TrayIconHost : IDisposable
{
    private const uint CallbackMessage = 0x8001;
    private readonly nint _hwnd;
    private readonly Action _showSettings, _exit;
    private readonly SubclassProc _callback;
    private NotifyIconData _icon;
    private bool _disposed;
    private readonly uint _taskbarCreated = RegisterWindowMessage("TaskbarCreated");
    public TrayIconHost(nint hwnd, Action showSettings, Action exit)
    {
        _hwnd = hwnd; _showSettings = showSettings; _exit = exit; _callback = WndProc;
        _icon = new NotifyIconData { Size = (uint)Marshal.SizeOf<NotifyIconData>(), Window = hwnd, Id = 1,
            Flags = 7, Callback = CallbackMessage, Icon = LoadIcon(0, (nint)32512), Tip = "NotchUI — berjalan", Info = "", InfoTitle = "" };
        if (!SetWindowSubclass(hwnd, _callback, 2, 0)) throw new Win32Exception();
        if (!ShellNotifyIcon(0, ref _icon)) { RemoveWindowSubclass(hwnd, _callback, 2); throw new Win32Exception(); }
    }
    private nint WndProc(nint hwnd, uint message, nuint wParam, nint lParam, nuint id, nuint data)
    {
        if (message == _taskbarCreated) ShellNotifyIcon(0, ref _icon);
        if (message == CallbackMessage)
        {
            if ((uint)lParam == 0x0203) _showSettings();
            if ((uint)lParam is 0x0205 or 0x007B) ShowMenu();
            return 0;
        }
        return DefSubclassProc(hwnd, message, wParam, lParam);
    }
    private void ShowMenu()
    {
        var menu = CreatePopupMenu();
        if (menu == 0) return;
        try
        {
            AppendMenu(menu, 0, 1, "Settings"); AppendMenu(menu, 0, 2, "Exit");
            GetCursorPos(out var point); SetForegroundWindow(_hwnd);
            int command = TrackPopupMenu(menu, 0x0102, point.X, point.Y, 0, _hwnd, 0);
            PostMessage(_hwnd, 0, 0, 0);
            if (command == 1) _showSettings(); else if (command == 2) _exit();
        }
        finally { DestroyMenu(menu); }
    }
    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;
        ShellNotifyIcon(2, ref _icon); RemoveWindowSubclass(_hwnd, _callback, 2);
    }
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct NotifyIconData
    {
        public uint Size; public nint Window; public uint Id, Flags, Callback; public nint Icon;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string Tip;
        public uint State, StateMask;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)] public string Info;
        public uint Version;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 64)] public string InfoTitle;
        public uint InfoFlags; public Guid Guid; public nint BalloonIcon;
    }
    [DllImport("shell32.dll", EntryPoint = "Shell_NotifyIconW", CharSet = CharSet.Unicode)][return: MarshalAs(UnmanagedType.Bool)] private static extern bool ShellNotifyIcon(uint message, ref NotifyIconData data);
    [DllImport("user32.dll", EntryPoint = "LoadIconW")] private static extern nint LoadIcon(nint instance, nint resource);
    [DllImport("user32.dll")] private static extern nint CreatePopupMenu();
    [DllImport("user32.dll", EntryPoint = "AppendMenuW", CharSet = CharSet.Unicode)] private static extern bool AppendMenu(nint menu, uint flags, nuint id, string text);
    [DllImport("user32.dll")] private static extern int TrackPopupMenu(nint menu, uint flags, int x, int y, int reserved, nint hwnd, nint rect);
    [DllImport("user32.dll")] private static extern bool DestroyMenu(nint menu);
    [DllImport("user32.dll")] private static extern bool GetCursorPos(out Point point);
    [DllImport("user32.dll")] private static extern bool SetForegroundWindow(nint hwnd);
    [DllImport("user32.dll", EntryPoint = "PostMessageW")] private static extern bool PostMessage(nint hwnd, uint message, nuint wParam, nint lParam);
    [DllImport("user32.dll", EntryPoint = "RegisterWindowMessageW", CharSet = CharSet.Unicode)] private static extern uint RegisterWindowMessage(string message);
}
