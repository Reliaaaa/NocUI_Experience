import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../app/app_services.dart';
import '../../../design/components/island_button.dart';
import '../../../design/components/staggered_reveal.dart';
import '../../../design/theme/island_theme.dart';
import '../../../design/tokens/db_colors.dart';
import '../../../design/tokens/db_dimens.dart';
import '../../../design/tokens/db_icons.dart';
import '../../../design/tokens/db_motion.dart';
import '../../../design/tokens/db_typography.dart';
import '../../../modules/notifications/island_notification.dart';
import '../../../modules/shortcuts/shortcut_catalog.dart';
import '../../../settings/app_settings.dart';
import 'page_scaffold.dart';

/// One click to the things you open all day, and the three switches worth
/// having at hand.
///
/// The catalogue is fixed rather than scanned from the Start menu: enumerating
/// installed software is slow, needs a watcher to stay current, and would tell
/// the application things about the user it has no reason to know. Pinning is
/// done here, in the page itself, rather than buried in Settings - the place
/// you notice something is missing is the place you should be able to add it.
class ShortcutsPage extends StatefulWidget {
  const ShortcutsPage({super.key});

  @override
  State<ShortcutsPage> createState() => _ShortcutsPageState();
}

class _ShortcutsPageState extends State<ShortcutsPage> {
  bool _editing = false;

  Future<void> _launch(ShortcutEntry entry) async {
    final AppServices services = AppScope.read(context);
    final bool opened = await services.shell.open(entry.target);
    if (!opened) {
      // Silence would be indistinguishable from a dead button.
      services.notifications.post(
        IslandNotification(
          id: 'shortcut.${entry.id}',
          title: 'Could not open ${entry.label}',
          body: 'Windows has nothing registered for it.',
          kind: NotificationKind.warning,
        ),
      );
    }
  }

