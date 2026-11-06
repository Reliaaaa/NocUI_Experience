import 'package:flutter/widgets.dart';

import '../theme/island_theme.dart';
import '../tokens/db_colors.dart';
import '../tokens/db_dimens.dart';
import '../tokens/db_shadows.dart';

/// The island shell.
///
/// Square at the top, rounded below: the shape should read as something cut
/// into the top bezel of the display, not as a card floating near it.
///
/// The glass is built from four quiet layers rather than one flashy one:
///
/// * a vertical tint, lighter at the top where the bezel would catch light;
/// * a hairline edge that brightens under the cursor;
/// * one soft highlight along the lower lip, where light from the desktop
///   below would actually fall;
/// * a contact shadow and an ambient shadow, so the shape has mass.
///
/// No blur, no neon, no second glow. There is exactly one halo in the product
/// and it belongs to urgent notifications.
class IslandSurface extends StatelessWidget {
  const IslandSurface({
    required this.topRadius,
    required this.bottomRadius,
    required this.shadowStrength,
    required this.child,
    this.glowColor,
    this.glowStrength = 0,
    this.highlight = 0,
    this.surfaceOpacity,
    super.key,
  });

  final double topRadius;
  final double bottomRadius;
  final double shadowStrength;
  final Color? glowColor;
  final double glowStrength;

  /// 0..1 pointer proximity. Brightens the edge, nothing more.
  final double highlight;

  /// Overrides the theme's surface alpha. Used by the settings panel, where a
  /// page of small text has to stay legible over whatever is behind it.
  final double? surfaceOpacity;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);
    final IslandPalette palette = theme.palette;

    final BorderRadius radius = BorderRadius.only(
      topLeft: Radius.circular(topRadius),
      topRight: Radius.circular(topRadius),
      bottomLeft: Radius.circular(bottomRadius),
      bottomRight: Radius.circular(bottomRadius),
    );

    final Color glow = glowColor ?? palette.accent;
    final Color base = surfaceOpacity == null
        ? palette.surface
        : palette.surface.withValues(alpha: surfaceOpacity!);
    // BoxDecoration ignores `color` when a gradient is present, so the tint
    // has to be blended into the base fill rather than layered over it.
    final Color topTint = palette.isDark
        ? const Color(0x0FFFFFFF)
        : const Color(0x14FFFFFF);
    final Color bottomTint = palette.isDark
        ? const Color(0x14000000)
        : const Color(0x08000000);
    final Color edge = Color.lerp(
      palette.stroke,
      palette.strokeStrong,
      highlight.clamp(0.0, 1.0),
    )!;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: <BoxShadow>[
          ...DbShadow.island(palette, shadowStrength),
          ...DbShadow.glow(glow, glowStrength),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color.alphaBlend(topTint, base),
              base,
              Color.alphaBlend(bottomTint, base),
            ],
            stops: const <double>[0.0, 0.42, 1.0],
          ),
          border: Border.all(
            color: edge,
            width: DbSize.hairline,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: CustomPaint(
            foregroundPainter: _LowerLipHighlight(
              radius: radius,
              color: palette.innerHighlight,
              strength: 0.7 + 0.3 * highlight.clamp(0.0, 1.0),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A single soft highlight tracing the lower edge, fading out towards the top.
/// One highlight, one direction: the whole reason the surface reads as glass
/// instead of a flat rectangle.
class _LowerLipHighlight extends CustomPainter {
  const _LowerLipHighlight({
    required this.radius,
    required this.color,
    required this.strength,
  });

  final BorderRadius radius;
  final Color color;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.height < 6 || color.a <= 0.01) {
      return;
    }
    final Rect bounds = Rect.fromLTWH(0, 0, size.width, size.height);
    final RRect shape = radius.toRRect(bounds).deflate(0.75);

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          color.withValues(alpha: 0),
          color.withValues(alpha: color.a * 0.35 * strength),
          color.withValues(alpha: color.a * strength),
        ],
        stops: const <double>[0.35, 0.78, 1.0],
      ).createShader(bounds);

    canvas.drawRRect(shape, paint);
  }

  @override
  bool shouldRepaint(_LowerLipHighlight oldDelegate) =>
      oldDelegate.radius != radius ||
      oldDelegate.color != color ||
      oldDelegate.strength != strength;
}

/// A card sitting on the island: media art, a timer row, a settings group.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    required this.child,
    this.padding = const EdgeInsets.all(DbSpace.md),
    this.radius = DbRadius.card,
    this.level = SurfaceLevel.raised,
    this.borderColor,
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final SurfaceLevel level;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    final Color background;
    switch (level) {
      case SurfaceLevel.island:
        background = palette.surface;
      case SurfaceLevel.raised:
        background = palette.surfaceRaised;
      case SurfaceLevel.overlay:
        background = palette.surfaceSunken;
    }

    final BoxDecoration decoration;
    if (palette.isDark && level == SurfaceLevel.raised) {
      decoration = BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color.alphaBlend(const Color(0x14FFFFFF), background),
            background,
            Color.alphaBlend(const Color(0x05FFFFFF), background),
          ],
          stops: const <double>[0.0, 0.45, 1.0],
        ),
        border: Border.all(
          color: borderColor ?? palette.stroke,
          width: DbSize.hairline,
        ),
      );
    } else {
      decoration = BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? palette.stroke,
          width: DbSize.hairline,
        ),
      );
    }

    final Widget content = DecoratedBox(
      decoration: decoration,
      child: Padding(padding: padding, child: child),
    );

    if (onTap == null) {
      return content;
    }
    return GestureDetector(onTap: onTap, child: content);
  }
}
