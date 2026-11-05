import 'native_channel.dart';

/// Watches the Downloads folder for transfer activity.
class DownloadsBridge extends NativeChannel {
  DownloadsBridge()
    : super(
        'dynamicbar/downloads',
        eventChannelName: 'dynamicbar/downloads/events',
      );

  Future<bool> setEnabled(bool enabled) async =>
      await invoke<bool>('setEnabled', <String, Object?>{'enabled': enabled}) ??
      false;

  Future<String> folder() async => await invoke<String>('folder') ?? '';
}
