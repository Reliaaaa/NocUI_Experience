import 'native_channel.dart';

/// Clipboard activity notifications.
///
/// The native side reports the shape of what was copied, not its contents,
/// unless text previews have been explicitly turned on in Privacy settings.
class ClipboardBridge extends NativeChannel {
  ClipboardBridge()
    : super(
        'dynamicbar/clipboard',
        eventChannelName: 'dynamicbar/clipboard/events',
      );

  Future<bool> setEnabled(bool enabled) async =>
      await invoke<bool>('setEnabled', <String, Object?>{'enabled': enabled}) ??
      false;

  /// Opt in to a short, single line preview of copied text.
  Future<void> setTextPreview({required bool enabled, int length = 80}) =>
      invoke<void>('setTextPreview', <String, Object?>{
        'enabled': enabled,
        'length': length,
      });
}
