# Windows integration

Every Windows API DynamicBar uses, why it was chosen, and what it cannot do.
Where a capability has a real limit, it is written down here rather than papered
over in the UI.

## Window and composition

| Need | API | Notes |
|---|---|---|
| Overlay window | `CreateWindowEx` with `WS_POPUP`, `WS_EX_TOPMOST | WS_EX_TOOLWINDOW` | Tool-style: no taskbar button, no Alt-Tab entry. |
| Per-pixel alpha | `DwmExtendFrameIntoClientArea` with margins of -1 (the whole client area becomes "frame") | The only mechanism that composited correctly on Windows 11 25H2. See below for the two that did not. |
| Click-through | `WS_EX_TRANSPARENT`, toggled from the mouse watch as the pointer crosses the island, with `WM_NCHITTEST` → `HTTRANSPARENT` behind it | `HTTRANSPARENT` alone is documented to pass the point only to windows **of the same thread**: the application under the stage is always another process, so its clicks were swallowed by a 750x450 dead zone. See below. |
| Focus policy | `WM_MOUSEACTIVATE`, `WS_EX_NOACTIVATE`, `WM_ACTIVATE` | Hover never steals focus; clicking to open does. |
| DPI | PerMonitorV2 (runner manifest), `WM_DPICHANGED`, `FlutterDesktopGetDpiForMonitor` | The suggested rectangle from `WM_DPICHANGED` is ignored: the stage owns its own placement and recomputes it. |
| Monitors | `EnumDisplayMonitors`, `GetMonitorInfoW`, `WM_DISPLAYCHANGE` | Identified by device name (`\\.\DISPLAY1`). A configured monitor that disappears falls back to the primary. |
| Work area | `SPI_SETWORKAREA` via `WM_SETTINGCHANGE` | Optional anchor, for taskbars docked at the top. |
| Sleep / wake | `WM_POWERBROADCAST` | Re-asserts topmost and re-places the stage. |
| Lock / unlock | `WTSRegisterSessionNotification` | Overlays are commonly demoted across a lock; topmost is re-asserted. |
| Explorer restart | `RegisterWindowMessage("TaskbarCreated")` | The tray icon is re-added and the stage re-asserted. |

### What was tried for transparency, and what happened

Verified by launching the release build and sampling the screen, not by
reading documentation:

| Mechanism | Result on Windows 11 25H2 |
|---|---|
| `DwmEnableBlurBehindWindow` with an empty blur region | The empty region is ignored; the **entire** stage is frosted into a pale rectangle. |
| `SetWindowCompositionAttribute(ACCENT_ENABLE_TRANSPARENTGRADIENT, colour 0x00000000)` | The transparent colour is not honoured; the stage fills with an opaque light tint and Flutter's own pixels are heavily washed out. |
| `DwmExtendFrameIntoClientArea({-1,-1,-1,-1})` | Correct. Alpha-zero pixels show the desktop, partial alpha blends, opaque pixels are opaque. No blur. |

## Click-through, and why `HTTRANSPARENT` is not enough

The stage is 752x456 logical pixels and almost all of it is empty: the island
occupies the top-centre and the rest exists only to hold shadow and glow. That
empty area must belong to whatever is behind it.

Answering `WM_NCHITTEST` with `HTTRANSPARENT` reads like the way to say so, and
it is what the stage did. Its documented behaviour is narrower than it looks -
the point is handed on to *windows of the same thread*. The window under the
stage belongs to another process, so nothing received those clicks at all: a
750x450 rectangle in the middle of the top of the screen quietly ate every
click that landed in it for as long as the island was on screen.

The flag the system's own hit test honours is `WS_EX_TRANSPARENT`, which is a
property of the window rather than an answer to a message, so it cannot be
per-region. The stage therefore carries it whenever the pointer is not over the
island, and drops it the moment the pointer arrives:

- the position comes from the existing `WH_MOUSE_LL` watch, which already keeps
  the island's rectangle in screen pixels for the outside-click feature. The
  watch now also runs while the stage is merely visible;
