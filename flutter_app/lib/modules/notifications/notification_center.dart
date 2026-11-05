import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/logging/app_logger.dart';
import 'island_notification.dart';

/// Holds the transient messages the island is showing or about to show.
///
/// Rules, in order:
///
/// * One at a time. Stacking notifications on a 200px surface produces noise,
///   not information; extras queue and are counted.
/// * Higher priority arrives ahead of the queue, but never cuts off a message
///   that is already on screen mid-read - it takes over once the current one
///   has had a minimum time to be seen.
/// * Replacing by id updates in place, so a download that reports progress
///   twenty times is one notification, not twenty.
class NotificationCenter extends ChangeNotifier {
  NotificationCenter({this.maxQueued = 5});

  static const Logger _log = Logger('Notifications');

  /// Shortest time a notification is allowed on screen before something more
  /// urgent may replace it.
  static const Duration minimumOnScreen = Duration(milliseconds: 700);

  final int maxQueued;

  final List<IslandNotification> _queue = <IslandNotification>[];
  IslandNotification? _current;
  DateTime? _currentSince;
  Timer? _dismissTimer;
  bool _enabled = true;

  IslandNotification? get current => _current;
  List<IslandNotification> get queued =>
      List<IslandNotification>.unmodifiable(_queue);
  int get pendingCount => _queue.length;
  bool get hasNotification => _current != null;

  bool get isEnabled => _enabled;

  set enabled(bool value) {
    if (_enabled == value) {
      return;
    }
    _enabled = value;
    if (!value) {
      clear();
    }
  }

  /// Posts a notification, or updates the one already carrying this id.
  void post(IslandNotification notification) {
    if (!_enabled) {
      return;
    }

    if (_current?.id == notification.id) {
      _current = notification;
      _restartDismissTimer();
      notifyListeners();
      return;
    }

    final int queuedIndex = _queue.indexWhere(
      (entry) => entry.id == notification.id,
    );
    if (queuedIndex >= 0) {
      _queue[queuedIndex] = notification;
      notifyListeners();
      return;
    }

    if (_current == null) {
      _show(notification);
      return;
    }

    if (_shouldPreempt(notification)) {
      _queue.insert(0, _current!);
      _show(notification);
      return;
    }

    _queue.add(notification);
    if (_queue.length > maxQueued) {
      // Drop the oldest low priority entry rather than the newest message.
      final int victim = _queue.indexWhere(
        (entry) => entry.priority == NotificationPriority.low,
      );
      _queue.removeAt(victim >= 0 ? victim : 0);
    }
    notifyListeners();
  }

  bool _shouldPreempt(IslandNotification candidate) {
    final IslandNotification? current = _current;
    final DateTime? since = _currentSince;
    if (current == null || since == null) {
      return true;
    }
    if (candidate.priority.index <= current.priority.index) {
      return false;
    }
    return DateTime.now().difference(since) >= minimumOnScreen;
  }

  void _show(IslandNotification notification) {
    _current = notification;
    _currentSince = DateTime.now();
    _restartDismissTimer();
    _log.debug('Showing ${notification.id} (${notification.kind.name}).');
    notifyListeners();
  }

  void _restartDismissTimer() {
    _dismissTimer?.cancel();
    final IslandNotification? current = _current;
    if (current == null || current.sticky) {
      return;
    }
    _dismissTimer = Timer(current.effectiveLifetime, () {
      if (_current?.id == current.id) {
        dismiss(current.id);
      }
    });
  }

  /// Removes a notification whether it is on screen or still queued.
  void dismiss(String id) {
    if (_current?.id == id) {
      _dismissTimer?.cancel();
      _dismissTimer = null;
      _current = null;
      _currentSince = null;
      if (_queue.isNotEmpty) {
        _queue.sort((a, b) {
          final int byPriority = b.priority.index.compareTo(a.priority.index);
          if (byPriority != 0) {
            return byPriority;
          }
          return a.createdAt.compareTo(b.createdAt);
        });
        _show(_queue.removeAt(0));
      } else {
        notifyListeners();
      }
      return;
    }
    final int before = _queue.length;
    _queue.removeWhere((entry) => entry.id == id);
    if (_queue.length != before) {
      notifyListeners();
    }
  }

  /// Dismisses whatever is on screen. Bound to the island's close affordance.
  void dismissCurrent() {
    final IslandNotification? current = _current;
    if (current != null) {
      dismiss(current.id);
    }
  }

  void clear() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _queue.clear();
    _current = null;
    _currentSince = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    super.dispose();
  }
}
