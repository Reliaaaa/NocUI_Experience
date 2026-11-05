import 'dart:math' as math;

import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/widgets.dart';

import '../../../../design/theme/island_theme.dart';
import '../../../../design/tokens/db_colors.dart';
import '../../../../design/tokens/db_motion.dart';

/// The ring every timer is drawn as.
///
/// A countdown fills clockwise from twelve and empties as it runs; a stopwatch
/// has no end to fill towards, so it carries a single bright point sweeping
/// once a minute - the seconds hand of a watch, reduced to the one pixel that
/// matters. A finished timer breathes: the ring swells and settles on the
/// ambient cadence until it is dismissed, so it is noticed without a sound.
///
/// The painter draws what it is given. Whoever owns the ring decides how the
/// value moves - the page drives it from a ticker so it is continuous rather
/// than stepped at the controller's tick, which is the difference between a
/// ring that drains and one that jerks.
class TimerRing extends StatelessWidget {
  const TimerRing({
    required this.size,
    this.progress,
    this.sweep,
    this.strokeWidth = 6,
    this.color,
    this.trackColor,
    this.finished = false,
    this.glow = 0,
    this.child,
    super.key,
  });

  final double size;

  /// 0..1 of the ring filled, clockwise from the top. Null draws no fill.
  final double? progress;

  /// 0..1 of a turn, for the sweeping point. Null draws no point.
  final double? sweep;

  final double strokeWidth;
  final Color? color;
  final Color? trackColor;
  final bool finished;

  /// 0..1 soft halo behind the fill, for a ring that has something to say.
  final double glow;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    final Color fill = color ?? (finished ? palette.positive : palette.accent);

    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress,
          sweep: sweep,
          strokeWidth: strokeWidth,
          color: fill,
          trackColor: trackColor ?? palette.surfaceSunken,
          glow: glow,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.sweep,
    required this.strokeWidth,
    required this.color,
    required this.trackColor,
    required this.glow,
  });

  final double? progress;
  final double? sweep;
  final double strokeWidth;
  final Color color;
  final Color trackColor;
  final double glow;

  static const double _top = -math.pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect bounds = Offset.zero & size;
    final Rect ring = bounds.deflate(strokeWidth / 2 + 1);
    final Offset centre = ring.center;
    final double radius = ring.width / 2;

    if (glow > 0) {
      // The halo sits behind everything, wide and soft, and only as strong as
      // the ring has a reason to be: a finished timer, or a dial being held.
      final Paint halo = Paint()
        ..color = color.withValues(alpha: 0.28 * glow)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, strokeWidth * 2.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 2;
      canvas.drawCircle(centre, radius, halo);
    }

    final Paint track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    canvas.drawCircle(centre, radius, track);

    final double? value = progress;
    if (value != null && value > 0) {
      final Paint fill = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = color;
      canvas.drawArc(ring, _top, math.pi * 2 * value.clamp(0.0, 1.0), false,
          fill);
    }

    final double? turn = sweep;
    if (turn != null) {
      final double angle = _top + math.pi * 2 * (turn % 1);
      final Offset point = centre +
          Offset(math.cos(angle) * radius, math.sin(angle) * radius);
      // A short comet tail behind the point, so the direction of travel is
      // readable even in a still frame.
      final Paint tail = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: angle - math.pi * 0.28,
          endAngle: angle,
          colors: <Color>[color.withValues(alpha: 0), color],
          transform: GradientRotation(0),
        ).createShader(ring);
      canvas.drawArc(ring, angle - math.pi * 0.28, math.pi * 0.28, false, tail);
      final Paint head = Paint()..color = color;
      canvas.drawCircle(point, strokeWidth * 0.62, head);
      final Paint spark = Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.85);
      canvas.drawCircle(point, strokeWidth * 0.22, spark);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.sweep != sweep ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth ||
      old.glow != glow;
}

/// Drives [TimerRing] from a ticker while something is counting.
///
/// The controller wakes five times a second to catch a countdown reaching
/// zero; a ring that moved only then would visibly step. This repaints every
/// frame while [running] and not at all otherwise, so a paused ring costs
/// nothing and a running one is as smooth as the display.
class LiveRing extends StatefulWidget {
  const LiveRing({
    required this.size,
    required this.running,
    required this.frame,
    this.strokeWidth = 6,
    this.centre,
    super.key,
  });

  final double size;
  final bool running;
  final double strokeWidth;

  /// Called every frame with the current time; returns what to draw.
  final RingFrame Function(DateTime now) frame;

  /// What sits inside the ring, built with the same instant as the ring so a
  /// stopwatch's hundredths move with its sweep rather than a beat behind.
  final Widget Function(DateTime now)? centre;

  @override
  State<LiveRing> createState() => _LiveRingState();
}

/// One frame's worth of ring.
class RingFrame {
  const RingFrame({
    this.progress,
    this.sweep,
    this.color,
    this.finished = false,
    this.glow = 0,
  });

  final double? progress;
  final double? sweep;
  final Color? color;
  final bool finished;
  final double glow;
}

class _LiveRingState extends State<LiveRing>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((_) => setState(() {}));

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(LiveRing old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final bool animate = widget.running && !IslandTheme.read(context).motion.isInstant;
    if (animate && !_ticker.isActive) {
      _ticker.start();
    } else if (!animate && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final RingFrame frame = widget.frame(now);
    return TimerRing(
      size: widget.size,
      progress: frame.progress,
      sweep: frame.sweep,
      color: frame.color,
      finished: frame.finished,
      glow: frame.glow,
      strokeWidth: widget.strokeWidth,
      child: widget.centre?.call(now),
    );
  }
}

/// The slow swell a finished ring keeps making until someone answers it.
class Breathing extends StatefulWidget {
  const Breathing({required this.builder, this.active = true, super.key});

  final Widget Function(BuildContext context, double breath) builder;
  final bool active;

  @override
  State<Breathing> createState() => _BreathingState();
}

class _BreathingState extends State<Breathing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: DbDuration.ambient,
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(Breathing old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final bool animate =
        widget.active && !IslandTheme.read(context).motion.isInstant;
    if (animate && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!animate && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, _) => widget.builder(
        context,
        DbCurve.breathe.transform(_controller.value),
      ),
    );
  }
}
