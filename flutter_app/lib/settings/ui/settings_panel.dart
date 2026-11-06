import 'package:flutter/widgets.dart';

import '../../app/app_info.dart';
import '../../app/app_services.dart';
import '../../design/components/island_button.dart';
import '../../design/theme/island_theme.dart';
import '../../design/tokens/db_colors.dart';
import '../../design/tokens/db_dimens.dart';
import '../../design/tokens/db_icons.dart';
import '../../design/tokens/db_motion.dart';
import '../../design/tokens/db_typography.dart';
import '../../native/models/native_models.dart';
import '../../native/startup_bridge.dart';
import 'settings_sections.dart';

/// The sections of the settings panel, in the order they appear.
enum SettingsTab {
  general,
  appearance,
  display,
  features,
  shortcuts,
  privacy,
  about,
}

extension SettingsTabX on SettingsTab {
  /// Identifier used when something elsewhere in the island asks for settings
  /// to open on a particular section.
  String get id => name;

  static SettingsTab? fromId(String? id) {
    for (final SettingsTab tab in SettingsTab.values) {
      if (tab.id == id) {
        return tab;
      }
    }
    return null;
  }

  String get label {
    switch (this) {
      case SettingsTab.general:
        return 'General';
      case SettingsTab.appearance:
        return 'Appearance';
      case SettingsTab.display:
        return 'Display';
      case SettingsTab.features:
        return 'Features';
      case SettingsTab.shortcuts:
        return 'Shortcuts';
      case SettingsTab.privacy:
        return 'Privacy';
      case SettingsTab.about:
        return 'About';
    }
  }

  IconData get icon {
    switch (this) {
      case SettingsTab.general:
        return DbIcons.settings;
      case SettingsTab.appearance:
        return DbIcons.appearance;
      case SettingsTab.display:
        return DbIcons.display;
      case SettingsTab.features:
        return DbIcons.features;
      case SettingsTab.shortcuts:
        return DbIcons.keyboard;
      case SettingsTab.privacy:
        return DbIcons.privacy;
      case SettingsTab.about:
        return DbIcons.about;
    }
  }
}

/// The settings surface, hosted in the separate settings window.
class SettingsPanel extends StatefulWidget {
  const SettingsPanel({required this.onClose, this.initialSection, super.key});

  final VoidCallback onClose;
  final String? initialSection;

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  SettingsTab _tab = SettingsTab.general;
  bool _landed = false;

  List<DisplayInfo> _displays = const <DisplayInfo>[];
  StartupStatus _startup = StartupStatus.unknown;
  String _downloadsFolder = '';
  String _logPath = '';

