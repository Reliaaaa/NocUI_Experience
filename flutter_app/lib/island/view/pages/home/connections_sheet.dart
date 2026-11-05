import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../../app/app_services.dart';
import '../../../../design/components/island_button.dart';
import '../../../../design/theme/island_theme.dart';
import '../../../../design/tokens/db_colors.dart';
import '../../../../design/tokens/db_dimens.dart';
import '../../../../design/tokens/db_icons.dart';
import '../../../../design/tokens/db_motion.dart';
import '../../../../design/tokens/db_typography.dart';
import '../../../../modules/connectivity/connectivity_controller.dart';
import '../../../../native/connectivity_bridge.dart';
import 'deck_panel.dart';

/// Which list the sheet is showing.
enum ConnectionsTarget { wifi, bluetooth }

extension ConnectionsTargetX on ConnectionsTarget {
  String get label =>
      this == ConnectionsTarget.wifi ? 'Wi-Fi' : 'Bluetooth';

  /// The Windows panel this list belongs to, for the settings button.
  String get settingsTarget => this == ConnectionsTarget.wifi
      ? 'ms-settings:network-wifi'
      : 'ms-settings:bluetooth';
}

/// The list behind the Network panel: what is in range, or what is paired.
///
/// It takes over the middle of the home page rather than opening a window,
/// because there is nowhere for a window to go - the island is the surface.
/// One click in, one click back.
class ConnectionsSheet extends StatefulWidget {
  const ConnectionsSheet({
    required this.target,
    required this.onTargetChanged,
    required this.onClose,
    super.key,
  });

  final ConnectionsTarget target;
  final ValueChanged<ConnectionsTarget> onTargetChanged;
  final VoidCallback onClose;

  @override
  State<ConnectionsSheet> createState() => _ConnectionsSheetState();
}

