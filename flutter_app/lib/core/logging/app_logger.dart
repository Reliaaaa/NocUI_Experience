import 'dart:collection';
import 'dart:developer' as developer;

/// Severity of a log record. Mirrors the native `LogLevel` so that native and
/// Dart diagnostics read as one stream.
enum LogLevel { trace, debug, info, warn, error }

/// A single retained log record.
class LogRecord {
  const LogRecord({
    required this.time,
    required this.level,
    required this.tag,
    required this.message,
    this.error,
    this.stackTrace,
  });

  final DateTime time;
  final LogLevel level;
  final String tag;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;

  @override
  String toString() {
    final buffer = StringBuffer()
      ..write(_two(time.hour))
      ..write(':')
      ..write(_two(time.minute))
      ..write(':')
      ..write(_two(time.second))
      ..write(' [')
      ..write(level.name.toUpperCase().padRight(5))
      ..write('] ')
      ..write(tag)
      ..write(': ')
      ..write(message);
    if (error != null) {
      buffer.write(' | ');
      buffer.write(error);
    }
    return buffer.toString();
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}

/// Process wide logger.
///
/// Records are kept in a bounded ring buffer so the About / Diagnostics screen
/// can show recent history without a file read, and forwarded to the VM service
/// so they show up in `flutter run` and in DevTools.
class AppLog {
  AppLog._();

  static const int _capacity = 400;
  static final ListQueue<LogRecord> _records = ListQueue<LogRecord>(_capacity);

  /// Records below this level are dropped before they are stored.
  static LogLevel minimumLevel = LogLevel.debug;

  /// Optional forwarder, wired to the native logger by `bootstrap` so that a
  /// released build writes Dart and native diagnostics into the same file, in
  /// order. Failures here are ignored: logging must never be able to break the
  /// thing it is reporting on.
  static void Function(LogRecord record)? sink;

  /// Most recent records, oldest first.
  static List<LogRecord> get records => List<LogRecord>.unmodifiable(_records);

  static void write(
    LogLevel level,
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.index < minimumLevel.index) {
      return;
    }
    final record = LogRecord(
      time: DateTime.now(),
      level: level,
      tag: tag,
      message: message,
      error: error,
      stackTrace: stackTrace,
    );
    if (_records.length >= _capacity) {
      _records.removeFirst();
    }
    _records.addLast(record);
    try {
      sink?.call(record);
    } on Object {
      // Deliberately swallowed; see the note on [sink].
    }
    developer.log(
      message,
      name: 'DynamicBar.$tag',
      level: _developerLevel(level),
      error: error,
      stackTrace: stackTrace,
    );
  }

  static int _developerLevel(LogLevel level) {
    switch (level) {
      case LogLevel.trace:
        return 300;
      case LogLevel.debug:
        return 500;
      case LogLevel.info:
        return 800;
      case LogLevel.warn:
        return 900;
      case LogLevel.error:
        return 1000;
    }
  }
}

/// Tag bound logger handed to each service.
class Logger {
  const Logger(this.tag);

  final String tag;

  void trace(String message) => AppLog.write(LogLevel.trace, tag, message);
  void debug(String message) => AppLog.write(LogLevel.debug, tag, message);
  void info(String message) => AppLog.write(LogLevel.info, tag, message);
  void warn(String message, [Object? error]) =>
      AppLog.write(LogLevel.warn, tag, message, error: error);
  void error(String message, [Object? error, StackTrace? stackTrace]) =>
      AppLog.write(
        LogLevel.error,
        tag,
        message,
        error: error,
        stackTrace: stackTrace,
      );
}
