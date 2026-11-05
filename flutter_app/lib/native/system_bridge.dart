import 'native_channel.dart';

/// Battery and power source.
class PowerStatus {
  const PowerStatus({
    this.hasBattery = false,
    this.charging = false,
    this.onAcPower = true,
    this.percent = -1,
    this.minutesRemaining = -1,
    this.saverOn = false,
  });

  final bool hasBattery;
  final bool charging;
  final bool onAcPower;

  /// 0..100, or -1 when unknown.
  final int percent;

  /// Estimated runtime left, or -1 when Windows will not say.
  final int minutesRemaining;
  final bool saverOn;

  bool get isLow => hasBattery && !charging && percent >= 0 && percent <= 20;
  bool get isCritical =>
      hasBattery && !charging && percent >= 0 && percent <= 8;

  static PowerStatus fromMap(Map<Object?, Object?> map) => PowerStatus(
    hasBattery: (map['hasBattery'] as bool?) ?? false,
    charging: (map['charging'] as bool?) ?? false,
    onAcPower: (map['onAcPower'] as bool?) ?? true,
    percent: (map['percent'] as num?)?.toInt() ?? -1,
    minutesRemaining: (map['minutesRemaining'] as num?)?.toInt() ?? -1,
    saverOn: (map['saverOn'] as bool?) ?? false,
  );
}

/// Default output device volume.
class VolumeStatus {
  const VolumeStatus({
    this.available = false,
    this.level = 0,
    this.muted = false,
  });

  final bool available;

  /// 0..1.
  final double level;
  final bool muted;

  int get percent => (level * 100).round();

  static VolumeStatus fromMap(Map<Object?, Object?> map) => VolumeStatus(
    available: (map['available'] as bool?) ?? false,
    level: (map['level'] as num?)?.toDouble() ?? 0,
    muted: (map['muted'] as bool?) ?? false,
  );
}

/// Whether the microphone or camera is being captured right now.
class PrivacyStatus {
  const PrivacyStatus({this.microphoneInUse = false, this.cameraInUse = false});

  final bool microphoneInUse;
  final bool cameraInUse;

  bool get anyInUse => microphoneInUse || cameraInUse;

  static PrivacyStatus fromMap(Map<Object?, Object?> map) => PrivacyStatus(
    microphoneInUse: (map['microphone'] as bool?) ?? false,
    cameraInUse: (map['camera'] as bool?) ?? false,
  );
}

/// Connectivity, and Wi-Fi details when the connection is wireless.
class NetworkStatus {
  const NetworkStatus({
    this.connected = false,
    this.hasInternet = false,
    this.isWifi = false,
    this.ssid = '',
    this.signal = -1,
  });

  final bool connected;
  final bool hasInternet;
  final bool isWifi;
  final String ssid;

  /// 0..100 signal quality, or -1 when not a wireless connection.
  final int signal;

  static NetworkStatus fromMap(Map<Object?, Object?> map) => NetworkStatus(
    connected: (map['connected'] as bool?) ?? false,
    hasInternet: (map['internet'] as bool?) ?? false,
    isWifi: (map['wifi'] as bool?) ?? false,
    ssid: (map['ssid'] as String?) ?? '',
    signal: (map['signal'] as num?)?.toInt() ?? -1,
  );
}

/// CPU and memory load. Sampled, not pushed; see [SystemBridge].
class PerformanceStatus {
  const PerformanceStatus({
    this.cpuPercent = 0,
    this.memoryPercent = 0,
    this.memoryUsedBytes = 0,
    this.memoryTotalBytes = 0,
    this.networkDownBytes = 0,
    this.networkUpBytes = 0,
    this.cpuValid = false,
    this.networkValid = false,
  });

  final double cpuPercent;
  final double memoryPercent;
  final int memoryUsedBytes;
  final int memoryTotalBytes;

  /// Bytes per second in and out, summed across every operational adapter.
  final double networkDownBytes;
  final double networkUpBytes;

  /// False until a second sample has been taken. CPU load is a delta between
  /// two readings, so the first one carries no information.
  final bool cpuValid;

  /// Throughput is a delta too, and additionally needs the adapter table to
  /// have been readable at all.
  final bool networkValid;

  bool get hasMemory => memoryTotalBytes > 0;

  static PerformanceStatus fromMap(Map<Object?, Object?> map) =>
      PerformanceStatus(
        cpuPercent: (map['cpu'] as num?)?.toDouble() ?? 0,
        memoryPercent: (map['memory'] as num?)?.toDouble() ?? 0,
        memoryUsedBytes: (map['memoryUsed'] as num?)?.toInt() ?? 0,
        memoryTotalBytes: (map['memoryTotal'] as num?)?.toInt() ?? 0,
        networkDownBytes: (map['networkDown'] as num?)?.toDouble() ?? 0,
        networkUpBytes: (map['networkUp'] as num?)?.toDouble() ?? 0,
        cpuValid: (map['cpuValid'] as bool?) ?? false,
        networkValid: (map['networkValid'] as bool?) ?? false,
      );
}

/// What the user is doing, as far as the shell will say.
///
/// Anything other than [normal] means an overlay would be an intrusion: a game
/// is running exclusive full screen, a presentation is projecting, or the user
/// has asked Windows for quiet.
enum PresentationState {
  normal,
  busy,
  fullscreen,
  fullscreenApp,
  presentation,
  quiet,
}

extension PresentationStateX on PresentationState {
  /// Whether the island should stay out of the way.
  bool get shouldSuppress => this != PresentationState.normal;

  static PresentationState fromName(String? name) {
    for (final state in PresentationState.values) {
      if (state.name == name) {
        return state;
      }
    }
    return PresentationState.normal;
  }
}

/// System sensors, all on their native event sources.
class SystemBridge extends NativeChannel {
  SystemBridge()
    : super('dynamicbar/system', eventChannelName: 'dynamicbar/system/events');

  Future<bool> setEnabled(bool enabled) async =>
      await invoke<bool>('setEnabled', <String, Object?>{'enabled': enabled}) ??
      false;

  /// CPU and memory have no notification API, so they are sampled on a timer.
  /// That timer exists only between this being turned on and off again, which
  /// the UI ties to a face that actually shows the numbers.
  Future<bool> setPerformanceEnabled(bool enabled) async =>
      await invoke<bool>('setPerformanceEnabled', <String, Object?>{
        'enabled': enabled,
      }) ??
      false;

  Future<void> refresh() => invoke<void>('refresh');

  Future<bool> setVolume(double level) async =>
      await invoke<bool>('setVolume', <String, Object?>{'level': level}) ??
      false;

  Future<bool> setMuted(bool muted) async =>
      await invoke<bool>('setMuted', <String, Object?>{'muted': muted}) ??
      false;
}
