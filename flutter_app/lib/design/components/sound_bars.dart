import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme/island_theme.dart';

/// Four bars that rise and fall while music plays.
///
/// This is the one piece of purely decorative motion in the product, and it
/// earns its place: it is how the collapsed island says "sound is coming out of
/// this machine" without a word of text. It runs only while playback is
/// actually active, stops dead when paused, and is skipped entirely under
/// reduced motion, where a static level meter says the same thing.
class SoundBars extends StatefulWidget {
  const SoundBars({
    required this.active,
    this.color,
    this.height = 12,
    this.barWidth = 2,
    this.spacing = 2.5,
    this.barCount = 4,
    super.key,
  });

  final bool active;
  final Color? color;
  final double height;
  final double barWidth;
  final double spacing;
  final int barCount;

  @override
  State<SoundBars> createState() => _SoundBarsState();
}

class _SoundBarsState extends State<SoundBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(SoundBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      _sync();
    }
  }

  void _sync() {
    if (widget.active) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
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
    final IslandThemeData theme = IslandTheme.of(context);
    final Color color = widget.color ?? theme.palette.textPrimary;
    final bool animate = widget.active && !theme.motion.isInstant;

    return SizedBox(
      height: widget.height,
      width:
          widget.barCount * widget.barWidth +
          (widget.barCount - 1) * widget.spacing,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, _) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: List<Widget>.generate(widget.barCount, (int index) {
              // Each bar runs the same sine at a different phase and rate, so
              // the group never falls into a visible lock step.
              final double phase = index * 0.7;
              final double rate = 1 + index * 0.23;
              final double wave = animate
                  ? (math.sin(
                              (_controller.value * rate * 2 * math.pi) + phase,
                            ) +
                            1) /
                        2
                  : 0.45 + index * 0.08;
              final double factor = 0.25 + wave * 0.75;
              return Padding(
                padding: EdgeInsets.only(
                  right: index == widget.barCount - 1 ? 0 : widget.spacing,
                ),
                child: Container(
                  width: widget.barWidth,
                  height: widget.height * factor,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(widget.barWidth),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
