import 'native_channel.dart';

/// A radio, as Windows reports it.
///
/// `absent` and `unknown` are kept apart on purpose: a machine with no
/// Bluetooth hardware should say so, while one whose radio could not be read
/// should not be drawn as switched off.
enum RadioState { on, off, disabled, absent, unknown }

extension RadioStateX on RadioState {
  bool get isOn => this == RadioState.on;

  /// Whether a switch should be offered at all.
  bool get isControllable =>
      this == RadioState.on || this == RadioState.off;

  String get label {
    switch (this) {
      case RadioState.on:
        return 'On';
      case RadioState.off:
        return 'Off';
      case RadioState.disabled:
        return 'Blocked';
      case RadioState.absent:
        return 'Not fitted';
      case RadioState.unknown:
        return 'Unknown';
    }
  }

  static RadioState fromName(String? name) {
    for (final RadioState state in RadioState.values) {
      if (state.name == name) {
        return state;
      }
    }
    return RadioState.unknown;
  }
}

/// One wireless network, as the user thinks of it: a name, a strength, and
/// whether this machine already knows how to get on it.
class WifiNetwork {
  const WifiNetwork({
    required this.ssid,
    this.signal = 0,
    this.secured = false,
    this.saved = false,
    this.connected = false,
  });

  final String ssid;

  /// 0..100 signal quality.
  final int signal;
  final bool secured;

  /// A stored profile exists, so one click is enough to connect.
  final bool saved;
  final bool connected;

  /// 0..4, for a four-bar glyph.
  int get bars => signal <= 0
      ? 0
      : signal >= 75
      ? 4
      : signal >= 50
      ? 3
      : signal >= 25
      ? 2
      : 1;

  static WifiNetwork? fromMap(Object? value) {
    if (value is! Map) {
      return null;
    }
    final String ssid = (value['ssid'] as String?) ?? '';
    if (ssid.isEmpty) {
      return null;
    }
    return WifiNetwork(
      ssid: ssid,
      signal: (value['signal'] as num?)?.toInt() ?? 0,
      secured: (value['secured'] as bool?) ?? false,
      saved: (value['saved'] as bool?) ?? false,
      connected: (value['connected'] as bool?) ?? false,
    );
  }
}

/// One paired Bluetooth device.
class BluetoothDeviceInfo {
  const BluetoothDeviceInfo({
    required this.address,
    required this.name,
    this.connected = false,
    this.paired = false,
    this.kind = 'device',
  });

  final String address;
  final String name;
  final bool connected;
  final bool paired;

  /// Coarse class of device - audio, input, phone, computer, wearable,
  /// imaging or device - used only to pick an icon.
  final String kind;

  static BluetoothDeviceInfo? fromMap(Object? value) {
    if (value is! Map) {
      return null;
    }
    final String address = (value['address'] as String?) ?? '';
    if (address.isEmpty) {
      return null;
    }
    return BluetoothDeviceInfo(
      address: address,
      name: (value['name'] as String?) ?? address,
      connected: (value['connected'] as bool?) ?? false,
      paired: (value['paired'] as bool?) ?? false,
      kind: (value['kind'] as String?) ?? 'device',
    );
  }
}

/// Everything known about Wi-Fi at one moment.
class WifiSnapshot {
  const WifiSnapshot({
    this.available = false,
    this.radio = RadioState.unknown,
    this.scanning = false,
    this.networks = const <WifiNetwork>[],
  });

  static const WifiSnapshot empty = WifiSnapshot();

  /// Whether this machine has a wireless interface at all.
  final bool available;
  final RadioState radio;
  final bool scanning;
  final List<WifiNetwork> networks;

  WifiNetwork? get connected {
    for (final WifiNetwork network in networks) {
      if (network.connected) {
        return network;
      }
    }
    return null;
  }

  static WifiSnapshot fromMap(Map<Object?, Object?> map) => WifiSnapshot(
    available: (map['available'] as bool?) ?? false,
    radio: RadioStateX.fromName(map['radio'] as String?),
    scanning: (map['scanning'] as bool?) ?? false,
    networks: <WifiNetwork>[
      for (final Object? entry in (map['networks'] as List<Object?>?) ??
          const <Object?>[])
        ?WifiNetwork.fromMap(entry),
    ],
  );
}

/// Everything known about Bluetooth at one moment.
class BluetoothSnapshot {
  const BluetoothSnapshot({
    this.available = false,
    this.radio = RadioState.unknown,
    this.devices = const <BluetoothDeviceInfo>[],
  });

  static const BluetoothSnapshot empty = BluetoothSnapshot();

  final bool available;
  final RadioState radio;

  /// Paired devices, connected ones first.
  final List<BluetoothDeviceInfo> devices;

  int get connectedCount {
    int count = 0;
    for (final BluetoothDeviceInfo device in devices) {
      if (device.connected) {
        count++;
      }
    }
    return count;
  }

  static BluetoothSnapshot fromMap(Map<Object?, Object?> map) =>
      BluetoothSnapshot(
        available: (map['available'] as bool?) ?? false,
        radio: RadioStateX.fromName(map['radio'] as String?),
        devices: <BluetoothDeviceInfo>[
          for (final Object? entry in (map['devices'] as List<Object?>?) ??
              const <Object?>[])
            ?BluetoothDeviceInfo.fromMap(entry),
        ],
      );
}

/// Wi-Fi networks, paired Bluetooth devices, and the two radio switches.
///
/// Everything is gated behind [setEnabled]: the lists are only worth keeping
/// current while a surface that shows them is on screen, and a scan is a real
/// cost - it takes seconds and briefly interrupts throughput on the connection
/// it is scanning from.
class ConnectivityBridge extends NativeChannel {
  ConnectivityBridge()
    : super(
        'dynamicbar/connectivity',
        eventChannelName: 'dynamicbar/connectivity/events',
      );

  Future<bool> setEnabled(bool enabled) async =>
      await invoke<bool>('setEnabled', <String, Object?>{'enabled': enabled}) ??
      false;

  /// Re-reads both lists from what Windows already knows. Cheap: no radio time
  /// is spent, so this is what a panel opening does.
  Future<bool> refresh() async => await invoke<bool>('refresh') ?? false;

  /// Asks the wireless interface to look for networks. Expensive, so it only
  /// happens when someone asked to see the list.
  Future<bool> scan() async => await invoke<bool>('scan') ?? false;

  /// Connects using the profile Windows already has for [ssid]. Returns false
  /// for a network this machine has never joined - those need Windows' own
  /// credential prompt.
  Future<bool> connect(String ssid) async =>
      await invoke<bool>('connect', <String, Object?>{'ssid': ssid}) ?? false;

  Future<bool> disconnect() async =>
      await invoke<bool>('disconnect') ?? false;

  Future<bool> setRadio({required bool bluetooth, required bool on}) async =>
      await invoke<bool>('setRadio', <String, Object?>{
        'kind': bluetooth ? 'bluetooth' : 'wifi',
        'on': on,
      }) ??
      false;
}
