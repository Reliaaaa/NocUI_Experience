import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/logging/app_logger.dart';
import '../../native/clipboard_bridge.dart';
import '../../native/models/native_models.dart';
import '../notifications/island_notification.dart';
import '../notifications/notification_center.dart';

/// What kind of thing was copied.
enum ClipboardKind { text, image, files, other }

/// A single copy event, holding as little as possible.
class ClipboardActivity {
  const ClipboardActivity({
    required this.kind,
    required this.source,
    required this.length,
    required this.at,
    this.preview = '',
  });

  final ClipboardKind kind;

  /// Executable name of the application that owned the clipboard.
  final String source;

  /// Character count for text, 0 otherwise.
  final int length;

  /// Empty unless the user turned previews on.
  final String preview;
  final DateTime at;

  String get kindLabel {
    switch (kind) {
      case ClipboardKind.text:
        return length > 0 ? '$length characters' : 'Text';
      case ClipboardKind.image:
        return 'Image';
      case ClipboardKind.files:
        return 'Files';
      case ClipboardKind.other:
        return 'Content';
    }
  }

  static ClipboardKind kindFromName(String? name) {
    switch (name) {
      case 'text':
        return ClipboardKind.text;
      case 'image':
        return ClipboardKind.image;
      case 'files':
        return ClipboardKind.files;
      default:
        return ClipboardKind.other;
    }
  }
}

/// Turns clipboard activity into a brief, low priority acknowledgement.
///
/// This module is off by default and stays off until the user enables it. When
/// it is on, the island says that something was copied and how big it was; the
/// content itself is only read if text previews are separately enabled, and
/// nothing is ever stored, logged or sent anywhere.
class ClipboardController extends ChangeNotifier {
  ClipboardController({
    required ClipboardBridge bridge,
    required NotificationCenter notifications,
  }) : _bridge = bridge,
       _notifications = notifications;

  static const Logger _log = Logger('Clipboard');

  final ClipboardBridge _bridge;
  final NotificationCenter _notifications;
  StreamSubscription<NativeEvent>? _subscription;

  ClipboardActivity? _last;
  bool _enabled = false;
  bool _previewEnabled = false;
  int _counter = 0;

  ClipboardActivity? get last => _last;
  bool get isEnabled => _enabled;
  bool get isPreviewEnabled => _previewEnabled;

  Future<void> setEnabled(bool value) async {
    if (_enabled == value) {
      return;
    }
    _enabled = value;
    if (value) {
      _subscription ??= _bridge.events.listen(_onEvent);
      await _bridge.setEnabled(true);
      await _bridge.setTextPreview(enabled: _previewEnabled);
      _log.info('Clipboard activity enabled.');
    } else {
      await _bridge.setEnabled(false);
      await _subscription?.cancel();
      _subscription = null;
      _last = null;
      _log.info('Clipboard activity disabled.');
    }
    notifyListeners();
  }

  Future<void> setPreviewEnabled(bool value) async {
    if (_previewEnabled == value) {
      return;
    }
    _previewEnabled = value;
    await _bridge.setTextPreview(enabled: value);
    notifyListeners();
  }

  void _onEvent(NativeEvent event) {
    if (event.type != 'copied') {
      return;
    }
    final ClipboardActivity activity = ClipboardActivity(
      kind: ClipboardActivity.kindFromName(event.read<String>('kind')),
      source: event.read<String>('source') ?? '',
      length: (event.data['length'] as num?)?.toInt() ?? 0,
      preview: _previewEnabled ? (event.read<String>('preview') ?? '') : '',
      at: DateTime.now(),
    );
    _last = activity;

    _notifications.post(
      IslandNotification(
        id: 'clipboard.${_counter++}',
        title: 'Copied',
        body: activity.preview.isNotEmpty
            ? activity.preview
            : activity.kindLabel,
        kind: NotificationKind.clipboard,
        priority: NotificationPriority.low,
      ),
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }
}
