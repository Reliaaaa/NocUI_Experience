import 'dart:async';
import 'dart:ui';

import 'models/native_models.dart';
import 'native_channel.dart';

/// Control surface for the transparent stage window.
///
/// Everything here is deliberately cheap and rare. The island animates entirely
/// inside Flutter, so the only calls that happen during normal interaction are
/// [setInteractiveRects] (twice per expand/collapse cycle) and [setFocusable].
class WindowBridge extends NativeChannel {
  WindowBridge()
    : super('dynamicbar/window', eventChannelName: 'dynamicbar/window/events');

  Future<StageInfo> describe() async =>
      StageInfo.fromMap(await invokeMap('describe'));

  /// Moves and resizes the stage. All values are logical pixels.
  Future<StageInfo> setPlacement({
    String? monitorId,
    double? width,
    double? height,
    double? alignX,
    double? offsetX,
    double? offsetY,
    bool? useWorkArea,
  }) async {
    final result = await invokeMap('setPlacement', <String, Object?>{
      'monitorId': ?monitorId,
      'width': ?width,
      'height': ?height,
      'alignX': ?alignX,
      'offsetX': ?offsetX,
      'offsetY': ?offsetY,
      'useWorkArea': ?useWorkArea,
    });
    return StageInfo.fromMap(result);
  }

  /// Regions of the stage that accept mouse input. Everything else is
  /// click-through, so the empty stage never blocks the desktop underneath.
  Future<void> setInteractiveRects(List<Rect> rects) =>
      invoke<void>('setInteractiveRects', <String, Object?>{
        'rects': rects
            .map(
              (rect) => <String, Object?>{
                'left': rect.left,
                'top': rect.top,
                'right': rect.right,
                'bottom': rect.bottom,
              },
            )
            .toList(growable: false),
      });

  Future<void> setVisible(bool visible) =>
      invoke<void>('setVisible', <String, Object?>{'visible': visible});

  /// When false, the island can be clicked without stealing focus from the
  /// application the user is actually working in.
  Future<void> setFocusable(bool focusable) =>
      invoke<void>('setFocusable', <String, Object?>{'focusable': focusable});

  Future<void> setIgnoreMouse(bool ignore) =>
      invoke<void>('setIgnoreMouse', <String, Object?>{'ignore': ignore});

  Future<void> setAlwaysOnTop(bool value) =>
      invoke<void>('setAlwaysOnTop', <String, Object?>{'value': value});

  Future<void> assertTopmost() => invoke<void>('assertTopmost');

  Future<void> requestFocus() => invoke<void>('requestFocus');

  /// While on, any mouse button pressed outside the island raises a
  /// `clickOutside` event. Held only while the island is open.
  Future<void> setOutsideClickWatch(bool enabled) => invoke<void>(
        'setOutsideClickWatch',
        <String, Object?>{'enabled': enabled},
      );

  /// While on, the cursor crossing into or out of the reveal zone raises a
  /// `proximity` event. Held only while the island is hidden by auto-hide.
  Future<void> setProximityWatch(bool enabled) => invoke<void>(
        'setProximityWatch',
        <String, Object?>{'enabled': enabled},
      );

  /// The area the cursor has to reach for a hidden island to come back, in
  /// logical stage coordinates.
  Future<void> setRevealZone(Rect zone) =>
      invoke<void>('setRevealZone', <String, Object?>{
        'left': zone.left,
        'top': zone.top,
        'right': zone.right,
        'bottom': zone.bottom,
      });

  Future<bool> systemPrefersDarkMode() async =>
      await invoke<bool>('systemPrefersDarkMode') ?? true;

  Future<String> nativeLogPath() async => await invoke<String>('logPath') ?? '';

  /// Appends a Dart log record to the native log file.
  ///
  /// Fire and forget: the result is never awaited, because a log line must not
  /// be able to stall the caller.
  void writeLog({
    required String level,
    required String tag,
    required String message,
  }) {
    unawaited(
      invoke<void>('log', <String, Object?>{
        'level': level,
        'tag': tag,
        'message': message,
      }),
    );
  }

  Future<void> quit() => invoke<void>('quit');
}
