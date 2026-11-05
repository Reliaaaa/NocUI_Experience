import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../app/app_services.dart';
import '../../design/components/db_text_field.dart';
import '../../design/components/island_button.dart';
import '../../design/theme/island_theme.dart';
import '../../design/tokens/db_colors.dart';
import '../../design/tokens/db_dimens.dart';
import '../../design/tokens/db_icons.dart';
import '../../design/tokens/db_motion.dart';
import '../../design/tokens/db_typography.dart';
import '../../modules/shortcuts/shortcut_catalog.dart';
import '../../modules/weather/weather_report.dart';
import '../app_settings.dart';
import 'settings_controls.dart';

/// The home page's four panels, and the two of them with something to
/// configure: which apps sit on the shelf, and where the weather is from.
class HomeSettings extends StatelessWidget {
  const HomeSettings({required this.services, super.key});

  final AppServices services;

  AppSettings get settings => services.settings.settings;

  void update(AppSettings Function(AppSettings current) transform) =>
      services.settings.mutate(transform);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SettingsSection(
          title: 'Home panels',
          description:
              'Apps, power, weather and network, under the clock. They open '
              'when the pointer reaches them - there is nothing to click.',
          children: <Widget>[
            SettingsRow(
              label: 'Show the four panels',
              description:
                  'Off leaves the home page as the clock and today’s '
                  'agenda.',
              control: DbSwitch(
                value: settings.homeDeckEnabled,
                onChanged: (bool value) => update(
                  (AppSettings s) => s.copyWith(homeDeckEnabled: value),
                ),
              ),
            ),
            _ShelfEditor(services: services),
          ],
        ),
        SettingsSection(
          title: 'Weather',
          description:
              'The one module that reaches the internet. It asks a public '
              'forecast service for a latitude and a longitude, rounded to '
              'about a city block, and sends nothing else.',
          children: <Widget>[
            SettingsRow(
              label: 'Weather panel',
              description: 'Off means no request is ever made.',
              control: DbSwitch(
                value: settings.weatherEnabled,
                onChanged: (bool value) => update(
                  (AppSettings s) => s.copyWith(weatherEnabled: value),
                ),
              ),
            ),
            SettingsRow(
              label: 'Units',
              control: DbSegmented<bool>(
                value: settings.weatherMetric,
                options: const <bool, String>{
                  true: '°C  km/h',
                  false: '°F  mph',
                },
                onChanged: (bool value) => update(
                  (AppSettings s) => s.copyWith(weatherMetric: value),
                ),
              ),
            ),
            SettingsRow(
              label: 'Find where I am',
              description:
                  'Looks the location up from this connection when no place '
                  'has been chosen. Off leaves it to you.',
              control: DbSwitch(
                value: settings.weatherAutoLocate,
                onChanged: (bool value) => update(
                  (AppSettings s) => s.copyWith(weatherAutoLocate: value),
                ),
              ),
            ),
            _PlacePicker(services: services),
          ],
        ),
      ],
    );
  }
}

/// The four slots on the home page's Apps panel.
///
/// A slot is chosen, not earned: no recency, no usage counting. Clicking one
/// opens the catalogue underneath it, which is the same catalogue the
/// Shortcuts page pins from.
class _ShelfEditor extends StatefulWidget {
  const _ShelfEditor({required this.services});

  final AppServices services;

  @override
  State<_ShelfEditor> createState() => _ShelfEditorState();
}

class _ShelfEditorState extends State<_ShelfEditor> {
  int? _editing;

  List<String> get _ids {
    final List<String> ids = List<String>.of(
      widget.services.settings.settings.homeShortcuts,
    );
    // A short or over-long list is a settings file someone edited by hand;
    // it is padded and trimmed rather than treated as an error.
    while (ids.length < ShortcutCatalog.homeSlots) {
      ids.add('');
    }
    return ids.sublist(0, ShortcutCatalog.homeSlots);
  }

  void _assign(int slot, String id) {
    final List<String> ids = _ids;
    // The same shortcut twice on a shelf of four is almost certainly a
    // misclick, so it moves rather than duplicates.
    for (int i = 0; i < ids.length; i++) {
      if (i != slot && ids[i] == id) {
        ids[i] = '';
      }
    }
    ids[slot] = id;
    widget.services.settings.mutate(
      (AppSettings s) => s.copyWith(
        homeShortcuts: <String>[
          for (final String value in ids)
            if (value.isNotEmpty) value,
        ],
      ),
    );
    setState(() => _editing = null);
  }

