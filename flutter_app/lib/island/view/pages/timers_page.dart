import 'package:flutter/widgets.dart';

import '../../../app/app_services.dart';
import '../../../core/utils/formatters.dart';
import '../../../design/components/island_button.dart';
import '../../../design/components/rolling_text.dart';
import '../../../design/components/staggered_reveal.dart';
import '../../../design/theme/island_theme.dart';
import '../../../design/tokens/db_colors.dart';
import '../../../design/tokens/db_dimens.dart';
import '../../../design/tokens/db_icons.dart';
import '../../../design/tokens/db_motion.dart';
import '../../../design/tokens/db_typography.dart';
import '../../../modules/timers/island_timer.dart';
import '../../../modules/timers/timer_controller.dart';
import 'page_scaffold.dart';
import 'timers/timer_dial.dart';
import 'timers/timer_ring.dart';

/// Countdowns and stopwatches.
///
/// Two faces on one page. With nothing running it is a dial: turn it, or
/// press a preset, and press Start. With something running it is the stage:
/// the timer that matters drawn as a ring the size of the page, its controls
/// beside it, and everything else counting quietly in a list underneath. The
/// two cross-fade rather than cut, and the plus button brings the dial back
/// over a running stage for one more.
class TimersPage extends StatefulWidget {
  const TimersPage({super.key});

  static const List<int> presets = <int>[1, 3, 5, 10, 15, 25, 45];

  @override
  State<TimersPage> createState() => _TimersPageState();
}

class _TimersPageState extends State<TimersPage> {
  /// The length on the dial. Five minutes is what a person means by "a timer"
  /// more often than any other number.
  int _minutes = 5;

  /// True when the dial has been asked for over a running stage.
  bool _composing = false;

  void _start(TimerController timers) {
    final String id = timers.addCountdown(
      Duration(minutes: _minutes),
      label: _minutes == 1 ? '1 minute' : '$_minutes minutes',
    );
    timers.focus(id);
    setState(() => _composing = false);
  }

  void _startStopwatch(TimerController timers) {
    final String id = timers.addStopwatch();
    timers.focus(id);
    setState(() => _composing = false);
  }

  @override
  Widget build(BuildContext context) {
    final TimerController timers = AppScope.read(context).timers;
    final IslandThemeData theme = IslandTheme.of(context);

    return AnimatedBuilder(
      animation: timers,
      builder: (BuildContext context, _) {
        final IslandTimer? primary = timers.primary;
        final bool composing = primary == null || _composing;

        return PageScaffold(
          title: composing ? 'New timer' : 'Timers',
          trailing: primary == null
              ? null
              : IslandButton(
                  icon: composing ? DbIcons.close : DbIcons.add,
                  tooltip: composing ? 'Back to the timers' : 'Another timer',
                  tone: composing
                      ? IslandButtonTone.neutral
                      : IslandButtonTone.accent,
                  size: DbSize.controlSm,
                  onPressed: () => setState(() => _composing = !composing),
                ),
          child: AnimatedSwitcher(
            duration: theme.motion.scale(DbDuration.standard),
            switchInCurve: DbCurve.emphasized,
            switchOutCurve: DbCurve.exit,
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
                  child: child,
                ),
              );
            },
            child: composing
                ? _Composer(
                    key: const ValueKey<String>('composer'),
                    minutes: _minutes,
                    onMinutes: (int value) => setState(() => _minutes = value),
                    onStart: () => _start(timers),
                    onStopwatch: () => _startStopwatch(timers),
                  )
                : _Stage(
                    key: ValueKey<String>('stage-${primary.id}'),
                    timer: primary,
                    timers: timers,
                  ),
          ),
        );
      },
    );
  }
}

// --- The dial ---------------------------------------------------------------

class _Composer extends StatelessWidget {
  const _Composer({
    required this.minutes,
    required this.onMinutes,
    required this.onStart,
    required this.onStopwatch,
    super.key,
  });

