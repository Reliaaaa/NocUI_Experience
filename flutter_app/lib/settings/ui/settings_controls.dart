import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../design/theme/island_theme.dart';
import '../../design/tokens/db_colors.dart';
import '../../design/tokens/db_dimens.dart';
import '../../design/tokens/db_motion.dart';
import '../../design/tokens/db_typography.dart';
import '../../native/hotkey_bridge.dart';

/// A titled group of settings.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    required this.title,
    required this.children,
    this.description,
    super.key,
  });

  final String title;
  final String? description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          title.toUpperCase(),
          style: DbType.overline.copyWith(color: palette.textTertiary),
        ),
        if (description != null) ...<Widget>[
          const SizedBox(height: DbSpace.xs),
          Text(
            description!,
            style: DbType.caption.copyWith(color: palette.textTertiary),
          ),
        ],
        const SizedBox(height: DbSpace.md),
        DecoratedBox(
          decoration: BoxDecoration(
            color: palette.surfaceRaised,
            borderRadius: BorderRadius.circular(DbRadius.card),
            border: Border.all(color: palette.stroke),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (int i = 0; i < children.length; i++) ...<Widget>[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: DbSpace.lg),
                    child: Container(height: 1, color: palette.separator),
                  ),
                children[i],
              ],
            ],
          ),
        ),
        const SizedBox(height: DbSpace.xl),
      ],
    );
  }
}

/// One labelled row inside a [SettingsSection].
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    required this.label,
    required this.control,
    this.description,
    super.key,
  });

  final String label;
  final String? description;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DbSpace.lg,
        vertical: DbSpace.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  label,
                  style: DbType.body.copyWith(color: palette.textPrimary),
                ),
                if (description != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    description!,
                    style: DbType.caption.copyWith(color: palette.textTertiary),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: DbSpace.lg),
          control,
        ],
      ),
    );
  }
}

/// A switch, sized and weighted for a dense settings surface.
class DbSwitch extends StatelessWidget {
  const DbSwitch({required this.value, required this.onChanged, super.key});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);
    final IslandPalette palette = theme.palette;
    final bool enabled = onChanged != null;

    return Semantics(
      toggled: value,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => onChanged!(!value) : null,
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: AnimatedContainer(
            duration: theme.motion.scale(DbDuration.micro),
            curve: DbCurve.standard,
            width: 38,
            height: 22,
            padding: const EdgeInsets.all(3),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            decoration: BoxDecoration(
              color: value
                  ? palette.accent.withValues(alpha: enabled ? 0.9 : 0.4)
                  : palette.surfaceSunken,
              borderRadius: BorderRadius.circular(DbRadius.pill),
              border: Border.all(
                color: value ? const Color(0x00000000) : palette.stroke,
              ),
            ),
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: value
                    ? (palette.isDark
                          ? const Color(0xFF0B0C0F)
                          : const Color(0xFFFFFFFF))
                    : palette.textSecondary,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A horizontal slider with an editable value in the displayed unit.
class DbSlider extends StatefulWidget {
  const DbSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.label,
    this.width = 168,
    this.displayFactor = 1,
    this.unit = '',
    this.semanticLabel = 'Setting',
    super.key,
  });

  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final String? label;
  final double width;
  final double displayFactor;
  final String unit;
  final String semanticLabel;

  @override
  State<DbSlider> createState() => _DbSliderState();
}

class _DbSliderState extends State<DbSlider> {
  late final TextEditingController _controller;
  final FocusNode _focus = FocusNode();

