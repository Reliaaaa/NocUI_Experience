import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme/island_theme.dart';
import '../tokens/db_colors.dart';

/// A rolling line graph.
///
/// The shape people recognise from Activity Monitor: a smoothed line over a
/// soft gradient, drawn right-aligned so the newest sample is always at the
/// leading edge and the history scrolls away to the left.
///
/// Two decisions are worth stating. The curve is a Catmull-Rom spline rather
/// than straight segments, because at one sample a second a polyline reads as a
/// row of spikes and hides the trend. And a series shorter than the window is
/// drawn short rather than stretched: a graph that widened as it filled would
/// make the same load look like a change.
class Sparkline extends StatelessWidget {
  const Sparkline({
    required this.values,
    required this.color,
    this.capacity = 60,
    this.maxValue = 1.0,
    this.height = 46,
    this.strokeWidth = 1.6,
    this.mirrored = false,
    super.key,
  });

  /// Samples, oldest first, already normalised against [maxValue].
  final List<double> values;

  /// The value that reaches the top of the plot. Below 1 for a graph with a
  /// fixed ceiling; a running peak for one without.
  final double maxValue;

  /// How many samples the plot is scaled for. A partly filled series occupies
  /// the corresponding fraction of the width.
  final int capacity;

  final Color color;
  final double height;
  final double strokeWidth;

  /// Draws downward from the top edge instead of upward from the bottom, so an
  /// upload line can be stacked under a download line and read as its opposite.
  final bool mirrored;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    return RepaintBoundary(
      child: CustomPaint(
        size: Size(double.infinity, height),
        painter: _SparklinePainter(
          // Copied, not referenced: the controller mutates one list in place,
          // and a painter holding that same list can never see it change - its
          // "old" values are the new ones, so shouldRepaint always says no and
          // the graph stays empty for ever.
          values: List<double>.of(values),
          capacity: capacity,
          maxValue: maxValue,
          color: color,
          baseline: palette.stroke,
          strokeWidth: strokeWidth,
          mirrored: mirrored,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.values,
    required this.capacity,
    required this.maxValue,
    required this.color,
    required this.baseline,
    required this.strokeWidth,
    required this.mirrored,
  });

  final List<double> values;
  final int capacity;
  final double maxValue;
  final Color color;
  final Color baseline;
  final double strokeWidth;
  final bool mirrored;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint rule = Paint()
      ..color = baseline
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final double floor = mirrored ? 0.0 : size.height;
    canvas.drawLine(Offset(0, floor), Offset(size.width, floor), rule);

    if (values.length < 2 || size.width <= 0) {
      return;
    }

    final double ceiling = maxValue <= 0 ? 1.0 : maxValue;
    final double step = size.width / math.max(1, capacity - 1);
    final int count = values.length;
    // Right-aligned: the newest sample sits on the right edge whatever the
    // series length, so a filling graph does not slide sideways.
    final double startX = size.width - (count - 1) * step;

    final List<Offset> points = <Offset>[
      for (int i = 0; i < count; i++)
        Offset(
          startX + i * step,
          _y(size.height, (values[i] / ceiling).clamp(0.0, 1.0).toDouble()),
        ),
    ];

    final Path line = _spline(points);
    final Path fill = Path.from(line)
      ..lineTo(points.last.dx, floor)
      ..lineTo(points.first.dx, floor)
      ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: mirrored ? Alignment.bottomCenter : Alignment.topCenter,
          end: mirrored ? Alignment.topCenter : Alignment.bottomCenter,
          colors: <Color>[
            color.withValues(alpha: 0.30),
            color.withValues(alpha: 0.02),
          ],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );

    // The head of the line, so the eye lands on "now" first.
    canvas.drawCircle(
      points.last,
      strokeWidth * 1.5,
      Paint()..color = color,
    );
  }

  double _y(double height, double normalised) =>
      mirrored ? normalised * height : height - normalised * height;

  /// Catmull-Rom through every point, converted to the cubic segments Path
  /// understands. Passing through the samples rather than near them matters:
  /// this is a measurement, not a decoration.
  static Path _spline(List<Offset> points) {
    final Path path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final Offset p0 = i == 0 ? points[0] : points[i - 1];
      final Offset p1 = points[i];
      final Offset p2 = points[i + 1];
      final Offset p3 = i + 2 < points.length ? points[i + 2] : p2;

      final Offset c1 = p1 + (p2 - p0) / 6;
      final Offset c2 = p2 - (p3 - p1) / 6;
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    return path;
  }

  @override
  bool shouldRepaint(_SparklinePainter old) {
    if (old.maxValue != maxValue ||
        old.color != color ||
        old.mirrored != mirrored ||
        old.capacity != capacity ||
        old.values.length != values.length) {
      return true;
    }
    // At most sixty doubles; cheaper than repainting a spline that has not
    // moved, and correct when the newest sample happens to equal the last.
    for (int i = 0; i < values.length; i++) {
      if (old.values[i] != values[i]) {
        return true;
      }
    }
    return false;
  }
}
