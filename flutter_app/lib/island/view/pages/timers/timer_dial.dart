import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../design/components/rolling_text.dart';
import '../../../../design/theme/island_theme.dart';
import '../../../../design/tokens/db_colors.dart';
import '../../../../design/tokens/db_motion.dart';
import '../../../../design/tokens/db_typography.dart';
import 'timer_ring.dart';

/// The ring you set a countdown on.
///
/// One turn is an hour. Drag the ring and the arc follows the pointer; scroll
/// over it and it moves a minute a notch; press a preset and it travels there
/// on a spring. The number in the middle is the same rolling display the
/// clock uses, so the dial reads as the timer it is about to become rather
/// than as a control for one.
///
/// Dragging past twelve o'clock carries into a second turn, up to [maxMinutes];
/// dragging back below one minute stops at one, because a timer of nothing is
/// not a thing anyone means.
class TimerDial extends StatefulWidget {
  const TimerDial({
    required this.minutes,
    required this.onChanged,
    required this.size,
    this.maxMinutes = 120,
    super.key,
  });

  final int minutes;
  final ValueChanged<int> onChanged;
  final double size;
  final int maxMinutes;

  @override
  State<TimerDial> createState() => _TimerDialState();
}

class _TimerDialState extends State<TimerDial> {
  bool _dragging = false;
  bool _hovered = false;

  /// Whole turns already made in this drag, so the second hour continues from
  /// the first instead of snapping back to zero at twelve.
  int _turns = 0;
  double _lastAngle = 0;

  double _angleAt(Offset local) {
    final Offset centre = Offset(widget.size / 2, widget.size / 2);
    final Offset d = local - centre;
    // Clockwise from the top, 0..2pi.
    final double a = math.atan2(d.dx, -d.dy);
    return a < 0 ? a + math.pi * 2 : a;
  }

  void _start(Offset local) {
    final double angle = _angleAt(local);
    setState(() {
      _dragging = true;
      _turns = (widget.minutes - 1) ~/ 60;
      _lastAngle = angle;
    });
    _apply(angle);
  }

  void _update(Offset local) {
    final double angle = _angleAt(local);
    // Crossing twelve: a jump of more than half a turn between two pointer
    // samples is a wrap, not a leap.
    if (_lastAngle > math.pi * 1.5 && angle < math.pi * 0.5) {
      _turns++;
    } else if (_lastAngle < math.pi * 0.5 && angle > math.pi * 1.5) {
      _turns--;
    }
    _lastAngle = angle;
    _apply(angle);
  }

  void _apply(double angle) {
    final int minutesInTurn = (angle / (math.pi * 2) * 60).round();
    int minutes = _turns * 60 + minutesInTurn;
    if (_turns < 0 || minutes < 1) {
      _turns = 0;
      minutes = 1;
    }
    if (minutes > widget.maxMinutes) {
      minutes = widget.maxMinutes;
      _turns = (minutes - 1) ~/ 60;
    }
    if (minutes != widget.minutes) {
      widget.onChanged(minutes);
    }
  }

  void _end() => setState(() => _dragging = false);

  void _wheel(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) {
      return;
    }
    GestureBinding.instance.pointerSignalResolver.register(event, (
      PointerEvent e,
    ) {
      if (e is! PointerScrollEvent) {
        return;
      }
      // Wheel up adds time, like turning a dial clockwise. One notch is one
      // minute; a trackpad's small deltas are folded into the same rule.
      final int step = e.scrollDelta.dy < 0 ? 1 : -1;
      widget.onChanged((widget.minutes + step).clamp(1, widget.maxMinutes));
    });
  }

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);
    final IslandPalette palette = theme.palette;
    final int minutes = widget.minutes;
    final double target = minutes >= 60 ? 1.0 : minutes / 60;
    final bool secondHour = minutes > 60;

    return Semantics(
      slider: true,
      value: '$minutes minutes',
      label: 'Timer length',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Listener(
          onPointerSignal: _wheel,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (DragStartDetails d) => _start(d.localPosition),
            onPanUpdate: (DragUpdateDetails d) => _update(d.localPosition),
            onPanEnd: (_) => _end(),
            onPanCancel: _end,
            onTapDown: (TapDownDetails d) => _start(d.localPosition),
            onTapUp: (_) => _end(),
            // While held, the arc follows the hand exactly; released, it
            // travels to a preset on the standard curve. Both go through one
            // tween so a preset pressed mid-drag does not fight the pointer.
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: target),
              duration: _dragging
                  ? Duration.zero
                  : theme.motion.scale(DbDuration.standard),
              curve: DbCurve.emphasized,
              builder: (BuildContext context, double arc, _) {
                return AnimatedContainer(
                  duration: theme.motion.scale(DbDuration.micro),
                  curve: DbCurve.standard,
                  transform: Matrix4.identity()
                    ..scaleByDouble(
                      _dragging ? 1.03 : 1.0,
                      _dragging ? 1.03 : 1.0,
                      1.0,
                      1.0,
                    ),
                  transformAlignment: Alignment.center,
                  child: TimerRing(
                    size: widget.size,
                    progress: arc,
                    // The second hour lays a brighter ring over a full one,
                    // so 75 minutes is visibly more than 60 rather than the
                    // same full circle.
                    color: secondHour
                        ? Color.lerp(palette.accent, palette.textPrimary, 0.35)
                        : palette.accent,
                    glow: _dragging ? 1 : (_hovered ? 0.45 : 0.15),
                    strokeWidth: 7,
                    child: _Readout(
                      minutes: minutes,
                      emphasised: _dragging || _hovered,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Readout extends StatelessWidget {
  const _Readout({required this.minutes, required this.emphasised});

  final int minutes;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        RollingText(
          Formatters.duration(Duration(minutes: minutes)),
          style: DbType.display.copyWith(
            fontSize: 30,
            letterSpacing: -1.2,
            color: palette.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        AnimatedDefaultTextStyle(
          duration: DbDuration.micro,
          style: DbType.overline.copyWith(
            color: emphasised ? palette.accent : palette.textTertiary,
          ),
          child: Text(minutes == 1 ? 'MINUTE' : 'MINUTES'),
        ),
      ],
    );
  }
}
