# Architecture

## Layers

```
                       ┌────────────────────────────┐
   Windows  ─────────► │  windows/dynamicbar/*.cpp  │  Win32 / WinRT
                       │  one static library        │
                       └─────────────┬──────────────┘
                                     │ method + event channels
                       ┌─────────────▼──────────────┐
                       │  lib/native/*_bridge.dart  │  typed, failure-tolerant
                       └─────────────┬──────────────┘
                                     │
      ┌──────────────────────────────┼───────────────────────────────┐
      │                              │                               │
┌─────▼──────┐              ┌────────▼────────┐             ┌────────▼───────┐
│ lib/modules│              │ lib/island/state│             │ lib/settings   │
│ media,     │─ facts ─────►│ controller +    │◄─ document ─│ store +        │
│ downloads, │              │ router          │             │ controller     │
│ timers, …  │              └────────┬────────┘             └────────────────┘
└────────────┘                       │ intent + mode
                              ┌──────▼───────┐
                              │ lib/island/  │  springs, faces, choreography
                              │ view         │
                              └──────┬───────┘
                                     │ tokens only
                              ┌──────▼───────┐
                              │ lib/design   │
                              └──────────────┘
```

Dependencies point one way. A module never reaches into the view; the view never
opens a platform channel; the design system knows nothing about any of them.
`lib/app/island_coordinator.dart` is the single place where native events turn
into application decisions.

## The stage, and why it never moves

The obvious way to build an island is to resize its window as it grows. That is
also the wrong way: every frame becomes a `SetWindowPos`, the compositor and the
Flutter raster thread disagree about who is authoritative, and the shape tears at
its edges.

Instead a fixed **stage** window is placed at the top of the chosen monitor,
sized once from the island's declared maximum
(`IslandMetrics.stageSize`). It is frameless, always-on-top, tool-styled (no
taskbar button, no Alt-Tab entry) and composites with per-pixel alpha, so it is
invisible except where the island is drawn. All morphing happens inside Flutter.

The window is repositioned only on:

- a monitor, DPI or work-area change,
- a settings change that affects placement,
- entering or leaving the larger settings stage.

### Click-through

An invisible window covering the top of the screen must not swallow clicks.
`WM_NCHITTEST` returns `HTTRANSPARENT` everywhere except a rectangle the Dart
side publishes. That rectangle is pushed on a rule that matters:

> **grow immediately, shrink late.**

When a transition starts, the union of the current and target shapes is
published, so the region is always at least as large as the island. It shrinks
back only once the springs have settled. The pointer is therefore never handed
back to the desktop mid-animation. Two channel calls per interaction, none per
frame.

### Focus

Hover never activates the window. `WM_MOUSEACTIVATE` returns `MA_NOACTIVATE`
while the island is closed, so the application the user is working in keeps
focus. Clicking to open sets `focusable`, takes focus, and enables Escape and
keyboard navigation; `WM_ACTIVATE(WA_INACTIVE)` then gives "click outside to
close" for free.

## State

Two ideas, deliberately kept apart:

- **`IslandIntent`** — what the island has been asked to be: `hidden`,
  `collapsed`, `expanded`. A decision.
- **`IslandPhase`** — what is actually on screen: `hidden`, `collapsed`,
  `expanding`, `expanded`, `interactive`, `collapsing`. An observation, derived
  from the animation's own progress and velocity.

Because they are separate, a collapse requested halfway through an expansion is
an ordinary event rather than a special case. `IslandController.reportProgress`
is called every frame but notifies only when the derived phase changes, so a
running animation does not rebuild the rest of the application with it.

`PresentationRouter` chooses *what* is shown. Its ordering is fixed and not
configurable:

1. settings, when the user opened it
2. a live notification
3. an active capture (microphone or camera)
4. a running download
5. playing media
6. a running timer
7. paused media, then idle

Ambient priority is ordered by how quickly the information goes stale, not by how
interesting it is.

## Motion

