import 'package:flutter/widgets.dart';

import '../../../design/theme/island_theme.dart';
import '../../../design/tokens/db_colors.dart';
import '../../../design/tokens/db_dimens.dart';
import '../../../design/tokens/db_motion.dart';

/// Page indicator, and the smallest usable page switcher.
///
/// The active dot stretches into a short bar rather than merely brightening:
/// at three pixels tall, a change of shape reads at a glance where a change of
/// opacity does not.
class PageDots extends StatelessWidget {
  const PageDots({
    required this.count,
    required this.index,
    this.onSelected,
    super.key,
  });

  final int count;
  final int index;
  final ValueChanged<int>? onSelected;

  @override
  Widget build(BuildContext context) {
    if (count < 2) {
      return const SizedBox.shrink();
    }
    final IslandThemeData theme = IslandTheme.of(context);
    final IslandPalette palette = theme.palette;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < count; i++)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onSelected == null ? null : () => onSelected!(i),
            child: MouseRegion(
              cursor: onSelected == null
                  ? MouseCursor.defer
                  : SystemMouseCursors.click,
              child: Padding(
                // The tap target is bigger than the mark, which is 3px tall.
                padding: const EdgeInsets.symmetric(
                  horizontal: 3,
                  vertical: DbSpace.sm,
                ),
                child: AnimatedContainer(
                  duration: theme.motion.scale(DbDuration.quick),
                  curve: DbCurve.emphasized,
                  width: i == index ? 14 : 4,
                  height: 3,
                  decoration: BoxDecoration(
                    color: i == index
                        ? palette.textSecondary
                        : palette.textTertiary.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(DbRadius.pill),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
