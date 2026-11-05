/// How a transfer ended.
enum DownloadOutcome { active, completed, cancelled, failed }

/// One file arriving in the Downloads folder.
///
/// [totalBytes] is deliberately nullable. A partially written download does not
/// carry its final size anywhere the file system can see, so for most of a
/// transfer the honest answer is "unknown", and the UI shows an indeterminate
/// bar with a real transfer rate rather than a percentage that was guessed.
class DownloadActivity {
  const DownloadActivity({
    required this.id,
    required this.name,
    required this.bytes,
    required this.startedAt,
    required this.updatedAt,
    this.totalBytes,
    this.bytesPerSecond = 0,
    this.outcome = DownloadOutcome.active,
  });

  final String id;
  final String name;
  final int bytes;
  final int? totalBytes;
  final double bytesPerSecond;
  final DateTime startedAt;
  final DateTime updatedAt;
  final DownloadOutcome outcome;

  bool get isActive => outcome == DownloadOutcome.active;
  bool get isComplete => outcome == DownloadOutcome.completed;
  bool get hasFailed =>
      outcome == DownloadOutcome.failed || outcome == DownloadOutcome.cancelled;

  /// 0..1, or null when the total size is not knowable.
  double? get progress {
    final int? total = totalBytes;
    if (total == null || total <= 0) {
      return null;
    }
    return (bytes / total).clamp(0.0, 1.0).toDouble();
  }

  Duration get duration => updatedAt.difference(startedAt);

  DownloadActivity copyWith({
    String? name,
    int? bytes,
    int? totalBytes,
    double? bytesPerSecond,
    DateTime? updatedAt,
    DownloadOutcome? outcome,
  }) {
    return DownloadActivity(
      id: id,
      name: name ?? this.name,
      bytes: bytes ?? this.bytes,
      totalBytes: totalBytes ?? this.totalBytes,
      bytesPerSecond: bytesPerSecond ?? this.bytesPerSecond,
      startedAt: startedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      outcome: outcome ?? this.outcome,
    );
  }

  static DownloadOutcome outcomeFromName(String? name) {
    switch (name) {
      case 'completed':
        return DownloadOutcome.completed;
      case 'cancelled':
        return DownloadOutcome.cancelled;
      case 'failed':
        return DownloadOutcome.failed;
      default:
        return DownloadOutcome.active;
    }
  }
}
