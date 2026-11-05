import 'package:flutter/widgets.dart';

import '../tokens/db_colors.dart';
import '../tokens/db_motion.dart';

/// The resolved design system for one build.
///
/// Widgets read colour and motion from here and nowhere else, which is what
/// makes theme and reduced-motion changes a single rebuild rather than a sweep
/// through the widget tree.
class IslandThemeData {
  const IslandThemeData({
    required this.palette,
    required this.motion,
    required this.surfaceOpacity,
    required this.cornerScale,
    required this.islandScale,
  });

  final IslandPalette palette;
  final MotionProfile motion;

  /// How solid the island glass is. 1.0 is opaque.
  final double surfaceOpacity;

  /// Multiplier applied to every corner radius, so the user can go from a
  /// rounded pill to a squarer bar.
  final double cornerScale;

  /// Multiplier applied to the island footprint, independent of DPI scaling.
  final double islandScale;

  IslandThemeData copyWith({
    IslandPalette? palette,
    MotionProfile? motion,
    double? surfaceOpacity,
    double? cornerScale,
    double? islandScale,
  }) {
    return IslandThemeData(
      palette: palette ?? this.palette,
      motion: motion ?? this.motion,
      surfaceOpacity: surfaceOpacity ?? this.surfaceOpacity,
      cornerScale: cornerScale ?? this.cornerScale,
      islandScale: islandScale ?? this.islandScale,
    );
  }
}

/// Provides [IslandThemeData] to the tree.
class IslandTheme extends InheritedWidget {
  const IslandTheme({required this.data, required super.child, super.key});

  final IslandThemeData data;

  static IslandThemeData of(BuildContext context) {
    final theme = context.dependOnInheritedWidgetOfExactType<IslandTheme>();
    assert(theme != null, 'No IslandTheme found in the widget tree.');
    return theme!.data;
  }

  /// Reads the theme without subscribing. For one-off lookups inside callbacks.
  static IslandThemeData read(BuildContext context) {
    final theme = context.getInheritedWidgetOfExactType<IslandTheme>();
    assert(theme != null, 'No IslandTheme found in the widget tree.');
    return theme!.data;
  }

  @override
  bool updateShouldNotify(IslandTheme oldWidget) =>
      oldWidget.data.palette != data.palette ||
      oldWidget.data.motion.intensity != data.motion.intensity ||
      oldWidget.data.surfaceOpacity != data.surfaceOpacity ||
      oldWidget.data.cornerScale != data.cornerScale ||
      oldWidget.data.islandScale != data.islandScale;
}
