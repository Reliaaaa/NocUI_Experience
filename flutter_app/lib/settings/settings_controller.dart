import 'package:flutter/foundation.dart';

import '../core/logging/app_logger.dart';
import '../core/utils/debouncer.dart';
import '../design/theme/theme_controller.dart';
import 'app_settings.dart';
import 'settings_store.dart';

/// Owns the persisted document and is the only writer of it.
///
/// Live appearance state lives in [ThemeController]; this class keeps the two
/// in step and batches disk writes, so dragging a slider does not produce one
/// file write per frame.
class SettingsController extends ChangeNotifier {
  SettingsController({
    required SettingsStore store,
    required ThemeController theme,
  }) {
    _store = store;
    _theme = theme;
  }

  static const Logger _log = Logger('Settings');

  late final SettingsStore _store;
  late final ThemeController _theme;
  final Debouncer _writeDebouncer = Debouncer(
    const Duration(milliseconds: 600),
  );

  AppSettings _settings = AppSettings.defaults;
  bool _loaded = false;

  AppSettings get settings => _settings;
  bool get isLoaded => _loaded;

  /// Absolute path of the settings file, for the diagnostics screen.
  String get filePath => _store.file.path;

  Future<void> load() async {
    _settings = await _store.load();
    _loaded = true;
    _applyToTheme();
    notifyListeners();
    _log.info('Settings loaded from ${_store.file.path}.');
  }

  /// Replaces the document. Appearance changes are applied to the live theme
  /// immediately; the disk write is debounced.
  void update(AppSettings next) {
    if (identical(next, _settings)) {
      return;
    }
    _settings = next;
    _applyToTheme();
    notifyListeners();
    _writeDebouncer.run(_write);
  }

  void mutate(AppSettings Function(AppSettings current) transform) =>
      update(transform(_settings));

  /// Writes immediately, skipping the debounce. Used on shutdown.
  Future<void> flush() async {
    _writeDebouncer.cancel();
    await _write();
  }

  Future<void> _write() async {
    final bool ok = await _store.save(_settings);
    if (!ok) {
      _log.warn('Settings could not be persisted; keeping them in memory.');
    }
  }

  void _applyToTheme() {
    _theme
      ..appearance = _settings.appearance
      ..accent = _settings.accent
      ..surfaceOpacity = _settings.surfaceOpacity
      ..cornerScale = _settings.cornerScale
      ..islandScale = _settings.islandScale
      ..motionIntensity = _settings.motionIntensity;
  }

  @override
  void dispose() {
    _writeDebouncer.dispose();
    super.dispose();
  }
}
