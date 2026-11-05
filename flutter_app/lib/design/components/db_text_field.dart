import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../theme/island_theme.dart';
import '../tokens/db_colors.dart';
import '../tokens/db_dimens.dart';
import '../tokens/db_motion.dart';
import '../tokens/db_typography.dart';

/// A text box for the island.
///
/// Built on [EditableText] rather than Material's `TextField` because this
/// application deliberately carries no Material theme: bringing one in for a
/// single control would drag an entire design system's colours, ripples and
/// text selection styling into a surface that has its own.
///
/// Selection handles are off. They are a touch affordance, and this is a
/// keyboard-and-mouse overlay a few hundred pixels tall.
class DbTextField extends StatefulWidget {
  const DbTextField({
    required this.controller,
    this.focusNode,
    this.placeholder = '',
    this.maxLines = 1,
    this.minLines = 1,
    this.autofocus = false,
    this.onSubmitted,
    this.onChanged,
    this.textStyle,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String placeholder;
  final int maxLines;
  final int minLines;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final TextStyle? textStyle;

  @override
  State<DbTextField> createState() => _DbTextFieldState();
}

class _DbTextFieldState extends State<DbTextField> {
  FocusNode? _owned;
  bool _focused = false;

  FocusNode get _node => widget.focusNode ?? (_owned ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _node.addListener(_onFocusChanged);
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _node.removeListener(_onFocusChanged);
    widget.controller.removeListener(_onTextChanged);
    _owned?.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted && _focused != _node.hasFocus) {
      setState(() => _focused = _node.hasFocus);
    }
  }

  /// Only to keep the placeholder in step; the value itself is the caller's.
  void _onTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);
    final IslandPalette palette = theme.palette;
    final TextStyle style = (widget.textStyle ?? DbType.body).copyWith(
      color: palette.textPrimary,
    );

    return AnimatedContainer(
      duration: theme.motion.scale(DbDuration.micro),
      curve: DbCurve.standard,
      padding: const EdgeInsets.symmetric(
        horizontal: DbSpace.md,
        vertical: DbSpace.sm,
      ),
      decoration: BoxDecoration(
        color: palette.surfaceSunken,
        borderRadius: BorderRadius.circular(DbRadius.control),
        border: Border.all(
          color: _focused ? palette.accent : palette.stroke,
        ),
      ),
      child: Stack(
        children: <Widget>[
          if (widget.controller.text.isEmpty)
            Positioned.fill(
              child: Align(
                alignment: Alignment.topLeft,
                child: Text(
                  widget.placeholder,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style.copyWith(color: palette.textTertiary),
                ),
              ),
            ),
          EditableText(
            controller: widget.controller,
            focusNode: _node,
            style: style,
            cursorColor: palette.accent,
            backgroundCursorColor: palette.textTertiary,
            selectionColor: palette.accent.withValues(alpha: 0.32),
            cursorWidth: 1.5,
            cursorRadius: const Radius.circular(1),
            maxLines: widget.maxLines,
            minLines: widget.minLines,
            autofocus: widget.autofocus,
            textInputAction: widget.maxLines > 1
                ? TextInputAction.newline
                : TextInputAction.done,
            keyboardType: widget.maxLines > 1
                ? TextInputType.multiline
                : TextInputType.text,
            onSubmitted: widget.onSubmitted,
            onChanged: widget.onChanged,
            rendererIgnoresPointer: false,
            enableInteractiveSelection: true,
            selectionControls: null,
          ),
        ],
      ),
    );
  }
}
