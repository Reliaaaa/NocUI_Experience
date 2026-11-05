import 'dart:async';

import 'package:flutter/services.dart';

import '../core/logging/app_logger.dart';
import 'models/native_models.dart';

/// Base class for the Dart side of a native service.
///
/// Every native call is funnelled through [invoke] so that a missing or failing
/// platform implementation degrades to a logged warning and a null result
/// instead of an unhandled exception on the UI thread. The island has to
/// survive a Windows capability being unavailable, not crash with it.
abstract class NativeChannel {
  NativeChannel(String methodChannelName, {String? eventChannelName})
    : _method = MethodChannel(methodChannelName),
      _event = eventChannelName == null ? null : EventChannel(eventChannelName),
      log = Logger(methodChannelName.split('/').last);

  final MethodChannel _method;
  final EventChannel? _event;
  final Logger log;

  Stream<NativeEvent>? _events;

  /// Broadcast stream of `{type, ...}` events from the native side.
  ///
  /// Returns an empty stream when this channel has no event channel, so callers
  /// never need a null check.
  Stream<NativeEvent> get events {
    final channel = _event;
    if (channel == null) {
      return const Stream<NativeEvent>.empty();
    }
    return _events ??= channel
        .receiveBroadcastStream()
        .map(NativeEvent.fromMap)
        .where((event) => event != null)
        .cast<NativeEvent>()
        .handleError((Object error, StackTrace stackTrace) {
          log.error('Native event stream failed.', error, stackTrace);
        });
  }

  Future<T?> invoke<T>(String method, [Map<String, Object?>? arguments]) async {
    try {
      return await _method.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      log.warn('Native method "$method" is not available on this platform.');
      return null;
    } on PlatformException catch (error, stackTrace) {
      log.error('Native method "$method" failed.', error, stackTrace);
      return null;
    }
  }

  Future<Map<Object?, Object?>?> invokeMap(
    String method, [
    Map<String, Object?>? arguments,
  ]) => invoke<Map<Object?, Object?>>(method, arguments);

  Future<List<Object?>> invokeList(
    String method, [
    Map<String, Object?>? arguments,
  ]) async =>
      await invoke<List<Object?>>(method, arguments) ?? const <Object?>[];
}
