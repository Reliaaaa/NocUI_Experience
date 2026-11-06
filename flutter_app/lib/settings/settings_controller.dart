import 'dart:convert';

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
  }) : _remoteUpdate = null {
    _store = store;
    _theme = theme;
  }

  /// A settings window is a second engine; its changes are forwarded to the
  /// owner, which alone persists the document and applies system side effects.
  SettingsController.remote({
    required ThemeController theme,
    required Future<Map<String, Object?>> Function(Map<String, Object?>) update,
    SettingsStore? store,
  }) : _remoteUpdate = update {
    _store = store ?? SettingsStore();
    _theme = theme;
  }

  static const Logger _log = Logger('Settings');

  late final SettingsStore _store;
  late final ThemeController _theme;
  final Future<Map<String, Object?>> Function(Map<String, Object?>)? _remoteUpdate;
  Future<void>? _remoteDrain;
  final Map<String, Object?> _queued = <String, Object?>{};
  final Map<String, Object?> _pending = <String, Object?>{};
  final Map<String, int> _pendingGeneration = <String, int>{};
  Map<String, Object?>? _ownerSnapshot;
  int _generation = 0;
  String? remoteError;
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
    final previous = _settings.toJson();
    final values = next.toJson();
    _settings = next;
    _applyToTheme();
    notifyListeners();
    final remote = _remoteUpdate;
    if (remote == null) {
      _writeDebouncer.run(_write);
      return;
    }
    final patch = <String, Object?>{};
    for (final entry in values.entries) {
      if (jsonEncode(previous[entry.key]) != jsonEncode(entry.value)) {
        patch[entry.key] = entry.value;
      }
    }
    if (patch.isEmpty) return;
    final generation = ++_generation;
    _pending.addAll(patch);
    for (final key in patch.keys) {
      _pendingGeneration[key] = generation;
    }
    _queued.addAll(patch);
    _scheduleRemote();
  }

  void _scheduleRemote() {
    if (_remoteDrain != null) return;
    _remoteDrain = _drainRemote().whenComplete(() {
      _remoteDrain = null;
      if (_queued.isNotEmpty) _scheduleRemote();
    });
  }

  Future<void> _drainRemote() async {
    while (_queued.isNotEmpty) {
      final patch = Map<String, Object?>.of(_queued);
      _queued.clear();
      final generations = <String, int>{
        for (final key in patch.keys) key: _pendingGeneration[key]!,
      };
      try {
        final snapshot = await _remoteUpdate!(patch);
        for (final entry in patch.entries) {
          if (_pendingGeneration[entry.key] == generations[entry.key]) {
            _pending.remove(entry.key);
            _pendingGeneration.remove(entry.key);
          }
        }
        remoteError = null;
        applyRemote(snapshot);
      } catch (error, stack) {
        for (final key in patch.keys) {
          if (_pendingGeneration[key] == generations[key]) {
            _pending.remove(key);
            _pendingGeneration.remove(key);
          }
        }
        remoteError = 'Settings could not be applied. Please reopen settings and try again.';
        _log.error('Settings update failed.', error, stack);
        final owner = _ownerSnapshot;
        if (owner != null) {
          applyRemote(owner);
        } else {
          notifyListeners();
        }
      }
    }
  }

  /// Adopt an owner snapshot while keeping locally queued edits visible.
  void applyRemote(Map<String, Object?> values) {
    _ownerSnapshot = Map<String, Object?>.of(values);
    _settings = AppSettings.fromJson(<String, Object?>{...values, ..._pending});
    _loaded = true;
    _applyToTheme();
    notifyListeners();
  }

  void mutate(AppSettings Function(AppSettings current) transform) =>
      update(transform(_settings));

  /// Writes immediately, skipping the debounce. Used on shutdown.
  Future<void> flush() async {
    if (_remoteUpdate != null) {
      while (_remoteDrain != null) {
        await _remoteDrain;
      }
      return;
    }
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
