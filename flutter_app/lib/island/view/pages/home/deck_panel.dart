import 'package:flutter/widgets.dart';

import '../../../../design/theme/island_theme.dart';
import '../../../../design/tokens/db_colors.dart';
import '../../../../design/tokens/db_dimens.dart';
import '../../../../design/tokens/db_motion.dart';
import '../../../../design/tokens/db_typography.dart';

/// One of the four panels under the clock.
///
/// A panel has two faces and shows whichever the pointer has asked for. The
/// summary is what it looks like at rest - a glyph, a number, a word - and the
/// detail is what it becomes when the cursor arrives. Nothing is clicked to get
/// there: hovering is the whole gesture, which is what makes a row of four of
/// these faster than any menu.
///
/// Both faces are laid out at a *fixed* width - the summary at the panel's
/// resting width, the detail at its open width - and only the frame between
/// them animates. That is the difference between content that morphs and
/// content that reflows: no line ever re-wraps mid-animation, and no icon ever
/// slides sideways because its neighbour got shorter.
class DeckPanel extends StatelessWidget {
  const DeckPanel({
    required this.progress,
    required this.width,
    required this.expandedWidth,
    required this.summary,
    required this.detail,
    this.compact = false,
    super.key,
  });

  /// 0 at rest, 1 fully open.
  final double progress;

  /// The live width, driven by the deck so that the four always add up to the
  /// space available.
  final double width;

  /// Width the detail face is laid out at. The summary takes whatever the
  /// frame currently is - it is one glyph and two short lines, so it narrows
  /// gracefully - while the detail is pinned, because a six-button grid that
  /// reflowed mid-animation would look like a bug.
  final double expandedWidth;

  final Widget summary;
  final Widget detail;

  /// True when the island is scaled down far enough that the deck had to give
  /// height back to the agenda above it. Panels tighten rather than clip.
  final bool compact;

  /// The summary is gone well before the detail arrives, so the two never
  /// overlap into mud.
  static double summaryOpacity(double t) => (1 - t * 2.6).clamp(0.0, 1.0);

  static double detailOpacity(double t) =>
      ((t - 0.36) / 0.46).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);
    final IslandPalette palette = theme.palette;
    final double t = progress.clamp(0.0, 1.0);

    final double summaryFade = summaryOpacity(t);
    final double detailFade = detailOpacity(t);

    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color.lerp(
            palette.surfaceSunken,
            palette.surfaceRaised,
            t,
          ),
          borderRadius: BorderRadius.circular(DbRadius.card),
          border: Border.all(
            color: Color.lerp(palette.stroke, palette.strokeStrong, t)!,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(DbRadius.card),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (summaryFade > 0.004)
                _Face(
                  opacity: summaryFade,
                  ignoring: t > 0.5,
                  compact: compact,
                  child: summary,
                ),
              if (detailFade > 0.004)
                _Face(
                  width: expandedWidth,
                  opacity: detailFade,
                  ignoring: t < 0.5,
                  compact: compact,
                  child: detail,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One face, pinned to its own width regardless of the frame around it.
class _Face extends StatelessWidget {
  const _Face({
    required this.opacity,
    required this.ignoring,
    required this.child,
    this.width,
    this.compact = false,
  });

  /// Null lays the face out in whatever the frame currently is.
  final double? width;
  final double opacity;
  final bool ignoring;
  final bool compact;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Widget face = Opacity(
      opacity: opacity,
      child: IgnorePointer(
        ignoring: ignoring,
        child: Padding(
          padding: EdgeInsets.all(compact ? DbSpace.sm + 2 : DbSpace.md),
          child: child,
        ),
      ),
    );
    final double? pinned = width;
    if (pinned == null) {
      return face;
    }
    return OverflowBox(
      alignment: Alignment.centerLeft,
      minWidth: pinned,
      maxWidth: pinned,
      child: face,
    );
  }
}

/// The resting face of a panel: a glyph, the one fact worth reading at a
/// glance, and a quieter line under it.
class PanelSummary extends StatelessWidget {
  const PanelSummary({
    required this.icon,
    required this.title,
    this.subtitle,
    this.footer,
    this.tint,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Replaces [subtitle] when a panel has something better to show than words.
  final Widget? footer;

  /// Colours the glyph when the panel has something to say - a warning, a
  /// connection, a running state.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: DbSize.iconMd, color: tint ?? palette.textSecondary),
        const Spacer(),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: DbType.title.copyWith(
            color: palette.textPrimary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: DbSpace.xxs),
        if (footer != null)
          footer!
        else
          Text(
            subtitle ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: DbType.caption.copyWith(color: palette.textTertiary),
          ),
      ],
    );
  }
}

