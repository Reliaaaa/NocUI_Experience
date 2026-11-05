import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/logging/app_logger.dart';
import '../../native/models/native_models.dart';
import '../../native/system_bridge.dart';
import '../notifications/island_notification.dart';
import '../notifications/notification_center.dart';

/// Everything the island knows about the machine it is running on.
///
/// The controller is a thin fan-out over the native event stream. It adds two
/// pieces of judgement on top of the raw readings:
///
/// * a volume change becomes a brief heads-up, because volume is something the
///   user just did and wants confirmed;
/// * a battery crossing into low or critical becomes a notification exactly
///   once per crossing, because a warning that repeats every percent is a
///   warning that gets ignored.
class SystemController extends ChangeNotifier {
  SystemController({
    required SystemBridge bridge,
    required NotificationCenter notifications,
  }) : _bridge = bridge,
       _notifications = notifications;

  static const Logger _log = Logger('System');

  final SystemBridge _bridge;
  final NotificationCenter _notifications;
  StreamSubscription<NativeEvent>? _subscription;

  PowerStatus _power = const PowerStatus();
  VolumeStatus _volume = const VolumeStatus();
  PrivacyStatus _privacy = const PrivacyStatus();
  NetworkStatus _network = const NetworkStatus();
  PerformanceStatus _performance = const PerformanceStatus();
  PresentationState _presentation = PresentationState.normal;
  bool _foregroundCovers = false;

  bool _enabled = false;
  bool _performanceEnabled = false;
  bool _volumeHudEnabled = true;
  bool _seenFirstVolume = false;
  bool _warnedLow = false;
  bool _warnedCritical = false;

  /// How many samples the graphs keep. At one sample a second this is the last
  /// minute, which is the span over which "is something wrong right now" is
  /// actually answerable.
  static const int historyLength = 60;

  final List<double> _cpuHistory = <double>[];
  final List<double> _memoryHistory = <double>[];
  final List<double> _downHistory = <double>[];
  final List<double> _upHistory = <double>[];

  /// Rolling load history, oldest first. Empty until the sampler has produced
  /// something meaningful, which the graph renders as a flat baseline rather
  /// than a made-up line.
  List<double> get cpuHistory => _cpuHistory;
  List<double> get memoryHistory => _memoryHistory;
  List<double> get downHistory => _downHistory;
  List<double> get upHistory => _upHistory;

  /// The largest throughput seen in the window, in bytes per second. Both
  /// network lines share it so the two are directly comparable.
  double get throughputPeak {
    double peak = 0;
    for (final double value in _downHistory) {
      if (value > peak) {
        peak = value;
      }
    }
    for (final double value in _upHistory) {
      if (value > peak) {
        peak = value;
      }
    }
    return peak;
  }

  PowerStatus get power => _power;
  VolumeStatus get volume => _volume;
  PrivacyStatus get privacy => _privacy;
  NetworkStatus get network => _network;
  PerformanceStatus get performance => _performance;
  PresentationState get presentation => _presentation;

  /// True while a maximised or full-screen application is in front. The island
  /// would sit over its title bar, so it steps aside until that changes.
  bool get foregroundCovers => _foregroundCovers;

  bool get isEnabled => _enabled;
  bool get isPerformanceEnabled => _performanceEnabled;

  /// True while an application is capturing audio or video.
  bool get isRecording => _privacy.anyInUse;

  set volumeHudEnabled(bool value) => _volumeHudEnabled = value;

  Future<void> setEnabled(bool value) async {
    if (_enabled == value) {
      return;
    }
    _enabled = value;
    if (value) {
      _subscription ??= _bridge.events.listen(_onEvent);
      await _bridge.setEnabled(true);
      _log.info('System sensors enabled.');
    } else {
      await _bridge.setEnabled(false);
      await _subscription?.cancel();
      _subscription = null;
      _power = const PowerStatus();
      _volume = const VolumeStatus();
      _privacy = const PrivacyStatus();
      _network = const NetworkStatus();
      _presentation = PresentationState.normal;
      _foregroundCovers = false;
      _seenFirstVolume = false;
      _log.info('System sensors disabled.');
    }
    notifyListeners();
  }

