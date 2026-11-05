import 'dart:convert';
import 'dart:io';

import '../core/logging/app_logger.dart';
import 'app_settings.dart';

/// Reads and writes the settings document.
///
/// Writes go to a temporary file first and are then renamed over the real one,
/// so a crash or a power cut during a save can never leave a half written
/// settings file behind — the worst case is the previous good copy.
class SettingsStore {
  SettingsStore({Directory? directory}) : _directoryOverride = directory;

  static const Logger _log = Logger('Settings');
  static const String _fileName = 'settings.json';

  final Directory? _directoryOverride;
  Directory? _resolved;

  Directory get directory {
    final Directory? cached = _resolved ?? _directoryOverride;
    if (cached != null) {
      return _resolved = cached;
    }
    final String appData =
        Platform.environment['APPDATA'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.systemTemp.path;
    return _resolved = Directory('$appData${Platform.pathSeparator}DynamicBar');
  }

  File get file => File('${directory.path}${Platform.pathSeparator}$_fileName');

  Future<AppSettings> load() async {
    try {
      final File target = file;
      if (!target.existsSync()) {
        _log.info('No settings file yet; starting from defaults.');
        return AppSettings.defaults;
      }
      final String raw = await target.readAsString();
      if (raw.trim().isEmpty) {
        return AppSettings.defaults;
      }
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) {
        _log.warn('Settings file is not an object; using defaults.');
        return AppSettings.defaults;
      }
      return AppSettings.fromJson(decoded.cast<String, Object?>());
    } on FormatException catch (error) {
      _log.warn('Settings file is corrupt; using defaults.', error);
      return AppSettings.defaults;
    } on FileSystemException catch (error) {
      _log.warn('Settings file could not be read; using defaults.', error);
      return AppSettings.defaults;
    }
  }

  Future<bool> save(AppSettings settings) async {
    try {
      final Directory target = directory;
      if (!target.existsSync()) {
        await target.create(recursive: true);
      }
      final File temporary = File(
        '${target.path}${Platform.pathSeparator}$_fileName.tmp',
      );
      const JsonEncoder encoder = JsonEncoder.withIndent('  ');
      await temporary.writeAsString(
        encoder.convert(settings.toJson()),
        flush: true,
      );
      await temporary.rename(file.path);
      return true;
    } on FileSystemException catch (error, stackTrace) {
      _log.error('Could not save settings.', error, stackTrace);
      return false;
    }
  }
}
