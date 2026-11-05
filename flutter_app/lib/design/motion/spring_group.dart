import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';

import '../tokens/db_motion.dart';

/// A set of independently retargetable spring simulations sharing one ticker.
///
/// This is the animation engine the island morphs on. Three properties matter:
///
/// * **Interruptible.** Retargeting a track keeps its current velocity, so a
///   collapse that starts mid-expansion continues from the motion already in
///   flight instead of snapping to a new curve.
/// * **Cheap.** One [Ticker] and one notification per frame for every animated
///   dimension, integrated in a few dozen floating point operations.
/// * **Idle-free.** The ticker stops the moment every track is at rest, so a
///   still island costs exactly nothing. This is what lets the app sit in the
///   tray all day.
class SpringGroup extends ChangeNotifier {
  SpringGroup({
    required TickerProvider vsync,
    MotionProfile profile = MotionProfile.full,
  }) {
    _profile = profile;
    _ticker = vsync.createTicker(_onTick);
  }

  /// Fixed integration step. Small enough that a stiff spring stays stable even
  /// when the raster thread drops a frame.
  static const double _step = 1 / 480;
  static const double _maxFrame = 1 / 20;

  late final Ticker _ticker;
  final Map<String, _SpringTrack> _tracks = <String, _SpringTrack>{};
  final List<VoidCallback> _settleListeners = <VoidCallback>[];

  late MotionProfile _profile;
  Duration _lastElapsed = Duration.zero;
  bool _disposed = false;

  MotionProfile get profile => _profile;

  set profile(MotionProfile value) {
    if (_profile.intensity == value.intensity) {
      return;
    }
    _profile = value;
    if (value.isInstant) {
      // Reduced motion: land everything now rather than re-tuning simulations.
      for (final track in _tracks.values) {
        track.value = track.target;
        track.velocity = 0;
      }
      _stop();
      notifyListeners();
      _notifySettled();
    }
  }

  bool get isAnimating => _ticker.isActive;

  /// Current value of a track. Unknown tracks read as 0 so a widget can be
  /// built before its first target is set.
  double operator [](String key) => _tracks[key]?.value ?? 0;

  double valueOf(String key, {double fallback = 0}) =>
      _tracks[key]?.value ?? fallback;

  double velocityOf(String key) => _tracks[key]?.velocity ?? 0;

  bool isAtRest(String key) => _tracks[key]?.isAtRest ?? true;

  /// Places a track at [value] with no motion. Used for first layout and for
  /// hard state changes such as the island being hidden.
  void reset(String key, double value) {
    final track = _tracks.putIfAbsent(key, () => _SpringTrack(value));
    track.value = value;
    track.target = value;
    track.velocity = 0;
    if (_tracks.values.every((t) => t.isAtRest)) {
      _stop();
    }
  }

  /// Retargets a track, preserving its current velocity.
  void animateTo(
    String key,
    double target, {
    SpringDescription? spring,
    double epsilon = 0.01,
  }) {
    final track = _tracks.putIfAbsent(key, () => _SpringTrack(target));
    track.spring = _profile.spring(spring ?? DbSpring.arrival);
    track.epsilon = epsilon;
    if (track.target == target && track.isAtRest) {
      return;
    }
    track.target = target;
    if (_profile.isInstant) {
      track.value = target;
      track.velocity = 0;
      notifyListeners();
      _notifySettled();
      return;
    }
    _start();
  }

  /// Called once each time every track has come to rest. Used to publish the
  /// settled island geometry to the native hit-test region.
  void addSettleListener(VoidCallback listener) =>
      _settleListeners.add(listener);

  void removeSettleListener(VoidCallback listener) =>
      _settleListeners.remove(listener);

  void _start() {
    if (_disposed || _ticker.isActive) {
      return;
    }
    _lastElapsed = Duration.zero;
    _ticker.start();
  }

  void _stop() {
    if (_ticker.isActive) {
      _ticker.stop();
    }
    _lastElapsed = Duration.zero;
  }

  void _onTick(Duration elapsed) {
    double dt = (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    if (dt <= 0) {
      return;
    }
    if (dt > _maxFrame) {
      // A long stall (a hitch, a resumed session) must not launch the springs
      // across the screen; treat it as a single ordinary frame.
      dt = _maxFrame;
    }

    var allAtRest = true;
    for (final track in _tracks.values) {
      if (!track.isAtRest) {
        track.integrate(dt);
      }
      if (!track.isAtRest) {
        allAtRest = false;
      }
    }

    notifyListeners();
    if (allAtRest) {
      _stop();
      _notifySettled();
    }
  }

  void _notifySettled() {
    for (final listener in List<VoidCallback>.of(_settleListeners)) {
      listener();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _settleListeners.clear();
    _ticker.dispose();
    super.dispose();
  }
}

class _SpringTrack {
  _SpringTrack(this.value) : target = value, spring = DbSpring.arrival;

  double value;
  double target;
  double velocity = 0;
  double epsilon = 0.01;
  SpringDescription spring;

  bool get isAtRest =>
      (value - target).abs() <= epsilon && velocity.abs() <= epsilon * 8;

  /// Semi-implicit Euler at a fixed sub-step. Deterministic, unconditionally
  /// stable for the stiffnesses used here, and far cheaper than rebuilding a
  /// [SpringSimulation] on every retarget.
  void integrate(double dt) {
    final double k = spring.stiffness;
    final double c = spring.damping;
    final double m = math.max(spring.mass, 0.0001);

    double remaining = dt;
    while (remaining > 0) {
      final double h = remaining < SpringGroup._step
          ? remaining
          : SpringGroup._step;
      final double displacement = value - target;
      final double acceleration = (-k * displacement - c * velocity) / m;
      velocity += acceleration * h;
      value += velocity * h;
      remaining -= h;
    }

    if (isAtRest) {
      value = target;
      velocity = 0;
    }
  }
}
