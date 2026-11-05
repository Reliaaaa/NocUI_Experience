import 'dart:async';

import 'app_event.dart';

/// A tiny typed broadcast bus.
///
/// Deliberately not a package: the whole contract is "publish an [AppEvent],
/// listen to a subtype", and a StreamController does that in a dozen lines
/// without adding a dependency or a code generator.
class EventBus {
  final StreamController<AppEvent> _controller =
      StreamController<AppEvent>.broadcast(sync: false);

  bool _closed = false;

  /// Events of type [T] only.
  Stream<T> on<T extends AppEvent>() =>
      _controller.stream.where((event) => event is T).cast<T>();

  Stream<AppEvent> get all => _controller.stream;

  void emit(AppEvent event) {
    if (_closed) {
      return;
    }
    _controller.add(event);
  }

  Future<void> dispose() async {
    if (_closed) {
      return;
    }
    _closed = true;
    await _controller.close();
  }
}