- the hook may not touch the window - `SetWindowLongPtr` sends
  `WM_STYLECHANGING` to the owning thread, and a hook that waits on the UI
  thread stops the mouse for the whole session - so it posts, and the style is
  written by the thread that owns the window;
- the pointer is re-read directly (`GetCursorPos`) whenever the island's
  rectangle changes, because the island can arrive, grow or leave from under a
  cursor that never moved and a movement hook cannot know that;
- the state is never re-decided while a button is down, so a drag that wanders
  off the island keeps the rest of its gesture;
- if the hook fails to install, the stage stays opaque rather than permanently
  click-through: an island that cannot be clicked is a far worse failure than
  one that is greedy with the pointer.

`HTTRANSPARENT` is still answered underneath all of this. It costs nothing and
covers the frames between the pointer crossing the boundary and the style
being applied.

`DYNAMICBAR_ALPHA=accent|glass|both|none` overrides the mechanism at launch and
`DYNAMICBAR_OPAQUE=1` skips it entirely, so this can be re-checked on another
machine without a rebuild.

### The surface must not be resized before its first frame

Creating the Flutter view and then resizing the window before Flutter has
presented a frame left the engine presenting a **stale, stretched** surface:
the island appeared far from where the render tree placed it, squashed
non-uniformly, and stayed that way. Resizes *after* the first frame are fine -
the settings panel grows and shrinks the stage without trouble.

So `IslandWindow` parks any placement request that arrives before the engine's
first-frame callback (`FlutterEngine::SetNextFrameCallback`) and applies it from
that hook. The stage is also created at the size Dart will ask for at the
default island scale (`StagePlacement` defaults match
`IslandMetrics.stageSize()`), so the common launch needs no resize at all; a
non-default island scale is what exercises the deferral. `SetWindowPos` is
never called with `SWP_NOREDRAW`.

### Known limitation: no true blur behind the island

Windows can blur what is behind a window (`DWMWA_SYSTEMBACKDROP_TYPE`, acrylic,
mica), but only for the whole window rectangle. The island is a shape inside a
much larger transparent stage, so a system backdrop would tint the entire stage.

Clipping the window to the island shape with `SetWindowRgn` would work, but a
window region is hard-edged: the rounded corners would be aliased, and the soft
shadow would be cut off. For a surface whose whole point is its edge quality,
that is not a trade worth making.

So the glass is painted in Flutter — a deep charcoal surface with a translucency
control, an edge light and a single lower-lip highlight. This is also what the
surface it is modelled on actually looks like: the real Dynamic Island is
essentially opaque black. The **Translucency** setting controls how much desktop
shows through.

## Media

`Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager`, through
the WinRT ABI headers with WRL smart pointers.

- `RequestAsync` → manager; `CurrentSessionChanged` and `SessionsChanged` keep
  the current session up to date.
- Per session: `MediaPropertiesChanged`, `PlaybackInfoChanged`,
  `TimelinePropertiesChanged`.
- Controls: `TryPlayAsync`, `TryPauseAsync`, `TryTogglePlayPauseAsync`,
  `TrySkipNextAsync`, `TrySkipPreviousAsync`, `TryChangePlaybackPositionAsync`.
- Artwork: `IRandomAccessStreamReference::OpenReadAsync` → `DataReader`, capped
  at 4 MiB.

**Why the ABI and not C++/WinRT:** the projection requires exceptions, and the
Flutter runner compiles with `_HAS_EXCEPTIONS=0`. Mixing the two would put two
standard library configurations in one binary.

**Position between events.** The session reports a position together with the
time it was measured (`LastUpdatedTime`). Dart projects forward from that
snapshot, so the progress bar moves smoothly with no polling and no platform
calls. See `MediaSession.positionAt`.

**Limits.** Not every player publishes to SMTC, and those that do vary in what
they fill in: some omit album art, some omit the timeline. Missing fields are
shown as missing rather than invented. `SourceAppUserModelId` is a raw
identifier, not a friendly name; the executable stem is the closest available.

## Notifications

DynamicBar shows its **own** notifications on the island. It does not read the
Windows notification centre.

