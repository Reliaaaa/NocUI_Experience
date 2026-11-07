import 'package:flutter/widgets.dart';

import '../../../app/app_services.dart';
import '../../../core/time/clock_service.dart';
import '../../../core/time/seconds_scope.dart';
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
import '../../../modules/calendar/calendar_controller.dart';
import '../../../modules/calendar/calendar_entry.dart';
import '../../../modules/system/system_controller.dart';
import '../../../modules/timers/island_timer.dart';
import '../../../modules/timers/timer_controller.dart';
import '../../../native/system_bridge.dart';
import '../../state/island_controller.dart';
import '../../state/island_page.dart';
import '../../state/island_state.dart';
import '../../../settings/app_settings.dart';
import 'home/connections_sheet.dart';
import 'home/home_deck.dart';
import 'intro_banner.dart';
import 'page_scaffold.dart';

/// The home page: the time, what is on today, and the few things worth
/// reaching without going anywhere else.
///
/// The middle of this page used to be empty, which was defensible when it was
/// only a clock and indefensible once there was something true to put there.
/// What it carries now is the answer to the question people actually open a
/// clock for - *what is next* - assembled from the notes on today's date and
/// any timer that is running, and from nothing else.
///
/// Under that sit the four panels of the [HomeDeck]: apps, power, weather and
/// network. They open under the pointer without being clicked, and the network
/// one can push a list of Wi-Fi networks or Bluetooth devices over this page -
/// which is why the page owns that state rather than the deck does.
class NowPage extends StatefulWidget {
  const NowPage({required this.controller, super.key});

  final IslandController controller;

  @override
  State<NowPage> createState() => _NowPageState();
}

class _NowPageState extends State<NowPage> {
  ConnectionsTarget? _connections;

  void _openConnections(ConnectionsTarget target) =>
      setState(() => _connections = target);

  void _closeConnections() => setState(() => _connections = null);

  @override
  Widget build(BuildContext context) {
    final AppServices services = AppScope.read(context);
    final IslandPalette palette = IslandTheme.of(context).palette;
    final AppSettings settings = services.settings.settings;
    final bool use24Hour = settings.use24HourClock;
    final bool deck = settings.homeDeckEnabled;
    final IslandController controller = widget.controller;

    return SecondsScope(
      child: PageScaffold(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Reveal(
              order: 0,
              child: AnimatedBuilder(
                animation: services.clock,
                builder: (BuildContext context, _) {
                  final DateTime now = services.clock.now;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: <Widget>[
                          // The clock is the strongest element in the summary;
                          // only digits that changed roll between values.
                          RollingText(
                            ClockFormat.time(now, use24Hour: use24Hour),
                            style: DbType.display.copyWith(
                              color: palette.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontVariations: const <FontVariation>[
                                FontVariation('wght', 600),
                              ],
                            ),
                          ),
                          const SizedBox(width: DbSpace.sm),
                          // Seconds are deliberately not rolled: a digit
                          // animating once a second at the top of the screen
                          // is the ambient motion this design exists to avoid.
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              use24Hour
                                  ? ClockFormat.seconds(now)
                                  : ClockFormat.meridiem(now),
                              style: DbType.numeric.copyWith(
                                color: palette.accent,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const Spacer(),
                          _WeekChip(now: now),
                        ],
                      ),
                      const SizedBox(height: DbSpace.sm),
                      // The date as one wide-tracked line, with the weekday
                      // carried in the accent so the eye lands on the word that
                      // answers "which day is it" before the number does.
                      _Dateline(now: now),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: DbSpace.md),
            Expanded(
              child: _Body(
                controller: controller,
                deck: deck,
                connections: _connections,
                onOpenConnections: _openConnections,
                onCloseConnections: _closeConnections,
              ),
            ),
            const SizedBox(height: DbSpace.md),
            const IntroBanner(),
            // The deck's network panel already carries the connection, the
            // battery and the volume; showing them twice on one page would be
            // the kind of duplication this design exists to avoid.
            if (!deck) Reveal(order: 2, child: const _StatusLine()),
            if (!deck) const SizedBox(height: DbSpace.md),
            Reveal(
              order: 3,
              scaleFrom: 0.95,
              child: _Actions(controller: controller, services: services),
            ),
          ],
        ),
      ),
    );
  }
}

