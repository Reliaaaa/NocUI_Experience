import 'package:flutter/widgets.dart';

import '../../../app/app_services.dart';
import '../../../core/utils/formatters.dart';
import '../../../design/components/island_button.dart';
import '../../../design/components/island_progress.dart';
import '../../../design/components/staggered_reveal.dart';
import '../../../design/theme/island_theme.dart';
import '../../../design/tokens/db_colors.dart';
import '../../../design/tokens/db_dimens.dart';
import '../../../design/tokens/db_icons.dart';
import '../../../design/tokens/db_typography.dart';
import '../../../modules/timers/island_timer.dart';
import '../../../modules/timers/timer_controller.dart';

/// Collapsed timer face: a ring and the number that matters.
class TimerCollapsed extends StatelessWidget {
  const TimerCollapsed({super.key});

  @override
  Widget build(BuildContext context) {
    final TimerController timers = AppScope.read(context).timers;
    final IslandPalette palette = IslandTheme.of(context).palette;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DbSpace.lg),
      child: AnimatedBuilder(
        animation: timers,
        builder: (BuildContext context, _) {
          final IslandTimer? timer = timers.primary;
          if (timer == null) {
            return const SizedBox.shrink();
          }
          final DateTime now = DateTime.now();
          final double? progress = timer.progressAt(now);
          final bool finished = timer.isFinished;

          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (progress != null)
                IslandProgressRing(
                  value: progress,
                  size: 14,
                  strokeWidth: 2,
                  color: finished ? palette.positive : palette.accent,
                )
              else
                Icon(DbIcons.clock, size: DbSize.iconSm, color: palette.accent),
              const SizedBox(width: DbSpace.md),
              Text(
                timer.kind == TimerKind.countdown
                    ? Formatters.duration(timer.remainingAt(now))
                    : Formatters.duration(timer.elapsedAt(now)),
                style: DbType.clock.copyWith(
                  color: finished ? palette.positive : palette.textPrimary,
                ),
              ),
              if (timers.timers.length > 1) ...<Widget>[
                const SizedBox(width: DbSpace.sm),
                Text(
                  '+${timers.timers.length - 1}',
                  style: DbType.caption.copyWith(color: palette.textTertiary),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Expanded timer face: the primary timer large, with its controls, and the
/// others listed beneath it.
class TimerExpanded extends StatelessWidget {
  const TimerExpanded({super.key});

  @override
  Widget build(BuildContext context) {
    final TimerController timers = AppScope.read(context).timers;
    final IslandPalette palette = IslandTheme.of(context).palette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DbSpace.xl,
        DbSpace.lg,
        DbSpace.xl,
        DbSpace.lg,
      ),
      child: AnimatedBuilder(
        animation: timers,
        builder: (BuildContext context, _) {
          final IslandTimer? primary = timers.primary;
          if (primary == null) {
            return Center(
              child: Text(
                'No timers running',
                style: DbType.body.copyWith(color: palette.textTertiary),
              ),
            );
          }
          final DateTime now = DateTime.now();
          final bool countdown = primary.kind == TimerKind.countdown;
          final Duration value = countdown
              ? primary.remainingAt(now)
              : primary.elapsedAt(now);
          final double? progress = primary.progressAt(now);
          final Color valueColor = primary.isFinished
              ? palette.positive
              : palette.textPrimary;

          final List<IslandTimer> others = timers.timers
              .where((IslandTimer timer) => timer.id != primary.id)
              .toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: staggered(<Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  Text(
                    countdown
                        ? Formatters.duration(value)
                        : Formatters.stopwatch(value),
                    style: DbType.headline.copyWith(color: valueColor),
                  ),
                  const SizedBox(width: DbSpace.md),
                  Expanded(
                    child: Text(
                      primary.isFinished ? 'Finished' : primary.displayLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DbType.body.copyWith(color: palette.textSecondary),
                    ),
                  ),
                ],
              ),
              if (progress != null) ...<Widget>[
                const SizedBox(height: DbSpace.md),
                IslandProgressBar(
                  value: progress,
                  color: primary.isFinished ? palette.positive : palette.accent,
                ),
              ],
              const SizedBox(height: DbSpace.md),
              Row(
                children: <Widget>[
                  IslandButton(
                    icon: primary.isRunning ? DbIcons.pause : DbIcons.play,
                    tone: IslandButtonTone.accent,
                    tooltip: primary.isRunning ? 'Pause' : 'Resume',
                    onPressed: primary.isFinished
                        ? null
                        : () => timers.toggle(primary.id),
                  ),
                  const SizedBox(width: DbSpace.sm),
                  IslandButton(
                    icon: DbIcons.collapse,
                    label: 'Reset',
                    tooltip: 'Reset this timer',
                    onPressed: () => timers.reset(primary.id),
                  ),
                  const Spacer(),
                  IslandButton(
                    icon: DbIcons.close,
                    tone: IslandButtonTone.danger,
                    tooltip: 'Remove this timer',
                    onPressed: () => timers.remove(primary.id),
                  ),
                ],
              ),
              const Spacer(),
              if (others.isNotEmpty) ...<Widget>[
                Container(height: 1, color: palette.separator),
                const SizedBox(height: DbSpace.sm),
                Row(
                  children: <Widget>[
                    for (final IslandTimer timer in others.take(3))
                      Padding(
                        padding: const EdgeInsets.only(right: DbSpace.md),
                        child: _TimerChip(timer: timer, now: now),
                      ),
                    if (others.length > 3)
                      Text(
                        '+${others.length - 3}',
                        style: DbType.caption.copyWith(
                          color: palette.textTertiary,
                        ),
                      ),
                  ],
                ),
              ],
            ]),
          );
        },
      ),
    );
  }
}

class _TimerChip extends StatelessWidget {
  const _TimerChip({required this.timer, required this.now});

  final IslandTimer timer;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    final Duration value = timer.kind == TimerKind.countdown
        ? timer.remainingAt(now)
        : timer.elapsedAt(now);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DbSpace.md,
        vertical: DbSpace.xs,
      ),
      decoration: BoxDecoration(
        color: palette.surfaceSunken,
        borderRadius: BorderRadius.circular(DbRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            timer.isRunning ? DbIcons.timer : DbIcons.pause,
            size: 11,
            color: palette.textTertiary,
          ),
          const SizedBox(width: DbSpace.xs),
          Text(
            Formatters.duration(value),
            style: DbType.caption.copyWith(color: palette.textSecondary),
          ),
        ],
      ),
    );
  }
}
