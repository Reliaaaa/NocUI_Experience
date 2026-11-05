import 'package:flutter/painting.dart';

import 'db_colors.dart';

/// Elevation.
///
/// Two shadows per level: a tight contact shadow that anchors the shape to the
/// screen edge, and a wide ambient one that gives it mass. A single blurred
/// drop shadow always reads as a sticker.
class DbShadow {
  const DbShadow._();

  static List<BoxShadow> island(IslandPalette palette, double strength) {
    final double t = strength.clamp(0.0, 1.0);
    if (t <= 0.01) {
      return const <BoxShadow>[];
    }
    final Color shadow = palette.shadow;
    return <BoxShadow>[
      BoxShadow(
        color: shadow.withValues(alpha: (palette.isDark ? 0.46 : 0.16) * t),
        blurRadius: 34 * t,
        spreadRadius: -6,
        offset: Offset(0, 14 * t),
      ),
      BoxShadow(
        color: shadow.withValues(alpha: (palette.isDark ? 0.30 : 0.10) * t),
        blurRadius: 10 * t,
        spreadRadius: -2,
        offset: Offset(0, 3 * t),
      ),
    ];
  }

  static List<BoxShadow> raised(IslandPalette palette) => <BoxShadow>[
    BoxShadow(
      color: palette.shadow.withValues(alpha: palette.isDark ? 0.34 : 0.10),
      blurRadius: 14,
      spreadRadius: -4,
      offset: const Offset(0, 5),
    ),
  ];

  /// A soft coloured halo used to mark an event (a finished timer, a failed
  /// download). Deliberately faint: this is the only glow in the product.
  static List<BoxShadow> glow(Color color, double strength) {
    final double t = strength.clamp(0.0, 1.0);
    if (t <= 0.01) {
      return const <BoxShadow>[];
    }
    return <BoxShadow>[
      BoxShadow(
        color: color.withValues(alpha: 0.30 * t),
        blurRadius: 26 * t,
        spreadRadius: 1 * t,
      ),
    ];
  }
}
