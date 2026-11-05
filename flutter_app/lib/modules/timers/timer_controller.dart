import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/logging/app_logger.dart';
import '../notifications/island_notification.dart';
import '../notifications/notification_center.dart';
import 'island_timer.dart';

/// Owns every timer and stopwatch.
///
/// A single ticker drives all of them, and it only runs while something is
/// actually counting. The tick exists to refresh the display and to notice a
/// countdown reaching zero; the values themselves come from wall clock
/// arithmetic, so a missed tick costs accuracy nothing.
class TimerController extends ChangeNotifier {
  TimerController({required NotificationCenter notifications})
    : _notifications = notifications;

  static const Logger _log = Logger('Timers');
  static const Duration _tick = Duration(milliseconds: 200);

  final NotificationCenter _notifications;
  final List<IslandTimer> _timers = <IslandTimer>[];
  Timer? _ticker;
  int _nextId = 1;
  String? _focusedId;

  List<IslandTimer> get timers => List<IslandTimer>.unmodifiable(_timers);
  bool get hasTimers => _timers.isNotEmpty;

  bool get hasRunning => _timers.any((timer) => timer.isRunning);

  /// The timer the user last asked to see, if it still exists. Set by
  /// clicking one in the list; cleared when it is removed.
  String? get focusedId => _focusedId;

  /// Brings one timer to the front of the page. Null lets [primary] choose
  /// again on its own.
  void focus(String? id) {
    final String? next = id != null && _find(id) != null ? id : null;
    if (next == _focusedId) {
      return;
    }
    _focusedId = next;
    notifyListeners();
  }

  /// The timer the island should show: the one the user picked, else the
  /// countdown closest to finishing, else the first running timer, else the
  /// most recent.
  IslandTimer? get primary {
    if (_timers.isEmpty) {
      return null;
    }
    final IslandTimer? focused = _focusedId == null ? null : _find(_focusedId!);
    if (focused != null) {
      return focused;
    }
    final DateTime now = DateTime.now();
    final List<IslandTimer> running = _timers
        .where((timer) => timer.isRunning)
        .toList();
    if (running.isEmpty) {
      return _timers.last;
    }
    running.sort((a, b) {
      final Duration left = a.kind == TimerKind.countdown
          ? a.remainingAt(now)
          : const Duration(days: 365);
      final Duration right = b.kind == TimerKind.countdown
          ? b.remainingAt(now)
          : const Duration(days: 365);
      return left.compareTo(right);
    });
    return running.first;
  }

  String addCountdown(
    Duration duration, {
    String label = '',
    bool start = true,
  }) {
    final String id = 't${_nextId++}';
    IslandTimer timer = IslandTimer.countdown(
      id: id,
      duration: duration,
      label: label,
    );
    if (start) {
      timer = timer.copyWith(
        state: TimerState.running,
        runningSince: DateTime.now(),
      );
    }
    _timers.add(timer);
    _log.info('Countdown $id for ${duration.inSeconds}s.');
    _syncTicker();
    notifyListeners();
    return id;
  }

  String addStopwatch({String label = '', bool start = true}) {
    final String id = 's${_nextId++}';
    IslandTimer timer = IslandTimer.stopwatch(id: id, label: label);
    if (start) {
      timer = timer.copyWith(
        state: TimerState.running,
        runningSince: DateTime.now(),
      );
    }
    _timers.add(timer);
    _syncTicker();
    notifyListeners();
    return id;
  }

  void pause(String id) => _mutate(id, (IslandTimer timer) {
    if (!timer.isRunning) {
      return timer;
    }
    return timer.copyWith(
      state: TimerState.paused,
      accumulated: timer.elapsedAt(DateTime.now()),
      clearRunningSince: true,
    );
  });

  void resume(String id) => _mutate(id, (IslandTimer timer) {
    if (timer.state != TimerState.paused && timer.state != TimerState.idle) {
      return timer;
    }
    return timer.copyWith(
      state: TimerState.running,
      runningSince: DateTime.now(),
    );
  });

  void toggle(String id) {
    final IslandTimer? timer = _find(id);
    if (timer == null) {
      return;
    }
    if (timer.isRunning) {
      pause(id);
    } else if (!timer.isFinished) {
      resume(id);
    }
  }

  void reset(String id) => _mutate(id, (IslandTimer timer) {
    return timer.copyWith(
      state: TimerState.idle,
      accumulated: Duration.zero,
      clearRunningSince: true,
      clearFinishedAt: true,
      laps: const <Duration>[],
    );
  });

  /// Records the stopwatch's elapsed time as a lap. A countdown has no laps;
  /// asking for one is ignored rather than invented.
  void lap(String id) => _mutate(id, (IslandTimer timer) {
    if (timer.kind != TimerKind.stopwatch || !timer.isRunning) {
      return timer;
    }
    return timer.copyWith(
      laps: <Duration>[...timer.laps, timer.elapsedAt(DateTime.now())],
    );
  });

  void remove(String id) {
    final int before = _timers.length;
    _timers.removeWhere((timer) => timer.id == id);
    if (_timers.length != before) {
      if (_focusedId == id) {
        _focusedId = null;
      }
      _notifications.dismiss('timer.$id');
      _syncTicker();
      notifyListeners();
    }
  }

  void clear() {
    for (final IslandTimer timer in _timers) {
      _notifications.dismiss('timer.${timer.id}');
    }
    _timers.clear();
    _focusedId = null;
    _syncTicker();
    notifyListeners();
  }

  IslandTimer? _find(String id) {
    for (final IslandTimer timer in _timers) {
      if (timer.id == id) {
        return timer;
      }
    }
    return null;
  }

  void _mutate(String id, IslandTimer Function(IslandTimer timer) transform) {
    final int index = _timers.indexWhere((timer) => timer.id == id);
    if (index < 0) {
      return;
    }
    final IslandTimer updated = transform(_timers[index]);
    if (identical(updated, _timers[index])) {
      return;
    }
    _timers[index] = updated;
    _syncTicker();
    notifyListeners();
  }

  void _syncTicker() {
    if (hasRunning) {
      _ticker ??= Timer.periodic(_tick, (_) => _onTick());
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  void _onTick() {
    final DateTime now = DateTime.now();
    var changed = false;
    for (int i = 0; i < _timers.length; i++) {
      final IslandTimer timer = _timers[i];
      if (timer.hasExpiredAt(now)) {
        _timers[i] = timer.copyWith(
          state: TimerState.finished,
          accumulated: timer.duration,
          clearRunningSince: true,
          finishedAt: now,
        );
        _announceFinished(_timers[i]);
        changed = true;
      }
    }
    if (changed) {
      _syncTicker();
    }
    // The display needs a repaint every tick regardless; the values are derived
    // from the clock, not from stored state.
    notifyListeners();
  }

  void _announceFinished(IslandTimer timer) {
    _log.info('${timer.displayLabel} finished.');
    _notifications.post(
      IslandNotification(
        id: 'timer.${timer.id}',
        title: '${timer.displayLabel} finished',
        body: 'Ran for ${timer.duration.inMinutes} min',
        kind: NotificationKind.timer,
        priority: NotificationPriority.high,
      ),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ticker = null;
    super.dispose();
  }
}
