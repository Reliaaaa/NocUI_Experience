import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/logging/app_logger.dart';
import '../../core/utils/formatters.dart';
import '../../native/downloads_bridge.dart';
import '../../native/models/native_models.dart';
import '../notifications/island_notification.dart';
import '../notifications/notification_center.dart';
import 'download_activity.dart';

/// Tracks transfers landing in the Downloads folder.
class DownloadsController extends ChangeNotifier {
  DownloadsController({
    required DownloadsBridge bridge,
    required NotificationCenter notifications,
  }) : _bridge = bridge,
       _notifications = notifications;

  static const Logger _log = Logger('Downloads');

  /// How long a finished transfer stays in the recent list.
  static const Duration recentLifetime = Duration(minutes: 10);
  static const int maxRecent = 8;

  final DownloadsBridge _bridge;
  final NotificationCenter _notifications;
  StreamSubscription<NativeEvent>? _subscription;

  final Map<String, DownloadActivity> _active = <String, DownloadActivity>{};
  final List<DownloadActivity> _recent = <DownloadActivity>[];
  bool _enabled = false;
  String _folder = '';

  bool get isEnabled => _enabled;
  String get folder => _folder;

  List<DownloadActivity> get active =>
      List<DownloadActivity>.unmodifiable(_active.values);
  List<DownloadActivity> get recent =>
      List<DownloadActivity>.unmodifiable(_recent);

  bool get hasActivity => _active.isNotEmpty;

  /// The transfer the island should show: the one moving the most bytes.
  DownloadActivity? get primary {
    if (_active.isEmpty) {
      return null;
    }
    DownloadActivity? best;
    for (final DownloadActivity activity in _active.values) {
      if (best == null || activity.bytesPerSecond > best.bytesPerSecond) {
        best = activity;
      }
    }
    return best;
  }

  /// Combined rate of everything in flight.
  double get totalRate {
    var total = 0.0;
    for (final DownloadActivity activity in _active.values) {
      total += activity.bytesPerSecond;
    }
    return total;
  }

  Future<void> setEnabled(bool value) async {
    if (_enabled == value) {
      return;
    }
    _enabled = value;
    if (value) {
      _subscription ??= _bridge.events.listen(_onEvent);
      final bool watching = await _bridge.setEnabled(true);
      _folder = await _bridge.folder();
      if (!watching) {
        _log.warn('The Downloads folder could not be watched.');
      }
    } else {
      await _bridge.setEnabled(false);
      await _subscription?.cancel();
      _subscription = null;
      _active.clear();
      _recent.clear();
    }
    notifyListeners();
  }

  void _onEvent(NativeEvent event) {
    final String id = event.read<String>('id') ?? '';
    if (id.isEmpty) {
      return;
    }
    final String name = event.read<String>('name') ?? '';
    final int bytes = (event.data['bytes'] as num?)?.toInt() ?? 0;
    final DateTime now = DateTime.now();

    switch (event.type) {
      case 'started':
        _active[id] = DownloadActivity(
          id: id,
          name: name,
          bytes: bytes,
          startedAt: now,
          updatedAt: now,
        );
        _log.debug('Started $name.');
        _publishActiveNotification();
        notifyListeners();

      case 'progress':
        final DownloadActivity? existing = _active[id];
        if (existing == null) {
          return;
        }
        _active[id] = existing.copyWith(
          name: name.isEmpty ? existing.name : name,
          bytes: bytes,
          bytesPerSecond:
              (event.data['bytesPerSecond'] as num?)?.toDouble() ?? 0,
          updatedAt: now,
        );
        _publishActiveNotification();
        notifyListeners();

      case 'finished':
        final DownloadOutcome outcome = DownloadActivity.outcomeFromName(
          event.read<String>('outcome'),
        );
        final DownloadActivity? existing = _active.remove(id);
        final DownloadActivity finished =
            (existing ??
                    DownloadActivity(
                      id: id,
                      name: name,
                      bytes: bytes,
                      startedAt: now,
                      updatedAt: now,
                    ))
                .copyWith(
                  name: name.isEmpty ? null : name,
                  bytes: bytes,
                  updatedAt: now,
                  outcome: outcome,
                  bytesPerSecond: 0,
                );
        _remember(finished);
        _announceFinished(finished);
        _publishActiveNotification();
        notifyListeners();

      default:
        break;
    }
  }

  void _remember(DownloadActivity activity) {
    _recent.insert(0, activity);
    final DateTime cutoff = DateTime.now().subtract(recentLifetime);
    _recent.removeWhere((entry) => entry.updatedAt.isBefore(cutoff));
    while (_recent.length > maxRecent) {
      _recent.removeLast();
    }
  }

  /// A single sticky notification represents everything in flight, so ten
  /// parallel downloads are one line on the island rather than ten.
  void _publishActiveNotification() {
    const String id = 'downloads.active';
    if (_active.isEmpty) {
      _notifications.dismiss(id);
      return;
    }
    final DownloadActivity? lead = primary;
    if (lead == null) {
      return;
    }
    final int count = _active.length;
    _notifications.post(
      IslandNotification(
        id: id,
        title: count == 1 ? Formatters.fileName(lead.name) : '$count downloads',
        body:
            '${Formatters.bytes(lead.bytes)} · '
            '${Formatters.rate(totalRate)}',
        kind: NotificationKind.download,
        priority: NotificationPriority.low,
        progress: lead.progress,
        sticky: true,
      ),
    );
  }

  void _announceFinished(DownloadActivity activity) {
    final bool ok = activity.isComplete;
    _notifications.post(
      IslandNotification(
        id: 'downloads.${activity.id}',
        title: Formatters.fileName(activity.name),
        body: ok
            ? 'Downloaded · ${Formatters.bytes(activity.bytes)}'
            : 'Download ${activity.outcome.name}',
        kind: NotificationKind.download,
        priority: ok
            ? NotificationPriority.normal
            : NotificationPriority.normal,
      ),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }
}