  void _clear(int slot) {
    final List<String> ids = _ids..[slot] = '';
    widget.services.settings.mutate(
      (AppSettings s) => s.copyWith(
        homeShortcuts: <String>[
          for (final String value in ids)
            if (value.isNotEmpty) value,
        ],
      ),
    );
    setState(() => _editing = null);
  }

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;

    return AnimatedBuilder(
      animation: widget.services.settings,
      builder: (BuildContext context, _) {
        final List<String> ids = _ids;

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DbSpace.lg,
            vertical: DbSpace.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'The four apps on the shelf',
                style: DbType.body.copyWith(color: palette.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                _editing == null
                    ? 'Click a slot to change what is in it.'
                    : 'Choose what goes in slot ${_editing! + 1}.',
                style: DbType.caption.copyWith(color: palette.textTertiary),
              ),
              const SizedBox(height: DbSpace.md),
              Row(
                children: <Widget>[
                  for (int slot = 0; slot < ShortcutCatalog.homeSlots; slot++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: slot == ShortcutCatalog.homeSlots - 1
                              ? 0
                              : DbSpace.sm,
                        ),
                        child: _Slot(
                          entry: ShortcutCatalog.byId(ids[slot]),
                          index: slot,
                          selected: _editing == slot,
                          onPressed: () => setState(
                            () => _editing = _editing == slot ? null : slot,
                          ),
                          onClear: ids[slot].isEmpty
                              ? null
                              : () => _clear(slot),
                        ),
                      ),
                    ),
                ],
              ),
              if (_editing != null) ...<Widget>[
                const SizedBox(height: DbSpace.md),
                _Catalogue(
                  chosen: ids.toSet(),
                  onPick: (ShortcutEntry entry) => _assign(_editing!, entry.id),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({
    required this.entry,
    required this.index,
    required this.selected,
    required this.onPressed,
    required this.onClear,
  });

  final ShortcutEntry? entry;
  final int index;
  final bool selected;
  final VoidCallback onPressed;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);
    final IslandPalette palette = theme.palette;

    return Semantics(
      button: true,
      selected: selected,
      label: entry == null
          ? 'Empty slot ${index + 1}'
          : 'Slot ${index + 1}: ${entry!.label}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: AnimatedContainer(
            duration: theme.motion.scale(DbDuration.micro),
            curve: DbCurve.standard,
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: DbSpace.sm),
            decoration: BoxDecoration(
              color: selected
                  ? palette.accent.withValues(alpha: 0.12)
                  : palette.surfaceSunken,
              borderRadius: BorderRadius.circular(DbRadius.control),
              border: Border.all(
                color: selected ? palette.accent : palette.stroke,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  entry?.icon ?? DbIcons.add,
                  size: DbSize.iconMd,
                  color: entry == null
                      ? palette.textTertiary
                      : palette.textPrimary,
                ),
                const SizedBox(height: DbSpace.xs),
                Text(
                  entry?.label ?? 'Empty',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: DbType.caption.copyWith(
                    color: entry == null
                        ? palette.textTertiary
                        : palette.textSecondary,
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

/// Everything that can go on the shelf, in the three groups the catalogue
/// already declares.
class _Catalogue extends StatelessWidget {
  const _Catalogue({required this.chosen, required this.onPick});

  final Set<String> chosen;
  final ValueChanged<ShortcutEntry> onPick;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surfaceSunken,
        borderRadius: BorderRadius.circular(DbRadius.card),
        border: Border.all(color: palette.stroke),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DbSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final ShortcutGroup group in ShortcutGroup.values) ...<Widget>[
              Padding(
                padding: const EdgeInsets.only(bottom: DbSpace.sm),
                child: Text(
                  group.label.toUpperCase(),
                  style: DbType.overline.copyWith(color: palette.textTertiary),
                ),
              ),
              Wrap(
                spacing: DbSpace.sm,
                runSpacing: DbSpace.sm,
                children: <Widget>[
                  for (final ShortcutEntry entry
                      in ShortcutCatalog.inGroup(group))
                    IslandButton(
                      icon: entry.icon,
                      label: entry.label,
                      tooltip: 'Put ${entry.label} on the shelf',
                      tone: chosen.contains(entry.id)
                          ? IslandButtonTone.accent
                          : IslandButtonTone.neutral,
                      onPressed: () => onPick(entry),
                    ),
                ],
              ),
              if (group != ShortcutGroup.values.last)
                const SizedBox(height: DbSpace.lg),
            ],
          ],
        ),
      ),
    );
  }
}

