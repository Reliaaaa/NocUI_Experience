import 'package:flutter/widgets.dart';

import '../../../design/theme/island_theme.dart';
import '../../../design/tokens/db_colors.dart';
import '../../../design/tokens/db_dimens.dart';
import '../../../design/tokens/db_motion.dart';

/// Page indicator, and the smallest usable page switcher.
///
/// Uses one circular indicator per available page. Each indicator also acts
/// as a keyboard-accessible page selector.
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
              _PageDot(
                index: i,
                count: widget.count,
                selected: i == widget.index,
                hovered: _hovered,
                onTap: widget.onSelected == null
                    ? null
                    : () => widget.onSelected!(i),
              ),
          ],
        ),
      ),
    );
  }
}

class _PageDot extends StatefulWidget {
  const _PageDot({
    required this.index,
    required this.count,
    required this.selected,
    required this.hovered,
    required this.onTap,
  });

  final int index;
  final int count;
  final bool selected;
  final bool hovered;
  final VoidCallback? onTap;

  @override
  State<_PageDot> createState() => _PageDotState();
}

class _PageDotState extends State<_PageDot> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);
    final IslandPalette palette = theme.palette;
    return Semantics(
      button: true,
      enabled: widget.onTap != null,
      selected: widget.selected,
      label: 'Page ${widget.index + 1} of ${widget.count}',
      onTap: widget.onTap,
      child: FocusableActionDetector(
        enabled: widget.onTap != null,
        onShowFocusHighlight: (focused) => setState(() => _focused = focused),
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap?.call();
              return null;
            },
          ),
        },
        child: MouseRegion(
          cursor: widget.onTap == null
              ? MouseCursor.defer
              : SystemMouseCursors.click,
          child: GestureDetector(
            excludeFromSemantics: true,
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: SizedBox(
              width: 20,
              height: 22,
              child: Center(
                child: AnimatedContainer(
                  duration: theme.motion.scale(DbDuration.quick),
                  curve: DbCurve.emphasized,
                  width: widget.selected ? 7 : 5,
                  height: widget.selected ? 7 : 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.selected
                        ? palette.accent
                        : palette.textTertiary.withValues(
                            alpha: widget.hovered ? 0.8 : 0.55,
                          ),
                    border: _focused
                        ? Border.all(color: palette.textPrimary, width: 1)
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
