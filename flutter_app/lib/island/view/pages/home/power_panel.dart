import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../../app/app_services.dart';
import '../../../../design/theme/island_theme.dart';
import '../../../../design/tokens/db_colors.dart';
import '../../../../design/tokens/db_dimens.dart';
import '../../../../design/tokens/db_icons.dart';
import '../../../../design/tokens/db_motion.dart';
import '../../../../design/tokens/db_typography.dart';
import '../../../../native/power_bridge.dart';
import '../../../../native/system_bridge.dart';
import 'deck_panel.dart';

/// Lock, sleep, and the three that end the session.
///
/// The Start menu buries these behind two clicks and a submenu that moves; this
/// is one hover away. That speed is exactly why the destructive three ask
/// again: an overlay that sits under the cursor all day must never be one
/// stray click from losing an afternoon's work. Lock and sleep do not ask,
/// because neither of them costs anything.
class PowerPanel extends StatefulWidget {
  const PowerPanel({
    required this.progress,
    required this.width,
    required this.expandedWidth,
    this.compact = false,
    super.key,
  });

  final double progress;
  final double width;
  final double expandedWidth;

  /// True when the deck is short and the panel has to tighten up.
  final bool compact;

  @override
  State<PowerPanel> createState() => _PowerPanelState();
}

class _PowerPanelState extends State<PowerPanel> {
  /// How long a confirmation stays armed. Long enough to move the pointer,
  /// short enough that an armed button is never found later by accident.
  static const Duration _confirmWindow = Duration(seconds: 4);

  /// Six actions, in ascending order of what they cost you.
  static const List<PowerAction> _actions = <PowerAction>[
    PowerAction.lock,
    PowerAction.sleep,
    PowerAction.screenOff,
    PowerAction.signOut,
    PowerAction.restart,
    PowerAction.shutdown,
  ];

  PowerCapabilities _capabilities = PowerCapabilities.unknown;
  PowerAction? _pending;
  Timer? _disarm;

  @override
  void initState() {
    super.initState();
    // A one-shot question with a fixed answer: whether this machine can sleep
    // does not change while the island is open.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCapabilities());
  }

  @override
  void dispose() {
    _disarm?.cancel();
    super.dispose();
  }

  Future<void> _loadCapabilities() async {
    final PowerCapabilities capabilities = await AppScope.read(
      context,
    ).power.capabilities();
    if (mounted) {
      setState(() => _capabilities = capabilities);
    }
  }

  void _press(PowerAction action) {
    if (action.needsConfirmation && _pending != action) {
      _disarm?.cancel();
      setState(() => _pending = action);
      _disarm = Timer(_confirmWindow, () {
        if (mounted) {
          setState(() => _pending = null);
        }
      });
      return;
    }
    _disarm?.cancel();
    setState(() => _pending = null);
    unawaited(AppScope.read(context).power.run(action));
  }

  @override
  Widget build(BuildContext context) {
    final AppServices services = AppScope.read(context);

    return AnimatedBuilder(
      animation: services.system,
      builder: (BuildContext context, _) {
        final PowerStatus power = services.system.power;

        return DeckPanel(
          progress: widget.progress,
          width: widget.width,
          expandedWidth: widget.expandedWidth,
          compact: widget.compact,
          summary: _Summary(power: power),
          detail: _Detail(
            power: power,
            capabilities: _capabilities,
            actions: _actions,
            pending: _pending,
            onPressed: _press,
          ),
        );
      },
    );
  }
}

/// `3h 20m left`, or what is true instead.
///
/// [short] is for the resting panel, which is about seventy pixels wide: there
/// the choice is between a shorter phrase and an ellipsis, and an ellipsis
/// tells the reader nothing.
String describePower(PowerStatus power, {bool short = false}) {
  if (!power.hasBattery) {
    return short ? 'On AC' : 'On mains power';
  }
  if (power.charging) {
    return 'Charging';
  }
  if (power.minutesRemaining > 0) {
    final int hours = power.minutesRemaining ~/ 60;
    final int minutes = power.minutesRemaining % 60;
    final String left = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
    return short ? left : '$left left';
  }
  if (power.onAcPower) {
    return short ? 'On AC' : 'Plugged in';
  }
  return 'On battery';
}

