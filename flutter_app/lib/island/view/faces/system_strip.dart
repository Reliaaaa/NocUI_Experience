import 'package:flutter/widgets.dart';

import '../../../app/app_services.dart';
import '../../../core/utils/formatters.dart';
import '../../../design/theme/island_theme.dart';
import '../../../design/tokens/db_colors.dart';
import '../../../design/tokens/db_dimens.dart';
import '../../../design/tokens/db_icons.dart';
import '../../../design/tokens/db_typography.dart';
import '../../../modules/system/system_controller.dart';
import '../../../native/system_bridge.dart';

/// A row of system readings for the open island.
///
/// Holds the CPU and memory sampler on while it is mounted and releases it on
/// the way out, so the only polling in the application happens while someone is
/// looking at the numbers it produces.
class SystemStrip extends StatefulWidget {
  const SystemStrip({super.key});

  @override
  State<SystemStrip> createState() => _SystemStripState();
}

class _SystemStripState extends State<SystemStrip> {
  SystemController? _system;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final SystemController system = AppScope.read(context).system;
    if (identical(_system, system)) {
      return;
    }
    _release();
    _system = system;
    system.setPerformanceEnabled(true);
  }

  void _release() {
    _system?.setPerformanceEnabled(false);
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SystemController system = AppScope.read(context).system;
    final IslandPalette palette = IslandTheme.of(context).palette;

    return AnimatedBuilder(
      animation: system,
      builder: (BuildContext context, _) {
        if (!system.isEnabled) {
          return const SizedBox.shrink();
        }
        final PowerStatus power = system.power;
        final NetworkStatus network = system.network;
        final VolumeStatus volume = system.volume;
        final PerformanceStatus performance = system.performance;

        return Row(
          children: <Widget>[
            if (power.hasBattery)
              _Reading(
                icon: DbIcons.battery,
                label: '${power.percent}%',
                tone: power.isCritical
                    ? palette.negative
                    : (power.isLow ? palette.warning : null),
                detail: power.charging
                    ? 'Charging'
                    : (power.minutesRemaining > 0
                          ? '${power.minutesRemaining ~/ 60}h '
                                '${power.minutesRemaining % 60}m'
                          : null),
              ),
            _Reading(
              icon: network.isWifi ? DbIcons.wifi : DbIcons.network,
              label: network.connected
                  ? (network.isWifi && network.ssid.isNotEmpty
                        ? network.ssid
                        : 'Connected')
                  : 'Offline',
              tone: network.connected ? null : palette.textTertiary,
              detail: network.isWifi && network.signal >= 0
                  ? '${network.signal}%'
                  : null,
            ),
            if (volume.available)
              _Reading(
                icon: DbIcons.volume,
                label: volume.muted ? 'Muted' : '${volume.percent}%',
                tone: volume.muted ? palette.textTertiary : null,
              ),
            const Spacer(),
            // The sampler needs two ticks before it has a rate; until then the
            // reading would be a made-up zero.
            if (performance.hasMemory && performance.cpuValid)
              _Reading(
                icon: DbIcons.cpu,
                label: '${performance.cpuPercent.round()}%',
                detail: Formatters.bytes(performance.memoryUsedBytes),
              ),
          ],
        );
      },
    );
  }
}

class _Reading extends StatelessWidget {
  const _Reading({
    required this.icon,
    required this.label,
    this.detail,
    this.tone,
  });

  final IconData icon;
  final String label;
  final String? detail;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    final Color color = tone ?? palette.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(right: DbSpace.lg),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: DbSpace.xs),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 96),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: DbType.caption.copyWith(color: color),
            ),
          ),
          if (detail != null) ...<Widget>[
            const SizedBox(width: DbSpace.xs),
            Text(
              detail!,
              style: DbType.caption.copyWith(color: palette.textTertiary),
            ),
          ],
        ],
      ),
    );
  }
}
