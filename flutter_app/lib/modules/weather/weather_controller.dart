import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/logging/app_logger.dart';
import '../../settings/app_settings.dart';
import '../../settings/settings_controller.dart';
import 'weather_report.dart';
import 'weather_service.dart';

/// Why the weather tile has nothing to show.
enum WeatherStatus {
  /// The module is switched off in settings.
  off,

  /// On, but nobody has said where. The tile offers to find out.
  noPlace,

  /// A request is in flight and there is no earlier reading to show.
  loading,

  /// The last request failed. Any earlier reading is still shown, marked stale.
  failed,

  /// A reading is current.
  ready,
}

/// The forecast for one place, kept no fresher than it needs to be.
///
/// Two rules keep this from being a background network task:
///
/// * nothing is fetched unless a view has claimed the module with [retain];
/// * a reading is reused for [freshFor] before another request is made, so
///   opening the island ten times in a minute is one request, not ten.
class WeatherController extends ChangeNotifier {
  WeatherController({
    required WeatherService service,
    required SettingsController settings,
  }) : _service = service,
       _settings = settings {
    _settings.addListener(_onSettingsChanged);
    _enabled = _settings.settings.weatherEnabled;
    _metric = _settings.settings.weatherMetric;
    _place = _placeFromSettings(_settings.settings);
  }

  static const Logger _log = Logger('Weather');

  /// How long a reading is treated as current. The models behind it publish
  /// hourly; a quarter of an hour is a reasonable compromise between a stale
  /// number and a needless request.
  static const Duration freshFor = Duration(minutes: 15);

  /// How often a claimed module re-reads while it is on screen.
  static const Duration refreshEvery = Duration(minutes: 15);

  final WeatherService _service;
  final SettingsController _settings;

  WeatherReport? _report;
  WeatherPlace? _place;
  WeatherStatus _status = WeatherStatus.off;
  DateTime? _fetchedAt;
  Timer? _timer;
  int _claims = 0;
  bool _inFlight = false;
  bool _enabled = false;
  bool _metric = true;
  bool _disposed = false;

  WeatherReport? get report => _report;
  WeatherStatus get status => _status;
  WeatherPlace? get place => _place;
  bool get isEnabled => _enabled;
  bool get isMetric => _metric;

  /// True while a request is in flight, whether or not a reading is showing.
  bool get isLoading => _inFlight;

  /// True when the newest reading is older than it should be. The tile keeps
  /// showing it, dimmed, rather than replacing a number with a spinner.
  bool get isStale {
    final DateTime? at = _fetchedAt;
    return at == null || DateTime.now().difference(at) > freshFor * 2;
  }

  /// Claims the module. The first claim fetches if what is held is stale.
  Future<void> retain() async {
    _claims++;
    if (_claims != 1) {
      return;
    }
    _startTimer();
    await refresh();
  }

  void release() {
    if (_claims == 0) {
      return;
    }
    _claims--;
    if (_claims == 0) {
      _timer?.cancel();
      _timer = null;
    }
  }

  /// Fetches unless the held reading is still current.
  ///
  /// [force] is what the refresh button does; everything else respects
  /// [freshFor], including the periodic timer, so a machine left with the
  /// island open does not turn into a polling client.
  Future<void> refresh({bool force = false}) async {
    if (!_enabled) {
      _set(WeatherStatus.off);
      return;
    }
    if (_inFlight) {
      return;
    }

    WeatherPlace? place = _place;
    if (place == null) {
      if (!_settings.settings.weatherAutoLocate) {
        _set(WeatherStatus.noPlace);
        return;
      }
      place = await _locate();
      if (place == null) {
        _set(WeatherStatus.noPlace);
        return;
      }
    }

    final DateTime? at = _fetchedAt;
    final bool fresh =
        !force &&
        _report != null &&
        _report!.metric == _metric &&
        _report!.place == place &&
        at != null &&
        DateTime.now().difference(at) < freshFor;
    if (fresh) {
      return;
    }

    _inFlight = true;
    if (_report == null) {
      _status = WeatherStatus.loading;
    }
    _notify();

    final WeatherReport? next = await _service.fetch(
      place: place,
      metric: _metric,
    );
    _inFlight = false;
    if (_disposed) {
      return;
    }
    if (next == null) {
      _set(WeatherStatus.failed);
      return;
    }
    _report = next;
    _fetchedAt = DateTime.now();
    _set(WeatherStatus.ready);
  }

  /// Asks the network roughly where this machine is and remembers the answer,
  /// so the lookup happens once rather than on every fetch.
  Future<WeatherPlace?> _locate() async {
    if (_inFlight) {
      return null;
    }
    _inFlight = true;
    if (_report == null) {
      _status = WeatherStatus.loading;
    }
    _notify();

    final WeatherPlace? found = await _service.locate();
    _inFlight = false;
    if (found == null || _disposed) {
      _notify();
      return null;
    }
    _log.info('Located ${found.qualified} for the forecast.');
    _place = found;
    _settings.mutate(
      (AppSettings current) => current.copyWith(
        weatherPlace: found.qualified,
        weatherLatitude: found.latitude,
        weatherLongitude: found.longitude,
      ),
    );
    return found;
  }

  /// Places matching a typed name, for the picker in settings. A search is a
  /// deliberate act, so it is not gated on the module being claimed.
  Future<List<WeatherPlace>> search(String query) => _service.search(query);

  /// Looks the location up now, because the user asked for it in settings.
  Future<void> locateNow() async {
    final WeatherPlace? found = await _locate();
    if (found != null) {
      await refresh(force: true);
    } else {
      _set(_report == null ? WeatherStatus.noPlace : _status);
    }
  }

  /// Points the module at a place the user picked in settings.
  void setPlace(WeatherPlace place) {
    _place = place;
    _settings.mutate(
      (AppSettings current) => current.copyWith(
        weatherPlace: place.qualified,
        weatherLatitude: place.latitude,
        weatherLongitude: place.longitude,
        weatherEnabled: true,
      ),
    );
    unawaited(refresh(force: true));
  }

  void _onSettingsChanged() {
    final AppSettings settings = _settings.settings;
    final WeatherPlace? place = _placeFromSettings(settings);
    final bool changed =
        settings.weatherEnabled != _enabled ||
        settings.weatherMetric != _metric ||
        place != _place;
    if (!changed) {
      return;
    }

    _enabled = settings.weatherEnabled;
    _metric = settings.weatherMetric;
    _place = place;
    if (!_enabled) {
      _report = null;
      _fetchedAt = null;
      _timer?.cancel();
      _timer = null;
      _set(WeatherStatus.off);
      return;
    }
    if (_claims > 0) {
      _startTimer();
      unawaited(refresh(force: true));
    }
  }

  static WeatherPlace? _placeFromSettings(AppSettings settings) {
    if (settings.weatherLatitude == null || settings.weatherLongitude == null) {
      return null;
    }
    final WeatherPlace place = WeatherPlace(
      name: settings.weatherPlace.isEmpty ? 'Here' : settings.weatherPlace,
      latitude: settings.weatherLatitude!,
      longitude: settings.weatherLongitude!,
    );
    return place.isValid ? place : null;
  }

  void _startTimer() {
    _timer?.cancel();
    if (!_enabled) {
      return;
    }
    _timer = Timer.periodic(refreshEvery, (_) => unawaited(refresh()));
  }

  void _set(WeatherStatus status) {
    _status = status;
    _notify();
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    _settings.removeListener(_onSettingsChanged);
    _service.dispose();
    super.dispose();
  }
}
