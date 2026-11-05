import 'package:dynamicbar/modules/notifications/notification_center.dart';
import 'package:dynamicbar/modules/timers/island_timer.dart';
import 'package:dynamicbar/modules/timers/timer_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime start = DateTime(2026, 9, 7, 12);

  group('IslandTimer arithmetic', () {
    test('a paused timer holds its banked time', () {
      const IslandTimer timer = IslandTimer(
        id: 't1',
        kind: TimerKind.countdown,
        label: '',
        state: TimerState.paused,
        duration: Duration(minutes: 5),
        accumulated: Duration(minutes: 2),
      );
      expect(
        timer.elapsedAt(start.add(const Duration(hours: 3))),
        const Duration(minutes: 2),
      );
      expect(timer.remainingAt(start), const Duration(minutes: 3));
    });

    test('a running timer counts from wall clock, not from ticks', () {
      final IslandTimer timer = IslandTimer(
        id: 't1',
        kind: TimerKind.countdown,
        label: '',
        state: TimerState.running,
        duration: const Duration(minutes: 5),
        accumulated: const Duration(minutes: 1),
        runningSince: start,
      );
      final DateTime later = start.add(const Duration(minutes: 2));
      expect(timer.elapsedAt(later), const Duration(minutes: 3));
      expect(timer.remainingAt(later), const Duration(minutes: 2));
    });

    test('remaining never goes negative', () {
      final IslandTimer timer = IslandTimer(
        id: 't1',
        kind: TimerKind.countdown,
        label: '',
        state: TimerState.running,
        duration: const Duration(minutes: 1),
        runningSince: start,
      );
      expect(
        timer.remainingAt(start.add(const Duration(hours: 1))),
        Duration.zero,
      );
      expect(timer.hasExpiredAt(start.add(const Duration(minutes: 2))), isTrue);
    });

    test('a stopwatch has no progress to report', () {
      final IslandTimer timer = IslandTimer(
        id: 's1',
        kind: TimerKind.stopwatch,
        label: '',
        state: TimerState.running,
        runningSince: start,
      );
      expect(timer.progressAt(start.add(const Duration(minutes: 1))), isNull);
      expect(timer.remainingAt(start), Duration.zero);
      expect(
        timer.elapsedAt(start.add(const Duration(seconds: 30))),
        const Duration(seconds: 30),
      );
    });

    test('progress is clamped to the timer length', () {
      final IslandTimer timer = IslandTimer(
        id: 't1',
        kind: TimerKind.countdown,
        label: '',
        state: TimerState.running,
        duration: const Duration(minutes: 2),
        runningSince: start,
      );
      expect(timer.progressAt(start), 0);
      expect(
        timer.progressAt(start.add(const Duration(minutes: 1))),
        closeTo(0.5, 1e-9),
      );
      expect(timer.progressAt(start.add(const Duration(minutes: 9))), 1.0);
    });

    test('falls back to a descriptive label', () {
      expect(
        IslandTimer.countdown(id: 'a', duration: Duration.zero).displayLabel,
        'Timer',
      );
      expect(IslandTimer.stopwatch(id: 'b').displayLabel, 'Stopwatch');
      expect(IslandTimer.stopwatch(id: 'b', label: 'Tea').displayLabel, 'Tea');
    });
  });

  group('TimerController', () {
    late NotificationCenter notifications;
    late TimerController controller;

    setUp(() {
      notifications = NotificationCenter();
      controller = TimerController(notifications: notifications);
    });

    tearDown(() {
      controller.dispose();
      notifications.dispose();
    });

    test('a focused timer is the primary one until it goes', () {
      final String first = controller.addCountdown(const Duration(minutes: 1));
      final String second = controller.addCountdown(const Duration(minutes: 9));
      // Closest to finishing wins on its own...
      expect(controller.primary!.id, first);
      // ...unless the user has pointed at another.
      controller.focus(second);
      expect(controller.primary!.id, second);
      controller.remove(second);
      expect(controller.focusedId, isNull);
      expect(controller.primary!.id, first);
      // Pointing at nothing is ignored rather than trusted.
      controller.focus('no-such-timer');
      expect(controller.focusedId, isNull);
    });

    test('laps belong to a running stopwatch only', () {
      final String stopwatch = controller.addStopwatch();
      final String countdown = controller.addCountdown(
        const Duration(minutes: 1),
      );
      controller.lap(stopwatch);
      controller.lap(stopwatch);
      controller.lap(countdown);
      expect(controller.timers.first.laps.length, 2);
      expect(controller.timers.last.laps, isEmpty);
      controller.pause(stopwatch);
      controller.lap(stopwatch);
      expect(controller.timers.first.laps.length, 2);
      controller.reset(stopwatch);
      expect(controller.timers.first.laps, isEmpty);
    });

    test('starts countdowns running by default', () {
      final String id = controller.addCountdown(const Duration(minutes: 5));
      expect(controller.timers.single.id, id);
      expect(controller.hasRunning, isTrue);
    });

    test('can add a timer without starting it', () {
      controller.addCountdown(const Duration(minutes: 5), start: false);
      expect(controller.hasRunning, isFalse);
      expect(controller.hasTimers, isTrue);
    });

    test('pause banks elapsed time and resume continues from it', () {
      final String id = controller.addCountdown(const Duration(minutes: 5));
      controller.pause(id);

      final IslandTimer paused = controller.timers.single;
      expect(paused.state, TimerState.paused);
      expect(paused.runningSince, isNull);

      controller.resume(id);
      expect(controller.timers.single.state, TimerState.running);
      expect(controller.timers.single.accumulated, paused.accumulated);
    });

    test('toggle flips between running and paused', () {
      final String id = controller.addStopwatch();
      controller.toggle(id);
      expect(controller.timers.single.isRunning, isFalse);
      controller.toggle(id);
      expect(controller.timers.single.isRunning, isTrue);
    });

    test('reset returns a timer to idle with nothing banked', () {
      final String id = controller.addCountdown(const Duration(minutes: 5));
      controller.pause(id);
      controller.reset(id);

      final IslandTimer timer = controller.timers.single;
      expect(timer.state, TimerState.idle);
      expect(timer.accumulated, Duration.zero);
    });

    test('the primary timer is the countdown closest to finishing', () {
      controller.addCountdown(const Duration(minutes: 30));
      final String soon = controller.addCountdown(const Duration(minutes: 2));
      controller.addStopwatch();
      expect(controller.primary?.id, soon);
    });

    test('removing a timer clears its notification', () {
      final String id = controller.addCountdown(const Duration(minutes: 1));
      controller.remove(id);
      expect(controller.hasTimers, isFalse);
      expect(controller.hasRunning, isFalse);
    });

    test('clear removes everything', () {
      controller.addCountdown(const Duration(minutes: 1));
      controller.addStopwatch();
      controller.clear();
      expect(controller.timers, isEmpty);
      expect(controller.primary, isNull);
    });
  });
}
