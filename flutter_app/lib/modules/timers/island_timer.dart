/// A countdown or a stopwatch.
enum TimerKind { countdown, stopwatch }

/// Where a timer is in its life.
enum TimerState { idle, running, paused, finished }

/// One timer.
///
/// Elapsed time is computed from wall clock stamps rather than accumulated per
/// tick. A timer that is accumulated tick by tick drifts, and drifts most
/// exactly when the machine is busy or asleep - which is when someone is most
/// likely to be relying on it.
class IslandTimer {
  const IslandTimer({
    required this.id,
    required this.kind,
    required this.label,
    required this.state,
    this.duration = Duration.zero,
    this.accumulated = Duration.zero,
    this.runningSince,
    this.finishedAt,
    this.laps = const <Duration>[],
  });

  factory IslandTimer.countdown({
    required String id,
    required Duration duration,
    String label = '',
  }) {
    return IslandTimer(
      id: id,
      kind: TimerKind.countdown,
      label: label,
      state: TimerState.idle,
      duration: duration,
    );
  }

  factory IslandTimer.stopwatch({required String id, String label = ''}) {
    return IslandTimer(
      id: id,
      kind: TimerKind.stopwatch,
      label: label,
      state: TimerState.idle,
    );
  }

  final String id;
  final TimerKind kind;
  final String label;
  final TimerState state;

  /// Total length, for a countdown.
  final Duration duration;

  /// Time banked from previous running spells.
  final Duration accumulated;

  /// When the current running spell began, or null when not running.
  final DateTime? runningSince;

  final DateTime? finishedAt;

  /// Elapsed time at each lap, oldest first. Only a stopwatch takes laps.
  final List<Duration> laps;

  bool get isRunning => state == TimerState.running;
  bool get isFinished => state == TimerState.finished;

  /// Time counted so far, at [now].
  Duration elapsedAt(DateTime now) {
    final DateTime? since = runningSince;
    if (state != TimerState.running || since == null) {
      return accumulated;
    }
    final Duration live = now.difference(since);
    return accumulated + (live.isNegative ? Duration.zero : live);
  }

  /// Time left on a countdown, clamped at zero. Always zero for a stopwatch.
  Duration remainingAt(DateTime now) {
    if (kind != TimerKind.countdown) {
      return Duration.zero;
    }
    final Duration left = duration - elapsedAt(now);
    return left.isNegative ? Duration.zero : left;
  }

  /// 0..1 for a countdown, null for a stopwatch, which has no end to progress
  /// towards.
  double? progressAt(DateTime now) {
    if (kind != TimerKind.countdown || duration.inMilliseconds <= 0) {
      return null;
    }
    final double value =
        elapsedAt(now).inMilliseconds / duration.inMilliseconds;
    return value.clamp(0.0, 1.0).toDouble();
  }

  bool hasExpiredAt(DateTime now) =>
      kind == TimerKind.countdown &&
      state == TimerState.running &&
      elapsedAt(now) >= duration;

  /// The name to show, falling back to something descriptive.
  String get displayLabel {
    if (label.isNotEmpty) {
      return label;
    }
    return kind == TimerKind.countdown ? 'Timer' : 'Stopwatch';
  }

  IslandTimer copyWith({
    String? label,
    TimerState? state,
    Duration? duration,
    Duration? accumulated,
    DateTime? runningSince,
    bool clearRunningSince = false,
    DateTime? finishedAt,
    bool clearFinishedAt = false,
    List<Duration>? laps,
  }) {
    return IslandTimer(
      id: id,
      kind: kind,
      label: label ?? this.label,
      state: state ?? this.state,
      duration: duration ?? this.duration,
      accumulated: accumulated ?? this.accumulated,
      runningSince: clearRunningSince
          ? null
          : (runningSince ?? this.runningSince),
      finishedAt: clearFinishedAt ? null : (finishedAt ?? this.finishedAt),
      laps: laps ?? this.laps,
    );
  }
}
