import 'package:flutter/widgets.dart' show IconData, immutable;

import '../../design/tokens/db_icons.dart';

/// A place a forecast can be asked for.
@immutable
class WeatherPlace {
  const WeatherPlace({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.region = '',
    this.country = '',
  });

  final String name;
  final double latitude;
  final double longitude;
  final String region;
  final String country;

  bool get isValid =>
      latitude.abs() <= 90 && longitude.abs() <= 180 && name.isNotEmpty;

  /// `Erbil, Iraq` - the second line of a search result, and what the weather
  /// tile shows underneath the temperature.
  String get qualified {
    final String tail = country.isNotEmpty ? country : region;
    return tail.isEmpty ? name : '$name, $tail';
  }

  @override
  bool operator ==(Object other) =>
      other is WeatherPlace &&
      other.name == name &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(name, latitude, longitude);
}

/// One hour of the forecast.
@immutable
class WeatherHour {
  const WeatherHour({
    required this.time,
    required this.temperature,
    required this.code,
    this.isDay = true,
  });

  final DateTime time;
  final double temperature;
  final int code;
  final bool isDay;

  IconData get icon => WeatherCodes.icon(code, isDay: isDay);
}

/// One day of the forecast.
@immutable
class WeatherDay {
  const WeatherDay({
    required this.date,
    required this.high,
    required this.low,
    required this.code,
    this.precipitationChance = -1,
  });

  final DateTime date;
  final double high;
  final double low;
  final int code;

  /// 0..100, or -1 when the model would not say.
  final int precipitationChance;

  IconData get icon => WeatherCodes.icon(code);
  String get summary => WeatherCodes.describe(code);
}

/// What the sky is doing, and what it will do for the rest of the day.
@immutable
class WeatherReport {
  const WeatherReport({
    required this.place,
    required this.observedAt,
    required this.temperature,
    required this.feelsLike,
    required this.code,
    required this.isDay,
    required this.metric,
    this.humidity = -1,
    this.windSpeed = -1,
    this.precipitationChance = -1,
    this.hours = const <WeatherHour>[],
    this.days = const <WeatherDay>[],
  });

  final WeatherPlace place;

  /// When the reading was taken, not when it was fetched.
  final DateTime observedAt;

  final double temperature;
  final double feelsLike;

  /// WMO weather interpretation code.
  final int code;
  final bool isDay;

  /// True for Celsius and km/h, false for Fahrenheit and mph.
  final bool metric;

  /// 0..100, or -1 when unknown.
  final int humidity;

  /// In km/h or mph, or -1 when unknown.
  final double windSpeed;

  /// 0..100 chance of precipitation today, or -1 when unknown.
  final int precipitationChance;

  final List<WeatherHour> hours;
  final List<WeatherDay> days;

  WeatherDay? get today => days.isEmpty ? null : days.first;

  String get summary => WeatherCodes.describe(code);
  IconData get icon => WeatherCodes.icon(code, isDay: isDay);

  String get unitSuffix => metric ? 'C' : 'F';
  String get windUnit => metric ? 'km/h' : 'mph';

  /// `24°` - the only number on the collapsed tile, so it is rounded rather
  /// than carrying a decimal no one reads at that size.
  static String degrees(double value) => '${value.round()}°';
}

/// WMO weather interpretation codes, which is what every open forecast API
/// speaks. Grouped down to the six skies worth drawing differently.
class WeatherCodes {
  const WeatherCodes._();

  static String describe(int code) {
    switch (code) {
      case 0:
        return 'Clear';
      case 1:
        return 'Mainly clear';
      case 2:
        return 'Partly cloudy';
      case 3:
        return 'Overcast';
      case 45:
      case 48:
        return 'Fog';
      case 51:
      case 53:
      case 55:
        return 'Drizzle';
      case 56:
      case 57:
        return 'Freezing drizzle';
      case 61:
        return 'Light rain';
      case 63:
        return 'Rain';
      case 65:
        return 'Heavy rain';
      case 66:
      case 67:
        return 'Freezing rain';
      case 71:
        return 'Light snow';
      case 73:
        return 'Snow';
      case 75:
        return 'Heavy snow';
      case 77:
        return 'Snow grains';
      case 80:
      case 81:
        return 'Rain showers';
      case 82:
        return 'Heavy showers';
      case 85:
      case 86:
        return 'Snow showers';
      case 95:
        return 'Thunderstorm';
      case 96:
      case 99:
        return 'Storm with hail';
      default:
        return 'Unknown';
    }
  }

  static IconData icon(int code, {bool isDay = true}) {
    if (code == 0 || code == 1) {
      return isDay ? DbIcons.weatherClear : DbIcons.weatherNight;
    }
    if (code == 2) {
      return DbIcons.weatherPartly;
    }
    if (code == 3) {
      return DbIcons.weatherCloudy;
    }
    if (code == 45 || code == 48) {
      return DbIcons.weatherFog;
    }
    if (code >= 71 && code <= 77) {
      return DbIcons.weatherSnow;
    }
    if (code == 85 || code == 86) {
      return DbIcons.weatherSnow;
    }
    if (code >= 95) {
      return DbIcons.weatherStorm;
    }
    return DbIcons.weatherRain;
  }
}
