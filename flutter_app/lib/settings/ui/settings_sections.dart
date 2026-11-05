import 'package:flutter/widgets.dart';

import '../../app/app_info.dart';
import '../../app/app_services.dart';
import '../../core/logging/app_logger.dart';
import '../../design/theme/island_theme.dart';
import '../../design/theme/theme_controller.dart';
import '../../design/tokens/db_colors.dart';
import '../../design/tokens/db_dimens.dart';
import '../../design/tokens/db_typography.dart';
import '../../island/state/island_page.dart';
import '../../native/models/native_models.dart';
import '../../native/startup_bridge.dart';
import '../app_settings.dart';
import 'home_settings.dart';
import 'settings_controls.dart';

/// Shared plumbing for every section: read the document, write it back.
abstract class _Section extends StatelessWidget {
  const _Section({required this.services, super.key});

  final AppServices services;

  AppSettings get settings => services.settings.settings;

  void update(AppSettings Function(AppSettings current) transform) =>
      services.settings.mutate(transform);
}

class GeneralSettings extends _Section {
  const GeneralSettings({
    required super.services,
    required this.startupStatus,
    super.key,
  });

  final StartupStatus startupStatus;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SettingsSection(
          title: 'Startup',
          children: <Widget>[
            SettingsRow(
              label: 'Launch at sign-in',
              description: startupStatus.isStale
                  ? 'The registered entry points elsewhere and will be '
                        'rewritten.'
                  : 'Adds NocUI Experience to the Windows startup list.',
              control: DbSwitch(
                value: settings.launchAtStartup,
                onChanged: (bool value) => update(
                  (AppSettings s) => s.copyWith(launchAtStartup: value),
                ),
              ),
            ),
            SettingsRow(
              label: 'Start delay',
              description: 'Wait for the desktop to settle before appearing.',
              control: DbSlider(
                value: settings.startupDelaySeconds.toDouble(),
                min: 0,
                max: 60,
                label: '${settings.startupDelaySeconds}s',
                onChanged: (double value) => update(
                  (AppSettings s) =>
                      s.copyWith(startupDelaySeconds: value.round()),
                ),
              ),
            ),
            SettingsRow(
              label: 'Start paused',
              description: 'Launch into the tray without showing the island.',
              control: DbSwitch(
                value: settings.startPaused,
                onChanged: (bool value) =>
                    update((AppSettings s) => s.copyWith(startPaused: value)),
              ),
            ),
          ],
        ),
        SettingsSection(
          title: 'Behaviour',
          children: <Widget>[
            SettingsRow(
              label: 'Step aside for full screen',
              description:
                  'Hide during games, presentations and Do Not Disturb.',
              control: DbSwitch(
                value: settings.suppressInFullscreen,
                onChanged: (bool value) => update(
                  (AppSettings s) => s.copyWith(suppressInFullscreen: value),
                ),
              ),
            ),
            SettingsRow(
              label: 'Hide behind maximised apps',
              description:
                  'Step aside while an app fills the screen; return when it '
                  'is minimised or restored.',
              control: DbSwitch(
                value: settings.hideWhenCovered,
                onChanged: (bool value) => update(
                  (AppSettings s) => s.copyWith(hideWhenCovered: value),
                ),
              ),
            ),
            SettingsRow(
              label: '24-hour clock',
              control: DbSwitch(
                value: settings.use24HourClock,
                onChanged: (bool value) => update(
                  (AppSettings s) => s.copyWith(use24HourClock: value),
                ),
              ),
            ),
            SettingsRow(
              label: 'Close by itself',
              description: settings.autoCollapseSeconds == 0
                  ? 'Stays open until you dismiss it.'
                  : 'Closes after a pause, unless the pointer is on it.',
              control: DbSlider(
                value: settings.autoCollapseSeconds.toDouble(),
                min: 0,
                max: 30,
                label: settings.autoCollapseSeconds == 0
                    ? 'Never'
                    : '${settings.autoCollapseSeconds}s',
                onChanged: (double value) => update(
                  (AppSettings s) =>
                      s.copyWith(autoCollapseSeconds: value.round()),
                ),
              ),
            ),
            SettingsRow(
              label: 'Hide until needed',
              description:
                  'The pill withdraws into the bezel when you are working '
                  'elsewhere, and comes back as the pointer approaches the '
                  'top of the screen.',
              control: DbSwitch(
                value: settings.autoHide,
                onChanged: (bool value) =>
                    update((AppSettings s) => s.copyWith(autoHide: value)),
              ),
            ),
            if (settings.autoHide)
              SettingsRow(
                label: 'Withdraw after',
                description:
                    'How long an island that was left alone waits before it '
                    'goes. Moving the pointer away from the top of the screen '
                    'is always quick, whatever this says.',
                control: DbSlider(
                  value: settings.autoHideSeconds.toDouble(),
                  min: 1,
                  max: 20,
                  label: '${settings.autoHideSeconds}s',
                  onChanged: (double value) => update(
                    (AppSettings s) =>
                        s.copyWith(autoHideSeconds: value.round()),
                  ),
                ),
              ),
            SettingsRow(
              label: 'Grow on hover',
              description: 'The pill breathes when the pointer reaches it.',
              control: DbSwitch(
                value: settings.hoverToPeek,
                onChanged: (bool value) =>
                    update((AppSettings s) => s.copyWith(hoverToPeek: value)),
              ),
            ),
            SettingsRow(
              label: 'Scroll to change volume',
              description: 'Wheel over the closed pill adjusts the volume.',
              control: DbSwitch(
                value: settings.wheelAdjustsVolume,
                onChanged: (bool value) => update(
                  (AppSettings s) => s.copyWith(wheelAdjustsVolume: value),
                ),
              ),
            ),
            SettingsRow(
              label: 'Motion',
              description: settings.motionIntensity <= 0.01
                  ? 'Reduced: states change instantly.'
                  : 'How much the island animates.',
              control: DbSlider(
                value: settings.motionIntensity,
                min: 0,
                max: 1.4,
                label: settings.motionIntensity <= 0.01
                    ? 'Off'
                    : '${(settings.motionIntensity * 100).round()}%',
                onChanged: (double value) => update(
                  (AppSettings s) => s.copyWith(motionIntensity: value),
                ),
              ),
            ),
          ],
        ),
        Text(
          'NocUI Experience has no window of its own. Closing the island leaves it '
          'running in the notification area.',
          style: DbType.caption.copyWith(color: palette.textTertiary),
        ),
      ],
    );
  }
}

