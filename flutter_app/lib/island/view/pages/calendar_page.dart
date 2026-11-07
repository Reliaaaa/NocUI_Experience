import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../../app/app_services.dart';
import '../../../core/time/clock_service.dart';
import '../../../design/components/db_text_field.dart';
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
import 'page_scaffold.dart';

/// The month, and what you have written on the day you picked.
///
/// Two sections side by side: the grid on the left to move around in, the
/// chosen day on the right to read and write. A note with a time on it is a
/// reminder and a note without one is just a note - they are the same thing in
/// the same list, because "remember this on Thursday" and "tell me at nine on
/// Thursday" differ only by whether a time was given.
///
/// Everything that changes here moves the way the calendar is being read: the
/// month slides in from the side you paged towards, the selection glides from
/// the day you had to the day you chose, and the day's notes arrive one after
/// another. Nothing blinks, because a calendar is a thing you look at for a
/// long time and a page that twitches is a page you stop looking at.
///
/// Reading the machine's own appointment store needs package identity, which
/// arrives with the MSIX build. Until then everything here is either
/// arithmetic on the date or something the user typed.
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  /// Width reserved for the month. Seven readable columns and nothing more;
  /// every remaining pixel is better spent on the day panel, which holds text.
  static const double _gridWidth = 200;

  DateTime? _month;
  DateTime? _selected;

  /// Which way the last month change went, so the grid slides the way the
  /// calendar is being read rather than always from the same side.
  int _direction = 1;

  /// Which way the last day change went, for the panel.
  int _dayDirection = 1;

  bool _wheelBusy = false;

  DateTime _today(BuildContext context) {
    final DateTime now = AppScope.read(context).clock.now;
    return DateTime(now.year, now.month, now.day);
  }

  void _shiftMonth(int by) {
    final DateTime current = _month ?? _today(context);
    setState(() {
      _direction = by.sign;
      _month = DateTime(current.year, current.month + by, 1);
    });
  }

  void _goToToday() {
    final DateTime today = _today(context);
    final DateTime current = _month ?? today;
    final DateTime selected = _selected ?? today;
    setState(() {
      _direction = today.isBefore(current) ? -1 : 1;
      _dayDirection = today.isBefore(selected) ? -1 : 1;
      _month = DateTime(today.year, today.month, 1);
      _selected = today;
    });
  }

  void _select(DateTime day) {
    final DateTime month = _month ?? _today(context);
    final DateTime previous = _selected ?? _today(context);
    setState(() {
      _dayDirection = day.isBefore(previous) ? -1 : 1;
      _selected = day;
      // A day from the month before or after is a request to go there, not
      // just to pick it.
      if (day.month != month.month || day.year != month.year) {
        _direction = day.isBefore(month) ? -1 : 1;
        _month = DateTime(day.year, day.month, 1);
      }
    });
  }

  /// The wheel over the grid turns months, one per gesture. Through the
  /// resolver, so the pager underneath does not turn pages with it.
  void _onWheel(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) {
      return;
    }
    GestureBinding.instance.pointerSignalResolver.register(event, (
      PointerEvent e,
    ) {
      if (e is! PointerScrollEvent || _wheelBusy) {
        return;
      }
      final double delta = e.scrollDelta.dy.abs() > e.scrollDelta.dx.abs()
          ? e.scrollDelta.dy
          : e.scrollDelta.dx;
      if (delta.abs() < 6) {
        return;
      }
      _wheelBusy = true;
      Future<void>.delayed(const Duration(milliseconds: 320), () {
        _wheelBusy = false;
      });
      _shiftMonth(delta > 0 ? 1 : -1);
    });
  }

  /// Slides a replaced child in from [direction] and the old one out the
  /// other side.
  static Widget _slide(
    Widget child,
    Animation<double> animation, {
    required int direction,
    double travel = 1,
    Axis axis = Axis.horizontal,
  }) {
    final bool incoming = animation.status != AnimationStatus.reverse;
    final double from = (incoming ? direction : -direction) * travel;
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: axis == Axis.horizontal ? Offset(from, 0) : Offset(0, from),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final CalendarController calendar = AppScope.read(context).calendar;
    final DateTime today = _today(context);
    final DateTime month = _month ?? DateTime(today.year, today.month, 1);
    final DateTime selected = _selected ?? today;
    final bool onToday = CalendarEntry.sameDay(selected, today) &&
        month.year == today.year &&
        month.month == today.month;
    final IslandThemeData theme = IslandTheme.of(context);
    final IslandPalette palette = theme.palette;

    return AnimatedBuilder(
      animation: calendar,
      builder: (BuildContext context, _) => PageScaffold(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Reveal(
              order: 0,
              child: _Header(
                month: month,
                direction: _direction,
                showToday: !onToday,
                onToday: _goToToday,
                onPrevious: () => _shiftMonth(-1),
                onNext: () => _shiftMonth(1),
                slide: _slide,
              ),
            ),
            const SizedBox(height: DbSpace.md),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SizedBox(
                    width: _gridWidth,
                    child: Reveal(
                      order: 1,
                      child: Listener(
                        onPointerSignal: _onWheel,
                        child: ClipRect(
                          child: AnimatedSwitcher(
                            duration: theme.motion.scale(DbDuration.standard),
                            switchInCurve: DbCurve.emphasized,
                            switchOutCurve: DbCurve.exit,
                            layoutBuilder:
                                (Widget? current, List<Widget> previous) =>
                                    Stack(
                                      fit: StackFit.expand,
                                      children: <Widget>[...previous, ?current],
                                    ),
                            transitionBuilder:
                                (Widget child, Animation<double> a) => _slide(
                                  child,
                                  a,
                                  direction: _direction,
                                  travel: 0.3,
                                ),
                            child: _MonthGrid(
                              key: ValueKey<String>(
                                '${month.year}-${month.month}',
                              ),
                              month: month,
                              today: today,
                              selected: selected,
                              calendar: calendar,
                              onSelect: _select,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: DbSpace.lg),
                  Expanded(
                    child: Reveal(
                      order: 2,
                      scaleFrom: 0.96,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(DbRadius.card),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: palette.surfaceSunken,
                            borderRadius: BorderRadius.circular(DbRadius.card),
                            border: Border.all(
                              color: palette.accent.withValues(alpha: 0.20),
                            ),
                          ),
                          child: AnimatedSwitcher(
                            duration: theme.motion.scale(DbDuration.quick),
                            switchInCurve: DbCurve.emphasized,
                            switchOutCurve: DbCurve.exit,
                            layoutBuilder:
                                (Widget? current, List<Widget> previous) =>
                                    Stack(
                                      fit: StackFit.expand,
                                      children: <Widget>[...previous, ?current],
                                    ),
                            transitionBuilder:
                                (Widget child, Animation<double> a) => _slide(
                                  child,
                                  a,
                                  direction: _dayDirection,
                                  travel: 0.08,
                                  axis: Axis.vertical,
                                ),
                            child: _DayPanel(
                              key: ValueKey<String>(
                                CalendarEntry.dayKey(selected),
                              ),
                              day: selected,
                              today: today,
                              calendar: calendar,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

typedef _Slide = Widget Function(
  Widget child,
  Animation<double> animation, {
  required int direction,
  double travel,
  Axis axis,
});

/// The month's name set large, the year beside it small, and the three ways
/// to move: back, forward, and home.
class _Header extends StatelessWidget {
  const _Header({
    required this.month,
    required this.direction,
    required this.showToday,
    required this.onToday,
    required this.onPrevious,
    required this.onNext,
    required this.slide,
  });

  final DateTime month;
  final int direction;
  final bool showToday;
  final VoidCallback onToday;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);
    final IslandPalette palette = theme.palette;
    final String monthYear = ClockFormat.monthYear(month);
    final int space = monthYear.lastIndexOf(' ');
    final String name = monthYear.substring(0, space);
    final String year = monthYear.substring(space + 1);

    return SizedBox(
      height: 28,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: ClipRect(
              child: AnimatedSwitcher(
                duration: theme.motion.scale(DbDuration.standard),
                switchInCurve: DbCurve.emphasized,
                switchOutCurve: DbCurve.exit,
                layoutBuilder: (Widget? current, List<Widget> previous) =>
                    Stack(
                      alignment: Alignment.centerLeft,
                      children: <Widget>[...previous, ?current],
                    ),
                transitionBuilder: (Widget child, Animation<double> a) =>
                    slide(child, a, direction: direction, travel: 0.18),
                child: Row(
                  key: ValueKey<String>(monthYear),
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: <Widget>[
                    Text(
                      name,
                      style: DbType.headline.copyWith(
                        color: palette.textPrimary,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(width: DbSpace.sm),
                    Text(
                      year,
                      style: DbType.label.copyWith(color: palette.textTertiary),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // The way home appears only when you have left, and slides in
          // from the side it will take you.
          AnimatedSize(
            duration: theme.motion.scale(DbDuration.quick),
            curve: DbCurve.emphasized,
            alignment: Alignment.centerRight,
            child: showToday
                ? Padding(
                    padding: const EdgeInsets.only(right: DbSpace.sm),
                    child: IslandButton(
                      icon: DbIcons.today,
                      label: 'Today',
                      tooltip: 'Back to today',
                      tone: IslandButtonTone.accent,
                      size: DbSize.controlSm,
                      onPressed: onToday,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          IslandButton(
            icon: DbIcons.chevronLeft,
            tooltip: 'Previous month',
            size: DbSize.controlSm,
            onPressed: onPrevious,
          ),
          const SizedBox(width: DbSpace.xs),
          IslandButton(
            icon: DbIcons.chevronRight,
            tooltip: 'Next month',
            size: DbSize.controlSm,
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

/// Six rows of seven, always. A grid that changed height between months would
/// make the page jump as you paged through it.
///
/// The selection is one pill that lives above the cells and glides to whichever
/// day is chosen. Cells never draw their own selection: a highlight that moves
/// reads as *the same choice moving*, where one that disappears here and
/// reappears there reads as two events.
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.today,
    required this.selected,
    required this.calendar,
    required this.onSelect,
    super.key,
  });

  final DateTime month;
  final DateTime today;
  final DateTime selected;
  final CalendarController calendar;
  final ValueChanged<DateTime> onSelect;

  static const int _rows = 6;

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);
    final IslandPalette palette = theme.palette;
    // DateTime.weekday counts Monday as 1, and the grid starts on Monday, so
    // the offset is simply how far into the week the first lands.
    final int leading = DateTime(month.year, month.month, 1).weekday - 1;

    DateTime dayAt(int row, int column) =>
        DateTime(month.year, month.month, row * 7 + column + 1 - leading);

    // Where the selected day sits, if it is on this sheet at all.
    int? selectedIndex;
    for (int i = 0; i < _rows * 7; i++) {
      if (CalendarEntry.sameDay(dayAt(i ~/ 7, i % 7), selected)) {
        selectedIndex = i;
        break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: 14,
          child: Row(
            children: <Widget>[
              for (int i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      ClockFormat.weekdayInitials[i],
                      style: DbType.overline.copyWith(
                        // The weekend reads a shade quieter, the way it does
                        // on a printed calendar.
                        color: i >= 5
                            ? palette.textTertiary.withValues(alpha: 0.6)
                            : palette.textTertiary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: DbSpace.xs),
        Expanded(
          child: Stack(
            children: <Widget>[
              // The pill, under the numbers, gliding.
              if (selectedIndex != null)
                AnimatedAlign(
                  duration: theme.motion.scale(DbDuration.quick),
                  curve: DbCurve.emphasized,
                  alignment: Alignment(
                    -1 + 2 * (selectedIndex % 7) / 6,
                    -1 + 2 * (selectedIndex ~/ 7) / (_rows - 1),
                  ),
                  child: FractionallySizedBox(
                    widthFactor: 1 / 7,
                    heightFactor: 1 / _rows,
                    child: Padding(
                      padding: const EdgeInsets.all(1.5),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: palette.accent.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(DbRadius.control),
                          border: Border.all(
                            color: palette.accent.withValues(alpha: 0.5),
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: palette.accent.withValues(alpha: 0.25),
                              blurRadius: 10,
                              spreadRadius: -2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              Column(
                children: <Widget>[
                  for (int row = 0; row < _rows; row++)
                    Expanded(
                      child: Row(
                        children: <Widget>[
                          for (int column = 0; column < 7; column++)
                            Expanded(
                              child: _DayCell(
                                day: dayAt(row, column),
                                inMonth: month,
                                today: today,
                                selected: selected,
                                mark: _markFor(dayAt(row, column)),
                                onSelect: onSelect,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// What the day carries: nothing, a note, or a reminder still to come.
  _Mark _markFor(DateTime day) {
    bool any = false;
    for (final CalendarEntry entry in calendar.forDay(day)) {
      any = true;
      if (entry.hasTime && !entry.notified) {
        return _Mark.reminder;
      }
    }
    return any ? _Mark.note : _Mark.none;
  }
}

enum _Mark { none, note, reminder }

class _DayCell extends StatefulWidget {
  const _DayCell({
    required this.day,
    required this.inMonth,
    required this.today,
    required this.selected,
    required this.mark,
    required this.onSelect,
  });

  final DateTime day;
  final DateTime inMonth;
  final DateTime today;
  final DateTime selected;
  final _Mark mark;
  final ValueChanged<DateTime> onSelect;

  @override
  State<_DayCell> createState() => _DayCellState();
}

class _DayCellState extends State<_DayCell> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);
    final IslandPalette palette = theme.palette;
    final DateTime day = widget.day;

    final bool outside = day.month != widget.inMonth.month;
    final bool isToday = CalendarEntry.sameDay(day, widget.today);
    final bool isSelected = CalendarEntry.sameDay(day, widget.selected);
    final bool weekend = day.weekday >= 6;

    final Color text = isSelected
        ? palette.textPrimary
        : outside
        ? palette.textTertiary.withValues(alpha: 0.4)
        : isToday
        ? palette.accent
        : weekend
        ? palette.textTertiary
        : palette.textSecondary;

    return Padding(
      padding: const EdgeInsets.all(1.5),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onSelect(day),
          child: AnimatedContainer(
            duration: theme.motion.scale(DbDuration.micro),
            curve: DbCurve.standard,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _hovered && !isSelected
                  ? palette.surfaceRaised
                  : const Color(0x00000000),
              borderRadius: BorderRadius.circular(DbRadius.control),
              border: isToday && !isSelected
                  ? Border.all(color: palette.accent.withValues(alpha: 0.5))
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                AnimatedDefaultTextStyle(
                  duration: theme.motion.scale(DbDuration.micro),
                  style: DbType.caption.copyWith(
                    color: text,
                    fontWeight: isToday || isSelected
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                  child: Text('${day.day}'),
                ),
                // A day carrying something says so without the number moving.
                if (widget.mark != _Mark.none)
                  Positioned(
                    bottom: 1.5,
                    child: Container(
                      width: 3.5,
                      height: 3.5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: outside
                            ? palette.textTertiary.withValues(alpha: 0.5)
                            : widget.mark == _Mark.reminder
                            ? palette.accent
                            : palette.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The right-hand section: one day, what is on it, and a way to add to it.
class _DayPanel extends StatefulWidget {
  const _DayPanel({
    required this.day,
    required this.today,
    required this.calendar,
    super.key,
  });

  final DateTime day;
  final DateTime today;
  final CalendarController calendar;

  @override
  State<_DayPanel> createState() => _DayPanelState();
}

class _DayPanelState extends State<_DayPanel> {
  final TextEditingController _text = TextEditingController();
  final FocusNode _focus = FocusNode(debugLabel: 'Calendar note');

  bool _timed = false;
  int _minute = 9 * 60;
  String? _editing;

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  String get _relative {
    final int days = widget.day.difference(widget.today).inDays;
    if (days == 0) {
      return 'Today';
    }
    if (days == 1) {
      return 'Tomorrow';
    }
    if (days == -1) {
      return 'Yesterday';
    }
    if (days > 0) {
      return days < 14 ? 'In $days days' : 'In ${days ~/ 7} weeks';
    }
    final int ago = -days;
    return ago < 14 ? '$ago days ago' : '${ago ~/ 7} weeks ago';
  }

  bool get _isPast => widget.day.isBefore(widget.today);
  bool get _isToday => CalendarEntry.sameDay(widget.day, widget.today);

  void _step(int minutes) {
    setState(() {
      // Wraps within the day rather than spilling into the next one: the day
      // is chosen in the grid, and a time control that silently changed it
      // would be a trap.
      _minute = (_minute + minutes + 1440) % 1440;
      _timed = true;
    });
  }

  void _startEditing(CalendarEntry entry) {
    setState(() {
      _editing = entry.id;
      _text.text = entry.text;
      _timed = entry.hasTime;
      _minute = entry.minuteOfDay ?? _minute;
    });
    _focus.requestFocus();
  }

  void _cancelEditing() {
    setState(() {
      _editing = null;
      _text.clear();
      _timed = false;
    });
  }

  void _commit() {
    final String value = _text.text.trim();
    if (value.isEmpty) {
      return;
    }
    final String? editing = _editing;
    if (editing != null) {
      for (final CalendarEntry existing in widget.calendar.entries) {
        if (existing.id != editing) {
          continue;
        }
        widget.calendar.update(
          existing.copyWith(
            text: value,
            minuteOfDay: _timed ? _minute : null,
            clearTime: !_timed,
            // Changing a reminder re-arms it; otherwise editing one that had
            // already fired would leave it silent for ever.
            notified: false,
          ),
        );
        break;
      }
    } else {
      widget.calendar.add(
        day: widget.day,
        text: value,
        minuteOfDay: _timed ? _minute : null,
      );
    }
    setState(() {
      _editing = null;
      _text.clear();
      _timed = false;
    });
    _focus.requestFocus();
  }

  String get _timeLabel {
    final String hh = (_minute ~/ 60).toString().padLeft(2, '0');
    final String mm = (_minute % 60).toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);
    final IslandPalette palette = theme.palette;
    final List<CalendarEntry> entries = widget.calendar.forDay(widget.day);
    final int reminders = entries
        .where((CalendarEntry e) => e.hasTime && !e.notified)
        .length;

    return Stack(
      children: <Widget>[
        // Today gets a wash of the accent across its top: the one day on the
        // calendar that is not like the others, drawn that way.
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedOpacity(
              duration: theme.motion.scale(DbDuration.quick),
              opacity: _isToday ? 1 : 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.center,
                    colors: <Color>[
                      palette.accent.withValues(alpha: 0.14),
                      palette.accent.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(DbSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _DayHeader(
                day: widget.day,
                relative: _relative,
                isToday: _isToday,
                isPast: _isPast,
                count: entries.length,
                reminders: reminders,
              ),
              const SizedBox(height: DbSpace.sm),
              Expanded(
                child: entries.isEmpty
                    ? _Empty(isPast: _isPast, onWrite: _focus.requestFocus)
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        physics: const ClampingScrollPhysics(),
                        itemCount: entries.length,
                        itemBuilder: (BuildContext context, int index) =>
                            _Arrive(
                              key: ValueKey<String>(entries[index].id),
                              index: index,
                              child: _Entry(
                                entry: entries[index],
                                editing: entries[index].id == _editing,
                                isPast: _isPast,
                                onTap: () => _startEditing(entries[index]),
                                onRemove: () {
                                  if (_editing == entries[index].id) {
                                    _cancelEditing();
                                  }
                                  widget.calendar.remove(entries[index].id);
                                },
                              ),
                            ),
                      ),
              ),
              const SizedBox(height: DbSpace.sm),
              _Composer(
                text: _text,
                focus: _focus,
                editing: _editing != null,
                timed: _timed,
                timeLabel: _timeLabel,
                onToggleTime: () => setState(() => _timed = !_timed),
                onEarlier: () => _step(-15),
                onLater: () => _step(15),
                onCommit: _commit,
                onCancel: _cancelEditing,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The day's number, large and rolling, with what kind of day it is.
class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.day,
    required this.relative,
    required this.isToday,
    required this.isPast,
    required this.count,
    required this.reminders,
  });

  final DateTime day;
  final String relative;
  final bool isToday;
  final bool isPast;
  final int count;
  final int reminders;

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);
    final IslandPalette palette = theme.palette;

    final String summary = count == 0
        ? ''
        : reminders > 0
        ? '$reminders reminder${reminders == 1 ? '' : 's'}'
        : '$count note${count == 1 ? '' : 's'}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        RollingText(
          '${day.day}',
          style: DbType.display.copyWith(
            fontSize: 30,
            letterSpacing: -1.2,
            color: isPast ? palette.textSecondary : palette.textPrimary,
          ),
        ),
        const SizedBox(width: DbSpace.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                ClockFormat.weekdayShort(day).toUpperCase(),
                style: DbType.overline.copyWith(
                  color: isToday ? palette.accent : palette.textTertiary,
                ),
              ),
              if (summary.isNotEmpty)
                Text(
                  summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DbType.caption.copyWith(color: palette.textTertiary),
                ),
            ],
          ),
        ),
        AnimatedContainer(
          duration: theme.motion.scale(DbDuration.micro),
          curve: DbCurve.standard,
          padding: const EdgeInsets.symmetric(
            horizontal: DbSpace.sm,
            vertical: DbSpace.xxs,
          ),
          decoration: BoxDecoration(
            color: isToday
                ? palette.accent.withValues(alpha: 0.18)
                : palette.surfaceRaised,
            borderRadius: BorderRadius.circular(DbRadius.pill),
            border: Border.all(
              color: isToday
                  ? palette.accent.withValues(alpha: 0.5)
                  : palette.stroke,
            ),
          ),
          child: Text(
            relative,
            style: DbType.caption.copyWith(
              color: isToday
                  ? palette.accent
                  : (isPast ? palette.textTertiary : palette.textSecondary),
            ),
          ),
        ),
      ],
    );
  }
}

/// A day with nothing on it says so, and offers the pen.
class _Empty extends StatelessWidget {
  const _Empty({required this.isPast, required this.onWrite});

  final bool isPast;
  final VoidCallback onWrite;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    return Center(
      child: MouseRegion(
        cursor: SystemMouseCursors.text,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onWrite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                DbIcons.notes,
                size: DbSize.iconLg,
                color: palette.textTertiary.withValues(alpha: 0.6),
              ),
              const SizedBox(height: DbSpace.sm),
              Text(
                isPast ? 'Nothing was written here.' : 'Nothing planned.',
                style: DbType.caption.copyWith(color: palette.textTertiary),
              ),
              if (!isPast)
                Text(
                  'Write a note, or set a time for a reminder.',
                  textAlign: TextAlign.center,
                  style: DbType.caption.copyWith(
                    color: palette.textTertiary.withValues(alpha: 0.7),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fades and lifts a child into place once, offset by its place in the list,
/// so a day's notes arrive one after another rather than all at once.
class _Arrive extends StatelessWidget {
  const _Arrive({required this.index, required this.child, super.key});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);
    if (theme.motion.isInstant) {
      return child;
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: theme.motion.scale(
        DbDuration.quick + DbDuration.stagger * index.clamp(0, 6),
      ),
      curve: DbCurve.emphasized,
      child: child,
      builder: (BuildContext context, double t, Widget? child) {
        // The later the row, the longer it waits; each still arrives on the
        // same curve, so the list reads as one gesture.
        final double delayed = ((t - 0.12 * index.clamp(0, 6)) /
                (1 - 0.12 * index.clamp(0, 6)))
            .clamp(0.0, 1.0);
        return Opacity(
          opacity: delayed,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - delayed)),
            child: child,
          ),
        );
      },
    );
  }
}

/// One line in the day's list: a time chip or a note glyph, the words, and
/// on hover the two things you can do to it.
class _Entry extends StatefulWidget {
  const _Entry({
    required this.entry,
    required this.editing,
    required this.isPast,
    required this.onTap,
    required this.onRemove,
  });

  final CalendarEntry entry;
  final bool editing;
  final bool isPast;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  State<_Entry> createState() => _EntryState();
}

class _EntryState extends State<_Entry> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);
    final IslandPalette palette = theme.palette;
    final CalendarEntry entry = widget.entry;
    final bool done = entry.notified || (widget.isPast && entry.hasTime);
    final bool live = entry.hasTime && !done;

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
          margin: const EdgeInsets.only(bottom: DbSpace.xs),
          padding: const EdgeInsets.symmetric(
            horizontal: DbSpace.sm,
            vertical: DbSpace.xs,
          ),
          decoration: BoxDecoration(
            color: widget.editing
                ? palette.accent.withValues(alpha: 0.14)
                : (_hovered ? palette.surfaceRaised : palette.surfaceRaised.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(DbRadius.control),
            border: Border.all(
              color: widget.editing
                  ? palette.accent.withValues(alpha: 0.5)
                  : (_hovered ? palette.stroke : const Color(0x00000000)),
            ),
          ),
          child: Stack(
            alignment: Alignment.centerRight,
            children: <Widget>[
              Row(
            children: <Widget>[
              if (entry.hasTime)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DbSpace.xs,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: live
                        ? palette.accent.withValues(alpha: 0.16)
                        : palette.surfaceSunken,
                    borderRadius: BorderRadius.circular(DbRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        done ? DbIcons.check : DbIcons.bell,
                        size: 9,
                        color: live ? palette.accent : palette.textTertiary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        entry.timeLabel,
                        style: DbType.numeric.copyWith(
                          fontSize: 10,
                          color: live ? palette.accent : palette.textTertiary,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Icon(DbIcons.notes, size: 11, color: palette.textTertiary),
              const SizedBox(width: DbSpace.sm),
              Expanded(
                child: Text(
                  entry.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: DbType.caption.copyWith(
                    color: done ? palette.textTertiary : palette.textPrimary,
                    decoration: done && entry.hasTime
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    decorationColor: palette.textTertiary,
                  ),
                ),
              ),
            ],
              ),
              // The two actions arrive over the end of the line, on a fade of
              // the row's own colour so the words behind them dissolve rather
              // than being cut.
              IgnorePointer(
                ignoring: !(_hovered || widget.editing),
                child: AnimatedOpacity(
                  opacity: _hovered || widget.editing ? 1 : 0,
                  duration: theme.motion.scale(DbDuration.micro),
                  curve: DbCurve.standard,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          palette.surfaceRaised.withValues(alpha: 0),
                          palette.surfaceRaised,
                          palette.surfaceRaised,
                        ],
                        stops: const <double>[0, 0.35, 1],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(left: DbSpace.lg),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          _Tiny(
                            icon: DbIcons.edit,
                            tooltip: 'Edit',
                            onTap: widget.onTap,
                          ),
                          _Tiny(
                            icon: DbIcons.close,
                            tooltip: 'Remove',
                            onTap: widget.onRemove,
                            danger: true,
                          ),
                        ],
                      ),
                    ),
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

class _Tiny extends StatefulWidget {
  const _Tiny({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool danger;

  @override
  State<_Tiny> createState() => _TinyState();
}

class _TinyState extends State<_Tiny> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    return Semantics(
      button: true,
      label: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: SizedBox(
            width: 18,
            height: 18,
            child: Icon(
              widget.icon,
              size: 12,
              color: _hovered
                  ? (widget.danger ? palette.negative : palette.textPrimary)
                  : palette.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}

/// The field at the foot of the day, and the time it may carry.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.text,
    required this.focus,
    required this.editing,
    required this.timed,
    required this.timeLabel,
    required this.onToggleTime,
    required this.onEarlier,
    required this.onLater,
    required this.onCommit,
    required this.onCancel,
  });

  final TextEditingController text;
  final FocusNode focus;
  final bool editing;
  final bool timed;
  final String timeLabel;
  final VoidCallback onToggleTime;
  final VoidCallback onEarlier;
  final VoidCallback onLater;
  final VoidCallback onCommit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // The words and the button that keeps them on one line; the time on
        // the next, with the whole width to open its steppers into.
        Row(
          children: <Widget>[
            Expanded(
              child: DbTextField(
                controller: text,
                focusNode: focus,
                placeholder: editing ? 'Edit the note…' : 'Add a note…',
                textStyle: DbType.caption,
                onSubmitted: (_) => onCommit(),
              ),
            ),
            const SizedBox(width: DbSpace.sm),
            IslandButton(
              icon: editing ? DbIcons.check : DbIcons.add,
              tooltip: editing ? 'Save' : 'Add',
              tone: IslandButtonTone.accent,
              size: DbSize.controlSm,
              onPressed: onCommit,
            ),
          ],
        ),
        const SizedBox(height: DbSpace.sm),
        Row(
          children: <Widget>[
            _TimeChip(
              on: timed,
              label: timed ? timeLabel : 'Remind me',
              onToggle: onToggleTime,
              onEarlier: onEarlier,
              onLater: onLater,
            ),
            const Spacer(),
            // Editing is a state you can leave; the way out is one small
            // button that appears only while you are in it.
            AnimatedSize(
              duration: theme.motion.scale(DbDuration.quick),
              curve: DbCurve.emphasized,
              child: editing
                  ? IslandButton(
                      icon: DbIcons.close,
                      label: 'Cancel',
                      tooltip: 'Stop editing',
                      size: DbSize.controlSm,
                      onPressed: onCancel,
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ],
    );
  }
}

/// The time control: a switch, and a value only when it is on.
///
/// Stepping the time turns it on, because reaching for the arrows *is* the
/// statement that a time is wanted. The steppers slide out of the chip rather
/// than appearing beside it, so the chip reads as one thing that opened.
class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.on,
    required this.label,
    required this.onToggle,
    required this.onEarlier,
    required this.onLater,
  });

  final bool on;
  final String label;
  final VoidCallback onToggle;
  final VoidCallback onEarlier;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);
    final IslandPalette palette = theme.palette;
    final Color tint = on ? palette.accent : palette.textTertiary;

    return AnimatedContainer(
      duration: theme.motion.scale(DbDuration.micro),
      curve: DbCurve.standard,
      padding: const EdgeInsets.symmetric(horizontal: DbSpace.xs),
      height: DbSize.controlSm,
      decoration: BoxDecoration(
        color: on
            ? palette.accent.withValues(alpha: 0.14)
            : palette.surfaceRaised,
        borderRadius: BorderRadius.circular(DbRadius.pill),
        border: Border.all(
          color: on ? palette.accent.withValues(alpha: 0.4) : palette.stroke,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Semantics(
            button: true,
            toggled: on,
            label: on ? 'Reminder at $label' : 'Set a reminder time',
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: DbSpace.xxs),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(DbIcons.bell, size: 11, color: tint),
                      const SizedBox(width: DbSpace.xs),
                      on
                          ? RollingText(
                              label,
                              style: DbType.numeric.copyWith(
                                fontSize: 11,
                                color: tint,
                              ),
                            )
                          : Text(
                              label,
                              style: DbType.caption.copyWith(color: tint),
                            ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: theme.motion.scale(DbDuration.quick),
            curve: DbCurve.emphasized,
            alignment: Alignment.centerLeft,
            child: on
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const SizedBox(width: DbSpace.xs),
                      _Step(
                        icon: DbIcons.collapse,
                        tooltip: 'Fifteen minutes later',
                        onPressed: onLater,
                      ),
                      _Step(
                        icon: DbIcons.expand,
                        tooltip: 'Fifteen minutes earlier',
                        onPressed: onEarlier,
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatefulWidget {
  const _Step({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  State<_Step> createState() => _StepState();
}

class _StepState extends State<_Step> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    return Semantics(
      button: true,
      label: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: SizedBox(
            width: 16,
            height: DbSize.controlSm,
            child: Icon(
              widget.icon,
              size: 14,
              color: _hovered ? palette.accent : palette.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
