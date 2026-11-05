import 'package:flutter/widgets.dart';

import '../../../app/app_services.dart';
import '../../../design/components/island_button.dart';
import '../../../design/components/island_progress.dart';
import '../../../design/components/staggered_reveal.dart';
import '../../../design/theme/island_theme.dart';
import '../../../design/tokens/db_colors.dart';
import '../../../design/tokens/db_dimens.dart';
import '../../../design/tokens/db_icons.dart';
import '../../../design/tokens/db_typography.dart';
import '../../../modules/notifications/island_notification.dart';

/// Icon and accent for a notification kind.
///
/// Colour is used here to classify, not to decorate: an error is the only thing
/// that turns the badge red, so red always means the same thing.
class _NotificationStyle {
  const _NotificationStyle(this.icon, this.color);

  final IconData icon;
  final Color color;

  static _NotificationStyle of(NotificationKind kind, IslandPalette palette) {
    switch (kind) {
      case NotificationKind.success:
        return _NotificationStyle(DbIcons.check, palette.positive);
      case NotificationKind.warning:
        return _NotificationStyle(DbIcons.warning, palette.warning);
      case NotificationKind.error:
        return _NotificationStyle(DbIcons.warning, palette.negative);
      case NotificationKind.media:
        return _NotificationStyle(DbIcons.play, palette.accent);
      case NotificationKind.download:
        return _NotificationStyle(DbIcons.download, palette.accent);
      case NotificationKind.clipboard:
        return _NotificationStyle(DbIcons.clipboard, palette.textSecondary);
      case NotificationKind.timer:
        return _NotificationStyle(DbIcons.timer, palette.accent);
      case NotificationKind.system:
        return _NotificationStyle(DbIcons.settings, palette.textSecondary);
      case NotificationKind.info:
        return _NotificationStyle(DbIcons.bell, palette.accent);
    }
  }
}

/// A small round badge carrying the notification's icon.
class NotificationGlyph extends StatelessWidget {
  const NotificationGlyph({
    required this.kind,
    this.size = 22,
    this.accent,
    super.key,
  });

  final NotificationKind kind;
  final double size;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    final _NotificationStyle style = _NotificationStyle.of(kind, palette);
    final Color color = accent ?? style.color;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(style.icon, size: size * 0.55, color: color),
      ),
    );
  }
}

/// Collapsed notification face: one line, read at a glance.
class NotificationCollapsed extends StatelessWidget {
  const NotificationCollapsed({super.key});

  @override
  Widget build(BuildContext context) {
    final AppServices services = AppScope.read(context);
    final IslandPalette palette = IslandTheme.of(context).palette;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DbSpace.md),
      child: AnimatedBuilder(
        animation: services.notifications,
        builder: (BuildContext context, _) {
          final IslandNotification? notification =
              services.notifications.current;
          if (notification == null) {
            return const SizedBox.shrink();
          }
          return Row(
            children: <Widget>[
              NotificationGlyph(
                kind: notification.kind,
                accent: notification.accent,
                size: 20,
              ),
              const SizedBox(width: DbSpace.md),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      notification.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: DbType.label.copyWith(color: palette.textPrimary),
                    ),
                    if (notification.body.isNotEmpty)
                      Text(
                        notification.body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: DbType.caption.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (services.notifications.pendingCount > 0) ...<Widget>[
                const SizedBox(width: DbSpace.sm),
                _PendingBadge(count: services.notifications.pendingCount),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Expanded notification face: the full message, plus a way to be rid of it.
class NotificationExpanded extends StatelessWidget {
  const NotificationExpanded({super.key});

  @override
  Widget build(BuildContext context) {
    final AppServices services = AppScope.read(context);
    final IslandPalette palette = IslandTheme.of(context).palette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DbSpace.xl,
        DbSpace.lg,
        DbSpace.xl,
        DbSpace.lg,
      ),
      child: AnimatedBuilder(
        animation: services.notifications,
        builder: (BuildContext context, _) {
          final IslandNotification? notification =
              services.notifications.current;
          if (notification == null) {
            return const SizedBox.shrink();
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: staggered(<Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  NotificationGlyph(
                    kind: notification.kind,
                    accent: notification.accent,
                    size: 30,
                  ),
                  const SizedBox(width: DbSpace.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          notification.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DbType.title.copyWith(
                            color: palette.textPrimary,
                          ),
                        ),
                        if (notification.body.isNotEmpty) ...<Widget>[
                          const SizedBox(height: DbSpace.xs),
                          Text(
                            notification.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: DbType.body.copyWith(
                              color: palette.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (notification.progress != null) ...<Widget>[
                const SizedBox(height: DbSpace.lg),
                IslandProgressBar(value: notification.progress),
              ],
              const Spacer(),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      services.notifications.pendingCount > 0
                          ? '${services.notifications.pendingCount} more waiting'
                          : '',
                      style: DbType.caption.copyWith(
                        color: palette.textTertiary,
                      ),
                    ),
                  ),
                  IslandButton(
                    icon: DbIcons.close,
                    label: 'Dismiss',
                    tooltip: 'Dismiss this notification',
                    onPressed: services.notifications.dismissCurrent,
                  ),
                ],
              ),
            ]),
          );
        },
      ),
    );
  }
}

class _PendingBadge extends StatelessWidget {
  const _PendingBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DbSpace.sm, vertical: 1),
      decoration: BoxDecoration(
        color: palette.surfaceSunken,
        borderRadius: BorderRadius.circular(DbRadius.pill),
      ),
      child: Text(
        '+$count',
        style: DbType.caption.copyWith(color: palette.textSecondary),
      ),
    );
  }
}