class _ConnectionsSheetState extends State<ConnectionsSheet> {
  ConnectivityController? _connectivity;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  @override
  void didUpdateWidget(ConnectionsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target != widget.target) {
      _refresh();
    }
  }

  @override
  void dispose() {
    unawaited(_connectivity?.release());
    super.dispose();
  }

  /// The sheet holds its own claim on the sensors, on top of the panel's, so
  /// that closing the deck under it cannot take the list away mid-read.
  Future<void> _open() async {
    if (!mounted) {
      return;
    }
    final ConnectivityController connectivity = AppScope.read(
      context,
    ).connectivity;
    _connectivity = connectivity;
    await connectivity.retain();
    await _refresh();
  }

  Future<void> _refresh() async {
    final ConnectivityController? connectivity = _connectivity;
    if (connectivity == null) {
      return;
    }
    await connectivity.refresh();
    if (widget.target == ConnectionsTarget.wifi) {
      // Only Wi-Fi costs radio time, and only when someone is looking at the
      // list of networks.
      await connectivity.scan();
    }
  }

  Future<void> _openWindowsSettings() async {
    await AppScope.read(context).shell.open(widget.target.settingsTarget);
  }

  @override
  Widget build(BuildContext context) {
    final AppServices services = AppScope.read(context);
    final IslandPalette palette = IslandTheme.of(context).palette;

    return AnimatedBuilder(
      animation: services.connectivity,
      builder: (BuildContext context, _) {
        final ConnectivityController connectivity = services.connectivity;
        final bool isWifi = widget.target == ConnectionsTarget.wifi;
        final RadioState radio = isWifi
            ? connectivity.wifi.radio
            : connectivity.bluetooth.radio;

        return DecoratedBox(
          decoration: BoxDecoration(
            color: palette.surfaceSunken,
            borderRadius: BorderRadius.circular(DbRadius.card),
            border: Border.all(color: palette.stroke),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              DbSpace.md,
              DbSpace.sm,
              DbSpace.md,
              DbSpace.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _Header(
                  target: widget.target,
                  radio: radio,
                  scanning: connectivity.wifi.scanning,
                  busy: connectivity.isBusy,
                  onTargetChanged: widget.onTargetChanged,
                  onClose: widget.onClose,
                  onRefresh: () => unawaited(_refresh()),
                  onSettings: () => unawaited(_openWindowsSettings()),
                  onRadio: radio.isControllable
                      ? () => unawaited(
                          connectivity.setRadio(
                            bluetooth: !isWifi,
                            on: !radio.isOn,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: DbSpace.sm),
                Expanded(
                  child: isWifi
                      ? _WifiList(connectivity: connectivity)
                      : _BluetoothList(connectivity: connectivity),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.target,
    required this.radio,
    required this.scanning,
    required this.busy,
    required this.onTargetChanged,
    required this.onClose,
    required this.onRefresh,
    required this.onSettings,
    required this.onRadio,
  });

  final ConnectionsTarget target;
  final RadioState radio;
  final bool scanning;
  final bool busy;
  final ValueChanged<ConnectionsTarget> onTargetChanged;
  final VoidCallback onClose;
  final VoidCallback onRefresh;
  final VoidCallback onSettings;
  final VoidCallback? onRadio;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;

    return Row(
      children: <Widget>[
        PanelIconButton(
          icon: DbIcons.back,
          tooltip: 'Back to the home page',
          size: 20,
          onPressed: onClose,
        ),
        const SizedBox(width: DbSpace.xs),
        _Switcher(target: target, onChanged: onTargetChanged),
        const SizedBox(width: DbSpace.sm),
        if (scanning || busy)
          Text(
            scanning ? 'Looking…' : 'Working…',
            style: DbType.caption.copyWith(color: palette.textTertiary),
          ),
        const Spacer(),
        _RadioSwitch(radio: radio, onPressed: onRadio),
        const SizedBox(width: DbSpace.xs),
        PanelIconButton(
          icon: DbIcons.refresh,
          tooltip: target == ConnectionsTarget.wifi
              ? 'Look for networks again'
              : 'Read the paired devices again',
          size: 20,
          onPressed: onRefresh,
        ),
        PanelIconButton(
          icon: DbIcons.settings,
          tooltip: 'Open ${target.label} in Windows settings',
          size: 20,
          onPressed: onSettings,
        ),
      ],
    );
  }
}

/// Wi-Fi or Bluetooth, in one control the width of two words.
class _Switcher extends StatelessWidget {
  const _Switcher({required this.target, required this.onChanged});

  final ConnectionsTarget target;
  final ValueChanged<ConnectionsTarget> onChanged;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surfaceRaised,
        borderRadius: BorderRadius.circular(DbRadius.pill),
        border: Border.all(color: palette.stroke),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final ConnectionsTarget value in ConnectionsTarget.values)
              _SwitcherTab(
                value: value,
                selected: value == target,
                onPressed: () => onChanged(value),
              ),
          ],
        ),
      ),
    );
  }
}

class _SwitcherTab extends StatelessWidget {
  const _SwitcherTab({
    required this.value,
    required this.selected,
    required this.onPressed,
  });

