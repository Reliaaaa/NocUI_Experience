import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../app/app_info.dart';
import '../../core/logging/app_logger.dart';
import 'weather_report.dart';

/// The one thing in DynamicBar that talks to the internet.
///
/// Three endpoints, all keyless and all public, so nothing here needs an
/// account, a token, or a per-user identifier:
///
/// * `api.open-meteo.com`        the forecast itself
/// * `geocoding-api.open-meteo.com`  turning a typed place name into a point
/// * `ipapi.co`                  a rough location, and only when the user has
///                               asked to have one found for them
///
/// Nothing is sent but a latitude and a longitude rounded to four decimals,
/// which is a city block. No cookies are kept, the connection is closed after
/// every call, and the whole thing is off when the weather module is off.
class WeatherService {
  WeatherService({HttpClient? client}) : _client = client ?? _defaultClient();

  static const Logger _log = Logger('Weather');

  /// Short enough that a dead network fails while the panel is still open,
  /// rather than resolving into a surface the user has already left.
  static const Duration timeout = Duration(seconds: 8);

  final HttpClient _client;

  static HttpClient _defaultClient() {
    final HttpClient client = HttpClient()
      ..connectionTimeout = timeout
      ..idleTimeout = const Duration(seconds: 5)
      ..userAgent = '${AppInfo.userAgentToken}/${AppInfo.version}';
    return client;
  }

  /// A rough location from the address the request came from. City-level at
  /// best, which is all a weather tile needs.
  Future<WeatherPlace?> locate() async {
    final Object? json = await _getJson(
      Uri.https('ipapi.co', '/json/'),
    );
    if (json is! Map<String, Object?>) {
      return null;
    }
    final double? latitude = _double(json['latitude']);
    final double? longitude = _double(json['longitude']);
    if (latitude == null || longitude == null) {
      return null;
    }
    final WeatherPlace place = WeatherPlace(
      name: (json['city'] as String?)?.trim().isNotEmpty == true
          ? json['city']! as String
          : 'Here',
      latitude: latitude,
      longitude: longitude,
      region: (json['region'] as String?) ?? '',
      country: (json['country_name'] as String?) ?? '',
    );
    return place.isValid ? place : null;
  }

  /// Places matching a typed name, best match first.
  Future<List<WeatherPlace>> search(String query) async {
    final String trimmed = query.trim();
    if (trimmed.length < 2) {
      return const <WeatherPlace>[];
    }
    final Object? json = await _getJson(
      Uri.https('geocoding-api.open-meteo.com', '/v1/search', <String, String>{
        'name': trimmed,
        'count': '6',
        'language': 'en',
        'format': 'json',
      }),
    );
    if (json is! Map<String, Object?>) {
      return const <WeatherPlace>[];
    }
    final Object? results = json['results'];
    if (results is! List) {
      return const <WeatherPlace>[];
    }
    return <WeatherPlace>[
      for (final Object? entry in results)
        if (entry is Map<String, Object?>)
          ?_place(entry),
    ];
  }

  static WeatherPlace? _place(Map<String, Object?> entry) {
    final double? latitude = _double(entry['latitude']);
    final double? longitude = _double(entry['longitude']);
    final String name = (entry['name'] as String?) ?? '';
    if (latitude == null || longitude == null || name.isEmpty) {
      return null;
    }
    return WeatherPlace(
      name: name,
      latitude: latitude,
      longitude: longitude,
      region: (entry['admin1'] as String?) ?? '',
      country: (entry['country'] as String?) ?? '',
    );
  }

  /// The current conditions plus the rest of today and the two days after it.
  Future<WeatherReport?> fetch({
    required WeatherPlace place,
    required bool metric,
  }) async {
    final Object? json = await _getJson(
      Uri.https('api.open-meteo.com', '/v1/forecast', <String, String>{
        // Four decimals is about ten metres, which is more than enough for a
        // forecast and less than enough to be a home address.
        'latitude': place.latitude.toStringAsFixed(4),
        'longitude': place.longitude.toStringAsFixed(4),
        'current':
            'temperature_2m,relative_humidity_2m,apparent_temperature,is_day,'
            'weather_code,wind_speed_10m',
        'hourly': 'temperature_2m,weather_code,is_day',
        'daily':
            'weather_code,temperature_2m_max,temperature_2m_min,'
            'precipitation_probability_max',
        'forecast_days': '3',
        'timezone': 'auto',
        'temperature_unit': metric ? 'celsius' : 'fahrenheit',
        'wind_speed_unit': metric ? 'kmh' : 'mph',
      }),
    );
    if (json is! Map<String, Object?>) {
      return null;
    }

    final Object? current = json['current'];
    if (current is! Map<String, Object?>) {
      return null;
    }
    final double? temperature = _double(current['temperature_2m']);
    if (temperature == null) {
      return null;
    }

    final DateTime observedAt =
        DateTime.tryParse((current['time'] as String?) ?? '') ?? DateTime.now();
    final bool isDay = (_double(current['is_day']) ?? 1) >= 0.5;

    return WeatherReport(
      place: place,
      observedAt: observedAt,
      temperature: temperature,
      feelsLike: _double(current['apparent_temperature']) ?? temperature,
      code: (_double(current['weather_code']) ?? 0).round(),
      isDay: isDay,
      metric: metric,
      humidity: (_double(current['relative_humidity_2m']) ?? -1).round(),
      windSpeed: _double(current['wind_speed_10m']) ?? -1,
      precipitationChance: _firstProbability(json['daily']),
      hours: _hours(json['hourly'], observedAt),
      days: _days(json['daily']),
    );
  }

