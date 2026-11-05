import 'dart:async';

import 'package:flutter/foundation.dart';

/// The wall clock, ticked exactly as often as something is actually watching.
///
/// A desktop utility that redraws a clock once a second all day is a desktop
/// utility that costs battery for nothing. This service ticks on minute
/// boundaries by default, and only switches to a one second cadence while a
/// view has explicitly asked for seconds — the expanded island, and nothing
/// else. Timers are aligned to the boundary rather than started at an arbitrary
/// offset, so the displayed value changes when the real minute does.
class ClockService extends ChangeNotifier {
  ClockService({DateTime Function()? now}) : _now = now ?? DateTime.now {
    _schedule();
  }

  final DateTime Function() _now;
  Timer? _timer;
  int _secondSubscribers = 0;
  bool _disposed = false;

  DateTime get now => _now();

  bool get isTickingSeconds => _secondSubscribers > 0;

  /// Asks for second precision. Every call must be paired with
  /// [releaseSeconds]; the faster timer stops as soon as the count drops to 0.
  void acquireSeconds() {
    _secondSubscribers++;
    if (_secondSubscribers == 1) {
      _schedule();
    }
  }

  void releaseSeconds() {
    if (_secondSubscribers == 0) {
      return;
    }
    _secondSubscribers--;
    if (_secondSubscribers == 0) {
      _schedule();
    }
  }

  void _schedule() {
    _timer?.cancel();
    if (_disposed) {
      return;
    }
    final DateTime current = _now();
    final Duration delay;
    if (_secondSubscribers > 0) {
      delay = Duration(milliseconds: 1000 - current.millisecond);
    } else {
      delay = Duration(
        seconds: 60 - current.second,
        milliseconds: -current.millisecond,
      );
    }
    _timer = Timer(delay.isNegative ? Duration.zero : delay, _onTick);
  }

  void _onTick() {
    if (_disposed) {
      return;
    }
    notifyListeners();
    _schedule();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}

/// Formatting helpers.
///
/// Written by hand rather than pulled from `intl`: the island shows a clock and
/// a date in the user's chosen 12/24 hour style, which is a dozen lines, and a
/// localisation package would be a large dependency for it.
class ClockFormat {
  const ClockFormat._();

  static const List<String> _weekdays = <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  static const List<String> _months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String time(DateTime value, {bool use24Hour = true}) {
    if (use24Hour) {
      return '${_two(value.hour)}:${_two(value.minute)}';
    }
    final int hour12 = value.hour % 12 == 0 ? 12 : value.hour % 12;
    return '$hour12:${_two(value.minute)}';
  }

  static String meridiem(DateTime value) => value.hour < 12 ? 'AM' : 'PM';

  static String seconds(DateTime value) => _two(value.second);

  /// `Mon 8 Sep`
  static String shortDate(DateTime value) =>
      '${_weekdays[value.weekday - 1]} ${value.day} ${_months[value.month - 1]}';

  /// `Monday, 8 September`
  static String longDate(DateTime value) {
    const List<String> longWeekdays = <String>[
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const List<String> longMonths = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${longWeekdays[value.weekday - 1]}, ${value.day} '
        '${longMonths[value.month - 1]}';
  }

  /// `September 2026`
  static String monthYear(DateTime value) {
    const List<String> longMonths = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${longMonths[value.month - 1]} ${value.year}';
  }

  /// Single letters for a calendar header, Monday first - the arrangement the
  /// rest of this application already assumes, since [DateTime.weekday] counts
  /// from Monday.
  static const List<String> weekdayInitials = <String>[
    'M',
    'T',
    'W',
    'T',
    'F',
    'S',
    'S',
  ];

  static String weekdayShort(DateTime value) => _weekdays[value.weekday - 1];

  /// ISO 8601 week number. Weeks start on Monday and the first week of a year
  /// is the one containing its first Thursday, which is why this counts from
  /// the Thursday of the week in question rather than from 1 January.
  static int isoWeek(DateTime value) {
    final DateTime thursday = DateTime(
      value.year,
      value.month,
      value.day,
    ).add(Duration(days: 4 - value.weekday));
    final int dayOfYear =
        thursday.difference(DateTime(thursday.year, 1, 1)).inDays + 1;
    return ((dayOfYear - 1) ~/ 7) + 1;
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
