import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core/logging/app_logger.dart';
import '../notifications/island_notification.dart';
import '../notifications/notification_center.dart';
import 'calendar_entry.dart';

/// Notes and reminders on the calendar.
///
/// Holds the whole list in memory - a year of daily notes is a few thousand
/// short strings - and keeps exactly one timer, set for the next entry that is
/// actually due. A timer per reminder would mean a hundred sleeping timers to
/// deliver one notification a day.
class CalendarController extends ChangeNotifier {
  CalendarController({
    required NotificationCenter notifications,
    Directory? directory,
  }) : _notifications = notifications,
       _directoryOverride = directory;

  static const Logger _log = Logger('Calendar');
  static const String _fileName = 'calendar.json';

  /// A reminder whose moment passed while the machine was asleep is dropped
  /// rather than shown late. "Your 09:00 meeting" at half past eleven is worse
  /// than nothing.
  static const Duration _lateGrace = Duration(minutes: 10);

  final NotificationCenter _notifications;
  final Directory? _directoryOverride;

  final List<CalendarEntry> _entries = <CalendarEntry>[];
  Timer? _next;
  Timer? _saveDebounce;
  bool _loaded = false;

  List<CalendarEntry> get entries => List<CalendarEntry>.unmodifiable(_entries);
  bool get isLoaded => _loaded;