class _Summary extends StatelessWidget {
  const _Summary({required this.power});

  final PowerStatus power;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    final bool hasBattery = power.hasBattery && power.percent >= 0;

    return PanelSummary(
      icon: hasBattery ? DbIcons.battery : DbIcons.power,
      tint: power.isCritical
          ? palette.negative
          : (power.isLow ? palette.warning : null),
      title: hasBattery ? '${power.percent}%' : 'Power',
      subtitle: hasBattery
          ? describePower(power, short: true)
          : 'Lock and sleep',
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({
    required this.power,
    required this.capabilities,
    required this.actions,
    required this.pending,
    required this.onPressed,
  });

  final PowerStatus power;
  final PowerCapabilities capabilities;
  final List<PowerAction> actions;
  final PowerAction? pending;
  final ValueChanged<PowerAction> onPressed;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    final bool hasBattery = power.hasBattery && power.percent >= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PanelHeader(
          label: 'Power',
          trailing: Text(
            hasBattery ? '${power.percent}% · ${describePower(power)}' : '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: DbType.caption.copyWith(
              color: power.isLow ? palette.warning : palette.textTertiary,
            ),
          ),
        ),
        const SizedBox(height: DbSpace.xs),
        Expanded(
          child: Column(
            children: <Widget>[
              for (int row = 0; row < 3; row++) ...<Widget>[
                if (row > 0) const SizedBox(height: DbSpace.xxs),
                Expanded(
                  child: Row(
                    children: <Widget>[
                      for (int column = 0; column < 2; column++) ...<Widget>[
                        if (column > 0) const SizedBox(width: DbSpace.xxs),
                        Expanded(
                          child: _ActionButton(
                            action: actions[row * 2 + column],
                            armed: pending == actions[row * 2 + column],
                            enabled: capabilities.supports(
                              actions[row * 2 + column],
                            ),
                            onPressed: onPressed,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.action,
    required this.armed,
    required this.enabled,
    required this.onPressed,
  });

  final PowerAction action;
  final bool armed;
  final bool enabled;
  final ValueChanged<PowerAction> onPressed;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);
    final IslandPalette palette = theme.palette;

    final bool armed = widget.armed;
    final Color tint = !widget.enabled
        ? palette.textTertiary
        : armed
        ? palette.negative
        : (_hovered ? palette.textPrimary : palette.textSecondary);

    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: armed
          ? 'Confirm ${widget.action.label}'
          : widget.action.description,
      child: MouseRegion(
        cursor: widget.enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled ? () => widget.onPressed(widget.action) : null,
          child: AnimatedContainer(
            duration: theme.motion.scale(DbDuration.micro),
            curve: DbCurve.standard,
            padding: const EdgeInsets.symmetric(horizontal: DbSpace.sm),
            decoration: BoxDecoration(
              color: armed
                  ? palette.negative.withValues(alpha: 0.14)
                  : (_hovered && widget.enabled
                        ? palette.surfaceSunken
                        : const Color(0x00000000)),
              borderRadius: BorderRadius.circular(DbRadius.control),
              border: Border.all(
                color: armed ? palette.negative : palette.stroke,
              ),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  armed ? DbIcons.warning : widget.action.icon,
                  size: 13,
                  color: tint,
                ),
                const SizedBox(width: DbSpace.xs),
                Expanded(
                  // "Shut down" set a shade smaller is still "Shut down";
                  // "Shut d..." on a button that ends the session is not
                  // good enough.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      armed ? 'Sure?' : widget.action.label,
                      maxLines: 1,
                      softWrap: false,
                      style: DbType.caption.copyWith(color: tint),
                    ),
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