  /// Turns the CPU and memory sampler on or off. Held only while a view that
  /// shows those numbers is on screen.
  Future<void> setPerformanceEnabled(bool value) async {
    if (_performanceEnabled == value) {
      return;
    }
    _performanceEnabled = value;
    if (!value) {
      // A graph that resumed with a minute-old line would be lying about when
      // those readings were taken.
      _cpuHistory.clear();
      _memoryHistory.clear();
      _downHistory.clear();
      _upHistory.clear();
    }
    await _bridge.setPerformanceEnabled(value);
    notifyListeners();
  }

  Future<void> refresh() => _bridge.refresh();

  Future<void> setVolume(double level) => _bridge.setVolume(level);
  Future<void> toggleMute() => _bridge.setMuted(!_volume.muted);

  void _onEvent(NativeEvent event) {
    switch (event.type) {
      case 'power':
        _power = PowerStatus.fromMap(event.data);
        _checkBattery();
        notifyListeners();

      case 'volume':
        final VolumeStatus next = VolumeStatus.fromMap(event.data);
        final bool changed =
            next.level != _volume.level || next.muted != _volume.muted;
        _volume = next;
        if (changed && _seenFirstVolume) {
          _announceVolume();
        }
        _seenFirstVolume = true;
        notifyListeners();

      case 'privacy':
        _privacy = PrivacyStatus.fromMap(event.data);
        notifyListeners();

      case 'network':
        _network = NetworkStatus.fromMap(event.data);
        notifyListeners();

      case 'performance':
        _performance = PerformanceStatus.fromMap(event.data);
        _recordHistory();
        notifyListeners();

      case 'occlusion':
        _foregroundCovers = event.read<bool>('covered') ?? false;
        notifyListeners();

      case 'presentation':
        _presentation = PresentationStateX.fromName(
          event.read<String>('state'),
        );
        _log.debug('Presentation state: ${_presentation.name}');
        notifyListeners();

      default:
        break;
    }
  }

  /// Appends the newest sample to each ring, dropping the oldest.
  ///
  /// A reading is recorded only once it is real: the first CPU sample is a
  /// seed, not a measurement, and plotting it would put a false zero at the
  /// left edge of every graph.
  void _recordHistory() {
    if (_performance.cpuValid) {
      _push(_cpuHistory, _performance.cpuPercent / 100);
    }
    if (_performance.hasMemory) {
      _push(_memoryHistory, _performance.memoryPercent / 100);
    }
    if (_performance.networkValid) {
      _push(_downHistory, _performance.networkDownBytes);
      _push(_upHistory, _performance.networkUpBytes);
    }
  }

  static void _push(List<double> series, double value) {
    series.add(value);
    if (series.length > historyLength) {
      series.removeAt(0);
    }
  }

  /// A single low priority heads-up that replaces itself, so holding the volume
  /// key produces one changing readout rather than a queue of them.
  void _announceVolume() {
    if (!_volumeHudEnabled || !_volume.available) {
      return;
    }
    _notifications.post(
      IslandNotification(
        id: 'system.volume',
        title: _volume.muted ? 'Muted' : 'Volume ${_volume.percent}%',
        kind: NotificationKind.system,
        priority: NotificationPriority.low,
        progress: _volume.muted ? 0 : _volume.level,
        lifetime: const Duration(milliseconds: 1400),
      ),
    );
  }

  void _checkBattery() {
    if (!_power.hasBattery || _power.charging) {
      // Plugging in clears the latch, so the next discharge warns again.
      _warnedLow = false;
      _warnedCritical = false;
      return;
    }
    if (_power.isCritical && !_warnedCritical) {
      _warnedCritical = true;
      _warnedLow = true;
      _notifications.post(
        IslandNotification(
          id: 'system.battery',
          title: 'Battery critical',
          body: '${_power.percent}% remaining',
          kind: NotificationKind.error,
          priority: NotificationPriority.high,
        ),
      );
      return;
    }
    if (_power.isLow && !_warnedLow) {
      _warnedLow = true;
      _notifications.post(
        IslandNotification(
          id: 'system.battery',
          title: 'Battery low',
          body: '${_power.percent}% remaining',
          kind: NotificationKind.warning,
          priority: NotificationPriority.normal,
        ),
      );
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }
}
