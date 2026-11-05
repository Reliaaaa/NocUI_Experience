import 'models/native_models.dart';
import 'native_channel.dart';

/// Notification area icon and context menu.
class TrayBridge extends NativeChannel {
  TrayBridge()
    : super('dynamicbar/tray', eventChannelName: 'dynamicbar/tray/events');

  Future<bool> install({required String tooltip}) async =>
      await invoke<bool>('install', <String, Object?>{'tooltip': tooltip}) ??
      false;

  Future<void> setTooltip(String tooltip) =>
      invoke<void>('setTooltip', <String, Object?>{'tooltip': tooltip});

  Future<void> setMenu(List<TrayMenuEntry> items) =>
      invoke<void>('setMenu', <String, Object?>{
        'items': items.map((item) => item.toMap()).toList(growable: false),
      });

  Future<void> showMenu() => invoke<void>('showMenu');

  /// Shows a shell balloon. This is the notification mechanism available to an
  /// unpackaged Win32 application; see docs/WINDOWS_INTEGRATION.md for why the
  /// packaged toast APIs are not used.
  Future<void> showBalloon({
    required String title,
    required String body,
    int level = 0,
  }) => invoke<void>('showBalloon', <String, Object?>{
    'title': title,
    'body': body,
    'level': level,
  });

  Future<void> remove() => invoke<void>('remove');
}
