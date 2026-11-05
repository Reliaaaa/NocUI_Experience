import 'native_channel.dart';

/// The result of pulling an image off the clipboard.
class CapturedImage {
  const CapturedImage({
    required this.ok,
    this.width = 0,
    this.height = 0,
  });

  final bool ok;
  final int width;
  final int height;

  static CapturedImage fromMap(Map<Object?, Object?>? map) {
    if (map == null) {
      return const CapturedImage(ok: false);
    }
    return CapturedImage(
      ok: (map['ok'] as bool?) ?? false,
      width: (map['width'] as num?)?.toInt() ?? 0,
      height: (map['height'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Images in and out of the clipboard.
///
/// Windows hands out clipboard images as GDI bitmaps, which cannot cross a
/// platform channel and cannot be written to disk unchanged, so the native side
/// encodes to PNG on the way in and rebuilds a device independent bitmap on the
/// way out. Text does not come through here: Flutter's own clipboard is enough
/// for that.
class ShelfBridge extends NativeChannel {
  ShelfBridge()
    : super('dynamicbar/shelf', eventChannelName: 'dynamicbar/shelf/events');

  /// Whether the clipboard is holding something that can be shelved as an
  /// image right now.
  Future<bool> hasImage() async => await invoke<bool>('hasImage') ?? false;

  /// Writes the clipboard image to [path] as a PNG.
  Future<CapturedImage> captureImage(String path) async =>
      CapturedImage.fromMap(
        await invokeMap('captureImage', <String, Object?>{'path': path}),
      );

  /// Re-encodes any image Windows can read - JPEG, BMP, GIF, WebP, TIFF - into
  /// a PNG at [path]. The shelf stores one format so the page needs one
  /// decoder and one extension.
  Future<CapturedImage> importImage(String source, String path) async =>
      CapturedImage.fromMap(
        await invokeMap('importImage', <String, Object?>{
          'source': source,
          'path': path,
        }),
      );

  /// Puts a shelved PNG back on the clipboard, ready to paste anywhere.
  Future<bool> copyImage(String path) async =>
      await invoke<bool>('copyImage', <String, Object?>{'path': path}) ?? false;
}
