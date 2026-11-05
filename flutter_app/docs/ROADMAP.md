# DynamicBar roadmap

What the category leaders ship, what DynamicBar ships, and the order the gap
gets closed in. Researched against NotchNook, Alcove, Boring Notch, Notchy,
Dynamic Notch, Perch (macOS) and Notchify, DynamicWin (Windows).

## The rule everything is judged against

The single most common complaint about this whole category — and about Apple's
own Dynamic Island — is that **it gets in the way more often than it helps**.
Every feature below is therefore designed to be:

- **quiet by default** — nothing animates or expands unless the user asked or
  something genuinely changed;
- **individually switchable** — every page, every gesture, every popup;
- **cheap when idle** — no page that is off holds a watcher, a timer or a
  channel subscription.

A feature that cannot meet those three does not ship.

## Part 1 — the 14 core capabilities

| # | Capability | Why it matters | Windows mechanism |
|---|---|---|---|
| 1 | **Pages with ← →, wheel, swipe** | The backbone. 480px cannot hold seven features at once. | Pure Flutter `PageView` + `Listener` for wheel |
| 2 | **File shelf** | The most-loved feature in every notch app. Drag in, drag out. | `IDropTarget` + `DoDragDrop` (OLE) |
| 3 | **Calendar + agenda** | "What's next" is the most-asked-for glance. | `Windows.ApplicationModel.Appointments` (WinRT) |
| 4 | **Live Activities (ears)** | A timer or download visible *while collapsed*. This is what makes it feel like a Dynamic Island rather than a menu. | Flutter; sources already exist |
| 5 | **Volume / brightness HUD** | Replaces the Windows flyout. Every competitor does it. | `IAudioEndpointVolume` (have) + `WmiMonitorBrightnessMethods` |
| 6 | **Notes / scratchpad** | Cheap to build, used daily. | Local JSON |
| 7 | **Clipboard history** | Opt-in, searchable, pin, paste. | `AddClipboardFormatListener` (have) |
| 8 | **Real Windows notifications** | The headline expectation. Needs package identity. | `UserNotificationListener` after MSIX |
| 9 | **Bluetooth / USB events** | "AirPods connected · 80%". | `DeviceWatcher`, `BluetoothLEDevice`, `WM_DEVICECHANGE` |
| 10 | **Weather** | Expected; must stay opt-in (first network call in the app). | Open-Meteo, no key |
| 11 | **Music polish** | Artwork tint, drag-to-seek, output picker. | SMTC (have) + `IMMDeviceEnumerator` (have) |
| 12 | **Hot-edge + gestures** | Peek on approach, wheel on pill = volume. | `WH_MOUSE_LL` (have, extend) |
| 13 | **Battery moments** | Plug in → "Charging · 3h 10m". | `GetSystemPowerStatus` (have) |
| 14 | **Focus / Do Not Disturb** | Pomodoro + respect Focus Assist. | `SHQueryUserNotificationState` (have) |

## Part 2 — eight more, from the research

| # | Capability | Source of the idea |
|---|---|---|
| 15 | **Quick launcher (⇧+Win)** — search apps, files, settings, run actions | DynamicWin's quick search |
| 16 | **Shortcuts / pinned launchers** — pin any app or file to the island | DynamicWin's shortcuts widget |
| 17 | **Configurable gestures** — tap, double-tap, long-press, wheel, each individually switchable | Boring Notch, Notchy |
| 18 | **First-run onboarding** — nobody discovers a hidden overlay on their own | Universal gap; the top usability failure |
| 19 | **Auto-collapse after inactivity** — "open on hover, close when done" | Notchy |
| 20 | **Per-app exclusions** — never appear over these apps | Directly answers the #1 complaint |
| 21 | **Window snapping helper** — drag a window to the island for snap zones | Notchy |
| 22 | **Custom widget slot** — a local JSON/script feeds a user-defined tile | Notchy's AI-usage widget, generalised |

## Build order

| Phase | Contents | State |
|---|---|---|
| **A** | Pager + navigation, Live Activity ears, collapsed face rebuild, auto-collapse, gestures, page settings, first-run welcome | **done** |
| **B** | File shelf: OLE drop target, drag-out, screenshot capture, shelf page | planned |
| **C** | Calendar + agenda, Notes page, Clipboard history page | planned |
| **D** | Music polish, Bluetooth/USB, battery moments, weather, brightness HUD | planned |
| **E** | Quick launcher, shortcuts, per-app exclusions, wallpaper accent, per-monitor islands | planned |
| **F** | MSIX packaging → real notification mirroring; window snapping | planned |

## Part 3 — eight more, from the second research pass

Sources: Dynamic Notch (16 modules), NotchNest, Atoll, Perch, Notchify.

| # | Capability | Note |
|---|---|---|
| 23 | **Auto-hide with proximity reveal** | The pill disappears entirely and returns when the cursor approaches the top edge. The single most requested behaviour for people who find an always-visible overlay intrusive. |
| 24 | **Quick toggles** | Mute, Do Not Disturb, and one-click access to the Windows panels behind them. Notchify ships these as its most-used widgets. |
| 25 | **Live throughput graphs** | Not just a number: a rolling line for processor, memory and network. Notchify makes these its headline. |
| 26 | **App / link shortcuts** | Pin YouTube, a music app, a folder, a settings panel. DynamicWin's shortcuts widget, generalised to URLs. |
| 27 | **Colour picker** | HEX / RGB / HSL with a contrast ratio. Shipped by Dynamic Notch and Atoll. |
| 28 | **Camera mirror** | One-click webcam preview before a call. Boring Notch, NotchNest and Dynamic Notch all ship it. |
| 29 | **Join meeting** | A button on a calendar event that opens the Teams / Zoom / Meet link. |
| 30 | **A measured idle budget** | Notchify shipped at 55% idle CPU and had to fix it publicly. Any watcher added here is event-driven and does nothing but compare a point to a rectangle. |

