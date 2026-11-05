import 'package:flutter/widgets.dart';

import '../theme/island_theme.dart';
import '../tokens/db_motion.dart';

/// A single line of text that scrolls itself when it does not fit.
///
/// An ellipsis is the right answer almost everywhere in this product, and the
/// wrong one for a track title: the part that gets cut is usually the part that
/// distinguishes one song from another. Rather than shrink the type until
/// everything fits - which would make the title smaller exactly when it has
/// more to say - the line travels the distance it overflows and comes back.
///
/// The motion is bounded and explained: it holds still at both ends, it runs
/// only while [enabled] (the media page passes playback state, so a paused
/// track sits still), it never runs when the text fits, and it does not run at
/// all under reduced motion, where the line is simply clipped with a fade. The
/// leading and trailing fades are what keep the clip from reading as a bug.
class MarqueeText extends StatelessWidget {
  const MarqueeText(
    this.text, {
    required this.style,
    this.enabled = true,
    this.velocity = 32,
    this.hold = const Duration(milliseconds: 1700),
    this.fade = 20,
    super.key,
  });

  final String text;
  final TextStyle style;

  /// Whether the line is allowed to move. It still fades and clips when false.
  final bool enabled;

  /// Logical pixels per second. Slow enough to read, fast enough to finish.
  final double velocity;

  /// How long the line rests at each end before travelling back.
  final Duration hold;

  /// Width of the soft edge on each side.
  final double fade;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double available = constraints.maxWidth;
        final TextPainter painter = TextPainter(
          text: TextSpan(text: text, style: style),
          maxLines: 1,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        final double width = painter.width;
        final double height = painter.height;
        painter.dispose();

        // Half a pixel of slack: a title that fits exactly should not travel.
        if (!available.isFinite || width <= available + 0.5) {
          return Text(
            text,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.clip,
            style: style,
          );
        }

        return _Scroller(
          text: text,
          style: style,
          overflow: width - available,
          height: height,
          fade: fade,
          velocity: velocity,
          hold: hold,
          enabled: enabled,
        );
      },
    );
  }
}

class _Scroller extends StatefulWidget {
  const _Scroller({
    required this.text,
    required this.style,
    required this.overflow,
    required this.height,
    required this.fade,
    required this.velocity,
    required this.hold,
    required this.enabled,
  });

  final String text;
  final TextStyle style;
  final double overflow;
  final double height;
  final double fade;
  final double velocity;
  final Duration hold;
  final bool enabled;

  @override
  State<_Scroller> createState() => _ScrollerState();
}

class _ScrollerState extends State<_Scroller>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _cycle,
  );
  late Animation<double> _travel = _sequence;
  bool _reduced = false;

  /// One cycle is: rest, travel out, rest, travel back. The two rests are what
  /// make the line readable at both ends; without them the eye never catches
  /// the start of a long title.
  Duration get _cycle {
    final int travelMs = (widget.overflow / widget.velocity * 1000)
        .round()
        .clamp(400, 12000);
    return Duration(milliseconds: 2 * (travelMs + widget.hold.inMilliseconds));
  }

  Animation<double> get _sequence {
    final double travel = (widget.overflow / widget.velocity * 1000).clamp(
      400,
      12000,
    );
    final double rest = widget.hold.inMilliseconds.toDouble().clamp(1, 8000);
    return TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: ConstantTween<double>(0),
        weight: rest,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0, end: 1)
            .chain(CurveTween(curve: DbCurve.inOut)),
        weight: travel,
      ),
      TweenSequenceItem<double>(
        tween: ConstantTween<double>(1),
        weight: rest,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1, end: 0)
            .chain(CurveTween(curve: DbCurve.inOut)),
        weight: travel,
      ),
    ]).animate(_controller);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion is a theme change, so it arrives here rather than in
    // didUpdateWidget, and stopping the loop is the whole response to it.
    final bool reduced = IslandTheme.of(context).motion.isInstant;
    if (reduced != _reduced) {
      _reduced = reduced;
    }
    _sync();
  }

  @override
  void didUpdateWidget(_Scroller oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.overflow != widget.overflow ||
        oldWidget.velocity != widget.velocity ||
        oldWidget.hold != widget.hold ||
        oldWidget.text != widget.text) {
      _controller.duration = _cycle;
      _travel = _sequence;
      // Setting the value stops the controller, so the loop is always started
      // again below rather than only when `enabled` changed.
      _controller.value = 0;
    }
    _sync();
  }

  void _sync() {
    if (widget.enabled && !_reduced) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else if (_controller.isAnimating) {
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
    final Widget line = Text(
      widget.text,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.visible,
      style: widget.style,
    );

    return SizedBox(
      // The strip takes the whole width it was offered: it sits in a Column,
      // whose cross-axis constraints are loose, and a box with no width there
      // would collapse to nothing.
      width: double.infinity,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _travel,
        builder: (BuildContext context, Widget? child) {
          final double t = _travel.value;
          return ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (Rect bounds) {
              // The leading fade only appears once the line has actually
              // moved; a title that starts at the left edge should not look
              // like it is hiding something before it does.
              final double lead = (t * 6).clamp(0.0, 1.0);
              final double trail = ((1 - t) * 6).clamp(0.0, 1.0);
              final double span = bounds.width <= 0 ? 1 : bounds.width;
              final double leadStop = (widget.fade / span) * lead;
              final double trailStop = 1 - (widget.fade / span) * trail;
              return LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: const <Color>[
                  Color(0x00FFFFFF),
                  Color(0xFFFFFFFF),
                  Color(0xFFFFFFFF),
                  Color(0x00FFFFFF),
                ],
                stops: <double>[
                  0,
                  leadStop.clamp(0.0, 0.5),
                  trailStop.clamp(0.5, 1.0),
                  1,
                ],
              ).createShader(bounds);
            },
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.centerLeft,
                minWidth: 0,
                maxWidth: double.infinity,
                child: Transform.translate(
                  offset: Offset(-widget.overflow * t, 0),
                  child: child,
                ),
              ),
            ),
          );
        },
        child: line,
      ),
    );
  }
}