/// The small caps line at the top of an open panel, with room for one control.
class PanelHeader extends StatelessWidget {
  const PanelHeader({required this.label, this.trailing, super.key});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    return SizedBox(
      height: 16,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: DbType.overline.copyWith(color: palette.textTertiary),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A small square control for the inside of a panel, where [IslandButton] at
/// its smallest is still too heavy a shape.
class PanelIconButton extends StatefulWidget {
  const PanelIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 16,
    this.tint,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;
  final Color? tint;

  @override
  State<PanelIconButton> createState() => _PanelIconButtonState();
}

class _PanelIconButtonState extends State<PanelIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);
    final IslandPalette palette = theme.palette;
    final bool enabled = widget.onPressed != null;
    final Color color = !enabled
        ? palette.textTertiary
        : (_hovered ? palette.textPrimary : (widget.tint ?? palette.textSecondary));

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.tooltip,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: theme.motion.scale(DbDuration.micro),
            curve: DbCurve.standard,
            width: widget.size,
            height: widget.size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _hovered && enabled
                  ? palette.surfaceSunken
                  : const Color(0x00000000),
              borderRadius: BorderRadius.circular(DbRadius.control),
            ),
            child: Icon(widget.icon, size: 12, color: color),
          ),
        ),
      ),
    );
  }
}

/// A row inside an open panel: glyph, label, and whatever belongs on the right.
///
/// Used by the power and connectivity panels, which are both lists of things
/// that happen when you click them.
class PanelRow extends StatefulWidget {
  const PanelRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.detail,
    this.trailing,
    this.tone,
    this.height = 22,
    super.key,
  });

  final IconData icon;
  final String label;

  /// Quieter text after the label, when there is something to add.
  final String? detail;
  final Widget? trailing;
  final Color? tone;
  final double height;
  final VoidCallback? onTap;

  @override
  State<PanelRow> createState() => _PanelRowState();
}

class _PanelRowState extends State<PanelRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);
    final IslandPalette palette = theme.palette;
    final bool enabled = widget.onTap != null;
    final Color tint = widget.tone ?? palette.textSecondary;

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: theme.motion.scale(DbDuration.micro),
          curve: DbCurve.standard,
          height: widget.height,
          padding: const EdgeInsets.symmetric(horizontal: DbSpace.xs),
          decoration: BoxDecoration(
            color: _hovered && enabled
                ? palette.surfaceSunken
                : const Color(0x00000000),
            borderRadius: BorderRadius.circular(DbRadius.control),
          ),
          child: Row(
            children: <Widget>[
              Icon(widget.icon, size: 12, color: tint),
              const SizedBox(width: DbSpace.sm),
              // The label is the message, so it is served first; a detail
              // beside it gets whatever is left and gives way before the
              // label does.
              Flexible(
                flex: 3,
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: DbType.caption.copyWith(
                    color: widget.tone ?? palette.textPrimary,
                  ),
                ),
              ),
              if (widget.detail != null) ...<Widget>[
                const SizedBox(width: DbSpace.xs),
                Flexible(
                  child: Text(
                    widget.detail!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: DbType.caption.copyWith(
                      color: palette.textTertiary,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              ?widget.trailing,
            ],
          ),
        ),
      ),
    );
  }
}
