import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../../app/app_services.dart';
import '../../../../design/theme/island_theme.dart';
import '../../../../design/tokens/db_colors.dart';
import '../../../../design/tokens/db_dimens.dart';
import '../../../../design/tokens/db_icons.dart';
import '../../../../modules/connectivity/connectivity_controller.dart';
import '../../../../native/connectivity_bridge.dart';
import '../../../../native/system_bridge.dart';
import '../../../../settings/app_settings.dart';
import 'connections_sheet.dart';
import 'deck_panel.dart';

/// Wi-Fi, Bluetooth and whether this thing is allowed to interrupt you.
///
/// The three switches nobody wants to go to Settings for. Wi-Fi and Bluetooth
/// each open the list behind them; quiet mode is a switch, because there is
/// nothing behind it worth a second surface.
class ConnectivityPanel extends StatelessWidget {
  const ConnectivityPanel({
    required this.progress,
    required this.width,
    required this.expandedWidth,
    required this.onOpen,
    this.compact = false,
    super.key,
  });

  final double progress;
  final double width;
  final double expandedWidth;

  /// True when the deck is short and the panel has to tighten up.
  final bool compact;
  final ValueChanged<ConnectionsTarget> onOpen;

  @override
  Widget build(BuildContext context) {
    final AppServices services = AppScope.read(context);

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        services.connectivity,
        services.system,
        services.settings,
      ]),
      builder: (BuildContext context, _) {
        final ConnectivityController connectivity = services.connectivity;
        final NetworkStatus network = services.system.network;

        return DeckPanel(
          progress: progress,
          width: width,
          expandedWidth: expandedWidth,
          compact: compact,
          summary: _Summary(
            connectivity: connectivity,
            network: network,
          ),
          detail: _Detail(
            connectivity: connectivity,
            network: network,
            onOpen: onOpen,
          ),
        );
      },
    );
  }
}

/// What to call the connection in one short line.
String describeNetwork(NetworkStatus network, WifiSnapshot wifi) {
  if (wifi.radio == RadioState.off) {
    return 'Wi-Fi off';
  }
  if (!network.connected) {
    return 'Offline';
  }
  if (network.isWifi) {
    final String ssid = network.ssid.isNotEmpty
        ? network.ssid
        : (wifi.connected?.ssid ?? '');
    return ssid.isNotEmpty ? ssid : 'Wi-Fi';
  }
  return 'Wired';
}

/// The Bluetooth row's own line. The glyph beside it already says
/// Bluetooth, so this says what Bluetooth is doing instead of repeating it.
String bluetoothLine(BluetoothSnapshot bluetooth) {
  switch (bluetooth.radio) {
    case RadioState.off:
      return 'Bluetooth off';
    case RadioState.disabled:
      return 'Bluetooth blocked';
    case RadioState.absent:
      return 'No Bluetooth';
    case RadioState.on:
    case RadioState.unknown:
      break;
  }
  if (!bluetooth.available) {
    return 'No Bluetooth';
  }
  final int connected = bluetooth.connectedCount;
  if (connected > 0) {
    return connected == 1 ? '1 connected' : '$connected connected';
  }
  return bluetooth.devices.isEmpty ? 'Nothing paired' : 'Bluetooth on';
}

String describeBluetooth(BluetoothSnapshot bluetooth) {
  switch (bluetooth.radio) {
    case RadioState.off:
      return 'Off';
    case RadioState.disabled:
      return 'Blocked';
    case RadioState.absent:
      return 'Not fitted';
    case RadioState.on:
    case RadioState.unknown:
      break;
  }
  if (!bluetooth.available) {
    return 'Not fitted';
  }
  final int connected = bluetooth.connectedCount;
  if (connected > 0) {
    return '$connected connected';
  }
  return bluetooth.devices.isEmpty
      ? 'Nothing paired'
      : '${bluetooth.devices.length} paired';
}

class _Summary extends StatelessWidget {
  const _Summary({required this.connectivity, required this.network});

  final ConnectivityController connectivity;
  final NetworkStatus network;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    final WifiSnapshot wifi = connectivity.wifi;
    final bool online = network.connected;

    return PanelSummary(
      icon: wifi.radio == RadioState.off
          ? DbIcons.wifiOff
          : (network.isWifi || !online ? DbIcons.wifi : DbIcons.network),
      tint: online ? palette.accent : palette.textTertiary,
      title: describeNetwork(network, wifi),
      subtitle: describeBluetooth(connectivity.bluetooth),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({
    required this.connectivity,
    required this.network,
    required this.onOpen,
  });

  final ConnectivityController connectivity;
  final NetworkStatus network;
  final ValueChanged<ConnectionsTarget> onOpen;

  @override
  Widget build(BuildContext context) {
    final AppServices services = AppScope.read(context);
    final IslandPalette palette = IslandTheme.of(context).palette;

    final WifiSnapshot wifi = connectivity.wifi;
    final BluetoothSnapshot bluetooth = connectivity.bluetooth;
    final VolumeStatus volume = services.system.volume;
    final bool quiet = !services.settings.settings.notificationsEnabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PanelHeader(
          label: 'Network',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              PanelIconButton(
                icon: volume.muted ? DbIcons.muted : DbIcons.volume,
                tooltip: volume.muted ? 'Unmute' : 'Mute',
                tint: volume.muted ? palette.warning : null,
                onPressed: volume.available
                    ? () => unawaited(services.system.toggleMute())
                    : null,
              ),
              PanelIconButton(
                icon: DbIcons.settings,
                tooltip: 'Open NocUI Experience settings',
                onPressed: () =>
                    services.router.openSettings(section: 'features'),
              ),
            ],
          ),
        ),
        const SizedBox(height: DbSpace.xs),
        Expanded(
          child: Column(
            children: <Widget>[
              // Each row is the network's own name, its state, or what is
              // connected - never a label plus an ellipsis. The glyph already
              // says which of the three it is.
              Expanded(
                child: PanelRow(
                  icon: wifi.radio == RadioState.off
                      ? DbIcons.wifiOff
                      : DbIcons.wifi,
                  label: describeNetwork(network, wifi),
                  tone: network.connected && network.isWifi
                      ? palette.textPrimary
                      : null,
                  trailing: Icon(
                    DbIcons.chevronRight,
                    size: 13,
                    color: palette.textTertiary,
                  ),
                  onTap: () => onOpen(ConnectionsTarget.wifi),
                ),
              ),
              Expanded(
                child: PanelRow(
                  icon: bluetooth.connectedCount > 0
                      ? DbIcons.bluetoothConnected
                      : (bluetooth.radio == RadioState.off
                            ? DbIcons.bluetoothOff
                            : DbIcons.bluetooth),
                  label: bluetoothLine(bluetooth),
                  trailing: Icon(
                    DbIcons.chevronRight,
                    size: 13,
                    color: palette.textTertiary,
                  ),
                  onTap: () => onOpen(ConnectionsTarget.bluetooth),
                ),
              ),
              Expanded(
                child: PanelRow(
                  icon: DbIcons.bell,
                  label: quiet ? 'Quiet' : 'Alerts on',
                  tone: quiet ? palette.warning : null,
                  trailing: _Dot(on: !quiet),
                  onTap: () => services.settings.mutate(
                    (AppSettings current) => current.copyWith(
                      notificationsEnabled: !current.notificationsEnabled,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    return Container(
      width: 6,
      height: 6,
      margin: const EdgeInsets.only(right: DbSpace.xxs),
      decoration: BoxDecoration(
        color: on ? palette.positive : palette.textTertiary,
        borderRadius: BorderRadius.circular(DbRadius.pill),
      ),
    );
  }
}
