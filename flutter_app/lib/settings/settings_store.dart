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
  SettingsStore({Directory? directory, File? legacyFile})
    : _directoryOverride = directory,
      _legacyOverride = legacyFile;

  static const Logger _log = Logger('Settings');
  static const String _fileName = 'settings.json';
  static const int _maximumBytes = 65536;

  final Directory? _directoryOverride;
  final File? _legacyOverride;
  Directory? _resolved;
  bool _inspected = false;
  bool _writeAllowed = true;

  Directory get directory {
    final Directory? cached = _resolved ?? _directoryOverride;
    if (cached != null) {
      return _resolved = cached;
    }
    final String appData =
        Platform.environment['APPDATA'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.systemTemp.path;
    return _resolved = Directory('$appData${Platform.pathSeparator}NocUIExperience');
  }

  File get file => File('${directory.path}${Platform.pathSeparator}$_fileName');

  File? get _legacyFile {
    if (_legacyOverride != null) return _legacyOverride;
    // An injected directory is normally used for tests; never read a real
    // user's legacy settings when a test store has been supplied.
    if (_directoryOverride != null) return null;
    final local = Platform.environment['LOCALAPPDATA'];
    if (local == null || local.isEmpty) return null;
    return File('$local${Platform.pathSeparator}NotchUI${Platform.pathSeparator}settings.json');
  }

  Future<Object?> _readBounded(File source) async {
    final input = await source.open();
    try {
      final bytes = await input.read(_maximumBytes + 1);
      if (bytes.length > _maximumBytes) throw const FormatException('Settings file is too large');
      return jsonDecode(utf8.decode(bytes));
    } finally {
      await input.close();
    }
  }

  Future<AppSettings> load() async {
    _inspected = true;
    _writeAllowed = false;
    try {
      final File target = file;
      if (!await target.exists()) {
        final legacy = _legacyFile;
        if (legacy != null && await legacy.exists()) {
          final decoded = await _readBounded(legacy);
          if (decoded is! Map || decoded['SchemaVersion'] != 1 || decoded['Settings'] is! Map) {
            _log.warn('Legacy settings could not be safely migrated; saving is disabled.');
            return AppSettings.defaults;
          }
          final values = decoded['Settings'] as Map;
          final media = values['MediaEnabled'];
          final duration = values['AnimationDurationMs'];
          if ((media != null && media is! bool) || (duration != null && duration is! num)) {
            _log.warn('Legacy settings contain invalid values; saving is disabled.');
            return AppSettings.defaults;
          }
          // Preserve only equivalent settings. Other geometry and behavior
          // settings have different meanings in the Flutter implementation.
          _writeAllowed = true;
          return AppSettings.defaults.copyWith(
            mediaEnabled: media as bool?,
            motionIntensity: duration == 0 ? 0 : null,
          );
        }
        _log.info('No settings file yet; starting from defaults.');
        _writeAllowed = true;
        return AppSettings.defaults;
      }
      final Object? decoded = await _readBounded(target);
      if (decoded is! Map) {
        _log.warn('Settings file is not an object; using defaults.');
        return AppSettings.defaults;
      }
      final version = decoded['schemaVersion'];
      if (version is! int || version != AppSettings.schemaVersion) {
        _log.warn('Settings schema is unsupported; saving is disabled.');
        return AppSettings.defaults;
      }
      final settings = AppSettings.fromJson(decoded.cast<String, Object?>());
      _writeAllowed = true;
      return settings;
    } on FormatException catch (error) {
      _log.warn('Settings file is corrupt; using defaults.', error);
      return AppSettings.defaults;
    } on FileSystemException catch (error) {
      _log.warn('Settings file could not be read; using defaults.', error);
      return AppSettings.defaults;
    }
  }

  Future<bool> save(AppSettings settings) async {
    if (!_inspected) await load();
    if (!_writeAllowed) {
      _log.warn('Settings were not saved because the existing data could not be safely read.');
      return false;
    }
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