`SpringGroup` (`lib/design/motion/spring_group.dart`) integrates every animated
dimension — width, height, corner radius, expansion, shadow, glow, edge light —
on a **single ticker**, with semi-implicit Euler at a fixed 1/480 s sub-step.

Three properties come out of that choice:

- **Interruptible.** Retargeting keeps the current velocity, so a reversal
  continues from the motion already in flight instead of snapping to a new curve.
- **Cheap.** One ticker and one notification per frame for all of it.
- **Idle-free.** The ticker stops the moment every track is at rest. A still
  island costs nothing, which is what makes running all day reasonable.

Non-shape animation — opacity, colour, hover tint — uses durations and curves
from `db_motion.dart`. A spring adds nothing there and costs a simulation.

`MotionProfile.intensity` scales the whole system, and at zero it lands
everything immediately: reduced motion means less motion, never less function.

The spring vocabulary itself, and the reasoning behind every number in it,
lives in `docs/MOTION.md`. The rule worth repeating here is the asymmetry:
opening uses `DbSpring.arrival` and overshoots very slightly, closing uses
`DbSpring.departure` and is critically damped. A shape that bounces on its way
out reads as the interface arguing with the user who just dismissed it.

### Content choreography

Both faces of the island are laid out at their **own natural size** and clipped
by the shell, never at the animating size. Text never re-wraps and icons never
jump; the only per-frame work is a clip and two opacity layers.

`IslandExpansionScope` publishes the live expansion value down the tree, and
`Reveal` uses it to stagger content in. The choreography therefore rides the
same spring as the shape, rather than a second controller that would have to be
kept in step with it.

### A Flutter footnote that cost an evening

`BoxDecoration` ignores `color` when `gradient` is set. The island's glass is a
base colour plus a faint vertical tint; painted as `color` + `gradient` the
base never appeared and every surface in the product was a near-invisible
gradient over the desktop. The tint is now blended into the gradient stops
(`Color.alphaBlend(tint, base)`). If a surface ever looks "washed out", check
this first.

## Native library

`windows/dynamicbar/` builds as `dynamicbar_native`, a static library with its
own compile settings, linked into the Flutter runner. It mirrors Flutter's
`APPLY_STANDARD_SETTINGS` (C++17, `/W4`, `/EHsc`, `_HAS_EXCEPTIONS=0`) so the STL
ABI matches the C++ client wrapper, but does not enable warnings-as-errors: a new
Windows SDK should not break the build of a shipped application.

```
core/      logging, main-thread dispatcher, EncodableValue helpers
window/    the stage window, transparency, the Dart-facing channel
display/   monitor enumeration
tray/      notification icon and menu
media/     GlobalSystemMediaTransportControlsSessionManager
clipboard/ AddClipboardFormatListener
downloads/ ReadDirectoryChangesW
system/    power, volume, capability consent store, network, CPU/memory
hotkey/    RegisterHotKey
startup/   the per-user Run key
app/       composition root
```

Native watchers signal from arbitrary threads — registry notification threads,
directory-change threads, WinRT completion handlers, audio callbacks. Every one
of them hops through `MainThreadDispatcher` before touching a channel, because a
Flutter channel may only be used from the thread that owns the engine.

## Error handling

The island is expected to run for days. Every native call goes through
`NativeChannel.invoke`, which turns a missing or failing platform implementation
into a logged warning and a null result. A module whose Windows API is
unavailable reports that it has nothing, and the rest of the application carries
on.

`bootstrap` installs `FlutterError.onError`, `PlatformDispatcher.onError` and a
guarded zone, all of which log rather than terminate.

## Testing

Unit tests cover the parts where a mistake is invisible until it is embarrassing:
the state machine's phase derivation, geometry and the stage-size contract,
settings serialisation including corrupt and out-of-range input, notification
priority and queueing, timer arithmetic across pause and resume, media position
interpolation, shortcut parsing, and the sensor payload parsers.

Windows integration itself is verified by building and running: a unit test can
assert that a registry write was requested, but not that Windows honoured it.
