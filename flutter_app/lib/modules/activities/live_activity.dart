import 'package:flutter/widgets.dart';

/// What a live activity is about. Drives its icon and where it sorts.
enum ActivityKind { recording, call, timer, download, media, focus, battery }

/// Something that is happening *now* and is worth a glance while the island is
/// closed.
///
/// This is the piece that makes the island read as a Dynamic Island rather than
/// a menu: a countdown or a transfer stays visible in the collapsed pill, in a
/// few characters, without the user opening anything.
///
/// Activities are derived from the modules that already own the underlying
/// state - they are a *view* of a running timer, not a second copy of it - so
/// there is nothing here to keep in sync.
@immutable
class LiveActivity {
  const LiveActivity({
    required this.id,
    required this.kind,
    required this.icon,
    required this.label,
    this.progress,
    this.tint,
    this.urgent = false,
  });

  final String id;
  final ActivityKind kind;
  final IconData icon;

  /// Short enough for the collapsed pill: a countdown, a percentage, a rate.
  /// Anything longer than about eight characters will be clipped.
  final String label;

  /// 0..1 when it is knowable, null for indeterminate or not applicable.
  final double? progress;

  final Color? tint;

  /// Draws attention: a finished timer, a failed transfer, a critical battery.
  final bool urgent;

  /// Lower sorts first, and first means the leading ear.
  ///
  /// The order is by how time-critical the information is, not by how
  /// interesting it is: a recording indicator is a privacy matter and always
  /// wins; a track that will still be playing in four minutes always loses.
  int get priority {
    switch (kind) {
      case ActivityKind.recording:
        return 0;
      case ActivityKind.call:
        return 1;
      case ActivityKind.timer:
        return 2;
      case ActivityKind.download:
        return 3;
      case ActivityKind.focus:
        return 4;
      case ActivityKind.battery:
        return 5;
      case ActivityKind.media:
        return 6;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is LiveActivity &&
      other.id == id &&
      other.label == label &&
      other.progress == progress &&
      other.urgent == urgent &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(id, label, progress, urgent, kind);

  @override
  String toString() => 'LiveActivity($id, ${kind.name}, $label)';
}
