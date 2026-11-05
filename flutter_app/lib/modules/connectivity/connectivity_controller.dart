import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/logging/app_logger.dart';
import '../../native/connectivity_bridge.dart';
import '../../native/models/native_models.dart';
import '../notifications/island_notification.dart';
import '../notifications/notification_center.dart';

/// What this machine is connected to, and the two switches that change it.
///
/// The native side is only watching while someone is looking at it. Views take
/// a claim with [retain] and drop it with [release]; the sensors run for as
/// long as at least one claim is held. A tray utility that kept a WLAN handle
/// open and a Bluetooth enumeration warm all day would be a battery cost with
/// nothing on screen to justify it.
class ConnectivityController extends ChangeNotifier {
  ConnectivityController({
    required ConnectivityBridge bridge,
    required NotificationCenter notifications,
  }) : _bridge = bridge,
       _notifications = notifications;

  static const Logger _log = Logger('Connectivity');

  final ConnectivityBridge _bridge;
  final NotificationCenter _notifications;
  StreamSubscription<NativeEvent>? _subscription;

  WifiSnapshot _wifi = WifiSnapshot.empty;
  BluetoothSnapshot _bluetooth = BluetoothSnapshot.empty;
  int _claims = 0;
  bool _busy = false;

  WifiSnapshot get wifi => _wifi;
  BluetoothSnapshot get bluetooth => _bluetooth;

  bool get isEnabled => _claims > 0;

  /// True while a connect or a radio change is in flight. Long enough to be
  /// worth showing: joining a network takes a second or two.
  bool get isBusy => _busy;

  /// Starts the sensors if this is the first claim.
  Future<void> retain() async {
    _claims++;
    if (_claims != 1) {
      return;
    }
    _subscription ??= _bridge.events.listen(_onEvent);
    await _bridge.setEnabled(true);
    _log.debug('Connectivity retained.');
  }

  /// Drops a claim, stopping the sensors when the last one goes.
  Future<void> release() async {
    if (_claims == 0) {
      return;
    }
    _claims--;
    if (_claims > 0) {
      return;
    }
    await _bridge.setEnabled(false);
    await _subscription?.cancel();
    _subscription = null;
    _wifi = WifiSnapshot.empty;
    _bluetooth = BluetoothSnapshot.empty;
    _busy = false;
    _log.debug('Connectivity released.');
    notifyListeners();
  }

  /// Re-reads both lists from what Windows already knows.
  Future<void> refresh() => _bridge.refresh();

  /// Asks the radio to look for networks. The result arrives as an event when
  /// the scan finishes, which is seconds away, so the UI shows that it is
  /// looking rather than pretending the list is already current.
  Future<void> scan() => _bridge.scan();

  /// Joins a network this machine already has a profile for.
  ///
  /// Returns false for anything else: a new network needs a password, and the
  /// only correct place to type one is Windows' own prompt.
  Future<bool> connect(WifiNetwork network) async {
    if (!network.saved) {
      return false;
    }
    _busy = true;
    notifyListeners();
    final bool ok = await _bridge.connect(network.ssid);
    _busy = false;
    notifyListeners();
    if (!ok) {
      _notifications.post(
        IslandNotification(
          id: 'connectivity.wifi',
          title: 'Could not join ${network.ssid}',
          body: 'Windows refused the saved connection.',
          kind: NotificationKind.warning,
        ),
      );
    }
    return ok;
  }

  Future<void> disconnect() async {
    _busy = true;
    notifyListeners();
    await _bridge.disconnect();
    _busy = false;
    notifyListeners();
  }

  /// Turns a radio on or off through the same path Quick Settings uses.
  Future<void> setRadio({required bool bluetooth, required bool on}) async {
    _busy = true;
    notifyListeners();
    final bool accepted = await _bridge.setRadio(bluetooth: bluetooth, on: on);
    _busy = false;
    notifyListeners();
    if (!accepted) {
      _notifications.post(
        IslandNotification(
          id: 'connectivity.radio',
          title: bluetooth ? 'Bluetooth unavailable' : 'Wi-Fi unavailable',
          body: 'Windows would not let this radio be switched.',
          kind: NotificationKind.warning,
        ),
      );
    }
  }

  /// Puts a snapshot in place without the platform.
  ///
  /// The only way to exercise the lists off Windows: everything else here is
  /// fed by an event channel that does not exist in a test.
  @visibleForTesting
  void seed({WifiSnapshot? wifi, BluetoothSnapshot? bluetooth}) {
    _wifi = wifi ?? _wifi;
    _bluetooth = bluetooth ?? _bluetooth;
    notifyListeners();
  }

  void _onEvent(NativeEvent event) {
    switch (event.type) {
      case 'wifi':
        _wifi = WifiSnapshot.fromMap(event.data);
        notifyListeners();

      case 'bluetooth':
        _bluetooth = BluetoothSnapshot.fromMap(event.data);
        notifyListeners();

      case 'radios':
        // The radios arrive on their own event because they change from
        // outside this application - Quick Settings, a laptop's Wi-Fi key,
        // airplane mode - and the lists around them do not.
        _wifi = WifiSnapshot(
          available: _wifi.available,
          radio: RadioStateX.fromName(event.read<String>('wifi')),
          scanning: _wifi.scanning,
          networks: _wifi.networks,
        );
        _bluetooth = BluetoothSnapshot(
          available: _bluetooth.available,
          radio: RadioStateX.fromName(event.read<String>('bluetooth')),
          devices: _bluetooth.devices,
        );
        notifyListeners();

      case 'scanning':
        _wifi = WifiSnapshot(
          available: _wifi.available,
          radio: _wifi.radio,
          scanning: event.read<bool>('scanning') ?? false,
          networks: _wifi.networks,
        );
        notifyListeners();

      default:
        break;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }
}