  @override
  void initState() {
    super.initState();
    // Everything here is a one-shot query, refreshed when the panel opens
    // rather than held live: none of it changes while it is being read.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadEnvironment());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_landed) {
      return;
    }
    _landed = true;
    // Whoever opened settings may have had a section in mind - the weather
    // panel asking for a place, the home shelf asking which four apps. Honour
    // it once, on the way in, and leave the user in charge after that.
    final SettingsTab? requested = SettingsTabX.fromId(
      widget.initialSection ?? AppScope.read(context).router.settingsSection,
    );
    if (requested != null) {
      _tab = requested;
    }
  }

  Future<void> _loadEnvironment() async {
    final AppServices services = AppScope.read(context);
    final List<DisplayInfo> displays = await services.displays.list();
    final StartupStatus startup = await services.startup.status();
    final String folder = await services.downloadsBridge.folder();
    final String log = await services.window.nativeLogPath();
    if (!mounted) {
      return;
    }
    setState(() {
      _displays = displays;
      _startup = startup;
      _downloadsFolder = folder;
      _logPath = log;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppServices services = AppScope.read(context);
    final IslandThemeData theme = IslandTheme.of(context);
    final IslandPalette palette = theme.palette;

    return AnimatedBuilder(
      animation: services.settings,
      builder: (BuildContext context, _) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _NavigationRail(
              selected: _tab,
              onSelected: (SettingsTab tab) => setState(() => _tab = tab),
              onClose: widget.onClose,
            ),
            Container(width: 1, color: palette.separator),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  DbSpace.xxl,
                  DbSpace.xl,
                  DbSpace.xxl,
                  DbSpace.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            _tab.label,
                            style: DbType.headline.copyWith(
                              color: palette.textPrimary,
                            ),
                          ),
                        ),
                        IslandButton(
                          icon: DbIcons.close,
                          tooltip: 'Close settings',
                          onPressed: widget.onClose,
                        ),
                      ],
                    ),
                    if (services.settings.remoteError != null) ...<Widget>[
                      const SizedBox(height: DbSpace.md),
                      Text(
                        services.settings.remoteError!,
                        style: DbType.caption.copyWith(color: palette.negative),
                      ),
                    ],
                    const SizedBox(height: DbSpace.xl),
                    Expanded(
                      child: _ScrollingSection(
                        child: AnimatedSwitcher(
                          duration: theme.motion.scale(DbDuration.quick),
                          switchInCurve: DbCurve.standard,
                          switchOutCurve: DbCurve.exit,
                          transitionBuilder:
                              (Widget child, Animation<double> animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0, 0.03),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                );
                              },
                          child: KeyedSubtree(
                            key: ValueKey<SettingsTab>(_tab),
                            child: _sectionFor(services),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _sectionFor(AppServices services) {
    switch (_tab) {
      case SettingsTab.general:
        return GeneralSettings(services: services, startupStatus: _startup);
      case SettingsTab.appearance:
        return AppearanceSettings(services: services);
      case SettingsTab.display:
        return DisplaySettings(services: services, displays: _displays);
      case SettingsTab.features:
        return FeatureSettings(services: services);
      case SettingsTab.shortcuts:
        // Conflicts come from the coordinator's own registration attempt;
        // re-registering here to find out would fight it.
        return ValueListenableBuilder<Set<String>>(
          valueListenable: services.hotkeyConflicts,
          builder: (BuildContext context, Set<String> conflicts, _) =>
              ShortcutSettings(services: services, conflicts: conflicts),
        );
      case SettingsTab.privacy:
        return PrivacySettings(
          services: services,
          downloadsFolder: _downloadsFolder,
        );
      case SettingsTab.about:
        return AboutSettings(services: services, nativeLogPath: _logPath);
    }
  }
}

class _NavigationRail extends StatelessWidget {
  const _NavigationRail({
    required this.selected,
    required this.onSelected,
    required this.onClose,
  });

  final SettingsTab selected;
  final ValueChanged<SettingsTab> onSelected;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);
    final IslandPalette palette = theme.palette;

    return SizedBox(
      width: 216,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DbSpace.md,
          vertical: DbSpace.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DbSpace.md),
              child: Text(
                AppInfo.name,
                style: DbType.title.copyWith(color: palette.textPrimary),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DbSpace.md),
              child: Text(
                AppInfo.version,
                style: DbType.caption.copyWith(color: palette.textTertiary),
              ),
            ),
            const SizedBox(height: DbSpace.xl),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (final SettingsTab tab in SettingsTab.values)
                      _RailItem(
                        tab: tab,
                        selected: tab == selected,
                        onTap: () => onSelected(tab),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RailItem extends StatefulWidget {
  const _RailItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final SettingsTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_RailItem> createState() => _RailItemState();
}

class _RailItemState extends State<_RailItem> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);
    final IslandPalette palette = theme.palette;
    final Color foreground = widget.selected
        ? palette.textPrimary
        : palette.textSecondary;

    return FocusableActionDetector(
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
          widget.onTap();
          return null;
        }),
      },
      child: Semantics(
        selected: widget.selected,
        button: true,
        label: widget.tab.label,
        child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: theme.motion.scale(DbDuration.micro),
            curve: DbCurve.standard,
            margin: const EdgeInsets.only(bottom: 2),
            padding: const EdgeInsets.symmetric(
              horizontal: DbSpace.md,
              vertical: DbSpace.md,
            ),
            decoration: BoxDecoration(
              color: widget.selected
                  ? palette.accent.withValues(alpha: 0.24)
                  : (_hovered
                        ? palette.textPrimary.withValues(alpha: 0.05)
                        : const Color(0x00000000)),
              borderRadius: BorderRadius.circular(DbRadius.control),
              border: Border.all(
                color: _focused ? palette.accent : const Color(0x00000000),
              ),
            ),
            child: Row(
              children: <Widget>[
                Icon(widget.tab.icon, size: DbSize.iconSm, color: foreground),
                const SizedBox(width: DbSpace.md),
                Text(
                  widget.tab.label,
                  style: DbType.body.copyWith(color: foreground),
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}

/// A scroll view with the platform's own behaviour, minus the glow.
class _ScrollingSection extends StatelessWidget {
  const _ScrollingSection({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: const _NoGlowScrollBehavior(),
      child: SingleChildScrollView(primary: false, child: child),
    );
  }
}

class _NoGlowScrollBehavior extends ScrollBehavior {
  const _NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}
