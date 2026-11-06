import 'package:flutter/widgets.dart';

import '../../../app/app_services.dart';
import '../../../core/time/clock_service.dart';
import '../../../design/theme/island_theme.dart';
import '../../../design/tokens/db_colors.dart';
import '../../../design/tokens/db_dimens.dart';
import '../../../design/tokens/db_motion.dart';
import '../../../design/tokens/db_typography.dart';
import '../../../modules/activities/live_activity.dart';

/// The resting face: a clock, flanked by up to two live activities.
///
/// This is the whole point of the collapsed state. A countdown or a transfer
/// rate sits in the pill in a few characters, so a glance at the top of the
/// screen answers the question without anything being opened. With nothing
/// happening it collapses to just the time, which is where the island spends
/// almost all of its life.
class CollapsedFace extends StatelessWidget {
  const CollapsedFace({super.key});

  @override
  Widget build(BuildContext context) {
    final AppServices services = AppScope.read(context);
    final IslandPalette palette = IslandTheme.of(context).palette;
    final bool use24Hour = services.settings.settings.use24HourClock;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DbSpace.lg),
      child: AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[
          services.clock,
          services.activities,
        ]),
        builder: (BuildContext context, _) {
          final List<LiveActivity> visible = services.activities.visible;
          final LiveActivity? leading =
              visible.isNotEmpty ? visible.first : null;
          final LiveActivity? trailing =
              visible.length > 1 ? visible[1] : null;
          final DateTime now = services.clock.now;

          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              if (leading != null)
                _ActivityEar(activity: leading, alignEnd: false)
              else
                _LiveDot(color: palette.accent),
              const SizedBox(width: DbSpace.md),
              Text(
                ClockFormat.time(now, use24Hour: use24Hour),
                style: DbType.clock.copyWith(
                  color: palette.textPrimary,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(width: DbSpace.md),
              if (trailing != null)
                _ActivityEar(activity: trailing, alignEnd: true)
              else
                Flexible(
                  child: Text(
                    ClockFormat.shortDate(now),
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    softWrap: false,
                    style: DbType.caption.copyWith(
                      color: palette.textSecondary,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// One activity in the pill: a glyph, a short value, and a hairline ring when
/// there is real progress to show.
class _ActivityEar extends StatelessWidget {
  const _ActivityEar({required this.activity, required this.alignEnd});

  final LiveActivity activity;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);
    final IslandPalette palette = theme.palette;
    final Color tint = activity.tint ??
        (activity.urgent ? palette.negative : palette.accent);

    return AnimatedSwitcher(
      duration: theme.motion.scale(DbDuration.quick),
      switchInCurve: DbCurve.standard,
      switchOutCurve: DbCurve.exit,
      transitionBuilder: (Widget child, Animation<double> animation) =>
          FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1).animate(animation),
          child: child,
        ),
      ),
      child: Row(
        key: ValueKey<String>('${activity.id}:${activity.label}'),
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _ActivityGlyph(activity: activity, tint: tint),
          const SizedBox(width: DbSpace.sm),
          Text(
            activity.label,
            maxLines: 1,
            overflow: TextOverflow.clip,
            softWrap: false,
            style: DbType.numeric.copyWith(
              color: activity.urgent ? tint : palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// The glyph, wrapped in a progress ring when the activity has one.
class _ActivityGlyph extends StatelessWidget {
  const _ActivityGlyph({required this.activity, required this.tint});

  final LiveActivity activity;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    final Widget glyph = Icon(activity.icon, size: 11, color: tint);
    final double? progress = activity.progress;
    if (progress == null) {
      return SizedBox(width: 14, height: 14, child: Center(child: glyph));
    }
    return SizedBox(
      width: 14,
      height: 14,
      child: CustomPaint(
        painter: _EarRing(
          value: progress.clamp(0.0, 1.0).toDouble(),
          color: tint,
          track: palette.surfaceSunken,
        ),
        child: Center(child: Icon(activity.icon, size: 8, color: tint)),
      ),
    );
  }
}

class _EarRing extends CustomPainter {
  const _EarRing({
    required this.value,
    required this.color,
    required this.track,
  });

  final double value;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect ring = (Offset.zero & size).deflate(0.9);
    canvas.drawArc(
      ring,
      0,
      6.28318,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = track,
    );
    if (value <= 0) {
      return;
    }
    canvas.drawArc(
      ring,
      -1.5708,
      6.28318 * value,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_EarRing oldDelegate) =>
      oldDelegate.value != value || oldDelegate.color != color;
}

/// The mark that says the island is running, designed after the macOS camera /
/// sensor lens aperture with an active indicator core.
class _LiveDot extends StatelessWidget {
  const _LiveDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF141416),
        border: Border.all(
          color: color.withValues(alpha: 0.55),
          width: 1.0,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 4,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 2.5,
          height: 2.5,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