  final ConnectionsTarget value;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);
    final IslandPalette palette = theme.palette;

    return Semantics(
      button: true,
      selected: selected,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: AnimatedContainer(
            duration: theme.motion.scale(DbDuration.micro),
            curve: DbCurve.standard,
            padding: const EdgeInsets.symmetric(
              horizontal: DbSpace.sm,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? palette.accent.withValues(alpha: 0.18)
                  : const Color(0x00000000),
              borderRadius: BorderRadius.circular(DbRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  value == ConnectionsTarget.wifi
                      ? DbIcons.wifi
                      : DbIcons.bluetooth,
                  size: 11,
                  color: selected ? palette.accent : palette.textTertiary,
                ),
                const SizedBox(width: DbSpace.xs),
                Text(
                  value.label,
                  style: DbType.caption.copyWith(
                    color: selected
                        ? palette.textPrimary
                        : palette.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The radio itself: on, off, or a state that cannot be changed from here.
class _RadioSwitch extends StatelessWidget {
  const _RadioSwitch({required this.radio, required this.onPressed});

  final RadioState radio;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);
    final IslandPalette palette = theme.palette;
    final bool on = radio.isOn;
    final Color tint = on ? palette.positive : palette.textTertiary;

    return Semantics(
      button: onPressed != null,
      toggled: on,
      label: 'Radio ${radio.label}',
      child: MouseRegion(
        cursor: onPressed != null
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: AnimatedContainer(
            duration: theme.motion.scale(DbDuration.micro),
            curve: DbCurve.standard,
            padding: const EdgeInsets.symmetric(
              horizontal: DbSpace.sm,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: on
                  ? palette.positive.withValues(alpha: 0.14)
                  : palette.surfaceRaised,
              borderRadius: BorderRadius.circular(DbRadius.pill),
              border: Border.all(color: palette.stroke),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: tint,
                    borderRadius: BorderRadius.circular(DbRadius.pill),
                  ),
                ),
                const SizedBox(width: DbSpace.xs),
                Text(
                  radio.label,
                  style: DbType.caption.copyWith(color: tint),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WifiList extends StatelessWidget {
  const _WifiList({required this.connectivity});

  final ConnectivityController connectivity;

  Future<void> _tap(BuildContext context, WifiNetwork network) async {
    final AppServices services = AppScope.read(context);
    if (network.connected) {
      await connectivity.disconnect();
      return;
    }
    if (network.saved) {
      await connectivity.connect(network);
      return;
    }
    // A network this machine has never joined needs a password, and the only
    // correct place to type one is Windows' own prompt.
    await services.shell.open('ms-availablenetworks:');
  }

  @override
  Widget build(BuildContext context) {
    final WifiSnapshot wifi = connectivity.wifi;

    // The radio is asked about before the adapter is: a switched-off radio
    // makes the adapter look absent, and "you have no Wi-Fi card" is a much
    // worse thing to tell someone than the truth.
    if (wifi.radio == RadioState.off || wifi.radio == RadioState.disabled) {
      return _Message(
        icon: DbIcons.wifiOff,
        message: wifi.radio == RadioState.disabled
            ? 'Wi-Fi is blocked - airplane mode, or a switch on this PC.'
            : 'Wi-Fi is off.',
        actionLabel: wifi.radio == RadioState.off ? 'Turn it on' : null,
        onAction: () => unawaited(
          connectivity.setRadio(bluetooth: false, on: true),
        ),
      );
    }
    if (!wifi.available) {
      return const _Message(
        icon: DbIcons.wifiOff,
        message: 'No wireless adapter on this PC.',
      );
    }
    if (wifi.networks.isEmpty) {
      return _Message(
        icon: DbIcons.wifi,
        message: wifi.scanning
            ? 'Looking for networks…'
            : 'Nothing in range yet.',
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      physics: const ClampingScrollPhysics(),
      itemCount: wifi.networks.length,
      itemBuilder: (BuildContext context, int index) {
        final WifiNetwork network = wifi.networks[index];
        return _WifiRow(
          network: network,
          onTap: () => unawaited(_tap(context, network)),
        );
      },
    );
  }
}

class _WifiRow extends StatelessWidget {
  const _WifiRow({required this.network, required this.onTap});

  final WifiNetwork network;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;

    final String status = network.connected
        ? 'Connected'
        : network.saved
        ? 'Saved'
        : 'Needs a password';

    return Padding(
      padding: const EdgeInsets.only(bottom: DbSpace.xxs),
      child: PanelRow(
        height: 26,
        icon: network.signal >= 25 ? DbIcons.wifi : DbIcons.network,
        label: network.ssid,
        tone: network.connected ? palette.positive : null,
        onTap: onTap,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (network.secured)
              Padding(
                padding: const EdgeInsets.only(right: DbSpace.sm),
                child: Icon(
                  DbIcons.lockSmall,
                  size: 10,
                  color: palette.textTertiary,
                ),
              ),
            _Bars(bars: network.bars),
            const SizedBox(width: DbSpace.sm),
            SizedBox(
              width: 92,
              child: Text(
                status,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: DbType.caption.copyWith(
                  color: network.connected
                      ? palette.positive
                      : palette.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Four bars, the ones above the signal filled in. Cheaper to read than a
/// percentage and truer than an icon that only has three states.
class _Bars extends StatelessWidget {
  const _Bars({required this.bars});

  final int bars;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 1; i <= 4; i++)
          Padding(
            padding: const EdgeInsets.only(left: 1.5),
            child: Container(
              width: 2.5,
              height: 3.0 + i * 2.0,
              decoration: BoxDecoration(
                color: i <= bars
                    ? palette.textSecondary
                    : palette.separator,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
      ],
    );
  }
}

class _BluetoothList extends StatelessWidget {
  const _BluetoothList({required this.connectivity});

  final ConnectivityController connectivity;

  static IconData iconFor(String kind) {
    switch (kind) {
      case 'audio':
        return DbIcons.headphones;
      case 'input':
        return DbIcons.mouse;
      case 'phone':
        return DbIcons.phone;
      case 'computer':
        return DbIcons.laptop;
      case 'wearable':
        return DbIcons.watch;
      case 'imaging':
        return DbIcons.printer;
      default:
        return DbIcons.devices;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppServices services = AppScope.read(context);
    final BluetoothSnapshot bluetooth = connectivity.bluetooth;
    final IslandPalette palette = IslandTheme.of(context).palette;

    // Windows hides the radio entirely while Bluetooth is switched off, so
    // the state is read before the hardware is: otherwise a machine with the
    // switch off is told it has no Bluetooth at all.
    if (bluetooth.radio == RadioState.off ||
        bluetooth.radio == RadioState.disabled) {
      return _Message(
        icon: DbIcons.bluetoothOff,
        message: bluetooth.radio == RadioState.disabled
            ? 'Bluetooth is blocked - airplane mode, or a switch on this PC.'
            : 'Bluetooth is off.',
        actionLabel: bluetooth.radio == RadioState.off ? 'Turn it on' : null,
        onAction: () => unawaited(
          connectivity.setRadio(bluetooth: true, on: true),
        ),
      );
    }
    if (!bluetooth.available && bluetooth.radio != RadioState.on) {
      return const _Message(
        icon: DbIcons.bluetoothOff,
        message: 'No Bluetooth radio on this PC.',
      );
    }
    if (bluetooth.devices.isEmpty) {
      return _Message(
        icon: DbIcons.bluetooth,
        message: 'Nothing paired yet.',
        actionLabel: 'Pair a device',
        onAction: () =>
            unawaited(services.shell.open('ms-settings:bluetooth')),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      physics: const ClampingScrollPhysics(),
      itemCount: bluetooth.devices.length,
      itemBuilder: (BuildContext context, int index) {
        final BluetoothDeviceInfo device = bluetooth.devices[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: DbSpace.xxs),
          child: PanelRow(
            height: 26,
            icon: device.connected
                ? DbIcons.bluetoothConnected
                : iconFor(device.kind),
            label: device.name,
            tone: device.connected ? palette.positive : null,
            // Windows has no supported way to connect a paired device from
            // another process, so this hands over to the panel that can.
            onTap: () =>
                unawaited(services.shell.open('ms-settings:bluetooth')),
            trailing: Text(
              device.connected
                  ? 'Connected'
                  : (device.paired ? 'Paired' : 'Known'),
              maxLines: 1,
              softWrap: false,
              style: DbType.caption.copyWith(
                color: device.connected
                    ? palette.positive
                    : palette.textTertiary,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// One line, a glyph, and - when there is one - the single button that
/// answers it. An empty list that explains itself and then leaves you to find
/// the fix somewhere else is only half an answer.
class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    final String? label = actionLabel;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: DbSize.iconLg, color: palette.textTertiary),
          const SizedBox(height: DbSpace.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: DbType.caption.copyWith(color: palette.textSecondary),
          ),
          if (label != null && onAction != null) ...<Widget>[
            const SizedBox(height: DbSpace.sm),
            IslandButton(
              icon: DbIcons.power,
              label: label,
              tooltip: label,
              size: DbSize.controlSm,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }
}
