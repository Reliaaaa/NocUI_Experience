import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme/island_theme.dart';
import '../tokens/db_colors.dart';
import '../tokens/db_motion.dart';

/// A progress rail.
///
/// Determinate progress animates towards its value with a non-overshooting
/// curve, because a bar that springs past 100% and comes back is a bar that
/// lies. When [value] is null the rail shows an indeterminate sweep, which is
/// the honest presentation for a transfer whose total size is unknown.
class IslandProgressBar extends StatelessWidget {
  const IslandProgressBar({
    this.value,
    this.height = 3,
    this.color,
    this.trackColor,
    this.animateChanges = true,
    super.key,
  });

  final double? value;
  final double height;
  final Color? color;
  final Color? trackColor;

  /// When false the rail follows [value] exactly. Used where the caller is
  /// already interpolating - a media timeline drives itself from the clock,
  /// and a second easing curve on top would make it lag behind the audio.
  final bool animateChanges;

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);
    final IslandPalette palette = theme.palette;
    final Color fill = color ?? palette.accent;
    final Color track = trackColor ?? palette.surfaceSunken;

    if (value == null) {
      return _IndeterminateBar(
        height: height,
        color: fill,
        trackColor: track,
        animate: !theme.motion.isInstant,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Stack(
          children: <Widget>[
            Positioned.fill(child: ColoredBox(color: track)),
            if (!animateChanges)
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: value!.clamp(0.0, 1.0).toDouble(),
                child: ColoredBox(color: fill),
              )
            else
              TweenAnimationBuilder<double>(
                tween: Tween<double>(
                  begin: 0,
                  end: value!.clamp(0.0, 1.0).toDouble(),
                ),
                duration: theme.motion.scale(DbDuration.standard),
                curve: DbCurve.standard,
                builder: (BuildContext context, double animated, _) {
                  return FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: animated,
                    child: ColoredBox(color: fill),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _IndeterminateBar extends StatefulWidget {
  const _IndeterminateBar({
    required this.height,
    required this.color,
    required this.trackColor,
    required this.animate,
  });

  final double height;
  final Color color;
  final Color trackColor;
  final bool animate;

  @override
  State<_IndeterminateBar> createState() => _IndeterminateBarState();
}

class _IndeterminateBarState extends State<_IndeterminateBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(_IndeterminateBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.height),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: <Widget>[
            Positioned.fill(child: ColoredBox(color: widget.trackColor)),
            AnimatedBuilder(
              animation: _controller,
              builder: (BuildContext context, _) {
                // Eases at both ends of the sweep so it reads as a pulse
                // travelling along the rail rather than a rectangle sliding.
                final double t = Curves.easeInOutCubic.transform(
                  _controller.value,
                );
                return FractionallySizedBox(
                  alignment: Alignment(-1 + 2 * t, 0),
                  widthFactor: 0.38,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          widget.color.withValues(alpha: 0),
                          widget.color,
                          widget.color.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// A circular progress ring, used where a bar would not fit: the collapsed
/// island's timer face.
class IslandProgressRing extends StatelessWidget {
  const IslandProgressRing({
    required this.value,
    this.size = 16,
    this.strokeWidth = 2,
    this.color,
    this.trackColor,
    super.key,
  });

  final double value;
  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);
    final IslandPalette palette = theme.palette;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.clamp(0.0, 1.0).toDouble()),
      duration: theme.motion.scale(DbDuration.quick),
      curve: DbCurve.standard,
      builder: (BuildContext context, double animated, _) {
        return CustomPaint(
          size: Size.square(size),
          painter: _RingPainter(
            value: animated,
            strokeWidth: strokeWidth,
            color: color ?? palette.accent,
            trackColor: trackColor ?? palette.surfaceSunken,
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.value,
    required this.strokeWidth,
    required this.color,
    required this.trackColor,
  });

  final double value;
  final double strokeWidth;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect bounds = Offset.zero & size;
    final Rect ring = bounds.deflate(strokeWidth / 2);

    final Paint track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    canvas.drawArc(ring, 0, math.pi * 2, false, track);

    if (value <= 0) {
      return;
    }
    final Paint fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(ring, -math.pi / 2, math.pi * 2 * value, false, fill);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.strokeWidth != strokeWidth;
}
