import 'dart:ui';

/// Accent presets.
///
/// The default is deliberately the most restrained of the set: on a surface
/// this small, a saturated accent reads as noise. Colour is used to mark one
/// thing at a time, never to decorate.
enum AccentPreset { graphite, blue, purple, emerald, amber, crimson }

extension AccentPresetX on AccentPreset {
  String get label {
    switch (this) {
      case AccentPreset.graphite:
        return 'Graphite';
      case AccentPreset.blue:
        return 'Blue';
      case AccentPreset.purple:
        return 'Purple';
      case AccentPreset.emerald:
        return 'Emerald';
      case AccentPreset.amber:
        return 'Amber';
      case AccentPreset.crimson:
        return 'Crimson';
    }
  }

  Color get color {
    switch (this) {
      case AccentPreset.graphite:
        return const Color(0xFFC3CAD6);
      case AccentPreset.blue:
        return const Color(0xFF3B8CFF);
      case AccentPreset.purple:
        return const Color(0xFF9A7CFF);
      case AccentPreset.emerald:
        return const Color(0xFF35D07F);
      case AccentPreset.amber:
        return const Color(0xFFF3B33D);
      case AccentPreset.crimson:
        return const Color(0xFFFF5C63);
    }
  }

  static AccentPreset fromName(String? name) {
    for (final preset in AccentPreset.values) {
      if (preset.name == name) {
        return preset;
      }
    }
    return AccentPreset.graphite;
  }
}

/// The full colour surface of the island for one brightness.
///
/// Built once per theme change and read through `IslandTheme.of(context)`;
/// never construct colours ad hoc inside widgets.
class IslandPalette {
  const IslandPalette({
    required this.isDark,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceSunken,
    required this.stroke,
    required this.strokeStrong,
    required this.innerHighlight,
    required this.separator,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.positive,
    required this.warning,
    required this.negative,
    required this.shadow,
  });

  final bool isDark;

  /// Base glass of the island itself.
  final Color surface;

  /// Cards and controls sitting on the island.
  final Color surfaceRaised;

  /// Track colours: progress rails, wells, empty states.
  final Color surfaceSunken;

  final Color stroke;
  final Color strokeStrong;

  /// The 1px light along the top edge that gives the glass its thickness.
  final Color innerHighlight;
  final Color separator;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  final Color accent;
  final Color positive;
  final Color warning;
  final Color negative;
  final Color shadow;

  static const Color _darkBase = Color(0xFF0B0C0F);
  static const Color _lightBase = Color(0xFFF6F7F9);

  /// Deep charcoal glass. Never pure black: pure black loses the edge light
  /// that separates the island from a dark wallpaper.
  factory IslandPalette.dark({required Color accent, required double opacity}) {
    return IslandPalette(
      isDark: true,
      surface: _darkBase.withValues(alpha: opacity),
      surfaceRaised: const Color(0xFF17191F).withValues(alpha: 0.92),
      surfaceSunken: const Color(0xFF000000).withValues(alpha: 0.34),
      stroke: const Color(0xFFFFFFFF).withValues(alpha: 0.07),
      strokeStrong: const Color(0xFFFFFFFF).withValues(alpha: 0.14),
      innerHighlight: const Color(0xFFFFFFFF).withValues(alpha: 0.10),
      separator: const Color(0xFFFFFFFF).withValues(alpha: 0.06),
      textPrimary: const Color(0xFFF4F5F7),
      textSecondary: const Color(0xFF9CA3AF),
      textTertiary: const Color(0xFF6B7280),
      accent: accent,
      positive: const Color(0xFF35D07F),
      warning: const Color(0xFFF3B33D),
      negative: const Color(0xFFFF5C63),
      shadow: const Color(0xFF000000),
    );
  }

  factory IslandPalette.light({
    required Color accent,
    required double opacity,
  }) {
    return IslandPalette(
      isDark: false,
      surface: _lightBase.withValues(alpha: opacity),
      surfaceRaised: const Color(0xFFFFFFFF).withValues(alpha: 0.94),
      surfaceSunken: const Color(0xFF0B0C0F).withValues(alpha: 0.07),
      stroke: const Color(0xFF0B0C0F).withValues(alpha: 0.09),
      strokeStrong: const Color(0xFF0B0C0F).withValues(alpha: 0.16),
      innerHighlight: const Color(0xFFFFFFFF).withValues(alpha: 0.85),
      separator: const Color(0xFF0B0C0F).withValues(alpha: 0.07),
      textPrimary: const Color(0xFF11141A),
      textSecondary: const Color(0xFF5A6270),
      textTertiary: const Color(0xFF8A929E),
      accent: accent,
      positive: const Color(0xFF1FA362),
      warning: const Color(0xFFB77A10),
      negative: const Color(0xFFD93A41),
      shadow: const Color(0xFF1A2030),
    );
  }
}