**Why not.** `Windows.UI.Notifications.Management.UserNotificationListener` is
the API for reading other applications' toasts, and it requires package identity
plus a user consent prompt. DynamicBar is an unpackaged Win32 application, so the
listener is unavailable. Shipping a fake would be worse than not shipping it.

`Shell_NotifyIcon` with `NIF_INFO` is available and wired up
(`TrayBridge.showBalloon`) for messages that should survive the island being
hidden.

Adding an MSIX identity later would make `UserNotificationListener` reachable;
the notification centre is already an internal abstraction, so a new source can
be added without touching the presentation.

## Downloads

There is no "current downloads" API on Windows: downloads belong to whichever
browser started them. What they share is that bytes land in the Downloads folder
and that in-progress files carry a partial extension.

`ReadDirectoryChangesW` on `FOLDERID_Downloads` (event-driven, overlapped, on a
worker thread) reconstructs the lifecycle: a `.crdownload`, `.part`, `.download`,
`.partial`, `.opdownload`, `.tmp`, `.!ut` or `.aria2` file appearing starts a
transfer; growth reports a rate; a rename to a final name completes it; a
disappearance cancels it.

**Limit: no percentage.** A partial file does not record its final size anywhere
the file system can see. Transferred bytes and rate are measured directly and are
real; a percentage would be a guess, so the UI shows an indeterminate rail
instead. `DownloadActivity.progress` returns null, and the design accommodates
that rather than filling it in.

Files that arrive already complete (small downloads, copies) are reported as
finished transfers, which is what they look like from the file system.

## Clipboard

`AddClipboardFormatListener` → `WM_CLIPBOARDUPDATE`. Event-driven, no polling,
and the clipboard is never read speculatively.

By default only the *shape* is reported: kind (text, image, files, other), length
for text, and the owning process name via `GetClipboardOwner` →
`QueryFullProcessImageName`. Content is read only when the user turns on text
previews, and then only the first line, truncated.

This module is off by default. Passwords, tokens and card numbers pass through
the clipboard constantly, and treating them as interesting data would be a
serious mistake.

## System sensors

| Reading | API | Event-driven |
|---|---|---|
| Battery, AC, saver | `GetSystemPowerStatus` + `RegisterPowerSettingNotification` | yes |
| Volume, mute | `IAudioEndpointVolume` + `IAudioEndpointVolumeCallback` | yes |
| Output device change | `IMMNotificationClient::OnDefaultDeviceChanged` | yes |
| Microphone / camera in use | `RegNotifyChangeKeyValue` on the capability consent store | yes |
| Network | `NotifyIpInterfaceChange`, then WLAN + `INetworkListManager` | yes |
| CPU, memory | `GetSystemTimes`, `GlobalMemoryStatusEx` | **no — polled** |

**The one poller.** Windows exposes no notification for CPU or memory load. That
sampler runs at 2 s, and only between `setPerformanceEnabled(true)` and `false`,
which the UI ties to a view that actually shows the numbers. A tray utility has
no business waking the CPU twice a second to report on the CPU.

**Microphone and camera** are read from
`HKCU\…\CapabilityAccessManager\ConsentStore\{microphone,webcam}` (and the
machine hive), where a `LastUsedTimeStop` of zero means a capture is in progress.
This is the same source the Windows privacy indicator uses, so the two agree.
Packaged applications appear directly; desktop applications appear under
`NonPackaged`.

**Power setting GUIDs** are written out as constants rather than taken from a
header, because which SDK library exports them has moved between versions and a
link error is a poor trade for three constants.

## Presentation state

`SHQueryUserNotificationState`, re-queried on `EVENT_SYSTEM_FOREGROUND` via
`SetWinEventHook(WINEVENT_OUTOFCONTEXT)` — no DLL is injected into any other
process. A state other than "accepts notifications" (exclusive full-screen D3D,
presentation mode, quiet hours, busy) hides the island until it clears.

## Stepping aside

Two more signals decide when the island should not be on screen:

