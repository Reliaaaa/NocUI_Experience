import 'package:flutter/widgets.dart';

import '../../../app/app_services.dart';
import '../../../core/utils/formatters.dart';
import '../../../design/components/island_progress.dart';
import '../../../design/components/staggered_reveal.dart';
import '../../../design/theme/island_theme.dart';
import '../../../design/tokens/db_colors.dart';
import '../../../design/tokens/db_dimens.dart';
import '../../../design/tokens/db_icons.dart';
import '../../../design/tokens/db_typography.dart';
import '../../../modules/downloads/download_activity.dart';
import '../../../modules/downloads/downloads_controller.dart';

/// Collapsed download face: what is arriving, and how fast.
class DownloadCollapsed extends StatelessWidget {
  const DownloadCollapsed({super.key});

  @override
  Widget build(BuildContext context) {
    final DownloadsController downloads = AppScope.read(context).downloads;
    final IslandPalette palette = IslandTheme.of(context).palette;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DbSpace.lg),
      child: AnimatedBuilder(
        animation: downloads,
        builder: (BuildContext context, _) {
          final DownloadActivity? activity = downloads.primary;
          if (activity == null) {
            return const SizedBox.shrink();
          }
          final int count = downloads.active.length;
          return Row(
            children: <Widget>[
              Icon(
                DbIcons.download,
                size: DbSize.iconSm,
                color: palette.accent,
              ),
              const SizedBox(width: DbSpace.md),
              Expanded(
                child: Text(
                  count > 1
                      ? '$count downloads'
                      : Formatters.fileName(activity.name, maxLength: 20),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: DbType.label.copyWith(color: palette.textPrimary),
                ),
              ),
              const SizedBox(width: DbSpace.md),
              Text(
                Formatters.rate(downloads.totalRate),
                style: DbType.numeric.copyWith(color: palette.textSecondary),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Expanded download face: everything in flight, with what is actually known
/// about each transfer.
class DownloadExpanded extends StatelessWidget {
  const DownloadExpanded({super.key});

  /// The island is not a download manager; three rows is as much as fits
  /// without the text shrinking to unreadable.
  static const int maxRows = 3;

  @override
  Widget build(BuildContext context) {
    final DownloadsController downloads = AppScope.read(context).downloads;
    final IslandPalette palette = IslandTheme.of(context).palette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DbSpace.xl,
        DbSpace.lg,
        DbSpace.xl,
        DbSpace.lg,
      ),
      child: AnimatedBuilder(
        animation: downloads,
        builder: (BuildContext context, _) {
          final List<DownloadActivity> active = downloads.active;
          final List<DownloadActivity> rows = active.isNotEmpty
              ? active.take(maxRows).toList()
              : downloads.recent.take(maxRows).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: staggered(<Widget>[
              Row(
                children: <Widget>[
                  Text(
                    active.isNotEmpty ? 'DOWNLOADING' : 'RECENT DOWNLOADS',
                    style: DbType.overline.copyWith(
                      color: palette.textTertiary,
                    ),
                  ),
                  const Spacer(),
                  if (active.isNotEmpty)
                    Text(
                      Formatters.rate(downloads.totalRate),
                      style: DbType.numeric.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: DbSpace.md),
              if (rows.isEmpty)
                Text(
                  'Nothing recent',
                  style: DbType.body.copyWith(color: palette.textTertiary),
                )
              else
                for (final DownloadActivity activity in rows) ...<Widget>[
                  _DownloadRow(activity: activity),
                  const SizedBox(height: DbSpace.md),
                ],
              const Spacer(),
              if (active.length > maxRows)
                Text(
                  '${active.length - maxRows} more in progress',
                  style: DbType.caption.copyWith(color: palette.textTertiary),
                ),
            ]),
          );
        },
      ),
    );
  }
}

class _DownloadRow extends StatelessWidget {
  const _DownloadRow({required this.activity});

  final DownloadActivity activity;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;

    final Color statusColor;
    final String status;
    if (activity.isActive) {
      statusColor = palette.textSecondary;
      status =
          '${Formatters.bytes(activity.bytes)} · '
          '${Formatters.rate(activity.bytesPerSecond)}';
    } else if (activity.isComplete) {
      statusColor = palette.positive;
      status = 'Done · ${Formatters.bytes(activity.bytes)}';
    } else {
      statusColor = palette.negative;
      status = activity.outcome.name;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                Formatters.fileName(activity.name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DbType.body.copyWith(color: palette.textPrimary),
              ),
            ),
            const SizedBox(width: DbSpace.md),
            Text(status, style: DbType.caption.copyWith(color: statusColor)),
          ],
        ),
        if (activity.isActive) ...<Widget>[
          const SizedBox(height: DbSpace.sm),
          // A partial file does not carry its final size, so most transfers
          // show an indeterminate rail rather than an invented percentage.
          IslandProgressBar(value: activity.progress),
        ],
      ],
    );
  }
}