class AppearanceSettings extends _Section {
  const AppearanceSettings({required super.services, super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SettingsSection(
          title: 'Theme',
          children: <Widget>[
            SettingsRow(
              label: 'Appearance',
              control: DbSegmented<AppearanceMode>(
                value: settings.appearance,
                options: <AppearanceMode, String>{
                  AppearanceMode.system: 'Auto',
                  AppearanceMode.dark: 'Dark',
                  AppearanceMode.light: 'Light',
                },
                onChanged: (AppearanceMode value) =>
                    update((AppSettings s) => s.copyWith(appearance: value)),
              ),
            ),
            SettingsRow(
              label: 'Accent',
              description: 'Used to mark one thing at a time.',
              control: DbSwatches(
                value: settings.accent,
                options: AccentPreset.values,
                onChanged: (AccentPreset value) =>
                    update((AppSettings s) => s.copyWith(accent: value)),
              ),
            ),
          ],
        ),
        SettingsSection(
          title: 'Surface',
          children: <Widget>[
            SettingsRow(
              label: 'Translucency',
              description: 'How much of the desktop shows through.',
              control: DbSlider(
                value: settings.surfaceOpacity,
                min: 0.55,
                max: 1.0,
                label: '${(settings.surfaceOpacity * 100).round()}%',
                onChanged: (double value) => update(
                  (AppSettings s) => s.copyWith(surfaceOpacity: value),
                ),
              ),
            ),
            SettingsRow(
              label: 'Corner radius',
              control: DbSlider(
                value: settings.cornerScale,
                min: 0.4,
                max: 1.6,
                label: '${(settings.cornerScale * 100).round()}%',
                onChanged: (double value) =>
                    update((AppSettings s) => s.copyWith(cornerScale: value)),
              ),
            ),
            SettingsRow(
              label: 'Island size',
              control: DbSlider(
                value: settings.islandScale,
                min: 0.85,
                max: 1.35,
                label: '${(settings.islandScale * 100).round()}%',
                onChanged: (double value) =>
                    update((AppSettings s) => s.copyWith(islandScale: value)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class DisplaySettings extends _Section {
  const DisplaySettings({
    required super.services,
    required this.displays,
    super.key,
  });

  final List<DisplayInfo> displays;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    final Map<String, String> options = <String, String>{
      '': 'Follow the primary display',
      for (final DisplayInfo display in displays)
        display.id:
            '${display.name.isEmpty ? display.id : display.name}'
            '  ·  ${display.bounds.width.round()}'
            '×${display.bounds.height.round()}'
            '  ·  ${(display.scale * 100).round()}%',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SettingsSection(
          title: 'Monitor',
          description: displays.length > 1
              ? '${displays.length} displays detected.'
              : 'One display detected.',
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DbSpace.lg,
                vertical: DbSpace.md,
              ),
              child: DbChoiceList<String>(
                value: options.containsKey(settings.monitorId)
                    ? settings.monitorId
                    : '',
                options: options,
                onChanged: (String value) =>
                    update((AppSettings s) => s.copyWith(monitorId: value)),
              ),
            ),
          ],
        ),
        SettingsSection(
          title: 'Position',
          children: <Widget>[
            SettingsRow(
              label: 'Horizontal offset',
              control: DbSlider(
                value: settings.offsetX,
                min: -400,
                max: 400,
                label: '${settings.offsetX.round()}',
                onChanged: (double value) =>
                    update((AppSettings s) => s.copyWith(offsetX: value)),
              ),
            ),
            SettingsRow(
              label: 'Vertical offset',
              description: 'Distance from the top edge of the screen.',
              control: DbSlider(
                value: settings.offsetY,
                min: 0,
                max: 200,
                label: '${settings.offsetY.round()}',
                onChanged: (double value) =>
                    update((AppSettings s) => s.copyWith(offsetY: value)),
              ),
            ),
            SettingsRow(
              label: 'Avoid the taskbar',
              description:
                  'Anchor to the work area rather than the screen edge.',
              control: DbSwitch(
                value: settings.useWorkArea,
                onChanged: (bool value) =>
                    update((AppSettings s) => s.copyWith(useWorkArea: value)),
              ),
            ),
          ],
        ),
        Text(
          'The island follows DPI changes and re-places itself when displays '
          'are added, removed or rearranged.',
          style: DbType.caption.copyWith(color: palette.textTertiary),
        ),
      ],
    );
  }
}

class FeatureSettings extends _Section {
  const FeatureSettings({required super.services, super.key});

  /// Pages the user can switch off. Now is not among them: the pager has to
  /// have somewhere to land.
  static const List<IslandPage> _optionalPages = <IslandPage>[
    IslandPage.calendar,
    IslandPage.timers,
    IslandPage.shortcuts,
    IslandPage.media,
    IslandPage.shelf,
    IslandPage.system,
  ];

  void _setPage(IslandPage page, bool enabled) {
    final Set<String> disabled = settings.disabledPages.toSet();
    if (enabled) {
      disabled.remove(page.id);
    } else {
      disabled.add(page.id);
    }
    update(
      (AppSettings s) =>
          s.copyWith(disabledPages: disabled.toList(growable: false)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Set<String> disabled = settings.disabledPages.toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SettingsSection(
          title: 'Pages',
          description:
              'What the open island can page through. Use the arrow keys, the '
              'scroll wheel, or the dots to move between them.',
          children: <Widget>[
            for (final IslandPage page in _optionalPages)
              SettingsRow(
                label: page.label,
                control: DbSwitch(
                  value: !disabled.contains(page.id),
                  onChanged: (bool value) => _setPage(page, value),
                ),
              ),
          ],
        ),
        HomeSettings(services: services),
        SettingsSection(
          title: 'Modules',
          description:
              'A module that is off holds no watcher, no channel and no timer.',
          children: <Widget>[
            SettingsRow(
              label: 'Media',
              description: 'Show and control whatever Windows is playing.',
              control: DbSwitch(
                value: settings.mediaEnabled,
                onChanged: (bool value) =>
                    update((AppSettings s) => s.copyWith(mediaEnabled: value)),
              ),
            ),
            SettingsRow(
              label: 'Notifications',
              description: 'Brief messages from the modules below.',
              control: DbSwitch(
                value: settings.notificationsEnabled,
                onChanged: (bool value) => update(
                  (AppSettings s) => s.copyWith(notificationsEnabled: value),
                ),
              ),
            ),
            SettingsRow(
              label: 'Downloads',
              description: 'Watch the Downloads folder for transfers.',
              control: DbSwitch(
                value: settings.downloadsEnabled,
                onChanged: (bool value) => update(
                  (AppSettings s) => s.copyWith(downloadsEnabled: value),
                ),
              ),
            ),
            SettingsRow(
              label: 'Timers',
              control: DbSwitch(
                value: settings.timersEnabled,
                onChanged: (bool value) =>
                    update((AppSettings s) => s.copyWith(timersEnabled: value)),
              ),
            ),
            SettingsRow(
              label: 'System status',
              description: 'Battery, network, volume, microphone and camera.',
              control: DbSwitch(
                value: settings.systemStatusEnabled,
                onChanged: (bool value) => update(
                  (AppSettings s) => s.copyWith(systemStatusEnabled: value),
                ),
              ),
            ),
            SettingsRow(
              label: 'Volume heads-up',
              description: 'Confirm volume changes on the island.',
              control: DbSwitch(
                value: settings.volumeHudEnabled,
                onChanged: settings.systemStatusEnabled
                    ? (bool value) => update(
                        (AppSettings s) => s.copyWith(volumeHudEnabled: value),
                      )
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class ShortcutSettings extends _Section {
  const ShortcutSettings({
    required super.services,
    required this.conflicts,
    super.key,
  });

  /// Ids that Windows refused to register because something else owns them.
  final Set<String> conflicts;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SettingsSection(
          title: 'Global shortcuts',
          description: 'Work anywhere in Windows. A modifier is required.',
          children: <Widget>[
            SettingsRow(
              label: 'Toggle island',
              control: DbShortcutField(
                value: settings.hotkeyToggle,
                conflict: conflicts.contains('toggle'),
                onChanged: (String value) =>
                    update((AppSettings s) => s.copyWith(hotkeyToggle: value)),
              ),
            ),
            SettingsRow(
              label: 'Open island',
              control: DbShortcutField(
                value: settings.hotkeyExpand,
                conflict: conflicts.contains('expand'),
                onChanged: (String value) =>
                    update((AppSettings s) => s.copyWith(hotkeyExpand: value)),
              ),
            ),
            SettingsRow(
              label: 'Hide island',
              control: DbShortcutField(
                value: settings.hotkeyHide,
                conflict: conflicts.contains('hide'),
                onChanged: (String value) =>
                    update((AppSettings s) => s.copyWith(hotkeyHide: value)),
              ),
            ),
          ],
        ),
        if (conflicts.isNotEmpty)
          Text(
            'A shortcut shown in red is already registered by another '
            'application and will not fire.',
            style: DbType.caption.copyWith(color: palette.negative),
          )
        else
          Text(
            'While the island is open, Escape closes it.',
            style: DbType.caption.copyWith(color: palette.textTertiary),
          ),
      ],
    );
  }
}

class PrivacySettings extends _Section {
  const PrivacySettings({
    required super.services,
    required this.downloadsFolder,
    super.key,
  });

  final String downloadsFolder;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SettingsSection(
          title: 'Clipboard',
          description:
              'Off by default. When on, NocUI Experience is told that something was '
              'copied, and how large it was.',
          children: <Widget>[
            SettingsRow(
              label: 'Clipboard activity',
              description: 'Acknowledge copies on the island.',
              control: DbSwitch(
                value: settings.clipboardEnabled,
                onChanged: (bool value) => update(
                  (AppSettings s) => s.copyWith(clipboardEnabled: value),
                ),
              ),
            ),
            SettingsRow(
              label: 'Show a text preview',
              description:
                  'Reads the first line of copied text. Leave off if you copy '
                  'passwords.',
              control: DbSwitch(
                value: settings.clipboardPreviewEnabled,
                onChanged: settings.clipboardEnabled
                    ? (bool value) => update(
                        (AppSettings s) =>
                            s.copyWith(clipboardPreviewEnabled: value),
                      )
                    : null,
              ),
            ),
          ],
        ),
        SettingsSection(
          title: 'What leaves this machine',
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(DbSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'Nothing.',
                    style: DbType.title.copyWith(color: palette.textPrimary),
                  ),
                  const SizedBox(height: DbSpace.sm),
                  Text(
                    'NocUI Experience makes no network requests unless weather is enabled. There is no '
                    'telemetry, no crash reporting and no account. Settings '
                    'and logs are written to your user profile and read by '
                    'nothing else.',
                    style: DbType.body.copyWith(color: palette.textSecondary),
                  ),
                  const SizedBox(height: DbSpace.md),
                  _PathLine(
                    label: 'Settings',
                    value: services.settings.filePath,
                  ),
                  if (downloadsFolder.isNotEmpty)
                    _PathLine(label: 'Watched folder', value: downloadsFolder),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class AboutSettings extends _Section {
  const AboutSettings({
    required super.services,
    required this.nativeLogPath,
    super.key,
  });

  final String nativeLogPath;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    final List<LogRecord> recent = AppLog.records.reversed.take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SettingsSection(
          title: 'Made by',
          children: <Widget>[_DeveloperCard()],
        ),
        SettingsSection(
          title: 'About',
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(DbSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '${AppInfo.name} ${AppInfo.version}',
                    style: DbType.title.copyWith(color: palette.textPrimary),
                  ),
                  const SizedBox(height: DbSpace.xs),
                  Text(
                    AppInfo.tagline,
                    style: DbType.body.copyWith(color: palette.textSecondary),
                  ),
                  const SizedBox(height: DbSpace.md),
                  for (final ({String name, String licence}) entry
                      in AppInfo.licences)
                    Text(
                      '${entry.name} — ${entry.licence}',
                      style: DbType.caption.copyWith(
                        color: palette.textTertiary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        SettingsSection(
          title: 'Diagnostics',
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(DbSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (nativeLogPath.isNotEmpty)
                    _PathLine(label: 'Log file', value: nativeLogPath),
                  const SizedBox(height: DbSpace.md),
                  Text(
                    'RECENT',
                    style: DbType.overline.copyWith(
                      color: palette.textTertiary,
                    ),
                  ),
                  const SizedBox(height: DbSpace.sm),
                  if (recent.isEmpty)
                    Text(
                      'Nothing logged yet.',
                      style: DbType.caption.copyWith(
                        color: palette.textTertiary,
                      ),
                    )
                  else
                    for (final LogRecord record in recent)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          record.toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DbType.caption.copyWith(
                            color: record.level == LogLevel.error
                                ? palette.negative
                                : palette.textSecondary,
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The one page in the application that is about a person rather than a
/// machine, so it is allowed to be the one card with a colour in it.
///
/// The monogram and name identify the developer without a contact address.
class _DeveloperCard extends StatelessWidget {
  const _DeveloperCard();

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;

    return Container(
      padding: const EdgeInsets.all(DbSpace.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DbRadius.card),
        // A wash of the accent across one corner, nothing more: enough to
        // make this card the one warm thing in a panel of switches.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            palette.accent.withValues(alpha: palette.isDark ? 0.16 : 0.12),
            palette.accent.withValues(alpha: 0.0),
          ],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          _Monogram(initials: AppInfo.developerInitials),
          const SizedBox(width: DbSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  AppInfo.developer,
                  style: DbType.headline.copyWith(
                    color: palette.textPrimary,
                    fontSize: 19,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${AppInfo.developerRole} · ${AppInfo.name}',
                  style: DbType.caption.copyWith(color: palette.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Two letters in a rounded square, in the accent. Cheaper than a photograph
/// and truer than a stock avatar.
class _Monogram extends StatelessWidget {
  const _Monogram({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;

    return Container(
      width: 54,
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette.accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(DbRadius.card),
        border: Border.all(
          color: palette.accent.withValues(alpha: 0.45),
        ),
      ),
      child: Text(
        initials,
        style: DbType.headline.copyWith(
          color: palette.accent,
          fontSize: 20,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _PathLine extends StatelessWidget {
  const _PathLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    return Padding(
      padding: const EdgeInsets.only(top: DbSpace.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: DbType.caption.copyWith(color: palette.textTertiary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DbType.caption.copyWith(color: palette.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