  String _format(double value) {
    final String formatted = (value * widget.displayFactor).toStringAsFixed(2);
    return formatted.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _format(widget.value));
    _focus.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(DbSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && (oldWidget.value != widget.value ||
        oldWidget.displayFactor != widget.displayFactor)) {
      _controller.text = _format(widget.value);
    }
  }

  void _onFocusChanged() {
    if (!_focus.hasFocus) _commit();
    if (mounted) setState(() {});
  }

  void _commit() {
    final double? input = double.tryParse(_controller.text.trim().replaceAll(',', '.'));
    if (input == null || !input.isFinite) {
      _controller.text = _format(widget.value);
      return;
    }
    final double next = (input / widget.displayFactor).clamp(widget.min, widget.max).toDouble();
    _controller.text = _format(next);
    widget.onChanged(next);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChanged);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  double get _fraction =>
      ((widget.value - widget.min) / (widget.max - widget.min)).clamp(0.0, 1.0).toDouble();

  void _updateFromLocal(double dx, double trackWidth) {
    if (_focus.hasFocus) _focus.unfocus();
    final double fraction = (dx / trackWidth).clamp(0.0, 1.0).toDouble();
    widget.onChanged(widget.min + fraction * (widget.max - widget.min));
  }

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Semantics(
          label: '${widget.semanticLabel}, enter value${widget.unit.isEmpty ? '' : ' in ${widget.unit}'}, '
              'range ${_format(widget.min)} to ${_format(widget.max)}',
          textField: true,
          child: Container(
            width: 68,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: palette.surfaceSunken,
              borderRadius: BorderRadius.circular(DbRadius.control),
              border: Border.all(color: _focus.hasFocus ? palette.accent : palette.stroke),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: EditableText(
                    controller: _controller,
                    focusNode: _focus,
                    style: DbType.numeric.copyWith(color: palette.textPrimary),
                    cursorColor: palette.accent,
                    backgroundCursorColor: palette.textTertiary,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    textInputAction: TextInputAction.done,
                    maxLines: 1,
                    onSubmitted: (_) => _focus.unfocus(),
                  ),
                ),
                if (widget.unit.isNotEmpty)
                  Text(widget.unit, style: DbType.caption.copyWith(color: palette.textSecondary)),
              ],
            ),
          ),
        ),
        const SizedBox(width: DbSpace.md),
        SizedBox(
          width: widget.width,
          height: 22,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (TapDownDetails details) =>
                _updateFromLocal(details.localPosition.dx, widget.width),
            onHorizontalDragUpdate: (DragUpdateDetails details) =>
                _updateFromLocal(details.localPosition.dx, widget.width),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: <Widget>[
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: palette.surfaceSunken,
                      borderRadius: BorderRadius.circular(DbRadius.pill),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: _fraction,
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: palette.accent,
                        borderRadius: BorderRadius.circular(DbRadius.pill),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment(_fraction * 2 - 1, 0),
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: palette.textPrimary,
                        shape: BoxShape.circle,
                        border: Border.all(color: palette.stroke),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A small segmented control for two to four mutually exclusive choices.
class DbSegmented<T> extends StatelessWidget {
  const DbSegmented({
    required this.value,
    required this.options,
    required this.onChanged,
    super.key,
  });

  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);
    final IslandPalette palette = theme.palette;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surfaceSunken,
        borderRadius: BorderRadius.circular(DbRadius.control),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final MapEntry<T, String> entry in options.entries)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(entry.key),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: AnimatedContainer(
                  duration: theme.motion.scale(DbDuration.micro),
                  curve: DbCurve.standard,
                  padding: const EdgeInsets.symmetric(
                    horizontal: DbSpace.md,
                    vertical: DbSpace.sm,
                  ),
                  decoration: BoxDecoration(
                    color: entry.key == value
                        ? palette.surfaceRaised
                        : const Color(0x00000000),
                    borderRadius: BorderRadius.circular(DbRadius.control),
                    border: Border.all(
                      color: entry.key == value
                          ? palette.stroke
                          : const Color(0x00000000),
                    ),
                  ),
                  child: Text(
                    entry.value,
                    style: DbType.label.copyWith(
                      color: entry.key == value
                          ? palette.textPrimary
                          : palette.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Accent swatches.
class DbSwatches extends StatelessWidget {
  const DbSwatches({
    required this.value,
    required this.options,
    required this.onChanged,
    super.key,
  });

  final AccentPreset value;
  final List<AccentPreset> options;
  final ValueChanged<AccentPreset> onChanged;

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);
    final IslandPalette palette = theme.palette;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final AccentPreset preset in options)
          Padding(
            padding: const EdgeInsets.only(left: DbSpace.sm),
            child: Semantics(
              label: preset.label,
              selected: preset == value,
              child: GestureDetector(
                onTap: () => onChanged(preset),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: AnimatedContainer(
                    duration: theme.motion.scale(DbDuration.micro),
                    curve: DbCurve.standard,
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: preset.color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: preset == value
                            ? palette.textPrimary
                            : palette.stroke,
                        width: preset == value ? 2 : 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A single-choice list, used where a segmented control would not fit: the
/// monitor picker.
class DbChoiceList<T> extends StatelessWidget {
  const DbChoiceList({
    required this.value,
    required this.options,
    required this.onChanged,
    super.key,
  });

  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final MapEntry<T, String> entry in options.entries)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(entry.key),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: DbSpace.sm),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: entry.key == value
                              ? palette.accent
                              : palette.stroke,
                          width: entry.key == value ? 4 : 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: DbSpace.md),
                    Expanded(
                      child: Text(
                        entry.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DbType.body.copyWith(color: palette.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A shortcut recorder.
///
/// Captures the next chord the user presses while focused. Modifier-only
/// presses are ignored: a global shortcut without a real key would swallow the
/// modifier for every other application on the machine.
class DbShortcutField extends StatefulWidget {
  const DbShortcutField({
    required this.value,
    required this.onChanged,
    this.conflict = false,
    super.key,
  });

  final String value;
  final ValueChanged<String> onChanged;

  /// Set when Windows refused the registration because something else owns it.
  final bool conflict;

  @override
  State<DbShortcutField> createState() => _DbShortcutFieldState();
}

class _DbShortcutFieldState extends State<DbShortcutField> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'Shortcut recorder');
  bool _recording = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!_recording || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      setState(() => _recording = false);
      _focusNode.unfocus();
      return KeyEventResult.handled;
    }

    final int keyCode = HotkeyCodes.fromLogicalKey(event.logicalKey);
    if (keyCode == 0) {
      // A modifier on its own; keep listening for the real key.
      return KeyEventResult.handled;
    }

    final Set<LogicalKeyboardKey> pressed =
        HardwareKeyboard.instance.logicalKeysPressed;
    var modifiers = 0;
    if (pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight)) {
      modifiers |= HotkeyModifiers.control;
    }
    if (pressed.contains(LogicalKeyboardKey.altLeft) ||
        pressed.contains(LogicalKeyboardKey.altRight)) {
      modifiers |= HotkeyModifiers.alt;
    }
    if (pressed.contains(LogicalKeyboardKey.shiftLeft) ||
        pressed.contains(LogicalKeyboardKey.shiftRight)) {
      modifiers |= HotkeyModifiers.shift;
    }
    if (pressed.contains(LogicalKeyboardKey.metaLeft) ||
        pressed.contains(LogicalKeyboardKey.metaRight)) {
      modifiers |= HotkeyModifiers.win;
    }

    if (modifiers == 0) {
      // An unmodified global shortcut would take that key away from every
      // other application.
      return KeyEventResult.handled;
    }

    final HotkeyBinding binding = HotkeyBinding(
      id: 'recorded',
      modifiers: modifiers,
      keyCode: keyCode,
    );
    widget.onChanged(binding.encode());
    setState(() => _recording = false);
    _focusNode.unfocus();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    final bool empty = widget.value.trim().isEmpty;

    final Color border = _recording
        ? palette.accent
        : (widget.conflict ? palette.negative : palette.stroke);

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _onKey,
      onFocusChange: (bool focused) {
        if (!focused && _recording) {
          setState(() => _recording = false);
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() => _recording = true);
              _focusNode.requestFocus();
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                width: 168,
                padding: const EdgeInsets.symmetric(
                  horizontal: DbSpace.md,
                  vertical: DbSpace.sm,
                ),
                decoration: BoxDecoration(
                  color: palette.surfaceSunken,
                  borderRadius: BorderRadius.circular(DbRadius.control),
                  border: Border.all(color: border),
                ),
                child: Text(
                  _recording
                      ? 'Press a shortcut…'
                      : (empty ? 'Not set' : widget.value),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DbType.label.copyWith(
                    color: _recording
                        ? palette.accent
                        : (empty ? palette.textTertiary : palette.textPrimary),
                  ),
                ),
              ),
            ),
          ),
          if (!empty) ...<Widget>[
            const SizedBox(width: DbSpace.sm),
            GestureDetector(
              onTap: () => widget.onChanged(''),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Text(
                  'Clear',
                  style: DbType.caption.copyWith(color: palette.textTertiary),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
