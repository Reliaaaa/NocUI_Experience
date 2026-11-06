import 'package:flutter/widgets.dart';

import '../theme/island_theme.dart';
import 'morph_icon.dart';
import '../tokens/db_colors.dart';
import '../tokens/db_dimens.dart';
import '../tokens/db_motion.dart';
import '../tokens/db_typography.dart';

/// Visual weight of an island action.
enum IslandButtonTone { neutral, accent, danger }

/// A control on the island.
///
/// Uses [FocusableActionDetector] rather than a bare GestureDetector so the
/// button is reachable by keyboard, announces itself to assistive technology
/// and shows a real focus ring — the island is a floating surface with no
/// window chrome, so focus has to be visible or it is lost.
class IslandButton extends StatefulWidget {
  const IslandButton({
    required this.icon,
    required this.onPressed,
    this.label,
    this.tooltip,
    this.tone = IslandButtonTone.neutral,
    this.tint,
    this.size = DbSize.controlMd,
    this.autofocus = false,
    super.key,
  });

  final IconData icon;
  final String? label;
  final String? tooltip;
  final VoidCallback? onPressed;
  final IslandButtonTone tone;

  /// Replaces the theme accent for this one control. Only the media page uses
  /// it, to carry the colour taken from the album art into the play button;
  /// every other caller leaves it null and gets the accent the user chose.
  final Color? tint;

  final double size;
  final bool autofocus;

  @override
  State<IslandButton> createState() => _IslandButtonState();
}

class _IslandButtonState extends State<IslandButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: DbDuration.instant,
    reverseDuration: DbDuration.micro,
  );

  bool _hovered = false;
  bool _focused = false;

  bool get _enabled => widget.onPressed != null;

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _setPressed(bool pressed) {
    if (!_enabled) {
      return;
    }
    if (pressed) {
      _press.forward();
    } else {
      _press.reverse();
    }
  }

  void _activate() {
    if (!_enabled) {
      return;
    }
    widget.onPressed!.call();
  }

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);
    final IslandPalette palette = theme.palette;
    final bool hasLabel = widget.label != null && widget.label!.isNotEmpty;

    final Color accent = widget.tint ?? palette.accent;

    Color foreground;
    Color background;
    switch (widget.tone) {
      case IslandButtonTone.neutral:
        foreground = palette.textPrimary;
        background = palette.surfaceRaised;
      case IslandButtonTone.accent:
        foreground = accent;
        background = accent.withValues(alpha: 0.16);
      case IslandButtonTone.danger:
        foreground = palette.negative;
        background = palette.negative.withValues(alpha: 0.14);
    }
    if (!_enabled) {
      foreground = palette.textTertiary;
      background = palette.surfaceSunken;
    } else if (_hovered) {
      background = Color.alphaBlend(
        palette.textPrimary.withValues(alpha: 0.07),
        background,
      );
    }

    final Widget content = hasLabel
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              MorphIcon(
                icon: widget.icon,
                size: DbSize.iconSm,
                color: foreground,
              ),
              const SizedBox(width: DbSpace.sm),
              Text(
                widget.label!,
                style: DbType.label.copyWith(color: foreground),
              ),
            ],
          )
        : MorphIcon(icon: widget.icon, size: DbSize.iconMd, color: foreground);

    Widget button = AnimatedBuilder(
      animation: _press,
      builder: (BuildContext context, Widget? child) {
        // A shallow, quick squeeze. Anything deeper reads as a toy.
        final double scale = 1 - 0.045 * _press.value;
        return Transform.scale(scale: scale, child: child);
      },
      child: AnimatedContainer(
        duration: theme.motion.scale(DbDuration.micro),
        curve: DbCurve.standard,
        height: widget.size,
        padding: hasLabel
            ? const EdgeInsets.symmetric(horizontal: DbSpace.md)
            : EdgeInsets.zero,
        width: hasLabel ? null : widget.size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(DbRadius.control),
          border: Border.all(
            color: _focused
                ? accent
                : (_hovered ? palette.strokeStrong : palette.stroke),
            width: _focused ? 1.4 : DbSize.hairline,
          ),
        ),
        child: content,
      ),
    );

    if (widget.tooltip != null) {
      button = Semantics(
        label: widget.tooltip,
        button: true,
        enabled: _enabled,
        child: button,
      );
    }

    return FocusableActionDetector(
      enabled: _enabled,
      autofocus: widget.autofocus,
      mouseCursor: _enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onShowHoverHighlight: (bool value) {
        if (_hovered != value) {
          setState(() => _hovered = value);
        }
      },
      onShowFocusHighlight: (bool value) {
        if (_focused != value) {
          setState(() => _focused = value);
        }
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (ActivateIntent intent) {
            _activate();
            return null;
          },
        ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: _activate,
        child: button,
      ),
    );
  }
}
