import 'package:flutter/widgets.dart';

import '../theme/island_theme.dart';
import '../tokens/db_motion.dart';

/// An icon that changes by turning into the next one.
///
/// Play becoming pause is the most frequently seen transition in the product,
/// and a hard swap makes it look like a redraw. The outgoing glyph shrinks and
/// rotates a few degrees out while the incoming one arrives from the opposite
/// side, which reads as one object changing state rather than two images
/// trading places. The rotation is deliberately tiny: a full spin would be a
/// toy, and at 16px nobody can follow it anyway.
class MorphIcon extends StatelessWidget {
  const MorphIcon({
    required this.icon,
    required this.size,
    required this.color,
    this.turns = 0.08,
    super.key,
  });

  final IconData icon;
  final double size;
  final Color color;

  /// Fraction of a full turn the glyph travels through. Keep it small.
  final double turns;

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);

    return AnimatedSwitcher(
      duration: theme.motion.scale(DbDuration.micro),
      switchInCurve: DbCurve.standard,
      switchOutCurve: DbCurve.exit,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: RotationTransition(
            turns: Tween<double>(begin: turns, end: 0).animate(animation),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.7, end: 1).animate(animation),
              child: child,
            ),
          ),
        );
      },
      child: Icon(
        icon,
        key: ValueKey<int>(icon.codePoint),
        size: size,
        color: color,
      ),
    );
  }
}