  void _togglePin(ShortcutEntry entry) {
    final AppServices services = AppScope.read(context);
    services.settings.mutate((AppSettings current) {
      final List<String> next = List<String>.of(current.pinnedShortcuts);
      if (!next.remove(entry.id)) {
        next.add(entry.id);
      }
      return current.copyWith(pinnedShortcuts: next);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppServices services = AppScope.read(context);

    return AnimatedBuilder(
      animation: services.settings,
      builder: (BuildContext context, _) {
        final List<String> pinnedIds =
            services.settings.settings.pinnedShortcuts;
        final List<ShortcutEntry> pinned = ShortcutCatalog.resolve(pinnedIds);

        return PageScaffold(
          title: _editing ? 'Choose shortcuts' : 'Shortcuts',
          trailing: IslandButton(
            icon: _editing ? DbIcons.check : DbIcons.pin,
            tooltip: _editing ? 'Done' : 'Add or remove shortcuts',
            tone: _editing
                ? IslandButtonTone.accent
                : IslandButtonTone.neutral,
            onPressed: () => setState(() => _editing = !_editing),
          ),
          child: _editing
              ? _Picker(
                  pinned: pinnedIds.toSet(),
                  onToggle: _togglePin,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Reveal(order: 1, child: const _QuickToggles()),
                    const SizedBox(height: DbSpace.md),
                    Expanded(
                      child: pinned.isEmpty
                          ? const PageEmptyState(
                              message: 'No shortcuts pinned',
                              hint: 'Use the pin button to choose some.',
                            )
                          : Reveal(
                              order: 2,
                              scaleFrom: 0.97,
                              child: _Grid(
                                entries: pinned,
                                onTap: _launch,
                              ),
                            ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

/// The switches that are genuinely one click, and honest about it.
///
/// Windows exposes no way to turn Focus Assist on programmatically, so there is
/// no "Do Not Disturb" button here pretending otherwise - Quiet silences this
/// application's own heads-ups, which is a promise it can keep, and the Focus
/// panel is one tile away in the grid.
class _QuickToggles extends StatelessWidget {
  const _QuickToggles();

  @override
  Widget build(BuildContext context) {
    final AppServices services = AppScope.read(context);

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        services.system,
        services.settings,
      ]),
      builder: (BuildContext context, _) {
        final AppSettings settings = services.settings.settings;
        final bool muted = services.system.volume.muted;
        final bool available = services.system.volume.available;

        return Row(
          children: <Widget>[
            Expanded(
              child: _Toggle(
                icon: muted ? DbIcons.muted : DbIcons.volume,
                label: muted ? 'Muted' : 'Sound on',
                on: muted,
                onPressed: available
                    ? () => unawaited(services.system.toggleMute())
                    : null,
              ),
            ),
            const SizedBox(width: DbSpace.sm),
            Expanded(
              child: _Toggle(
                icon: DbIcons.bell,
                label: settings.notificationsEnabled ? 'Alerts on' : 'Quiet',
                on: !settings.notificationsEnabled,
                onPressed: () => services.settings.mutate(
                  (AppSettings s) => s.copyWith(
                    notificationsEnabled: !s.notificationsEnabled,
                  ),
                ),
              ),
            ),
            const SizedBox(width: DbSpace.sm),
            Expanded(
              child: _Toggle(
                icon: DbIcons.visibilityOff,
                label: settings.autoHide ? 'Auto-hide' : 'Always shown',
                on: settings.autoHide,
                onPressed: () => services.settings.mutate(
                  (AppSettings s) => s.copyWith(autoHide: !s.autoHide),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.icon,
    required this.label,
    required this.on,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool on;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);
    final IslandPalette palette = theme.palette;
    final bool enabled = onPressed != null;
    final Color tint = on ? palette.accent : palette.textSecondary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: AnimatedContainer(
        duration: theme.motion.scale(DbDuration.micro),
        curve: DbCurve.standard,
        height: DbSize.controlLg,
        decoration: BoxDecoration(
          color: on
              ? palette.accent.withValues(alpha: 0.16)
              : palette.surfaceSunken,
          borderRadius: BorderRadius.circular(DbRadius.control),
          border: Border.all(
            color: on
                ? palette.accent.withValues(alpha: 0.34)
                : palette.stroke,
          ),
        ),
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: DbSize.iconSm, color: tint),
              const SizedBox(width: DbSpace.xs),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: DbType.caption.copyWith(color: tint),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Five across. Wide enough for a label under an icon at 100% scaling, and
/// scrollable rather than paged, because a shortcut grid that hid its last row
/// behind a page turn would be slower than the Start menu it replaces.
class _Grid extends StatelessWidget {
  const _Grid({required this.entries, required this.onTap});

  final List<ShortcutEntry> entries;
  final ValueChanged<ShortcutEntry> onTap;

  static const int _columns = 5;

  @override
  Widget build(BuildContext context) {
    final List<List<ShortcutEntry>> rows = <List<ShortcutEntry>>[];
    for (int i = 0; i < entries.length; i += _columns) {
      rows.add(
        entries.sublist(
          i,
          i + _columns > entries.length ? entries.length : i + _columns,
        ),
      );
    }

    // A row cut off by the bottom edge should read as "there is more below",
    // not as a clipped layout, so the last few pixels fade out.
    return ShaderMask(
      shaderCallback: (Rect bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xFFFFFFFF),
          Color(0xFFFFFFFF),
          Color(0x00FFFFFF),
        ],
        stops: <double>[0, 0.86, 1],
      ).createShader(bounds),
      blendMode: BlendMode.dstIn,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: DbSpace.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final List<ShortcutEntry> row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: DbSpace.sm),
                child: Row(
                  children: <Widget>[
                    for (int column = 0; column < _columns; column++)
                      Expanded(
                        child: column < row.length
                            ? Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: DbSpace.xxs,
                                ),
                                child: _Tile(
                                  entry: row[column],
                                  onTap: () => onTap(row[column]),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatefulWidget {
  const _Tile({required this.entry, required this.onTap});

  final ShortcutEntry entry;
  final VoidCallback onTap;

  @override
  State<_Tile> createState() => _TileState();
}

class _TileState extends State<_Tile> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);
    final IslandPalette palette = theme.palette;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {
          setState(() => _pressed = false);
          widget.onTap();
        },
        child: AnimatedScale(
          // The press is a real depth cue rather than a colour change: at this
          // tile size a fill alone is hard to see under the cursor.
          scale: _pressed ? 0.94 : 1.0,
          duration: theme.motion.scale(DbDuration.instant),
          curve: DbCurve.standard,
          child: AnimatedContainer(
            duration: theme.motion.scale(DbDuration.micro),
            curve: DbCurve.standard,
            height: 54,
            decoration: BoxDecoration(
              color: _hovered
                  ? palette.surfaceRaised
                  : palette.surfaceSunken,
              borderRadius: BorderRadius.circular(DbRadius.control),
              border: Border.all(
                color: _hovered ? palette.strokeStrong : palette.stroke,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  widget.entry.icon,
                  size: DbSize.iconMd,
                  color: _hovered ? palette.accent : palette.textSecondary,
                ),
                const SizedBox(height: DbSpace.xxs),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: DbSpace.xxs),
                  child: Text(
                    widget.entry.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    textAlign: TextAlign.center,
                    style: DbType.caption.copyWith(
                      color: palette.textSecondary,
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

/// The whole catalogue, grouped, with the pinned ones marked. Tapping a row
/// pins or unpins it; the grid behind updates as you go.
class _Picker extends StatelessWidget {
  const _Picker({required this.pinned, required this.onToggle});

  final Set<String> pinned;
  final ValueChanged<ShortcutEntry> onToggle;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final ShortcutGroup group in ShortcutGroup.values) ...<Widget>[
            Padding(
              padding: const EdgeInsets.only(
                top: DbSpace.xs,
                bottom: DbSpace.xs,
              ),
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
                  _PickerChip(
                    entry: entry,
                    pinned: pinned.contains(entry.id),
                    onTap: () => onToggle(entry),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PickerChip extends StatelessWidget {
  const _PickerChip({
    required this.entry,
    required this.pinned,
    required this.onTap,
  });

  final ShortcutEntry entry;
  final bool pinned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);
    final IslandPalette palette = theme.palette;
    final Color tint = pinned ? palette.accent : palette.textSecondary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: theme.motion.scale(DbDuration.micro),
          curve: DbCurve.standard,
          padding: const EdgeInsets.symmetric(
            horizontal: DbSpace.sm,
            vertical: DbSpace.xs,
          ),
          decoration: BoxDecoration(
            color: pinned
                ? palette.accent.withValues(alpha: 0.16)
                : palette.surfaceSunken,
            borderRadius: BorderRadius.circular(DbRadius.pill),
            border: Border.all(
              color: pinned
                  ? palette.accent.withValues(alpha: 0.34)
                  : palette.stroke,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                pinned ? DbIcons.pinned : entry.icon,
                size: DbSize.iconSm,
                color: tint,
              ),
              const SizedBox(width: DbSpace.xs),
              Text(
                entry.label,
                style: DbType.caption.copyWith(color: tint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
