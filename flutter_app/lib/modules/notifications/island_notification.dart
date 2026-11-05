import 'dart:ui' show Color;

/// How insistent a notification is allowed to be.
///
/// This is a promise about interruption, not decoration. Low never changes the
/// island's shape, normal peeks, and high peeks and holds. Nothing here can
/// take over the screen or steal focus - an overlay that interrupts is an
/// overlay that gets uninstalled.
enum NotificationPriority { low, normal, high }

extension NotificationPriorityX on NotificationPriority {
  /// How long the island holds the notification before returning to whatever it
  /// was showing.
  Duration get defaultLifetime {
    switch (this) {
      case NotificationPriority.low:
        return const Duration(milliseconds: 2200);
      case NotificationPriority.normal:
        return const Duration(milliseconds: 3600);
      case NotificationPriority.high:
        return const Duration(milliseconds: 5200);
    }
  }

  /// Whether the island grows for this notification, or merely re-labels its
  /// collapsed self.
  bool get peeks => this != NotificationPriority.low;
}

/// What a notification is about. Drives the icon and the accent.
enum NotificationKind {
  info,
  success,
  warning,
  error,
  media,
  download,
  clipboard,
  timer,
  system,
}

/// A transient message shown by the island.
class IslandNotification {
  IslandNotification({
    required this.id,
    required this.title,
    this.body = '',
    this.kind = NotificationKind.info,
    this.priority = NotificationPriority.normal,
    this.lifetime,
    this.progress,
    this.accent,
    this.sticky = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String title;
  final String body;
  final NotificationKind kind;
  final NotificationPriority priority;

  /// Overrides the priority's default lifetime.
  final Duration? lifetime;

  /// 0..1 for determinate progress, null for indeterminate or none.
  final double? progress;

  final Color? accent;

  /// Sticky notifications stay until something dismisses them explicitly. Used
  /// for a download that is still running, never for a message.
  final bool sticky;

  final DateTime createdAt;

  Duration get effectiveLifetime => lifetime ?? priority.defaultLifetime;

  IslandNotification copyWith({
    String? title,
    String? body,
    NotificationKind? kind,
    NotificationPriority? priority,
    Duration? lifetime,
    double? progress,
    bool clearProgress = false,
    Color? accent,
    bool? sticky,
  }) {
    return IslandNotification(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      kind: kind ?? this.kind,
      priority: priority ?? this.priority,
      lifetime: lifetime ?? this.lifetime,
      progress: clearProgress ? null : (progress ?? this.progress),
      accent: accent ?? this.accent,
      sticky: sticky ?? this.sticky,
      createdAt: createdAt,
    );
  }

  @override
  String toString() => 'IslandNotification($id, ${kind.name}, $title)';
}
