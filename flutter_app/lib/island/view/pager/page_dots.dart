import 'package:flutter/widgets.dart';

import '../../../design/theme/island_theme.dart';
import '../../../design/tokens/db_colors.dart';
import '../../../design/tokens/db_dimens.dart';
import '../../../design/tokens/db_motion.dart';

/// Page indicator, and the smallest usable page switcher.
///
/// Designed after the macOS / Gili interactive navigation pill dock:
/// resting as understated minimal dots, gently surfacing a frosted glass
/// pill container on hover with interactive page indicators.
class PageDots extends StatefulWidget {
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
  State<PageDots> createState() => _PageDotsState();
}

class _PageDotsState extends State<PageDots> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    if (widget.count < 2) {
      return const SizedBox.shrink();
    }
    final IslandThemeData theme = IslandTheme.of(context);
    final IslandPalette palette = theme.palette;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: theme.motion.scale(DbDuration.quick),
        curve: DbCurve.standard,
        padding: EdgeInsets.symmetric(
          horizontal: _hovered ? 8 : 4,
          vertical: _hovered ? 3 : 2,
        ),
        decoration: BoxDecoration(
          color: _hovered
              ? (palette.isDark
                  ? const Color(0x1AFFFFFF)
                  : const Color(0x0F000000))
              : const Color(0x00000000),
          borderRadius: BorderRadius.circular(DbRadius.pill),
          border: Border.all(
            color: _hovered
                ? (palette.isDark
                    ? const Color(0x26FFFFFF)
                    : const Color(0x14000000))
                : const Color(0x00000000),
            width: DbSize.hairline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int i = 0; i < widget.count; i++)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onSelected == null
                    ? null
                    : () => widget.onSelected!(i),
                child: MouseRegion(
                  cursor: widget.onSelected == null
                      ? MouseCursor.defer
                      : SystemMouseCursors.click,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 3,
                      vertical: DbSpace.sm,
                    ),
                    child: AnimatedContainer(
                      duration: theme.motion.scale(DbDuration.quick),
                      curve: DbCurve.emphasized,
                      width: i == widget.index ? (_hovered ? 18 : 14) : (_hovered ? 5 : 4),
                      height: _hovered ? 4 : 3,
                      decoration: BoxDecoration(
                        color: i == widget.index
                            ? palette.accent
                            : palette.textTertiary.withValues(
                                alpha: _hovered ? 0.65 : 0.45,
                              ),
                        borderRadius: BorderRadius.circular(DbRadius.pill),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
