# DynamicBar motion

The design language, written down so it can be checked rather than argued
about. Researched against Apple's Dynamic Island, NotchNook, NotchKit's
published motion specification and Apple's own spring guidance (WWDC23,
"Animate with springs").

## The five rules

**1. One shape that morphs, never two that trade places.**
The collapsed pill and the expanded panel are the same rectangle at different
sizes. Nothing cross-dissolves between them, because a cross-dissolve says
"different object" and the whole illusion depends on saying "same object".

**2. Arrival springs, departure does not.**
Opening overshoots very slightly - that reads as something physical coming to
rest. Closing is monotonic. A shape that bounces on its way out reads as the
interface arguing with the user who just dismissed it. This asymmetry is the
single most important rule here.

**3. Shape leads, content follows.**
Content fades in *after* the shape has started to move and finishes before the
shape does. Text that resizes with its container looks squeezed; text that
appears into a container that is already most of the way there looks placed.
On the way out the order reverses and the timing shortens: content leaves
first, then the shape closes behind it.

**4. Light lags mass.**
Shadow, glow and the edge highlight ride a softer, slower spring than the
geometry. In the world, a shadow does not keep up with the thing casting it.

**5. Reduced motion means less motion, never less function.**
At intensity 0 every spring lands immediately and every transition becomes a
cut. Nothing becomes unreachable, nothing is left mid-animation.

## The springs

Stated as *response* (the spring's natural period - roughly how long the bulk
of the travel takes) and *damping ratio*, which is how Apple's API talks about
them, then converted to stiffness for `SpringDescription.withDampingRatio` at
mass 1 with `k = (2π / response)²`.

| Name | Used for | Response | Damping | Stiffness |
|---|---|---|---|---|
| `arrival` | expanding, dropping out of the bezel | 0.52s | 0.80 | 146 |
| `departure` | collapsing, withdrawing into the bezel | 0.44s | 1.00 | 204 |
| `peek` | the pill growing under the pointer | 0.34s | 0.55 | 341 |
| `reveal` | dropping out of the bezel when the pointer arrives | 0.34s | 0.78 | 341 |
| `withdraw` | going back into the bezel when it leaves | 0.26s | 1.00 | 584 |
| `atmosphere` | shadow, glow, edge light | 0.70s | 0.95 | 81 |
| `precise` | meters and progress, which must not overshoot | 0.36s | 1.00 | 300 |

These are roughly a third slower than the values this application shipped with
in Phase A, deliberately: the point of an island is that you *watch* it change
shape. A 0.2s morph is technically smoother and emotionally nothing.

The `Motion` slider in Settings scales all of it. 100% is the timing above;
below that everything gets stiffer and shorter, above it slower and more
expressive, to 140%.

## Choreography

| Beat | Timing | Note |
|---|---|---|
| Shape starts | 0 | |
| Content begins to appear | +90ms | The morph is under way before text exists |
| Content finished | +350ms | Inside the shape's own settle |
| Stagger between items | 55ms | Eight items is the practical limit |
| Content leaves | 0, over 140ms | Before the shape, faster than it arrived |

## What animates where

**The island shell** (`island_stage.dart`) runs five spring tracks on one
ticker: width, height, corner radius, expansion and shadow, plus glow and edge
highlight on the atmosphere spring. Width and height take `arrival` or
`departure` depending on which way they are going; the radius follows one step
softer so the corners round out slightly behind the size.

**Pages** cross under each other with a parallax: the page being left drifts
34px against the swipe, loses 6% scale and 55% opacity. Small numbers on
purpose - at 486px wide, anything more turns a page change into an event.

**The clock** rolls. A digit that changes slides up and out while the new one
slides in beneath it, on the arrival spring; digits that did not change do not
move. This is the one place the application animates on its own without being
asked, which is why it is confined to a single digit changing once a minute.

**The calendar** slides the whole month grid horizontally when the month
changes, and the selected day's fill springs into place. Days that were already
on screen do not re-animate.

**Show and hide** are the *fastest* things in the application, not the slowest.
They answer a gesture the user is making right now, so they get `reveal` and
`withdraw` rather than the slower `arrival` and `departure` that opening and
closing a panel use. Returning still has a little life in it and leaving has
none.

## Hover filtering

A pointer crossing the top of the screen on its way somewhere else must not
wake anything up.

- **Open delay 70ms.** The cursor has to still be in the reveal zone after
  this before the island comes back. Long enough to reject a pointer passing
  through, short enough that arriving feels instant.
- **Cancel grace 180ms.** Leaving the zone does not immediately restart the
  withdraw countdown, so jitter at the boundary is tolerated.
- **26px of hysteresis**, applied natively: once the pointer is inside, the
  zone it has to leave is bigger than the one it entered.

All three exist because the failure they prevent - an island flickering under a
resting hand - is worse than the feature is good.

### Two clocks, not one

Withdrawing has two different reasons and therefore two different delays.

- **The pointer moved on**: 260ms after the cancel grace. It has already said
  where it is going, and making it wait would be the "always showing" behaviour
  the feature exists to avoid.
- **The island was used and then left alone**: the configured
  `autoHideSeconds`, three by default.

Measured end to end on the shipped build: **~95ms** from the pointer entering
the zone to the window being on screen, and **~470ms** from it leaving to the
window being gone, repeatably.

Auto-hide is on by default. An overlay that is always on screen is the single
most common complaint about this whole category, and one that comes back in a
tenth of a second costs nothing to have away.