| Signal | API | Behaviour |
|---|---|---|
| A maximised or full-screen app in front | `SetWinEventHook` for `EVENT_SYSTEM_FOREGROUND`, `MINIMIZESTART/END`, `MOVESIZEEND` and `EVENT_OBJECT_LOCATIONCHANGE` (top-level windows only), then `IsZoomed` / monitor-rect comparison on `GetForegroundWindow` | Island hides; returns when that window is minimised, restored or loses the foreground. Shell windows (desktop, taskbar) never count. Off via **Hide behind maximised apps**. |
| A click anywhere outside the open island | `WH_MOUSE_LL` | Collapses the island. Does not rely on our window holding focus, which Windows does not always grant an overlay. |
| The pointer approaching the top of the screen | The same `WH_MOUSE_LL` hook | Brings a hidden island back. |

### The low level mouse hook runs on a thread of its own

This one is worth stating on its own, because getting it wrong takes the whole
desktop down with it.

A `WH_MOUSE_LL` callback is delivered to **the thread that installed the hook**,
and Windows holds every mouse event in the session until that thread answers or
`LowLevelHooksTimeout` (300ms by default) expires. Installed on the UI thread,
the hook therefore ties the responsiveness of the entire desktop to Flutter's
frame loop: while the island was animating, clicking and scrolling stopped
working *everywhere*, until it went away again.

So the hook lives on a dedicated thread whose only job is to own it and pump
messages, and the hook procedure is written to be incapable of being slow:

- it compares the cursor against **pre-computed screen rectangles**, refreshed
  on the UI thread whenever the stage moves, the DPI changes or the interactive
  region is republished — no `ScreenToClient`, no DPI arithmetic, no window
  handles;
- the rectangles are read under an `SRWLOCK` held shared for a few instructions;
- the only thing it ever does with a result is `PostMessageW`, which is
  asynchronous, so the watch thread never waits on the UI thread either.

Measured: about **0.5ms of added latency per mouse event**, unchanged while the
island is opening, open, or animating.

If a future change needs more information inside that callback, the answer is
to precompute it, not to look it up there.

## Shortcuts

`RegisterHotKey` with `MOD_NOREPEAT`, on a dedicated message window.

Chosen over a low-level keyboard hook deliberately: it is cooperative, it cannot
observe anything the user types, and Windows arbitrates conflicts rather than the
first application to install a hook winning.

**Limit:** registration can fail when another application already owns the
combination. That failure is reported back to Dart and shown in Shortcuts
settings, rather than leaving a binding that silently does nothing.

## Startup

`HKCU\Software\Microsoft\Windows\CurrentVersion\Run`, value `DynamicBar`,
command `"<exe>" --autostart`.

Chosen over a scheduled task or a service: no elevation, and it appears in Task
Manager's Startup tab where a user would look for it and can disable it without
the application's cooperation.

The registered command is verified on every launch and rewritten if it points
somewhere else, which is what happens when the application is moved or
reinstalled. The `--autostart` flag is what makes the start delay apply only to
launches Windows made.

## Tray

`Shell_NotifyIcon` with `NOTIFYICON_VERSION_4`, on a hidden window of its own
rather than the stage. Popup menus need an owner that can be brought to the
foreground, and the stage deliberately refuses activation while collapsed;
keeping them apart avoids fighting over that policy.

`TaskbarCreated` is handled: when Explorer restarts it takes every notification
icon with it, and the icon is re-added.

## Single instance

A named mutex (`Local\DynamicBar.SingleInstance`). A second launch broadcasts a
registered window message and exits; the running instance shows itself. Two
copies would fight over the same screen real estate and the same tray icon.

## Not implemented, and why

| Capability | Reason |
|---|---|
| Reading Windows notifications | `UserNotificationListener` requires package identity. See above. |
| True blur behind the island | Would require a hard-edged window region. See above. |
| Download percentages | The total size is not knowable from a partial file. |
| Bluetooth radio state | `Windows.Devices.Radios` would provide it; it was judged low value for the surface area and left out rather than stubbed. |
| Brightness control | Reliable only on internal panels, and misleading where unsupported. |
