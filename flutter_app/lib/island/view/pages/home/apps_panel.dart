import 'package:flutter/widgets.dart';

import '../../../../app/app_services.dart';
import '../../../../design/theme/island_theme.dart';
import '../../../../design/tokens/db_colors.dart';
import '../../../../design/tokens/db_dimens.dart';
import '../../../../design/tokens/db_icons.dart';
import '../../../../design/tokens/db_motion.dart';
import '../../../../design/tokens/db_typography.dart';
import '../../../../modules/notifications/island_notification.dart';
import '../../../../modules/shortcuts/shortcut_catalog.dart';
import 'deck_panel.dart';

/// The four things you open without thinking.
///
/// Not the Shortcuts page in miniature: that page is a drawer of forty, and
/// this is the shelf by the door. Which four sit here is the user's choice and
/// nothing else's - no recency, no usage counting, no reordering under the
/// cursor. A shelf that rearranges itself is a shelf you have to read.
class AppsPanel extends StatelessWidget {
  const AppsPanel({
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

  static Future<void> launch(BuildContext context, ShortcutEntry entry) async {
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

  static void editShortcuts(BuildContext context) =>
      AppScope.read(context).router.openSettings(section: 'features');

  @override
  Widget build(BuildContext context) {
    final AppServices services = AppScope.read(context);

    return AnimatedBuilder(
      animation: services.settings,
      builder: (BuildContext context, _) {
        final List<ShortcutEntry> entries = ShortcutCatalog.resolve(
          services.settings.settings.homeShortcuts,
        );

        return DeckPanel(
          progress: progress,
          width: width,
          expandedWidth: expandedWidth,
          compact: compact,
          summary: _Summary(entries: entries),
          detail: _Detail(entries: entries),
        );
      },
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.entries});

  final List<ShortcutEntry> entries;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;

    return PanelSummary(
      icon: DbIcons.grid,
      title: 'Apps',
      footer: entries.isEmpty
          ? Text(
              'None chosen',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DbType.caption.copyWith(color: palette.textTertiary),
            )
          // Four glyphs have to fit the narrowest this panel ever gets, which
          // is a scaled-down island with another panel open. Scaling down is
          // invisible at this size; an overflow stripe is not.
          : FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (final ShortcutEntry entry in entries.take(
                    ShortcutCatalog.homeSlots,
                  ))
                    Padding(
                      padding: const EdgeInsets.only(right: DbSpace.xs),
                      child: Icon(
                        entry.icon,
                        size: 12,
                        color: palette.textTertiary,
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.entries});

  final List<ShortcutEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PanelHeader(
          label: 'Apps',
          trailing: PanelIconButton(
            icon: DbIcons.edit,
            tooltip: 'Choose which four appear here',
            onPressed: () => AppsPanel.editShortcuts(context),
          ),
        ),
        const SizedBox(height: DbSpace.xs),
        // Two by two rather than four across: at this width four columns
        // would leave every label as three letters and an ellipsis, and a
        // shortcut you cannot read is a shortcut you have to hover to
        // identify.
        Expanded(
          child: Column(
            children: <Widget>[
              for (int row = 0; row < 2; row++) ...<Widget>[
                if (row > 0) const SizedBox(height: DbSpace.xxs),
                Expanded(
                  child: Row(
                    children: <Widget>[
                      for (int column = 0; column < 2; column++) ...<Widget>[
                        if (column > 0) const SizedBox(width: DbSpace.xxs),
                        Expanded(
                          child: row * 2 + column < entries.length
                              ? _AppTile(entry: entries[row * 2 + column])
                              : const _EmptySlot(),
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

class _AppTile extends StatefulWidget {
  const _AppTile({required this.entry});

  final ShortcutEntry entry;

  @override
  State<_AppTile> createState() => _AppTileState();
}

class _AppTileState extends State<_AppTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);
    final IslandPalette palette = theme.palette;

    return Semantics(
      button: true,
      label: 'Open ${widget.entry.label}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => AppsPanel.launch(context, widget.entry),
          child: AnimatedContainer(
            duration: theme.motion.scale(DbDuration.micro),
            curve: DbCurve.standard,
            decoration: BoxDecoration(
              color: _hovered
                  ? palette.surfaceSunken
                  : const Color(0x00000000),
              borderRadius: BorderRadius.circular(DbRadius.control),
              border: Border.all(
                color: _hovered ? palette.stroke : const Color(0x00000000),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: DbSpace.sm),
            child: Row(
              children: <Widget>[
                Icon(
                  widget.entry.icon,
                  size: DbSize.iconMd,
                  color: _hovered ? palette.accent : palette.textSecondary,
                ),
                const SizedBox(width: DbSpace.xs),
                Expanded(
                  // A name a hair too long for its tile is set slightly
                  // smaller rather than cut short: "Explorer" reads at nine
                  // points, "Explo..." does not read at any size.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.entry.label,
                      maxLines: 1,
                      softWrap: false,
                      style: DbType.caption.copyWith(
                        color: _hovered
                            ? palette.textPrimary
                            : palette.textSecondary,
                      ),
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

/// A slot nobody has filled. Says what it is for rather than sitting empty.
class _EmptySlot extends StatelessWidget {
  const _EmptySlot();

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;

    return Semantics(
      button: true,
      label: 'Choose a shortcut for this slot',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => AppsPanel.editShortcuts(context),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(DbRadius.control),
              border: Border.all(color: palette.stroke),
            ),
            child: Center(
              child: Icon(
                DbIcons.add,
                size: DbSize.iconMd,
                color: palette.textTertiary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