## Build order (revised)

| Phase | Contents | State |
|---|---|---|
| **A** | Pager, Live Activity ears, auto-collapse, gestures, first-run banner | **done** |
| **B** | Auto-hide + proximity reveal, sparklines (CPU/RAM/network), Calendar page with notes and reminders, Shortcuts page, quick toggles, the shelf, motion system | **done** |
| **C** | Shelf: OLE drop target **done**; drag-out and screenshot-to-slot remain | in progress |
| **D** | Notes page, clipboard history page, colour picker, camera mirror | planned |
| **E** | Bluetooth/USB, battery moments, weather, brightness HUD, quick launcher | planned |
| **F** | MSIX → real notifications + the machine's own calendar + Join meeting; per-app exclusions; window snapping | planned |

## Phase B, as shipped

- **Auto-hide with proximity reveal.** The pill withdraws into the bezel after
  a configurable pause and comes back as the cursor approaches the top of the
  screen. One `WH_MOUSE_LL` hook, held only while the feature is on, doing
  nothing but comparing a point to a rectangle; 26px of hysteresis natively,
  and a 150ms open delay plus a 220ms cancel grace in Dart, so a pointer
  crossing the top of the screen on its way somewhere else wakes nothing.
- **Live graphs.** Processor, memory and network throughput as rolling
  Catmull-Rom lines over a minute, sampled once a second and only while the
  System page is on screen. Network bytes come from `GetIfTable2Ex`, summed
  across operational non-loopback adapters.
- **Calendar with notes and reminders.** A month grid and a day panel. A note
  with a time on it is a reminder; one without is a note. One timer for the
  next due entry, a ten-minute grace for anything missed while the machine
  slept, and everything in `calendar.json`.
- **Shortcuts.** Forty-odd fixed targets - web addresses, known folders,
  executables and `ms-settings:` panels - opened with one `ShellExecuteW`.
  Pinning happens in the page itself. Three quick toggles sit above the grid:
  mute, quiet, auto-hide.
- **The shelf.** Two image slots and a note. Images arrive from the clipboard
  or from a drag straight onto the island - an `IDropTarget` on the stage
  window, accepting both dropped files and the raw bitmap a browser hands over
  when an image is dragged out of a page - and are stored as PNG under
  `%LOCALAPPDATA%`. A drop needs no decision: it takes the first free slot, and
  when both are full it replaces the older one. They can be copied back to the
  clipboard, opened, replaced or cleared.
- **A motion system.** Written down in `docs/MOTION.md`: arrival springs,
  departure does not, shape leads content, light lags mass. The clock rolls
  only the digits that changed.

## Page model

The expanded island is a horizontal pager. Pages are:

```
Now · Calendar · Shortcuts · Media · Shelf · Timers · System
```

The order is not arbitrary. The three pages one arrow key from the clock are
the three a person reaches for without thinking - what is on today, and what
they want to open. Everything that reacts to the machine rather than to the
user sits behind them.

- The router picks the **opening** page from context (music playing → Media),
  the user moves freely from there.
- A page whose module is off is not in the pager at all.
- Transient presentations (a notification, a recording indicator) are *not*
  pages: they take the island over briefly and hand it back.
- Settings remains a separate, larger stage.

## Collapsed model

```
[ leading activity ] [ clock ] [ trailing activity ]
```

Up to two Live Activities flank the clock. The pill grows by a fixed step per
activity so the width stays predictable for the spring engine. With nothing
happening it is just the clock, which is the resting state the app is designed
around.

## Phase A, as shipped

- **Pager.** `IslandPage` + `IslandController.pages`. Four pages live: Now,
  Media, Timers, System. Navigation by arrow keys, scroll wheel, clickable
  dots, and chevrons that fade in under the pointer. The island opens on the
  page that matches the moment (music playing → Media) and the user moves from
  there.
- **One expanded size.** Every page shares `IslandMetrics.pagerSize`; a pager
  whose viewport resized as you swiped would make the shape the loudest thing
  on screen.
- **Live Activity ears.** `ActivityCenter` derives a short ordered list from the
  modules that already own the state. The collapsed pill shows up to two beside
  the clock and widens by a fixed step for each, so the spring always has a
  definite target.
- **Auto-collapse.** Configurable, suspended while the pointer is on the island.
- **Gestures.** Wheel over the closed pill changes volume; hover-to-peek is a
  switch.
- **First run.** A one-time banner naming the three ways to navigate.

### Two things worth remembering

`Shortcuts` cannot live below the focused node - key events travel up from the
focus node, not down - so page navigation is handled in the island's own
`Focus.onKeyEvent` alongside Escape.

CPU load is a delta between two samples, so the first reading carries no
information. The native side publishes memory immediately (it is valid at once)
and flags CPU as invalid until a second sample, which the page renders as
"measuring…" rather than a confident 0%.
