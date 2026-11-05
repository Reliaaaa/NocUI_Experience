import 'native_channel.dart';

/// Opens things: applications, folders, web addresses and Windows panels.
///
/// The only outward-facing call in the application, and it is always something
/// the user just clicked. Nothing here observes, polls or reports back, so
/// there is no state to switch off.
class ShellBridge extends NativeChannel {
  ShellBridge() : super('dynamicbar/shell');

  /// Hands a target to the Windows shell. A path, a `shell:` folder, a
  /// protocol such as `ms-settings:sound`, or an `https://` address - Windows
  /// resolves all four the same way.
  ///
  /// Returns false when nothing could open it, which the caller shows rather
  /// than swallowing: "nothing happened" is the worst possible answer to a
  /// click.
  Future<bool> open(String target, {String arguments = ''}) async =>
      await invoke<bool>('open', <String, Object?>{
        'target': target,
        'args': arguments,
      }) ??
      false;

  /// Opens the containing folder with the file selected.
  Future<bool> reveal(String path) async =>
      await invoke<bool>('reveal', <String, Object?>{'path': path}) ?? false;

  Future<bool> exists(String path) async =>
      await invoke<bool>('exists', <String, Object?>{'path': path}) ?? false;
}
