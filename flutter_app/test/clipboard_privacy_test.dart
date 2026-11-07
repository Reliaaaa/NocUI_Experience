import 'dart:async';

import 'package:dynamicbar/modules/clipboard/clipboard_controller.dart';
import 'package:dynamicbar/modules/notifications/notification_center.dart';
import 'package:dynamicbar/native/clipboard_bridge.dart';
import 'package:dynamicbar/native/models/native_models.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeClipboardBridge extends ClipboardBridge {
  // Closed in the test’s finally block after the controller is disposed.
  // ignore: close_sinks
  final StreamController<NativeEvent> controller = StreamController<NativeEvent>.broadcast(sync: true);

  @override
  Stream<NativeEvent> get events => controller.stream;

  @override
  Future<bool> setEnabled(bool enabled) async => true;

  @override
  Future<void> setTextPreview({required bool enabled, int length = 80}) async {}
}

void main() {
  test('preview is opt-in and removed when disabled', () async {
    final bridge = FakeClipboardBridge();
    final notifications = NotificationCenter();
    final clipboard = ClipboardController(bridge: bridge, notifications: notifications);
    final event = NativeEvent('copied', <Object?, Object?>{
      'kind': 'text', 'preview': 'private text', 'length': 12,
    });
    try {
      expect(clipboard.isEnabled, isFalse);
      expect(clipboard.isPreviewEnabled, isFalse);
      await clipboard.setEnabled(true);
      bridge.controller.add(event);
      expect(clipboard.last?.preview, isEmpty);
      await clipboard.setPreviewEnabled(true);
      bridge.controller.add(event);
      expect(clipboard.last?.preview, 'private text');
      expect(notifications.queued.any((n) => n.body == 'private text'), isTrue);
      await clipboard.setPreviewEnabled(false);
      expect(clipboard.last?.preview, isEmpty);
      expect(notifications.current, isNull);
      expect(notifications.queued, isEmpty);
      bridge.controller.add(event);
      expect(clipboard.last?.preview, isEmpty);
      await clipboard.setEnabled(false);
      expect(clipboard.last, isNull);
    } finally {
      clipboard.dispose();
      notifications.dispose();
      await bridge.controller.close();
    }
  });
}
