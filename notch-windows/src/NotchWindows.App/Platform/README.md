# Platform (Win32 interop)

Satu-satunya tempat yang boleh berisi `[DllImport]` di seluruh solution (aturan batas modul,
docs/02-architecture.md §6) — memudahkan audit Security Dev.

File yang dibuat di tahap implementasi F-001/F-002/F-003:

- `WindowStyler.cs` — `SetWindowLong`/`GetWindowLong` (WS_EX_LAYERED, WS_EX_TRANSPARENT, WS_EX_TOOLWINDOW),
  `SetWindowPos` (HWND_TOPMOST).
- `HitTestRegion.cs` — strategi click-through (`SetWindowRgn` atau pendekatan 2-window, keputusan
  spike teknis Sprint 1 dicatat di docs/02-architecture.md §3 poin 3).
- `MonitorHelper.cs` — `DisplayArea.GetFromWindowId`, re-center multi-monitor.
- `GlobalHotkey.cs` — `RegisterHotKey`/`UnregisterHotKey` untuk F-006 (Alt+N default).
- `ForegroundWindowWatcher.cs` — polling `GetForegroundWindow`/`GetWindowRect` untuk deteksi
  fullscreen (F-003 auto-hide).
