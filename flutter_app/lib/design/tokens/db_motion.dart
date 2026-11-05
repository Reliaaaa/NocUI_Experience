import 'dart:math' as math;

import 'package:flutter/animation.dart';

/// Motion tokens.
///
/// Two rules hold the system together. Anything that changes *shape* is driven
/// by a spring, so it can be interrupted and reversed without a seam. Anything
/// that changes *appearance only* (opacity, colour, blur) uses a duration and a
/// curve, because a spring adds nothing there and costs a simulation.
class DbDuration {
  const DbDuration._();

  /// Pressed / released states.
  static const Duration instant = Duration(milliseconds: 90);

  /// Icon swaps, hover tints, focus rings.
  static const Duration micro = Duration(milliseconds: 150);

  /// Content fading in behind a shape change.
  static const Duration quick = Duration(milliseconds: 260);

  /// Full module replacement.
  static const Duration standard = Duration(milliseconds: 380);

  /// Notification entrances, panel reveals.
  static const Duration slow = Duration(milliseconds: 520);

  /// How long the shape is allowed to move before content starts appearing.
  /// Text that resizes with its container looks squeezed; text that arrives
  /// into a container already most of the way there looks placed.
  static const Duration contentDelay = Duration(milliseconds: 90);

  /// Content leaves faster than it arrives, and before the shape closes.
  static const Duration contentExit = Duration(milliseconds: 140);

  /// Ambient, never-ending motion: breathing glows, waveform drift.
  static const Duration ambient = Duration(milliseconds: 2400);

  /// Stagger between adjacent items in a list or a row of controls.
  static const Duration stagger = Duration(milliseconds: 55);
}

class DbCurve {
  const DbCurve._();

  /// Default for content arriving. Fast start, long soft landing.
  static const Cubic standard = Cubic(0.32, 0.72, 0, 1);

  /// For the largest moves; almost no tail bounce, very long settle.
  static const Cubic emphasized = Cubic(0.22, 1, 0.36, 1);

  /// Content leaving. Content should exit faster than it enters.
  static const Cubic exit = Cubic(0.4, 0, 0.9, 0.4);

  /// Symmetric, for values that move back and forth (progress, meters).
  static const Cubic inOut = Cubic(0.65, 0, 0.35, 1);

  /// Ambient loops.
  static const Curve breathe = Curves.easeInOutSine;
}

/// Named spring characters.
///
/// Written as *response* (the spring's natural period) and damping ratio, the
/// way Apple's spring API talks about them, and converted here with
/// `k = (2 pi / response)^2` at mass 1. See `docs/MOTION.md` for why each one
/// is the value it is.
///
/// The important pair is [arrival] and [departure]. Opening overshoots very
/// slightly, which reads as something physical coming to rest; closing is
/// monotonic, because a shape that bounces on its way out reads as the
/// interface arguing with the user who just dismissed it.
class DbSpring {
  const DbSpring._();

  static SpringDescription _ratio(double stiffness, double dampingRatio) {
    return SpringDescription.withDampingRatio(
      mass: 1,
      stiffness: stiffness,
      ratio: dampingRatio,
    );
  }

  static SpringDescription _response(double seconds, double dampingRatio) {
    final double omega = 2 * math.pi / seconds;
    return _ratio(omega * omega, dampingRatio);
  }

  /// Expanding, and dropping out of the bezel. 0.52s, damping 0.80.
  static final SpringDescription arrival = _response(0.52, 0.80);

  /// Collapsing, and withdrawing into the bezel. 0.44s, critically damped so
  /// it cannot cross its target on the way out.
  static final SpringDescription departure = _response(0.44, 1.0);

  /// The pill growing under the pointer. Short and openly bouncy: this one is
  /// meant to be felt.
  static final SpringDescription peek = _response(0.34, 0.55);

  /// Shadow, glow and edge light. Slower than the geometry, so light lags
  /// mass the way it does in the world.
  static final SpringDescription atmosphere = _response(0.70, 0.95);

  /// No overshoot at all, for anything that must not cross its target
  /// (progress fills, meters).
  static final SpringDescription precise = _response(0.36, 1.0);

  /// Dropping out of the bezel when the pointer arrives. Faster than a normal
  /// expansion and only lightly sprung: this is an answer to a gesture the
  /// user is making right now, and anything slower feels like lag rather than
  /// like grace.
  static final SpringDescription reveal = _response(0.34, 0.78);

  /// Withdrawing into the bezel when the pointer leaves. Faster still, and
  /// critically damped, so getting out of the way is never something the user
  /// has to wait through.
  static final SpringDescription withdraw = _response(0.26, 1.0);

  /// The corner radius, which rounds out slightly behind the size so the
  /// shape reads as elastic rather than as a rectangle being resized.
  static final SpringDescription contour = _response(0.60, 0.92);

  /// The content cross-fade, opening. Slower than the shape on purpose: this
  /// is what makes content appear *into* a container that has already most of
  /// its final size, instead of being stretched with it.
  static final SpringDescription contentIn = _response(0.62, 1.0);

  /// The content cross-fade, closing. Much faster, so content is gone before
  /// the shape finishes closing over it.
  static final SpringDescription contentOut = _response(0.26, 1.0);

  /// Chooses the character of a move from its direction. Everything that
  /// changes the island's shape goes through here.
  static SpringDescription forDirection({required bool opening}) =>
      opening ? arrival : departure;
}

/// How much motion the user wants.
///
/// `intensity` scales spring stiffness and duration. At 0 the interface still
/// changes state, it just does so immediately: reduced motion must never mean
/// reduced function.
class MotionProfile {
  const MotionProfile({this.intensity = 1.0});

  static const MotionProfile full = MotionProfile();
  static const MotionProfile reduced = MotionProfile(intensity: 0.0);

  /// 0 = instant, 1 = designed, up to 1.4 = slower and more expressive.
  final double intensity;

  bool get isInstant => intensity <= 0.01;

  Duration scale(Duration duration) {
    if (isInstant) {
      return Duration.zero;
    }
    return Duration(
      microseconds: (duration.inMicroseconds / intensity).round(),
    );
  }

  /// A stiffer spring for lower intensity, so less motion also means less time
  /// spent in motion.
  SpringDescription spring(SpringDescription base) {
    if (intensity >= 0.99 && intensity <= 1.01) {
      return base;
    }
    final double factor = intensity <= 0.01 ? 8.0 : 1 / intensity;
    return SpringDescription(
      mass: base.mass,
      stiffness: base.stiffness * factor * factor,
      damping: base.damping * factor,
    );
  }

  static MotionProfile fromIntensity(double value) =>
      MotionProfile(intensity: value.clamp(0.0, 1.4));
}
