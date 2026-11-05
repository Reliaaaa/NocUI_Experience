import 'package:flutter/foundation.dart';

/// A note attached to a day, optionally with a time to be reminded at.
///
/// Two things in one because they are one thing to the user: "remember this on
/// Thursday" and "tell me at nine on Thursday" differ only by whether a time
/// was given. Splitting them into notes and reminders would mean two lists, two
/// editors and a decision to make before typing.
@immutable
class CalendarEntry {
  const CalendarEntry({
    required this.id,
    required this.date,
    required this.text,
    this.minuteOfDay,
    this.notified = false,
  });

  final String id;

  /// Midnight on the day this belongs to. Local time; a reminder is a promise
  /// about the user's clock, not about UTC.
  final DateTime date;

  final String text;

  /// Minutes past midnight, or null for a note with no time. A note with no
  /// time never raises a reminder.
  final int? minuteOfDay;

  /// Whether its reminder has already been shown. Latched so a reminder cannot
  /// fire twice, and so one missed by the machine being asleep is not replayed
  /// hours later out of context.
  final bool notified;

  bool get hasTime => minuteOfDay != null;

  /// The moment this is due, or null when it carries no time.
  DateTime? get dueAt {
    final int? minute = minuteOfDay;
    if (minute == null) {
      return null;
    }
    return DateTime(date.year, date.month, date.day, minute ~/ 60, minute % 60);
  }

  String get timeLabel {
    final int? minute = minuteOfDay;
    if (minute == null) {
      return '';
    }
    final String hh = (minute ~/ 60).toString().padLeft(2, '0');
    final String mm = (minute % 60).toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  CalendarEntry copyWith({
    String? text,
    int? minuteOfDay,
    bool clearTime = false,
    bool? notified,
  }) {
    return CalendarEntry(
      id: id,
      date: date,
      text: text ?? this.text,
      minuteOfDay: clearTime ? null : (minuteOfDay ?? this.minuteOfDay),
      notified: notified ?? this.notified,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    // Date only: the day is what was chosen, and storing an instant would make
    // an entry drift across midnight when the clock changes.
    'date':
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}',
    'text': text,
    'minuteOfDay': minuteOfDay,
    'notified': notified,
  };

  /// Returns null for anything that cannot be read back as a real entry, so a
  /// hand-edited or truncated file loses only the damaged rows.
  static CalendarEntry? fromJson(Map<String, Object?> json) {
    final Object? id = json['id'];
    final Object? date = json['date'];
    final Object? text = json['text'];
    if (id is! String || date is! String || text is! String) {
      return null;
    }
    final List<String> parts = date.split('-');
    if (parts.length != 3) {
      return null;
    }
    final int? year = int.tryParse(parts[0]);
    final int? month = int.tryParse(parts[1]);
    final int? day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) {
      return null;
    }
    final Object? minute = json['minuteOfDay'];
    return CalendarEntry(
      id: id,
      date: DateTime(year, month, day),
      text: text,
      minuteOfDay: minute is num && minute >= 0 && minute < 1440
          ? minute.toInt()
          : null,
      notified: json['notified'] is bool ? json['notified']! as bool : false,
    );
  }

  /// Days are compared by their calendar date, never by instant.
  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String dayKey(DateTime day) =>
      '${day.year}-${day.month}-${day.day}';
}
