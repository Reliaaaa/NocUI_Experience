import 'package:flutter/widgets.dart';

import '../../../app/app_services.dart';
import '../../../design/components/island_button.dart';
import '../../../design/theme/island_theme.dart';
import '../../../design/tokens/db_colors.dart';
import '../../../design/tokens/db_dimens.dart';
import '../../../design/tokens/db_icons.dart';
import '../../../design/tokens/db_typography.dart';
import '../../../modules/clipboard/clipboard_controller.dart';
import '../../../settings/app_settings.dart';
import 'page_scaffold.dart';

/// Shows only the last clipboard activity, never a stored clipboard history.
class ClipboardPage extends StatelessWidget {
  const ClipboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final services = AppScope.read(context);
    final IslandPalette palette = IslandTheme.of(context).palette;
    return AnimatedBuilder(
      animation: Listenable.merge([services.settings, services.clipboard]),
      builder: (context, _) {
        final bool enabled = services.settings.settings.clipboardEnabled;
        final ClipboardActivity? last = services.clipboard.last;
        return PageScaffold(
          title: 'Clipboard',
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(DbIcons.clipboard, size: 32, color: palette.textSecondary),
                const SizedBox(height: DbSpace.md),
                if (!enabled) ...[
                  Text('Clipboard monitoring is off',
                      style: DbType.title.copyWith(color: palette.textPrimary)),
                  const SizedBox(height: DbSpace.sm),
                  Text(services.settings.settings.clipboardPreviewEnabled
                          ? 'Enabling monitoring also enables your saved text preview preference.'
                          : 'Enable it to see the last copy event. Text previews are off.',
                      textAlign: TextAlign.center,
                      style: DbType.caption.copyWith(color: palette.textSecondary)),
                  const SizedBox(height: DbSpace.md),
                  IslandButton(
                    icon: DbIcons.power,
                    label: 'Enable clipboard',
                    tone: IslandButtonTone.accent,
                    onPressed: () => services.settings.mutate(
                      (AppSettings settings) => settings.copyWith(clipboardEnabled: true),
                    ),
                  ),
                ] else if (last == null) ...[
                  Text('No copy activity yet',
                      style: DbType.title.copyWith(color: palette.textPrimary)),
                  const SizedBox(height: DbSpace.sm),
                  Text('Only the latest copy event is shown.',
                      textAlign: TextAlign.center,
                      style: DbType.caption.copyWith(color: palette.textSecondary)),
                ] else ...[
                  Text('Last copy: ${last.kindLabel}',
                      style: DbType.title.copyWith(color: palette.textPrimary)),
                  const SizedBox(height: DbSpace.sm),
                  Text(!services.settings.settings.clipboardPreviewEnabled ||
                          !services.clipboard.isPreviewEnabled || last.preview.isEmpty
                          ? 'Text preview is off or unavailable.'
                          : last.preview,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: DbType.body.copyWith(color: palette.textSecondary)),
                  const SizedBox(height: DbSpace.sm),
                  Text('Only the latest event is kept in memory.',
                      style: DbType.caption.copyWith(color: palette.textTertiary)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