  /// The next six hours from now. The series starts at midnight, so everything
  /// before the current hour is dropped rather than shown as a forecast of the
  /// past.
  static List<WeatherHour> _hours(Object? hourly, DateTime from) {
    if (hourly is! Map<String, Object?>) {
      return const <WeatherHour>[];
    }
    final Object? times = hourly['time'];
    final Object? temperatures = hourly['temperature_2m'];
    final Object? codes = hourly['weather_code'];
    final Object? isDay = hourly['is_day'];
    if (times is! List || temperatures is! List || codes is! List) {
      return const <WeatherHour>[];
    }

    final DateTime cutoff = DateTime(from.year, from.month, from.day, from.hour)
        .add(const Duration(hours: 1));
    final List<WeatherHour> hours = <WeatherHour>[];
    for (int i = 0; i < times.length && hours.length < 6; i++) {
      final DateTime? time = DateTime.tryParse('${times[i]}');
      final double? temperature = i < temperatures.length
          ? _double(temperatures[i])
          : null;
      if (time == null || temperature == null || time.isBefore(cutoff)) {
        continue;
      }
      hours.add(
        WeatherHour(
          time: time,
          temperature: temperature,
          code: i < codes.length ? (_double(codes[i]) ?? 0).round() : 0,
          isDay: isDay is! List || i >= isDay.length
              ? true
              : (_double(isDay[i]) ?? 1) >= 0.5,
        ),
      );
    }
    return hours;
  }

  static List<WeatherDay> _days(Object? daily) {
    if (daily is! Map<String, Object?>) {
      return const <WeatherDay>[];
    }
    final Object? dates = daily['time'];
    final Object? highs = daily['temperature_2m_max'];
    final Object? lows = daily['temperature_2m_min'];
    final Object? codes = daily['weather_code'];
    final Object? chances = daily['precipitation_probability_max'];
    if (dates is! List || highs is! List || lows is! List) {
      return const <WeatherDay>[];
    }

    final List<WeatherDay> days = <WeatherDay>[];
    for (int i = 0; i < dates.length; i++) {
      final DateTime? date = DateTime.tryParse('${dates[i]}');
      final double? high = i < highs.length ? _double(highs[i]) : null;
      final double? low = i < lows.length ? _double(lows[i]) : null;
      if (date == null || high == null || low == null) {
        continue;
      }
      days.add(
        WeatherDay(
          date: date,
          high: high,
          low: low,
          code: codes is List && i < codes.length
              ? (_double(codes[i]) ?? 0).round()
              : 0,
          precipitationChance: chances is List && i < chances.length
              ? (_double(chances[i]) ?? -1).round()
              : -1,
        ),
      );
    }
    return days;
  }

  static int _firstProbability(Object? daily) {
    if (daily is! Map<String, Object?>) {
      return -1;
    }
    final Object? chances = daily['precipitation_probability_max'];
    if (chances is! List || chances.isEmpty) {
      return -1;
    }
    return (_double(chances.first) ?? -1).round();
  }

  static double? _double(Object? value) {
    if (value is num) {
      return value.isFinite ? value.toDouble() : null;
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  /// One GET, decoded, with every failure funnelled into a null.
  ///
  /// A weather tile that threw would take the island's home page down with it,
  /// which is a wildly disproportionate answer to a flaky network.
  Future<Object?> _getJson(Uri uri) async {
    HttpClientResponse? response;
    try {
      final HttpClientRequest request = await _client
          .getUrl(uri)
          .timeout(timeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      response = await request.close().timeout(timeout);
      if (response.statusCode != HttpStatus.ok) {
        _log.warn('${uri.host} answered ${response.statusCode}.');
        await response.drain<void>();
        return null;
      }
      final String body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(timeout);
      return jsonDecode(body);
    } on TimeoutException {
      _log.warn('${uri.host} timed out.');
      return null;
    } on SocketException catch (error) {
      _log.warn('${uri.host} unreachable: ${error.osError?.message ?? error}');
      return null;
    } on HttpException catch (error) {
      _log.warn('${uri.host} failed: ${error.message}');
      return null;
    } on FormatException {
      _log.warn('${uri.host} sent something that was not JSON.');
      return null;
    }
  }

  void dispose() => _client.close(force: true);
}
