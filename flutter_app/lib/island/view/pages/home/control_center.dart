import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../../app/app_services.dart';
import '../../../../core/time/clock_service.dart';
import '../../../../design/components/island_button.dart';
import '../../../../design/theme/island_theme.dart';
import '../../../../design/tokens/db_dimens.dart';
import '../../../../design/tokens/db_icons.dart';
import '../../../../design/tokens/db_typography.dart';
import '../../../../modules/connectivity/connectivity_controller.dart';
import '../../../../settings/app_settings.dart';
import 'connections_sheet.dart';
import 'connectivity_panel.dart';

/// A compact control surface using only services available to NocUI.
class ControlCenter extends StatefulWidget {
  const ControlCenter({required this.onHome, super.key});
  final VoidCallback onHome;

  @override
  State<ControlCenter> createState() => _ControlCenterState();
}

class _ControlCenterState extends State<ControlCenter> {
  ConnectivityController? _connectivity;
  ConnectionsTarget? _target;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_connectivity == null) {
      _connectivity = AppScope.read(context).connectivity;
      unawaited(_connectivity!.retain());
    }
  }

  @override
  void dispose() {
    final connectivity = _connectivity;
    if (connectivity != null) unawaited(connectivity.release());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.read(context);
    final palette = IslandTheme.of(context).palette;
    final target = _target;
    if (target != null) {
      return ConnectionsSheet(
        target: target,
        onTargetChanged: (value) => setState(() => _target = value),
        onClose: () => setState(() => _target = null),
      );
    }
    return AnimatedBuilder(
      animation: Listenable.merge([
        services.clock,
        services.system,
        services.connectivity,
        services.settings,
      ]),
      builder: (context, _) {
        final power = services.system.power;
        final volume = services.system.volume;
        final now = services.clock.now;
        final quiet = !services.settings.settings.notificationsEnabled;
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(child: Text(
                  power.hasBattery && power.percent >= 0 ? '${power.percent}%' : 'AC',
                  style: DbType.label.copyWith(color: power.isLow ? palette.warning : palette.positive),
                )),
                Text('${ClockFormat.shortDate(now)}  ${ClockFormat.time(now, use24Hour: services.settings.settings.use24HourClock)}',
                  style: DbType.caption.copyWith(color: palette.textSecondary)),
                const Spacer(),
              ]),
              const SizedBox(height: DbSpace.sm),
              Row(children: [
                IslandButton(icon: DbIcons.chevronLeft, tooltip: 'Open home overview', onPressed: widget.onHome),
                const SizedBox(width: DbSpace.sm),
                Expanded(child: Text('Control Center', textAlign: TextAlign.center,
                  style: DbType.title.copyWith(color: palette.textPrimary))),
                IslandButton(icon: DbIcons.settings, tooltip: 'Open settings', onPressed: () => services.router.openSettings()),
              ]),
              const SizedBox(height: DbSpace.sm),
              Row(children: [
                Expanded(child: _Tile(icon: DbIcons.wifi, title: 'Wi-Fi',
                  detail: describeNetwork(services.system.network, services.connectivity.wifi),
                  onPressed: () => setState(() => _target = ConnectionsTarget.wifi))),
                const SizedBox(width: DbSpace.sm),
                Expanded(child: _Tile(icon: DbIcons.bluetooth, title: 'Bluetooth',
                  detail: describeBluetooth(services.connectivity.bluetooth),
                  onPressed: () => setState(() => _target = ConnectionsTarget.bluetooth))),
              ]),
              const SizedBox(height: DbSpace.sm),
              Row(children: [
                Expanded(child: _Tile(icon: DbIcons.bell, title: 'Notifications',
                  detail: quiet ? 'Off' : 'On', onPressed: () => services.settings.mutate(
                    (AppSettings current) => current.copyWith(notificationsEnabled: !current.notificationsEnabled)))),
                const SizedBox(width: DbSpace.sm),
                Expanded(child: _Tile(icon: DbIcons.grid, title: 'Overview',
                  detail: 'Apps, weather and power', onPressed: widget.onHome)),
              ]),
              const SizedBox(height: DbSpace.sm),
              Row(children: [
                Icon(volume.muted ? DbIcons.muted : DbIcons.volume, color: palette.textSecondary, size: 18),
                Expanded(child: Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: VolumeSlider(
                      value: volume.level,
                      onChanged: volume.available
                          ? (value) => unawaited(services.system.setVolume(value))
                          : null,
                    ),
                  ),
                )),
                Text(volume.available ? '${volume.percent}%' : 'Unavailable', style: DbType.label.copyWith(color: palette.textPrimary)),
              ]),
            ],
          ),
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, required this.detail, required this.onPressed});
  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = IslandTheme.of(context).palette;
    return Semantics(button: true, label: '$title, $detail', onTap: onPressed,
      child: FocusableActionDetector(
        actions: <Type, Action<Intent>>{ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) { onPressed(); return null; })},
        child: GestureDetector(behavior: HitTestBehavior.opaque, excludeFromSemantics: true, onTap: onPressed,
          child: Container(height: 51, padding: const EdgeInsets.symmetric(horizontal: DbSpace.md),
            decoration: BoxDecoration(color: palette.surfaceRaised, borderRadius: BorderRadius.circular(DbRadius.control),
              border: Border.all(color: palette.stroke)),
            child: Row(children: [
              Icon(icon, size: 18, color: palette.accent),
              const SizedBox(width: DbSpace.sm),
              Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start,
                children: [Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: DbType.label.copyWith(color: palette.textPrimary)),
                  Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: DbType.caption.copyWith(color: palette.textSecondary))])),
              Icon(DbIcons.chevronRight, size: 15, color: palette.textTertiary),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Volume input that does not require a Material overlay in the notch window.
