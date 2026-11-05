import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';

import '../tokens/db_colors.dart';
import '../tokens/db_motion.dart';
import 'island_theme.dart';

/// Which brightness the island follows.
enum AppearanceMode { system, dark, light }

extension AppearanceModeX on AppearanceMode {
  String get label {
    switch (this) {
      case AppearanceMode.system:
        return 'Follow Windows';
      case AppearanceMode.dark:
        return 'Dark';
      case AppearanceMode.light:
        return 'Light';
    }
  }

  static AppearanceMode fromName(String? name) {
    for (final mode in AppearanceMode.values) {
      if (mode.name == name) {
        return mode;
      }
    }
    return AppearanceMode.system;
  }
}

/// Owns appearance state and hands out a cached [IslandThemeData].
///
/// The data object is rebuilt only when one of its inputs actually changes, so
/// `IslandTheme.updateShouldNotify` can compare by identity and the whole tree
/// is spared a rebuild on unrelated notifications.
class ThemeController extends ChangeNotifier {
  ThemeController();

  AppearanceMode _appearance = AppearanceMode.system;
  AccentPreset _accent = AccentPreset.graphite;
  double _surfaceOpacity = 0.94;
  double _cornerScale = 1.0;
  double _islandScale = 1.0;
  double _motionIntensity = 1.0;
  bool _systemIsDark = true;

  IslandThemeData? _cache;

  AppearanceMode get appearance => _appearance;
  AccentPreset get accent => _accent;
  double get surfaceOpacity => _surfaceOpacity;
  double get cornerScale => _cornerScale;
  double get islandScale => _islandScale;
  double get motionIntensity => _motionIntensity;
  bool get systemIsDark => _systemIsDark;

  bool get isDark {
    switch (_appearance) {
      case AppearanceMode.system:
        return _systemIsDark;
      case AppearanceMode.dark:
        return true;
      case AppearanceMode.light:
        return false;
    }
  }

  IslandThemeData get data => _cache ??= _build();

  IslandThemeData _build() {
    final Color accentColor = _accent.color;
    final IslandPalette palette = isDark
        ? IslandPalette.dark(accent: accentColor, opacity: _surfaceOpacity)
        : IslandPalette.light(accent: accentColor, opacity: _surfaceOpacity);
    return IslandThemeData(
      palette: palette,
      motion: MotionProfile.fromIntensity(_motionIntensity),
      surfaceOpacity: _surfaceOpacity,
      cornerScale: _cornerScale,
      islandScale: _islandScale,
    );
  }

  void _invalidate() {
    _cache = null;
    notifyListeners();
  }

  set appearance(AppearanceMode value) {
    if (_appearance == value) {
      return;
    }
    _appearance = value;
    _invalidate();
  }

  set accent(AccentPreset value) {
    if (_accent == value) {
      return;
    }
    _accent = value;
    _invalidate();
  }

  set surfaceOpacity(double value) {
    final double clamped = value.clamp(0.55, 1.0);
    if ((_surfaceOpacity - clamped).abs() < 0.001) {
      return;
    }
    _surfaceOpacity = clamped;
    _invalidate();
  }

  set cornerScale(double value) {
    final double clamped = value.clamp(0.4, 1.6);
    if ((_cornerScale - clamped).abs() < 0.001) {
      return;
    }
    _cornerScale = clamped;
    _invalidate();
  }

  set islandScale(double value) {
    final double clamped = value.clamp(0.85, 1.35);
    if ((_islandScale - clamped).abs() < 0.001) {
      return;
    }
    _islandScale = clamped;
    _invalidate();
  }

  set motionIntensity(double value) {
    final double clamped = value.clamp(0.0, 1.4);
    if ((_motionIntensity - clamped).abs() < 0.001) {
      return;
    }
    _motionIntensity = clamped;
    _invalidate();
  }

  /// Pushed by the native layer when Windows switches light/dark.
  void setSystemIsDark(bool value) {
    if (_systemIsDark == value) {
      return;
    }
    _systemIsDark = value;
    if (_appearance == AppearanceMode.system) {
      _invalidate();
    }
  }
}
