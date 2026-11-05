/// Human readable formatting for the small amounts of text the island shows.
///
/// Written by hand rather than pulled from a package: the island shows byte
/// counts, transfer rates and clock durations, and each is a handful of lines.
class Formatters {
  const Formatters._();

  static const List<String> _byteUnits = <String>['B', 'KB', 'MB', 'GB', 'TB'];

  /// `1.4 MB`. Uses one decimal below 100 so the width stays stable.
  static String bytes(int value) {
    if (value <= 0) {
      return '0 B';
    }
    double amount = value.toDouble();
    int unit = 0;
    while (amount >= 1024 && unit < _byteUnits.length - 1) {
      amount /= 1024;
      unit++;
    }
    if (unit == 0) {
      return '${amount.round()} ${_byteUnits[unit]}';
    }
    final String text = amount >= 100
        ? amount.round().toString()
        : amount.toStringAsFixed(1);
    return '$text ${_byteUnits[unit]}';
  }

  /// `2.1 MB/s`
  static String rate(double bytesPerSecond) {
    if (bytesPerSecond <= 0) {
      return '--';
    }
    return '${bytes(bytesPerSecond.round())}/s';
  }

  /// `4:07` or `1:02:33`. Always at least minutes and seconds.
  static String duration(Duration value) {
    final Duration clamped = value.isNegative ? Duration.zero : value;
    final int hours = clamped.inHours;
    final int minutes = clamped.inMinutes.remainder(60);
    final int seconds = clamped.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${_two(minutes)}:${_two(seconds)}';
    }
    return '$minutes:${_two(seconds)}';
  }

  /// Centiseconds for the stopwatch, where they are the point.
  static String stopwatch(Duration value) {
    final Duration clamped = value.isNegative ? Duration.zero : value;
    final int minutes = clamped.inMinutes;
    final int seconds = clamped.inSeconds.remainder(60);
    final int hundredths = (clamped.inMilliseconds.remainder(1000) / 10)
        .floor();
    return '${_two(minutes)}:${_two(seconds)}.${_two(hundredths)}';
  }

  /// Rough remaining time from a rate. Returns null when it cannot be known,
  /// which is the honest answer more often than not.
  static Duration? remaining(int transferred, int total, double rate) {
    if (total <= 0 || rate <= 0 || transferred >= total) {
      return null;
    }
    final double seconds = (total - transferred) / rate;
    if (!seconds.isFinite || seconds > 60 * 60 * 24) {
      return null;
    }
    return Duration(seconds: seconds.round());
  }

  /// Shortens a file name from the middle, keeping the extension visible.
  static String fileName(String value, {int maxLength = 34}) {
    if (value.length <= maxLength) {
      return value;
    }
    final int dot = value.lastIndexOf('.');
    final String extension = dot > 0 && value.length - dot <= 8
        ? value.substring(dot)
        : '';
    final int keep = maxLength - extension.length - 1;
    if (keep <= 4) {
      return '${value.substring(0, maxLength - 1)}…';
    }
    return '${value.substring(0, keep)}…$extension';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
