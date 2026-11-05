import 'package:flutter/widgets.dart';

import '../../../app/app_services.dart';
import '../../../design/components/island_button.dart';
import '../../../design/theme/island_theme.dart';
import '../../../design/tokens/db_colors.dart';
import '../../../design/tokens/db_dimens.dart';
import '../../../design/tokens/db_icons.dart';
import '../../../design/tokens/db_motion.dart';
import '../../../design/tokens/db_typography.dart';
import '../../../settings/app_settings.dart';

/// A one-time explanation of how to use the island.
///
/// An overlay with no title bar, no menu and no icon in the taskbar is close to
/// undiscoverable: nothing on screen says that it opens, that it has pages, or
/// how to get it back once hidden. This says all three, once, and then never
/// again.
class IntroBanner extends StatelessWidget {
  const IntroBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final AppServices services = AppScope.read(context);
    final IslandThemeData theme = IslandTheme.of(context);
    final IslandPalette palette = theme.palette;

    return AnimatedBuilder(
      animation: services.settings,
      builder: (BuildContext context, _) {
        final bool seen = services.settings.settings.introSeen;
        return AnimatedSize(
          duration: theme.motion.scale(DbDuration.standard),
          curve: DbCurve.emphasized,
          alignment: Alignment.topCenter,
          child: seen
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(bottom: DbSpace.md),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: palette.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(DbRadius.card),
                      border: Border.all(
                        color: palette.accent.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        DbSpace.md,
                        DbSpace.sm,
                        DbSpace.sm,
                        DbSpace.sm,
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            DbIcons.chevronRight,
                            size: DbSize.iconSm,
                            color: palette.accent,
                          ),
                          const SizedBox(width: DbSpace.sm),
                          Expanded(
                            child: Text(
                              'Arrow keys, scroll or the dots move between '
                              'pages. Ctrl + Alt + Space opens this anywhere.',
                              style: DbType.caption
                                  .copyWith(color: palette.textSecondary),
                            ),
                          ),
                          const SizedBox(width: DbSpace.sm),
                          IslandButton(
                            icon: DbIcons.check,
                            label: 'Got it',
                            tooltip: 'Do not show this again',
                            onPressed: () => services.settings.mutate(
                              (AppSettings s) => s.copyWith(introSeen: true),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}
