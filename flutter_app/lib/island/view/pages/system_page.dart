import 'package:flutter/widgets.dart';

import '../../../app/app_services.dart';
import '../../../core/utils/formatters.dart';
import '../../../design/components/sparkline.dart';
import '../../../design/components/staggered_reveal.dart';
import '../../../design/theme/island_theme.dart';
import '../../../design/tokens/db_colors.dart';
import '../../../design/tokens/db_dimens.dart';
import '../../../design/tokens/db_icons.dart';
import '../../../design/tokens/db_typography.dart';
import '../../../modules/system/system_controller.dart';
import '../../../native/system_bridge.dart';
import 'page_scaffold.dart';

/// Load, power, network and the privacy sensors, in one glance.
///
/// Mounting this page is what turns the sampler on; leaving it turns the
/// sampler off again. It is the only polling in the application and it exists
/// only while these numbers are being looked at.
///
/// The readings are drawn as lines rather than bars because a single percentage
/// cannot distinguish a machine that is busy from one that has been pinned for
/// a minute, and that difference is the whole reason to look.
class SystemPage extends StatefulWidget {
  const SystemPage({super.key});

  @override
  State<SystemPage> createState() => _SystemPageState();
}

class _SystemPageState extends State<SystemPage> {
  SystemController? _system;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final SystemController system = AppScope.read(context).system;
    if (identical(_system, system)) {
      return;
    }
    _system?.setPerformanceEnabled(false);
    _system = system;
    system.setPerformanceEnabled(true);
  }

  @override
  void dispose() {
    _system?.setPerformanceEnabled(false);
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
          return const PageScaffold(
            title: 'System',
            child: PageEmptyState(
              message: 'System status is switched off',
              hint: 'Turn it back on in Settings → Features.',
            ),
          );
        }

        final PerformanceStatus performance = system.performance;
        final PowerStatus power = system.power;
        final NetworkStatus network = system.network;
        final PrivacyStatus privacy = system.privacy;
        final double peak = system.throughputPeak;

        return PageScaffold(
          title: 'System',
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Keep power visible alongside the live graphs, as in the
                // compact design, without dropping network or privacy data.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    if (power.hasBattery) ...<Widget>[
                      SizedBox(
                        width: 100,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Icon(
                              DbIcons.battery,
                              size: 26,
                              color: power.isCritical
                                  ? palette.negative
                                  : (power.isLow ? palette.warning : palette.accent),
                            ),
                            const SizedBox(height: DbSpace.xs),
                            Text(
                              power.percent < 0 ? '—' : '${power.percent}%',
                              style: DbType.title.copyWith(color: palette.textPrimary),
                            ),
                            Text(
                              power.charging
                                  ? 'Charging'
                                  : (power.onAcPower ? 'Plugged in' : 'On battery'),
                              style: DbType.caption.copyWith(color: palette.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 104, color: palette.separator),
                      const SizedBox(width: DbSpace.md),
                    ],
                    Expanded(
                      child: Column(
                        children: <Widget>[
                          Reveal(
                            order: 1,
                            child: _Graph(
                              label: 'Processor',
                              readout: performance.cpuValid
                                  ? '${performance.cpuPercent.round()}%'
                                  : 'measuring…',
                              color: palette.accent,
                              values: system.cpuHistory,
                              height: 26,
                            ),
                          ),
                          const SizedBox(height: DbSpace.md),
                          Reveal(
                            order: 2,
                            child: _Graph(
                              label: 'Memory',
                              readout: performance.hasMemory
                                  ? '${performance.memoryPercent.round()}% · '
                                      '${Formatters.bytes(performance.memoryUsedBytes)}'
                                      ' of ${Formatters.bytes(performance.memoryTotalBytes)}'
                                  : 'measuring…',
                              color: palette.positive,
                              values: system.memoryHistory,
                              height: 22,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DbSpace.md),
                Reveal(
                  order: 3,
                  child: _Throughput(
                    down: system.downHistory,
                    up: system.upHistory,
                    peak: peak,
                    valid: performance.networkValid,
                    downNow: performance.networkDownBytes,
                    upNow: performance.networkUpBytes,
                  ),
                ),
                const SizedBox(height: DbSpace.md),
                Reveal(
                  order: 4,
                  child: Wrap(
                    runSpacing: DbSpace.xs,
                    children: <Widget>[
                      if (power.hasBattery && !power.charging && power.minutesRemaining > 0)
                        _Fact(
                          icon: DbIcons.battery,
                          label: '${power.minutesRemaining ~/ 60}h ${power.minutesRemaining % 60}m left',
                          tone: power.isCritical
                              ? palette.negative
                              : (power.isLow ? palette.warning : null),
                        ),
                      _Fact(
                        icon: network.isWifi ? DbIcons.wifi : DbIcons.network,
                        label: network.connected
                            ? (network.isWifi && network.ssid.isNotEmpty
                                ? network.ssid : 'Connected')
                            : 'Offline',
                        tone: network.connected ? null : palette.textTertiary,
                      ),
                      if (privacy.anyInUse)
                        _Fact(
                          icon: privacy.cameraInUse ? DbIcons.camera : DbIcons.microphone,
                          label: 'In use',
                          tone: palette.negative,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// One labelled line, scaled 0..100%.
class _Graph extends StatelessWidget {
  const _Graph({
    required this.label,
    required this.readout,
    required this.color,
    required this.values,
    required this.height,
  });

  final String label;
  final String readout;
  final Color color;
  final List<double> values;
  final double height;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: DbType.body.copyWith(color: palette.textSecondary),
              ),
            ),
            Flexible(
              child: Text(
                readout,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: DbType.numeric.copyWith(color: palette.textPrimary),
              ),
            ),
          ],
        ),
        const SizedBox(height: DbSpace.xs),
        Sparkline(
          values: values,
          color: color,
          capacity: SystemController.historyLength,
          height: height,
        ),
      ],
    );
  }
}

/// Download and upload, mirrored around a shared baseline and sharing one
/// scale, so the two are read against each other rather than separately.
class _Throughput extends StatelessWidget {
  const _Throughput({
    required this.down,
    required this.up,
    required this.peak,
    required this.valid,
    required this.downNow,
    required this.upNow,
  });

  final List<double> down;
  final List<double> up;
  final double peak;
  final bool valid;
  final double downNow;
  final double upNow;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    // A quiet network would otherwise scale its own noise up to full height and
    // look like a storm; the floor keeps an idle line flat.
    const double floor = 64 * 1024;
    final double scale = peak < floor ? floor : peak;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Network',
                style: DbType.body.copyWith(color: palette.textSecondary),
              ),
            ),
            if (valid) ...<Widget>[
              Icon(DbIcons.download, size: 11, color: palette.accent),
              const SizedBox(width: DbSpace.xxs),
              Text(
                Formatters.rate(downNow),
                style: DbType.numeric.copyWith(color: palette.textPrimary),
              ),
              const SizedBox(width: DbSpace.md),
              Icon(DbIcons.upload, size: 11, color: palette.warning),
              const SizedBox(width: DbSpace.xxs),
              Text(
                Formatters.rate(upNow),
                style: DbType.numeric.copyWith(color: palette.textPrimary),
              ),
            ] else
              Text(
                'measuring…',
                style: DbType.numeric.copyWith(color: palette.textPrimary),
              ),
          ],
        ),
        const SizedBox(height: DbSpace.xs),
        Sparkline(
          values: down,
          maxValue: scale,
          color: palette.accent,
          capacity: SystemController.historyLength,
          height: 22,
        ),
        Sparkline(
          values: up,
          maxValue: scale,
          color: palette.warning,
          capacity: SystemController.historyLength,
          height: 18,
          mirrored: true,
        ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, this.tone});

  final IconData icon;
  final String label;
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
            constraints: const BoxConstraints(maxWidth: 130),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: DbType.caption.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