class VolumeSlider extends StatefulWidget {
  const VolumeSlider({required this.value, required this.onChanged, super.key});
  final double value;
  final ValueChanged<double>? onChanged;

  @override
  State<VolumeSlider> createState() => _VolumeSliderState();
}

class _VolumeSliderState extends State<VolumeSlider> {
  bool _focused = false;

  void _change(double value) => widget.onChanged?.call(value.clamp(0.0, 1.0).toDouble());

  @override
  Widget build(BuildContext context) {
    final palette = IslandTheme.of(context).palette;
    final value = widget.value.clamp(0.0, 1.0).toDouble();
    final enabled = widget.onChanged != null;
    return LayoutBuilder(builder: (context, constraints) {
      void update(double x) {
        if (constraints.maxWidth > 0) _change(x / constraints.maxWidth);
      }
      return Semantics(
        label: 'Volume',
        slider: true,
        enabled: enabled,
        value: '${(value * 100).round()} percent',
        onIncrease: enabled ? () => _change(value + 0.05) : null,
        onDecrease: enabled ? () => _change(value - 0.05) : null,
        child: FocusableActionDetector(
          enabled: enabled,
          onShowFocusHighlight: (focused) => setState(() => _focused = focused),
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.arrowRight): _VolumeStepIntent(1),
            SingleActivator(LogicalKeyboardKey.arrowUp): _VolumeStepIntent(1),
            SingleActivator(LogicalKeyboardKey.arrowLeft): _VolumeStepIntent(-1),
            SingleActivator(LogicalKeyboardKey.arrowDown): _VolumeStepIntent(-1),
          },
          actions: <Type, Action<Intent>>{
            _VolumeStepIntent: CallbackAction<_VolumeStepIntent>(onInvoke: (intent) { _change(value + intent.direction * 0.05); return null; }),
          },
          child: GestureDetector(
            excludeFromSemantics: true,
            behavior: HitTestBehavior.opaque,
            onTapDown: enabled ? (details) => update(details.localPosition.dx) : null,
            onHorizontalDragUpdate: enabled ? (details) => update(details.localPosition.dx) : null,
            child: SizedBox(
              height: 32,
              child: Stack(alignment: Alignment.centerLeft, children: [
                Container(height: 5, decoration: BoxDecoration(color: palette.surfaceRaised, borderRadius: BorderRadius.circular(5))),
                FractionallySizedBox(widthFactor: value, child: Container(height: 5, decoration: BoxDecoration(
                  color: enabled ? palette.accent : palette.textTertiary, borderRadius: BorderRadius.circular(5)))),
                Align(alignment: Alignment(value * 2 - 1, 0), child: Container(
                  width: 12, height: 12, decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: enabled ? palette.accent : palette.textTertiary,
                    border: _focused ? Border.all(color: palette.textPrimary, width: 2) : null,
                  ),
                )),
              ]),
            ),
          ),
        ),
      );
    });
  }
}

class _VolumeStepIntent extends Intent {
  const _VolumeStepIntent(this.direction);
  final int direction;
}