  final int minutes;
  final ValueChanged<int> onMinutes;
  final VoidCallback onStart;
  final VoidCallback onStopwatch;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // The ring takes the page's height; the column beside it takes the
        // rest of the width. At the smallest island the ring is still a
        // hundred pixels across, which is enough to turn with a mouse.
        final double ring = constraints.maxHeight.clamp(96.0, 148.0);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Reveal(
              order: 1,
              scaleFrom: 0.9,
              child: TimerDial(
                minutes: minutes,
                onChanged: onMinutes,
                size: ring,
              ),
            ),
            const SizedBox(width: DbSpace.xl),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Reveal(
                    order: 2,
                    child: Text(
                      'PRESETS',
                      style: DbType.overline.copyWith(
                        color: palette.textTertiary,
                      ),
                    ),
                  ),
                  const SizedBox(height: DbSpace.sm),
                  Reveal(
                    order: 3,
                    scaleFrom: 0.96,
                    child: Wrap(
                      spacing: DbSpace.xs,
                      runSpacing: DbSpace.xs,
                      children: <Widget>[
                        for (final int preset in TimersPage.presets)
                          _Preset(
                            minutes: preset,
                            selected: preset == minutes,
                            onPressed: () => onMinutes(preset),
                          ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Reveal(
                    order: 4,
                    scaleFrom: 0.94,
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: _StartButton(
                            minutes: minutes,
                            onPressed: onStart,
                          ),
                        ),
                        const SizedBox(width: DbSpace.sm),
                        IslandButton(
                          icon: DbIcons.clock,
                          tooltip: 'Start a stopwatch instead',
                          size: DbSize.controlLg,
                          onPressed: onStopwatch,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: DbSpace.sm),
                  Reveal(
                    order: 5,
                    child: Text(
                      'Drag the ring or scroll over it to adjust.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DbType.caption.copyWith(
                        color: palette.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Preset extends StatefulWidget {
  const _Preset({
    required this.minutes,
    required this.selected,
    required this.onPressed,
  });

  final int minutes;
  final bool selected;
  final VoidCallback onPressed;

  @override
  State<_Preset> createState() => _PresetState();
}

class _PresetState extends State<_Preset> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);
    final IslandPalette palette = theme.palette;
    final bool on = widget.selected;

    return Semantics(
      button: true,
      selected: on,
      label: '${widget.minutes} minutes',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: theme.motion.scale(DbDuration.micro),
            curve: DbCurve.standard,
            padding: const EdgeInsets.symmetric(
              horizontal: DbSpace.md,
              vertical: DbSpace.xs,
            ),
            decoration: BoxDecoration(
              color: on
                  ? palette.accent.withValues(alpha: 0.18)
                  : (_hovered ? palette.surfaceRaised : palette.surfaceSunken),
              borderRadius: BorderRadius.circular(DbRadius.pill),
              border: Border.all(
                color: on ? palette.accent : palette.stroke,
              ),
            ),
            child: Text(
              '${widget.minutes} min',
              style: DbType.label.copyWith(
                color: on ? palette.accent : palette.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The one large button on the page: it names what it will do.
class _StartButton extends StatefulWidget {
  const _StartButton({required this.minutes, required this.onPressed});

  final int minutes;
  final VoidCallback onPressed;

  @override
  State<_StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends State<_StartButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);
    final IslandPalette palette = theme.palette;

    return Semantics(
      button: true,
      label: 'Start a ${widget.minutes} minute timer',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.onPressed,
          child: AnimatedScale(
            scale: _pressed ? 0.97 : 1,
            duration: DbDuration.instant,
            child: AnimatedContainer(
              duration: theme.motion.scale(DbDuration.micro),
              curve: DbCurve.standard,
              height: DbSize.controlLg,
              padding: const EdgeInsets.symmetric(horizontal: DbSpace.lg),
              decoration: BoxDecoration(
                color: palette.accent.withValues(alpha: _hovered ? 0.28 : 0.2),
                borderRadius: BorderRadius.circular(DbRadius.control),
                border: Border.all(
                  color: palette.accent.withValues(alpha: _hovered ? 0.9 : 0.5),
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: palette.accent.withValues(alpha: _hovered ? 0.3 : 0.12),
                    blurRadius: _hovered ? 18 : 10,
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(DbIcons.play, size: DbSize.iconMd, color: palette.accent),
                  const SizedBox(width: DbSpace.sm),
                  Flexible(
                    child: Text(
                      'Start ${Formatters.duration(Duration(minutes: widget.minutes))}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DbType.label.copyWith(
                        color: palette.textPrimary,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- The stage --------------------------------------------------------------

class _Stage extends StatelessWidget {
  const _Stage({required this.timer, required this.timers, super.key});

  final IslandTimer timer;
  final TimerController timers;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    final bool countdown = timer.kind == TimerKind.countdown;
    final List<IslandTimer> others = <IslandTimer>[
      for (final IslandTimer other in timers.timers)
        if (other.id != timer.id) other,
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double ring = constraints.maxHeight.clamp(96.0, 148.0);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Reveal(
              order: 1,
              scaleFrom: 0.9,
              child: _Hero(timer: timer, size: ring),
            ),
            const SizedBox(width: DbSpace.xl),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Reveal(
                    order: 2,
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            timer.isFinished ? 'Done' : timer.displayLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DbType.title.copyWith(
                              color: timer.isFinished
                                  ? palette.positive
                                  : palette.textPrimary,
                            ),
                          ),
                        ),
                        Flexible(
                          child: Text(
                            _stateLine(timer),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                            style: DbType.caption.copyWith(
                              color: palette.textTertiary,
                            ),
                          ),
                        ),
                        const SizedBox(width: DbSpace.sm),
                        // Removal lives up here with the name, away from the
                        // buttons a person presses repeatedly: pause and lap
                        // should never have a delete as their neighbour.
                        IslandButton(
                          icon: DbIcons.delete,
                          tone: IslandButtonTone.danger,
                          tooltip: 'Remove this timer',
                          size: DbSize.controlSm,
                          onPressed: () => timers.remove(timer.id),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: DbSpace.sm),
                  Reveal(
                    order: 3,
                    scaleFrom: 0.94,
                    child: _Controls(timer: timer, timers: timers),
                  ),
                  const SizedBox(height: DbSpace.sm),
                  Expanded(
                    child: Reveal(
                      order: 4,
                      child: _Others(
                        others: others,
                        laps: countdown ? const <Duration>[] : timer.laps,
                        timers: timers,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  static String _stateLine(IslandTimer timer) {
    if (timer.isFinished) {
      return 'rang ${_ago(timer.finishedAt)}';
    }
    if (timer.isRunning) {
      return timer.kind == TimerKind.countdown ? 'counting down' : 'running';
    }
    return timer.state == TimerState.idle ? 'ready' : 'paused';
  }

  static String _ago(DateTime? at) {
    if (at == null) {
      return 'just now';
    }
    final Duration since = DateTime.now().difference(at);
    if (since.inMinutes < 1) {
      return 'just now';
    }
    return '${since.inMinutes} min ago';
  }
}

/// The primary timer as a ring the height of the page, its number inside.
class _Hero extends StatelessWidget {
  const _Hero({required this.timer, required this.size});

  final IslandTimer timer;
  final double size;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    final bool countdown = timer.kind == TimerKind.countdown;

    return Breathing(
      active: timer.isFinished,
      builder: (BuildContext context, double breath) {
        return Transform.scale(
          scale: 1 + 0.03 * breath,
          child: LiveRing(
            size: size,
            running: timer.isRunning,
            strokeWidth: 7,
            frame: (DateTime now) {
              if (timer.isFinished) {
                return RingFrame(
                  progress: 1,
                  finished: true,
                  glow: 0.5 + 0.5 * breath,
                );
              }
              if (countdown) {
                final double elapsed = timer.progressAt(now) ?? 0;
                // The ring empties: what is drawn is what is left.
                return RingFrame(
                  progress: 1 - elapsed,
                  color: palette.accent,
                  glow: timer.isRunning ? 0.35 : 0,
                );
              }
              final Duration elapsed = timer.elapsedAt(now);
              return RingFrame(
                sweep: elapsed.inMilliseconds % 60000 / 60000,
                color: palette.accent,
                glow: timer.isRunning ? 0.35 : 0,
              );
            },
            centre: (DateTime now) => _Readout(timer: timer, now: now),
          ),
        );
      },
    );
  }
}

/// The number inside the ring. Minutes and seconds roll; a stopwatch's
/// hundredths simply change, because a digit rolling a hundred times a second
/// is not motion, it is noise.
class _Readout extends StatelessWidget {
  const _Readout({required this.timer, required this.now});

  final IslandTimer timer;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    final bool countdown = timer.kind == TimerKind.countdown;
    final Color color = timer.isFinished
        ? palette.positive
        : (timer.isRunning ? palette.textPrimary : palette.textSecondary);
    final TextStyle big = DbType.display.copyWith(
      fontSize: 30,
      letterSpacing: -1.2,
      color: color,
    );

    if (countdown) {
      return RollingText(
        Formatters.duration(timer.remainingAt(now)),
        descending: true,
        style: big,
      );
    }

    final Duration elapsed = timer.elapsedAt(now);
    final String full = Formatters.stopwatch(elapsed);
    final int dot = full.lastIndexOf('.');
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        RollingText(full.substring(0, dot), style: big),
        Text(
          full.substring(dot),
          style: DbType.numeric.copyWith(color: palette.textTertiary),
        ),
      ],
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.timer, required this.timers});

  final IslandTimer timer;
  final TimerController timers;

  @override
  Widget build(BuildContext context) {
    final bool stopwatch = timer.kind == TimerKind.stopwatch;

    if (timer.isFinished) {
      return Row(
        children: <Widget>[
          IslandButton(
            icon: DbIcons.restart,
            label: 'Again',
            tone: IslandButtonTone.accent,
            tooltip: 'Run this timer again',
            onPressed: () {
              timers.reset(timer.id);
              timers.resume(timer.id);
            },
          ),
          const SizedBox(width: DbSpace.sm),
          IslandButton(
            icon: DbIcons.check,
            label: 'Dismiss',
            tooltip: 'Remove this timer',
            onPressed: () => timers.remove(timer.id),
          ),
        ],
      );
    }


    return Row(
      children: <Widget>[
        IslandButton(
          icon: timer.isRunning ? DbIcons.pause : DbIcons.play,
          label: timer.isRunning
              ? 'Pause'
              : (timer.state == TimerState.idle ? 'Start' : 'Resume'),
          tone: IslandButtonTone.accent,
          tooltip: timer.isRunning ? 'Pause' : 'Resume',
          onPressed: () => timers.toggle(timer.id),
        ),
        const SizedBox(width: DbSpace.sm),
        if (stopwatch) ...<Widget>[
          IslandButton(
            icon: DbIcons.pin,
            label: 'Lap',
            tooltip: 'Mark a lap',
            onPressed: timer.isRunning ? () => timers.lap(timer.id) : null,
          ),
          const SizedBox(width: DbSpace.sm),
        ],
        IslandButton(
          icon: DbIcons.restart,
          tooltip: 'Reset',
          onPressed: () => timers.reset(timer.id),
        ),
      ],
    );
  }
}

/// Everything else on the page: the other timers, then a stopwatch's laps.
/// Click a timer to bring it to the front.
class _Others extends StatelessWidget {
  const _Others({
    required this.others,
    required this.laps,
    required this.timers,
  });

  final List<IslandTimer> others;
  final List<Duration> laps;
  final TimerController timers;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    if (others.isEmpty && laps.isEmpty) {
      return const SizedBox.shrink();
    }

    final DateTime now = DateTime.now();
    final List<Widget> rows = <Widget>[
      for (final IslandTimer other in others)
        _OtherRow(
          timer: other,
          now: now,
          onTap: () => timers.focus(other.id),
        ),
      for (int i = laps.length - 1; i >= 0; i--)
        _LapRow(
          index: i + 1,
          time: laps[i],
          split: i == 0 ? laps[i] : laps[i] - laps[i - 1],
        ),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.separator)),
      ),
      child: ListView(
        padding: const EdgeInsets.only(top: DbSpace.xs),
        physics: const ClampingScrollPhysics(),
        children: rows,
      ),
    );
  }
}

class _OtherRow extends StatefulWidget {
  const _OtherRow({
    required this.timer,
    required this.now,
    required this.onTap,
  });

  final IslandTimer timer;
  final DateTime now;
  final VoidCallback onTap;

  @override
  State<_OtherRow> createState() => _OtherRowState();
}

class _OtherRowState extends State<_OtherRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);
    final IslandPalette palette = theme.palette;
    final IslandTimer timer = widget.timer;
    final bool countdown = timer.kind == TimerKind.countdown;
    final Duration value = countdown
        ? timer.remainingAt(widget.now)
        : timer.elapsedAt(widget.now);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: theme.motion.scale(DbDuration.micro),
          curve: DbCurve.standard,
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: DbSpace.xs),
          decoration: BoxDecoration(
            color: _hovered ? palette.surfaceRaised : const Color(0x00000000),
            borderRadius: BorderRadius.circular(DbRadius.control),
          ),
          child: Row(
            children: <Widget>[
              TimerRing(
                size: 14,
                strokeWidth: 2,
                progress: timer.isFinished
                    ? 1
                    : (countdown ? 1 - (timer.progressAt(widget.now) ?? 0) : null),
                sweep: countdown
                    ? null
                    : timer.elapsedAt(widget.now).inMilliseconds % 60000 / 60000,
                finished: timer.isFinished,
                color: timer.isRunning || timer.isFinished
                    ? null
                    : palette.textTertiary,
              ),
              const SizedBox(width: DbSpace.sm),
              Text(
                Formatters.duration(value),
                style: DbType.numeric.copyWith(
                  color: timer.isFinished
                      ? palette.positive
                      : (timer.isRunning
                            ? palette.textPrimary
                            : palette.textTertiary),
                ),
              ),
              const SizedBox(width: DbSpace.sm),
              Expanded(
                child: Text(
                  timer.isFinished ? 'Done' : timer.displayLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DbType.caption.copyWith(color: palette.textSecondary),
                ),
              ),
              Icon(
                timer.isRunning ? DbIcons.play : DbIcons.pause,
                size: 11,
                color: palette.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LapRow extends StatelessWidget {
  const _LapRow({required this.index, required this.time, required this.split});

  final int index;
  final Duration time;
  final Duration split;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    return SizedBox(
      height: 22,
      child: Row(
        children: <Widget>[
          const SizedBox(width: DbSpace.xs),
          Text(
            'LAP $index',
            style: DbType.overline.copyWith(color: palette.textTertiary),
          ),
          const Spacer(),
          Text(
            '+${Formatters.stopwatch(split)}',
            style: DbType.caption.copyWith(color: palette.textTertiary),
          ),
          const SizedBox(width: DbSpace.md),
          Text(
            Formatters.stopwatch(time),
            style: DbType.numeric.copyWith(color: palette.textSecondary),
          ),
          const SizedBox(width: DbSpace.xs),
        ],
      ),
    );
  }
}