/// Where the forecast is for.
///
/// A name is typed, a public geocoder turns it into a point, and the point is
/// what gets stored - so the place is a coordinate this application chose once,
/// not a search term it keeps sending somewhere.
class _PlacePicker extends StatefulWidget {
  const _PlacePicker({required this.services});

  final AppServices services;

  @override
  State<_PlacePicker> createState() => _PlacePickerState();
}

class _PlacePickerState extends State<_PlacePicker> {
  final TextEditingController _query = TextEditingController();
  List<WeatherPlace> _results = const <WeatherPlace>[];
  bool _searching = false;
  bool _searched = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final String query = _query.text.trim();
    if (query.length < 2 || _searching) {
      return;
    }
    setState(() {
      _searching = true;
      _searched = true;
    });
    final List<WeatherPlace> results = await widget.services.weather.search(
      query,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _searching = false;
      _results = results;
    });
  }

  void _choose(WeatherPlace place) {
    widget.services.weather.setPlace(place);
    _query.clear();
    setState(() {
      _results = const <WeatherPlace>[];
      _searched = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;

    return AnimatedBuilder(
      animation: widget.services.settings,
      builder: (BuildContext context, _) {
        final AppSettings settings = widget.services.settings.settings;
        final String current = settings.weatherPlace.isEmpty
            ? 'Nowhere yet'
            : settings.weatherPlace;

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DbSpace.lg,
            vertical: DbSpace.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          'Place',
                          style: DbType.body.copyWith(
                            color: palette.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: <Widget>[
                            Icon(
                              DbIcons.place,
                              size: 11,
                              color: palette.textTertiary,
                            ),
                            const SizedBox(width: DbSpace.xs),
                            Text(
                              current,
                              style: DbType.caption.copyWith(
                                color: palette.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: DbSpace.lg),
                  IslandButton(
                    icon: DbIcons.place,
                    label: 'Find me',
                    tooltip: 'Look the location up from this connection',
                    onPressed: () =>
                        unawaited(widget.services.weather.locateNow()),
                  ),
                ],
              ),
              const SizedBox(height: DbSpace.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: DbTextField(
                      controller: _query,
                      placeholder: 'Search for a town or city',
                      onSubmitted: (_) => unawaited(_search()),
                    ),
                  ),
                  const SizedBox(width: DbSpace.sm),
                  IslandButton(
                    icon: DbIcons.search,
                    tooltip: 'Search',
                    onPressed: _searching ? null : () => unawaited(_search()),
                  ),
                ],
              ),
              if (_searching || (_searched && _results.isEmpty)) ...<Widget>[
                const SizedBox(height: DbSpace.sm),
                Text(
                  _searching ? 'Searching…' : 'Nothing matched that.',
                  style: DbType.caption.copyWith(color: palette.textTertiary),
                ),
              ],
              if (_results.isNotEmpty) ...<Widget>[
                const SizedBox(height: DbSpace.sm),
                for (final WeatherPlace place in _results)
                  Padding(
                    padding: const EdgeInsets.only(bottom: DbSpace.xs),
                    child: _Result(
                      place: place,
                      onPressed: () => _choose(place),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Result extends StatefulWidget {
  const _Result({required this.place, required this.onPressed});

  final WeatherPlace place;
  final VoidCallback onPressed;

  @override
  State<_Result> createState() => _ResultState();
}

class _ResultState extends State<_Result> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);
    final IslandPalette palette = theme.palette;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: theme.motion.scale(DbDuration.micro),
          curve: DbCurve.standard,
          padding: const EdgeInsets.symmetric(
            horizontal: DbSpace.md,
            vertical: DbSpace.sm,
          ),
          decoration: BoxDecoration(
            color: _hovered ? palette.surfaceSunken : const Color(0x00000000),
            borderRadius: BorderRadius.circular(DbRadius.control),
            border: Border.all(
              color: _hovered ? palette.stroke : const Color(0x00000000),
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(DbIcons.place, size: 12, color: palette.textTertiary),
              const SizedBox(width: DbSpace.sm),
              Expanded(
                child: Text(
                  widget.place.qualified,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: DbType.body.copyWith(color: palette.textPrimary),
                ),
              ),
              Text(
                '${widget.place.latitude.toStringAsFixed(2)}, '
                '${widget.place.longitude.toStringAsFixed(2)}',
                style: DbType.caption.copyWith(color: palette.textTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