  Directory get directory {
    final Directory? override = _directoryOverride;
    if (override != null) {
      return override;
    }
    final String appData =
        Platform.environment['APPDATA'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.systemTemp.path;
    return Directory('$appData${Platform.pathSeparator}NocUIExperience');
  }

  File get file => File('${directory.path}${Platform.pathSeparator}$_fileName');

  /// Entries for one day, timed ones first and in time order, then untimed
  /// notes in the order they were written.
  List<CalendarEntry> forDay(DateTime day) {
    final List<CalendarEntry> result = <CalendarEntry>[
      for (final CalendarEntry entry in _entries)
        if (CalendarEntry.sameDay(entry.date, day)) entry,
    ];
    result.sort((CalendarEntry a, CalendarEntry b) {
      if (a.hasTime != b.hasTime) {
        return a.hasTime ? -1 : 1;
      }
      if (a.hasTime && b.hasTime) {
        return a.minuteOfDay!.compareTo(b.minuteOfDay!);
      }
      return 0;
    });
    return result;
  }

  bool hasEntriesOn(DateTime day) {
    for (final CalendarEntry entry in _entries) {
      if (CalendarEntry.sameDay(entry.date, day)) {
        return true;
      }
    }
    return false;
  }

  /// The next reminder still to come, for the collapsed pill and the Now page.
  CalendarEntry? get nextReminder {
    final DateTime now = DateTime.now();
    CalendarEntry? best;
    DateTime? bestAt;
    for (final CalendarEntry entry in _entries) {
      final DateTime? at = entry.dueAt;
      if (at == null || entry.notified || at.isBefore(now)) {
        continue;
      }
      if (bestAt == null || at.isBefore(bestAt)) {
        best = entry;
        bestAt = at;
      }
    }
    return best;
  }

  Future<void> load() async {
    if (_loaded) {
      return;
    }
    _loaded = true;
    try {
      final File target = file;
      if (target.existsSync()) {
        final String raw = await target.readAsString();
        if (raw.trim().isNotEmpty) {
          final Object? decoded = jsonDecode(raw);
          if (decoded is Map && decoded['entries'] is List) {
            for (final Object? row in decoded['entries']! as List<Object?>) {
              if (row is Map) {
                final CalendarEntry? entry = CalendarEntry.fromJson(
                  row.cast<String, Object?>(),
                );
                if (entry != null) {
                  _entries.add(entry);
                }
              }
            }
          }
        }
      }
      _log.info('${_entries.length} calendar note(s) loaded.');
    } on FormatException catch (error) {
      _log.warn('Calendar file is corrupt; starting empty.', error);
    } on FileSystemException catch (error) {
      _log.warn('Calendar file could not be read; starting empty.', error);
    }
    _reschedule();
    notifyListeners();
  }

  CalendarEntry add({
    required DateTime day,
    required String text,
    int? minuteOfDay,
  }) {
    final CalendarEntry entry = CalendarEntry(
      id: 'n${DateTime.now().microsecondsSinceEpoch}',
      date: DateTime(day.year, day.month, day.day),
      text: text.trim(),
      minuteOfDay: minuteOfDay,
    );
    _entries.add(entry);
    _changed();
    return entry;
  }

  void update(CalendarEntry entry) {
    final int index = _entries.indexWhere((CalendarEntry e) => e.id == entry.id);
    if (index < 0) {
      return;
    }
    _entries[index] = entry;
    _changed();
  }

  void remove(String id) {
    final int before = _entries.length;
    _entries.removeWhere((CalendarEntry entry) => entry.id == id);
    if (_entries.length != before) {
      _changed();
    }
  }

  void _changed() {
    _reschedule();
    _scheduleSave();
    notifyListeners();
  }

  // --- Reminders ------------------------------------------------------------

  /// Sets one timer, for the soonest entry that has not yet fired.
  void _reschedule() {
    _next?.cancel();
    _next = null;

    final DateTime now = DateTime.now();
    CalendarEntry? soonest;
    DateTime? soonestAt;
    bool latched = false;

    for (final CalendarEntry entry in _entries) {
      final DateTime? at = entry.dueAt;
      if (at == null || entry.notified) {
        continue;
      }
      if (at.isBefore(now)) {
        // Due while we were not running. Inside the grace window it still
        // means something; outside it, latch it silently so it cannot surprise
        // the user hours later.
        if (now.difference(at) <= _lateGrace) {
          _fire(entry);
        } else {
          update(entry.copyWith(notified: true));
          latched = true;
        }
        continue;
      }
      if (soonestAt == null || at.isBefore(soonestAt)) {
        soonest = entry;
        soonestAt = at;
      }
    }

    if (latched) {
      // update() already rescheduled; that pass has the corrected list.
      return;
    }
    if (soonest == null || soonestAt == null) {
      return;
    }

    // Timer accepts any duration, but a reminder six months out held as a live
    // timer is pointless; anything past a day is re-examined when the app next
    // starts or the list next changes.
    final Duration wait = soonestAt.difference(now);
    if (wait > const Duration(hours: 24)) {
      return;
    }
    final CalendarEntry due = soonest;
    _next = Timer(wait, () => _fire(due));
  }

  void _fire(CalendarEntry entry) {
    _notifications.post(
      IslandNotification(
        id: 'calendar.${entry.id}',
        title: entry.timeLabel.isEmpty ? 'Reminder' : entry.timeLabel,
        body: entry.text,
        kind: NotificationKind.info,
        priority: NotificationPriority.high,
        lifetime: const Duration(seconds: 12),
      ),
    );
    _log.info('Reminder fired: ${entry.text}');
    update(entry.copyWith(notified: true));
  }

  // --- Persistence ----------------------------------------------------------

  /// Typing produces a change per keystroke; the file does not need to.
  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 600), () {
      unawaited(flush());
    });
  }

  Future<void> flush() async {
    _saveDebounce?.cancel();
    _saveDebounce = null;
    try {
      final Directory target = directory;
      if (!target.existsSync()) {
        await target.create(recursive: true);
      }
      final File temporary = File(
        '${target.path}${Platform.pathSeparator}$_fileName.tmp',
      );
      const JsonEncoder encoder = JsonEncoder.withIndent('  ');
      await temporary.writeAsString(
        encoder.convert(<String, Object?>{
          'entries': <Object?>[
            for (final CalendarEntry entry in _entries) entry.toJson(),
          ],
        }),
        flush: true,
      );
      await temporary.rename(file.path);
    } on FileSystemException catch (error, stackTrace) {
      _log.error('Could not save calendar notes.', error, stackTrace);
    }
  }

  @override
  void dispose() {
    _next?.cancel();
    _saveDebounce?.cancel();
    super.dispose();
  }
}
