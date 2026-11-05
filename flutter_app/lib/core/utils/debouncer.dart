import 'dart:async';

/// Collapses a burst of calls into a single delayed one.
///
/// Used for anything that writes to disk or crosses the platform channel more
/// often than it needs to (settings saves, placement updates).
class Debouncer {
  Debouncer(this.duration);

  final Duration duration;
  Timer? _timer;

  bool get isPending => _timer?.isActive ?? false;

  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }

  /// Runs a pending action immediately, if there is one.
  void flush(void Function() action) {
    if (_timer?.isActive ?? false) {
      _timer!.cancel();
      _timer = null;
      action();
    }
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => cancel();
}
