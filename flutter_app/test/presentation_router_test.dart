import 'package:dynamicbar/island/state/island_controller.dart';
import 'package:dynamicbar/island/state/island_metrics.dart';
import 'package:dynamicbar/island/state/island_state.dart';
import 'package:dynamicbar/island/state/presentation_router.dart';
import 'package:dynamicbar/modules/clipboard/clipboard_controller.dart';
import 'package:dynamicbar/modules/downloads/downloads_controller.dart';
import 'package:dynamicbar/modules/media/media_controller.dart';
import 'package:dynamicbar/modules/notifications/island_notification.dart';
import 'package:dynamicbar/modules/notifications/notification_center.dart';
import 'package:dynamicbar/modules/system/system_controller.dart';
import 'package:dynamicbar/modules/timers/timer_controller.dart';
import 'package:dynamicbar/native/clipboard_bridge.dart';
import 'package:dynamicbar/native/downloads_bridge.dart';
import 'package:dynamicbar/native/media_bridge.dart';
import 'package:dynamicbar/native/system_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

/// The router's inputs, none of which touch the platform until enabled.
class _Harness {
  _Harness()
    : island = IslandController(),
      notifications = NotificationCenter() {
    media = MediaController(bridge: MediaBridge());
    downloads = DownloadsController(
      bridge: DownloadsBridge(),
      notifications: notifications,
    );
    timers = TimerController(notifications: notifications);
    clipboard = ClipboardController(
      bridge: ClipboardBridge(),
      notifications: notifications,
    );
    system = SystemController(
      bridge: SystemBridge(),
      notifications: notifications,
    );
    router = PresentationRouter(
      island: island,
      notifications: notifications,
      media: media,
      downloads: downloads,
      timers: timers,
      clipboard: clipboard,
      system: system,
    );
  }

  final IslandController island;
  final NotificationCenter notifications;
  late final MediaController media;
  late final DownloadsController downloads;
  late final TimerController timers;
  late final ClipboardController clipboard;
  late final SystemController system;
  late final PresentationRouter router;

  void dispose() {
    router.dispose();
    system.dispose();
    clipboard.dispose();
    timers.dispose();
    downloads.dispose();
    media.dispose();
    notifications.dispose();
    island.dispose();
  }
}

void main() {
  group('PresentationRouter', () {
    late _Harness harness;

    setUp(() => harness = _Harness());
    tearDown(() => harness.dispose());

    test('shows the clock when nothing is happening', () {
      expect(harness.router.mode, IslandMode.idle);
      expect(harness.island.mode, IslandMode.idle);
    });

    test('a running timer becomes the ambient mode', () {
      harness.timers.addCountdown(const Duration(minutes: 5));
      expect(harness.router.mode, IslandMode.timer);
    });

    test('a notification takes the island over, then hands it back', () {
      harness.timers.addCountdown(const Duration(minutes: 5));
      harness.notifications.post(
        IslandNotification(
          id: 'a',
          title: 'Something happened',
          lifetime: const Duration(minutes: 5),
        ),
      );
      expect(harness.router.mode, IslandMode.notification);

      harness.notifications.dismiss('a');
      expect(harness.router.mode, IslandMode.timer);
    });

    test('a sticky low priority badge does not interrupt', () {
      harness.timers.addCountdown(const Duration(minutes: 5));
      harness.notifications.post(
        IslandNotification(
          id: 'downloads.active',
          title: 'file.zip',
          priority: NotificationPriority.low,
          sticky: true,
        ),
      );
      // An in-flight download is a badge on an ambient state, not an event.
      expect(harness.router.mode, IslandMode.timer);
    });

    test('a high priority notification raises the attention level', () {
      expect(harness.island.attention, 0);
      harness.notifications.post(
        IslandNotification(
          id: 'urgent',
          title: 'Battery critical',
          priority: NotificationPriority.high,
          lifetime: const Duration(minutes: 5),
        ),
      );
      expect(harness.island.attention, 1);

      harness.notifications.dismiss('urgent');
      expect(harness.island.attention, 0);
    });

    test('a normal notification does not raise it', () {
      harness.notifications.post(
        IslandNotification(
          id: 'ordinary',
          title: 'Copied',
          lifetime: const Duration(minutes: 5),
        ),
      );
      expect(harness.island.attention, 0);
    });

    test('settings outranks everything, including a live notification', () {
      harness.notifications.post(
        IslandNotification(
          id: 'urgent',
          title: 'Battery critical',
          priority: NotificationPriority.high,
          lifetime: const Duration(minutes: 5),
        ),
      );
      expect(harness.router.mode, IslandMode.notification);

      harness.router.openSettings();
      expect(harness.router.mode, IslandMode.settings);
      expect(harness.router.isSettingsOpen, isTrue);

      harness.router.closeSettings();
      expect(harness.router.mode, IslandMode.notification);
    });

    test('opening settings twice is not an event', () {
      var notifications = 0;
      harness.router.addListener(() => notifications++);
      harness.router.openSettings();
      harness.router.openSettings();
      expect(notifications, 1);
    });
  });

  group('Stage sizing', () {
    test('one stage holds every mode, so it is never resized', () {
      final islandStage = IslandMetrics.stageSize();
      final panelStage = IslandMetrics.stageSize(panel: true);

      expect(panelStage, islandStage);
      expect(IslandMode.settings.needsPanelStage, isTrue);
      expect(IslandMode.media.needsPanelStage, isFalse);
    });

    test('the settings panel fits the stage it asks for', () {
      expect(IslandMetrics.fitsInStage(IslandMode.settings), isTrue);
    });

    test('user scaling does not move the stage, and the largest fits', () {
      final normal = IslandMetrics.stageSize();
      final large = IslandMetrics.stageSize(scale: IslandMetrics.maxScale);
      expect(large, normal);
      final settings = IslandMetrics.expandedSizeFor(IslandMode.settings);
      expect(settings.width * IslandMetrics.maxScale, lessThan(normal.width));
      expect(settings.height * IslandMetrics.maxScale, lessThan(normal.height));
    });
  });
}
