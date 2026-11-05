import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../../app/app_services.dart';
import '../../../../design/theme/island_theme.dart';
import '../../../../design/tokens/db_colors.dart';
import '../../../../design/tokens/db_dimens.dart';
import '../../../../design/tokens/db_icons.dart';
import '../../../../design/tokens/db_typography.dart';
import '../../../../modules/weather/weather_controller.dart';
import '../../../../modules/weather/weather_report.dart';
import '../../../../settings/app_settings.dart';
import 'deck_panel.dart';

/// What the sky is doing.
///
/// The only part of DynamicBar that touches the network, and it says so: when
/// it is off it stays off, and when it has no place to report on it asks for
/// one rather than guessing quietly in the background.
class WeatherPanel extends StatelessWidget {
  const WeatherPanel({
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
  Widget build(BuildContext context) {
    final AppServices services = AppScope.read(context);

    return AnimatedBuilder(
      animation: services.weather,
      builder: (BuildContext context, _) {
        final WeatherController weather = services.weather;

        return DeckPanel(
          progress: progress,
          width: width,
          expandedWidth: expandedWidth,
          compact: compact,
          summary: _Summary(weather: weather),
          detail: _Detail(weather: weather, compact: compact),
        );
      },
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.weather});

  final WeatherController weather;

  @override
  Widget build(BuildContext context) {
    final WeatherReport? report = weather.report;
    if (report == null) {
      return PanelSummary(
        icon: DbIcons.weather,
        title: 'Weather',
        subtitle: switch (weather.status) {
          WeatherStatus.off => 'Switched off',
          WeatherStatus.noPlace => 'Set a place',
          WeatherStatus.loading => 'Checking…',
          WeatherStatus.failed => 'Unavailable',
          WeatherStatus.ready => '—',
        },
      );
    }

    return PanelSummary(
      icon: report.icon,
      title: WeatherReport.degrees(report.temperature),
      subtitle: report.summary,
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.weather, required this.compact});

  final WeatherController weather;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    final WeatherReport? report = weather.report;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // The heading is the place itself. A panel with a temperature the
        // size of a clock digit and a sun over it does not also need the word
        // "weather" - it needs to say where this is for.
        PanelHeader(
          label: report == null
              ? 'Weather'
              : (weather.isStale
                    ? '${report.place.name} · old'
                    : report.place.name),
          trailing: PanelIconButton(
            icon: DbIcons.refresh,
            tooltip: 'Check again now',
            onPressed: weather.isEnabled && !weather.isLoading
                ? () => unawaited(weather.refresh(force: true))
                : null,
          ),
        ),
        const SizedBox(height: DbSpace.xs),
        if (report == null)
          Expanded(child: _Empty(weather: weather))
        else ...<Widget>[
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  // A reading one pixel too tall for the row it is in would
                  // put an overflow stripe across the panel; scaled down by a
                  // hair instead, nobody can tell.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          WeatherReport.degrees(report.temperature),
                          maxLines: 1,
                          style: DbType.headline.copyWith(
                            color: weather.isStale
                                ? palette.textSecondary
                                : palette.textPrimary,
                          ),
                        ),
                        Text(
                          report.summary,
                          maxLines: 1,
                          softWrap: false,
                          style: DbType.caption.copyWith(
                            color: palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: DbSpace.xs),
                Icon(
                  report.icon,
                  size: compact ? DbSize.iconLg : DbSize.iconXl,
                  color: palette.accent,
                ),
              ],
            ),
          ),
          _Stats(report: report),
        ],
      ],
    );
  }
}

/// Three readings that change what you would wear, and nothing else.
class _Stats extends StatelessWidget {
  const _Stats({required this.report});

  final WeatherReport report;

  @override
  Widget build(BuildContext context) {
    final WeatherDay? today = report.today;

    // Three readings on one line in a panel that is sometimes narrow: laid
    // out at their natural size and scaled down together when they have to
    // be, which keeps them legible rather than clipped.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (today != null)
            _Stat(
              icon: DbIcons.thermostat,
              value:
                  '${WeatherReport.degrees(today.high)}'
                  ' / ${WeatherReport.degrees(today.low)}',
            ),
          if (report.precipitationChance >= 0)
            _Stat(
              icon: DbIcons.humidity,
              value: '${report.precipitationChance}%',
            ),
          if (report.windSpeed >= 0)
            _Stat(
              icon: DbIcons.wind,
              value: '${report.windSpeed.round()} ${report.windUnit}',
            ),
          if (today == null && report.humidity >= 0)
            _Stat(icon: DbIcons.humidity, value: '${report.humidity}%'),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    return Padding(
      padding: const EdgeInsets.only(right: DbSpace.md),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 11, color: palette.textTertiary),
          const SizedBox(width: DbSpace.xxs),
          Text(
            value,
            maxLines: 1,
            softWrap: false,
            style: DbType.caption.copyWith(color: palette.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// What the panel says when it has no reading: one sentence and the one button
/// that fixes it.
class _Empty extends StatelessWidget {
  const _Empty({required this.weather});

  final WeatherController weather;

  @override
  Widget build(BuildContext context) {
    final AppServices services = AppScope.read(context);
    final IslandPalette palette = IslandTheme.of(context).palette;

    final String message;
    final String actionLabel;
    final VoidCallback action;

    switch (weather.status) {
      case WeatherStatus.off:
        message = 'Weather is switched off.';
        actionLabel = 'Turn it on';
        action = () => services.settings.mutate(
          (AppSettings current) => current.copyWith(weatherEnabled: true),
        );
      case WeatherStatus.noPlace:
        message = 'No place chosen yet.';
        actionLabel = services.settings.settings.weatherAutoLocate
            ? 'Find me'
            : 'Choose one';
        action = services.settings.settings.weatherAutoLocate
            ? () => unawaited(weather.refresh(force: true))
            : () => services.router.openSettings(section: 'features');
      case WeatherStatus.loading:
        message = 'Checking the forecast…';
        actionLabel = '';
        action = () {};
      case WeatherStatus.failed:
      case WeatherStatus.ready:
        message = 'The forecast could not be reached.';
        actionLabel = 'Try again';
        action = () => unawaited(weather.refresh(force: true));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text(
          message,
          maxLines: 2,
          style: DbType.caption.copyWith(color: palette.textSecondary),
        ),
        if (actionLabel.isNotEmpty) ...<Widget>[
          const SizedBox(height: DbSpace.sm),
          _TextButton(label: actionLabel, onPressed: action),
        ],
      ],
    );
  }
}

class _TextButton extends StatefulWidget {
  const _TextButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  State<_TextButton> createState() => _TextButtonState();
}

class _TextButtonState extends State<_TextButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    return Semantics(
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DbSpace.sm,
              vertical: DbSpace.xxs,
            ),
            decoration: BoxDecoration(
              color: _hovered
                  ? palette.surfaceSunken
                  : const Color(0x00000000),
              borderRadius: BorderRadius.circular(DbRadius.control),
              border: Border.all(color: palette.stroke),
            ),
            child: Text(
              widget.label,
              style: DbType.caption.copyWith(color: palette.accent),
            ),
          ),
        ),
      ),
    );
  }
}
