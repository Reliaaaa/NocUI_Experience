import 'package:flutter/widgets.dart';

import '../../../design/components/staggered_reveal.dart';
import '../../../design/theme/island_theme.dart';
import '../../../design/tokens/db_colors.dart';
import '../../../design/tokens/db_dimens.dart';
import '../../../design/tokens/db_typography.dart';

/// Common frame for every page of the pager.
///
/// One padding, one header shape, one reserved strip for the dots. Pages that
/// each invented their own margins would make swiping feel like the content was
/// sliding around inside the shape rather than the shape holding still.
class PageScaffold extends StatelessWidget {
  const PageScaffold({
    required this.child,
    this.title,
    this.trailing,
    // The bottom is deeper than the sides on purpose: the page dots live in
    // that strip, and content that ran into them would look like a bug rather
    // than like a layout.
    this.padding = const EdgeInsets.fromLTRB(
      DbSpace.xl,
      DbSpace.lg,
      DbSpace.xl,
      DbSpace.xxl,
    ),
    super.key,
  });

  /// Page label. Omitted by pages with their own header.
  final String? title;

  /// Actions that belong with the title.
  final Widget? trailing;

  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (title != null) ...<Widget>[
            Reveal(
              order: 0,
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      title!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DbType.title.copyWith(color: palette.textPrimary),
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
            const SizedBox(height: DbSpace.xs),
            Stack(
              children: <Widget>[
                Container(height: 1, color: palette.separator),
                Container(
                  height: 2,
                  width: 72,
                  decoration: BoxDecoration(
                    color: palette.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DbSpace.xs),
          ],
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// A one-line message for a page that has nothing to show yet.
class PageEmptyState extends StatelessWidget {
  const PageEmptyState({required this.message, this.hint, super.key});

  final String message;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            message,
            textAlign: TextAlign.center,
            style: DbType.body.copyWith(color: palette.textSecondary),
          ),
          if (hint != null) ...<Widget>[
            const SizedBox(height: DbSpace.xs),
            Text(
              hint!,
              textAlign: TextAlign.center,
              style: DbType.caption.copyWith(color: palette.textTertiary),
            ),
          ],
        ],
      ),
    );
  }
}