/// What sits between the clock and the actions.
///
/// Three arrangements of the same space: today's agenda over the deck, the
/// agenda alone when the deck is switched off, or a list of connections
/// covering both. They cross-fade rather than cut, because this is the middle
/// of the page the user is already looking at.
class _Body extends StatelessWidget {
  const _Body({
    required this.controller,
    required this.deck,
    required this.connections,
    required this.onOpenConnections,
    required this.onCloseConnections,
  });

  final IslandController controller;
  final bool deck;
  final ConnectionsTarget? connections;
  final ValueChanged<ConnectionsTarget> onOpenConnections;
  final VoidCallback onCloseConnections;

  /// Height kept for today's agenda and the gap under it, before the deck is
  /// given anything. One row and its heading, which is the least that is worth
  /// showing at all.
  static const double _agendaFloor = 62;

  /// The least the agenda may be squeezed to before the deck sits a frame
  /// out. Smaller than [_agendaFloor] on purpose: the floor decides how much
  /// the deck gives back, this decides whether it appears at all, and at the
  /// smallest island scale the page has 146 for both.
  static const double _agendaMinimum = 24;

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);
    final ConnectionsTarget? target = deck ? connections : null;

    final Widget child = target != null
        ? ConnectionsSheet(
            key: const ValueKey<String>('connections'),
            target: target,
            onTargetChanged: onOpenConnections,
            onClose: onCloseConnections,
          )
        : LayoutBuilder(
            key: const ValueKey<String>('home'),
            builder: (BuildContext context, BoxConstraints constraints) {
              // A smaller island scale takes the room out of this page, and
              // the agenda has to keep a line of its own. The deck gives back
              // what it can and tightens rather than clipping.
              final double deckHeight =
                  (constraints.maxHeight - _agendaFloor).clamp(
                    HomeDeck.minHeight,
                    HomeDeck.fullHeight,
                  );
              // While the island is mid-transition - coming back from the
              // settings stage, say - a frame can arrive with less height than
              // even the shortest deck. The deck sits that frame out rather
              // than overflowing; the agenda is flexible and simply absorbs it.
              final bool showDeck =
                  deck &&
                  constraints.maxHeight >=
                      HomeDeck.minHeight + DbSpace.md + _agendaMinimum;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    child: Reveal(
                      order: 1,
                      scaleFrom: 0.97,
                      child: _Today(controller: controller),
                    ),
                  ),
                  if (showDeck) ...<Widget>[
                    const SizedBox(height: DbSpace.md),
                    Reveal(
                      order: 2,
                      scaleFrom: 0.98,
                      child: HomeDeck(
                        height: deckHeight,
                        onOpenConnections: onOpenConnections,
                      ),
                    ),
                  ],
                ],
              );
            },
          );

    return AnimatedSwitcher(
      duration: theme.motion.scale(DbDuration.quick),
      switchInCurve: DbCurve.standard,
      switchOutCurve: DbCurve.exit,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.985, end: 1).animate(animation),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// `TUESDAY · 8 SEPTEMBER`, hairline-separated.
///
/// Small caps at this size read as a label rather than as a sentence, which is
/// what lets the clock above it stay the only loud thing on the page.
class _Dateline extends StatelessWidget {
  const _Dateline({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    // `longDate` is "Tuesday, 8 September"; the weekday is everything before
    // the comma, and the rest is the day and month.
    final String full = ClockFormat.longDate(now);
    final int comma = full.indexOf(',');
    final String weekday = comma < 0 ? full : full.substring(0, comma);
    final String rest = comma < 0 ? '' : full.substring(comma + 2);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Text(
          weekday.toUpperCase(),
          style: DbType.dateline.copyWith(color: palette.accent),
        ),
        if (rest.isNotEmpty) ...<Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DbSpace.sm),
            child: Container(
              width: 1,
              height: 9,
              color: palette.separator,
            ),
          ),
          Flexible(
            child: Text(
              rest.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: DbType.dateline.copyWith(color: palette.textSecondary),
            ),
          ),
        ],
      ],
    );
  }
}

