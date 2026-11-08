namespace NotchWindows.Interop;

/// <summary>Registrasi global hotkey (default Alt+N, F-006) lewat RegisterHotKey Win32.</summary>
public sealed class HotkeyManager : IDisposable
{
    public const uint MOD_ALT = 0x0001;
    public const uint MOD_CONTROL = 0x0002;
    public const uint MOD_SHIFT = 0x0004;
    public const uint MOD_WIN = 0x0008;

    private readonly nint _hwnd;
    private readonly HashSet<int> _registeredIds = new();

    public HotkeyManager(nint hwnd)
    {
        _hwnd = hwnd;
    }

    /// <summary>Daftarkan hotkey global. id harus unik per app (gunakan konstanta HotkeyIds.*).</summary>
    public bool Register(int id, uint modifiers, uint virtualKey)
    {
        var ok = NativeMethods.RegisterHotKey(_hwnd, id, modifiers, virtualKey);
        if (ok) _registeredIds.Add(id);
        return ok;
    }

    public void Unregister(int id)
    {
        if (!_registeredIds.Remove(id)) return;
        NativeMethods.UnregisterHotKey(_hwnd, id);
    }

    public void Dispose()
    {
        foreach (var id in _registeredIds.ToArray())
        {
            NativeMethods.UnregisterHotKey(_hwnd, id);
        }
        _registeredIds.Clear();
    }
}

/// <summary>ID hotkey terdaftar di app — hindari tabrakan antar fitur.</summary>
public static class HotkeyIds
{
    public const int ToggleNotch = 1; // Alt+N default, F-006
}
