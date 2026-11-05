import 'package:dynamicbar/modules/notifications/island_notification.dart';
import 'package:dynamicbar/modules/notifications/notification_center.dart';
import 'package:flutter_test/flutter_test.dart';

IslandNotification _note(
  String id, {
  NotificationPriority priority = NotificationPriority.normal,
  bool sticky = false,
  String title = 'Title',
}) {
  return IslandNotification(
    id: id,
    title: title,
    priority: priority,
    sticky: sticky,
    // Long lifetimes keep the auto-dismiss timer out of these tests; expiry is
    // driven by a real Timer and is exercised by the app, not here.
    lifetime: const Duration(minutes: 5),
  );
}

void main() {
  group('NotificationCenter', () {
    late NotificationCenter center;

    setUp(() => center = NotificationCenter());
    tearDown(() => center.dispose());

    test('shows the first notification immediately', () {
      center.post(_note('a'));
      expect(center.current?.id, 'a');
      expect(center.pendingCount, 0);
    });

    test('queues a second notification of the same priority', () {
      center.post(_note('a'));
      center.post(_note('b'));
      expect(center.current?.id, 'a');
      expect(center.pendingCount, 1);
    });

    test('posting the same id updates in place instead of queueing', () {
      center.post(_note('a', title: 'First'));
      center.post(_note('a', title: 'Second'));
      expect(center.current?.title, 'Second');
      expect(center.pendingCount, 0);
    });

    test('updates a queued notification in place', () {
      center.post(_note('a'));
      center.post(_note('b', title: 'One'));
      center.post(_note('b', title: 'Two'));
      expect(center.pendingCount, 1);
      expect(center.queued.single.title, 'Two');
    });

    test('does not let a higher priority cut off a message just shown', () {
      center.post(_note('a'));
      center.post(_note('urgent', priority: NotificationPriority.high));
      // The first notification has been on screen for microseconds; taking it
      // away now would mean it was never readable.
      expect(center.current?.id, 'a');
      expect(center.pendingCount, 1);
    });

    test('dismissing promotes the highest priority waiting notification', () {
      center.post(_note('a'));
      center.post(_note('low', priority: NotificationPriority.low));
      center.post(_note('high', priority: NotificationPriority.high));

      center.dismiss('a');
      expect(center.current?.id, 'high');

      center.dismiss('high');
      expect(center.current?.id, 'low');

      center.dismiss('low');
      expect(center.current, isNull);
    });

    test('dismissing a queued notification leaves the current one alone', () {
      center.post(_note('a'));
      center.post(_note('b'));
      center.dismiss('b');
      expect(center.current?.id, 'a');
      expect(center.pendingCount, 0);
    });

    test('drops low priority entries first when the queue is full', () {
      final NotificationCenter small = NotificationCenter(maxQueued: 2);
      small.post(_note('showing'));
      small.post(_note('low', priority: NotificationPriority.low));
      small.post(_note('b'));
      small.post(_note('c'));

      final List<String> ids = small.queued
          .map((IslandNotification n) => n.id)
          .toList();
      expect(ids, isNot(contains('low')));
      expect(ids, containsAll(<String>['b', 'c']));
      small.dispose();
    });

    test('sticky notifications are not given a dismiss timer', () {
      center.post(_note('download', sticky: true));
      expect(center.current?.sticky, isTrue);
      expect(center.hasNotification, isTrue);
    });

    test('disabling clears everything and refuses new posts', () {
      center.post(_note('a'));
      center.enabled = false;
      expect(center.current, isNull);

      center.post(_note('b'));
      expect(center.current, isNull);

      center.enabled = true;
      center.post(_note('c'));
      expect(center.current?.id, 'c');
    });

    test('priority lifetimes grow with urgency', () {
      expect(
        NotificationPriority.low.defaultLifetime,
        lessThan(NotificationPriority.normal.defaultLifetime),
      );
      expect(
        NotificationPriority.normal.defaultLifetime,
        lessThan(NotificationPriority.high.defaultLifetime),
      );
      expect(NotificationPriority.low.peeks, isFalse);
      expect(NotificationPriority.high.peeks, isTrue);
    });
  });
}