/// The ISO week number, which is the one piece of calendar arithmetic people
/// routinely need and no clock ever shows them.
class _WeekChip extends StatelessWidget {
  const _WeekChip({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surfaceSunken,
        borderRadius: BorderRadius.circular(DbRadius.pill),
        border: Border.all(color: palette.stroke),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DbSpace.sm,
          vertical: DbSpace.xxs,
        ),
        child: Text(
          'Week ${ClockFormat.isoWeek(now)}',
          style: DbType.caption.copyWith(color: palette.textTertiary),
        ),
      ),
    );
  }
}

/// What is on today: notes with a time first, then untimed ones, then any
/// timer that is running. Three lines at most, because this is a glance.
class _Today extends StatelessWidget {
  const _Today({required this.controller});

  final IslandController controller;

  static const int _maxRows = 3;

  /// One row's height, margin included, for deciding how many fit, and the
  /// heading's.
  static const double _rowHeight = 22;
  static const double _headerHeight = 14;

  @override
  Widget build(BuildContext context) {
    final AppServices services = AppScope.read(context);
    final IslandPalette palette = IslandTheme.of(context).palette;

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        services.calendar,
        services.timers,
        services.clock,
      ]),
      builder: (BuildContext context, _) {
        final CalendarController calendar = services.calendar;
        final TimerController timers = services.timers;
        final DateTime now = services.clock.now;

        final List<CalendarEntry> today = calendar.forDay(now);
        final List<IslandTimer> running = <IslandTimer>[
          for (final IslandTimer timer in timers.timers)
            if (timer.isRunning) timer,
        ];
        final int total = today.length + running.length;

        final List<Widget> rows = <Widget>[];
        for (final CalendarEntry entry in today) {
          if (rows.length >= _maxRows) {
            break;
          }
          rows.add(
            _Row(
              icon: entry.hasTime ? DbIcons.bell : DbIcons.notes,
              lead: entry.hasTime ? entry.timeLabel : '',
              text: entry.text,
              // A reminder that has already been shown is history, not agenda.
              dimmed: entry.notified,
              onTap: () => controller.goToPage(IslandPage.calendar),
            ),
          );
        }
        for (final IslandTimer timer in running) {
          if (rows.length >= _maxRows) {
            break;
          }
          rows.add(
            _Row(
              icon: DbIcons.timer,
              lead: Formatters.stopwatch(
                timer.kind == TimerKind.countdown
                    ? timer.remainingAt(now)
                    : timer.elapsedAt(now),
              ),
              text: timer.displayLabel,
              onTap: () => controller.goToPage(IslandPage.timers),
            ),
          );
        }

        return DecoratedBox(
          decoration: BoxDecoration(
            color: palette.surfaceSunken,
            borderRadius: BorderRadius.circular(DbRadius.card),
            border: Border.all(color: palette.stroke),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DbSpace.md,
              vertical: DbSpace.sm,
            ),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints box) {
                // Only as many rows as there is room for. With the deck
                // below, the card can be as short as one line, and a
                // reminder that does not fit is better counted than clipped.
                final int fit = rows.isEmpty
                    ? 0
                    : ((box.maxHeight - _headerHeight) / _rowHeight)
                          .floor()
                          .clamp(1, rows.length);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SizedBox(
                      height: _headerHeight,
                      child: Row(
                        children: <Widget>[
                          Text(
                            'TODAY',
                            style: DbType.overline.copyWith(
                              color: palette.textTertiary,
                            ),
                          ),
                          const Spacer(),
                          if (total > fit)
                            Text(
                              '+${total - fit} more',
                              style: DbType.caption.copyWith(
                                color: palette.textTertiary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: rows.isEmpty
                          ? _Empty(controller: controller)
                          // Laid out at their own height and clipped, so a
                          // row a pixel taller than the estimate loses its
                          // bottom margin rather than raising an error.
                          : ClipRect(
                              child: OverflowBox(
                                alignment: Alignment.topCenter,
                                maxHeight: double.infinity,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: rows.take(fit).toList(),
                                ),
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.controller});

  final IslandController controller;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            'Nothing on today.',
            style: DbType.caption.copyWith(color: palette.textTertiary),
          ),
          const SizedBox(width: DbSpace.sm),
          IslandButton(
            icon: DbIcons.calendar,
            label: 'Add a note',
            tooltip: 'Open the calendar',
            size: DbSize.controlSm,
            onPressed: () => controller.goToPage(IslandPage.calendar),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatefulWidget {
  const _Row({
    required this.icon,
    required this.lead,
    required this.text,
    required this.onTap,
    this.dimmed = false,
  });

  final IconData icon;
  final String lead;
  final String text;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);
    final IslandPalette palette = theme.palette;
    final Color tint = widget.dimmed ? palette.textTertiary : palette.accent;

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
          margin: const EdgeInsets.only(bottom: DbSpace.xxs),
          padding: const EdgeInsets.symmetric(
            horizontal: DbSpace.xs,
            vertical: DbSpace.xxs,
          ),
          decoration: BoxDecoration(
            color: _hovered ? palette.surfaceRaised : const Color(0x00000000),
            borderRadius: BorderRadius.circular(DbRadius.control),
          ),
          child: Row(
            children: <Widget>[
              Icon(widget.icon, size: 11, color: tint),
              if (widget.lead.isNotEmpty) ...<Widget>[
                const SizedBox(width: DbSpace.xs),
                Text(
                  widget.lead,
                  style: DbType.numeric.copyWith(color: tint),
                ),
              ],
              const SizedBox(width: DbSpace.sm),
              Expanded(
                child: Text(
                  widget.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: DbType.caption.copyWith(
                    color: widget.dimmed
                        ? palette.textTertiary
                        : palette.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A quiet line of machine state. Each reading appears only when it has
/// something true to say.
class _StatusLine extends StatelessWidget {
  const _StatusLine();

  @override
  Widget build(BuildContext context) {
    final SystemController system = AppScope.read(context).system;
    final IslandPalette palette = IslandTheme.of(context).palette;

    return AnimatedBuilder(
      animation: system,
      builder: (BuildContext context, _) {
        if (!system.isEnabled) {
          return const SizedBox.shrink();
        }
        final PowerStatus power = system.power;
        final NetworkStatus network = system.network;
        final VolumeStatus volume = system.volume;

        return Row(
          children: <Widget>[
            if (power.hasBattery)
              _Chip(
                icon: DbIcons.battery,
                label: '${power.percent}%',
                tone: power.isCritical
                    ? palette.negative
                    : (power.isLow ? palette.warning : null),
              ),
            _Chip(
              icon: network.isWifi ? DbIcons.wifi : DbIcons.network,
              label: network.connected
                  ? (network.isWifi && network.ssid.isNotEmpty
                        ? network.ssid
                        : 'Connected')
                  : 'Offline',
              tone: network.connected ? null : palette.textTertiary,
            ),
            if (volume.available)
              _Chip(
                icon: volume.muted ? DbIcons.muted : DbIcons.volume,
                label: volume.muted ? 'Muted' : '${volume.percent}%',
                tone: volume.muted ? palette.textTertiary : null,
              ),
          ],
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, this.tone});

  final IconData icon;
  final String label;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    final Color color = tone ?? palette.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(right: DbSpace.lg),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: DbSpace.xs),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 110),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: DbType.caption.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.controller, required this.services});

  final IslandController controller;
  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            'NocUI Experience',
            style: DbType.label.copyWith(color: palette.textTertiary),
          ),
        ),
        IslandButton(
          icon: DbIcons.settings,
          tooltip: 'Open settings',
          onPressed: () => services.router.openSettings(),
        ),
        const SizedBox(width: DbSpace.sm),
        IslandButton(
          icon: DbIcons.visibilityOff,
          tooltip: 'Hide the island until it is next needed',
          onPressed: () => controller.hide(trigger: IslandTrigger.user),
        ),
        const SizedBox(width: DbSpace.sm),
        IslandButton(
          icon: DbIcons.pause,
          tooltip: 'Pause NocUI Experience',
          onPressed: () => controller.setPaused(true),
        ),
        const SizedBox(width: DbSpace.sm),
        IslandButton(
          icon: DbIcons.power,
          tone: IslandButtonTone.danger,
          tooltip: 'Quit NocUI Experience',
          onPressed: () => services.window.quit(),
        ),
      ],
    );
  }
}
