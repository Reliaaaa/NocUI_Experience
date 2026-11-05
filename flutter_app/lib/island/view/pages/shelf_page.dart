import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../app/app_services.dart';
import '../../../design/components/db_text_field.dart';
import '../../../design/components/island_button.dart';
import '../../../design/components/staggered_reveal.dart';
import '../../../design/theme/island_theme.dart';
import '../../../design/tokens/db_colors.dart';
import '../../../design/tokens/db_dimens.dart';
import '../../../design/tokens/db_icons.dart';
import '../../../design/tokens/db_motion.dart';
import '../../../design/tokens/db_typography.dart';
import '../../../modules/notifications/island_notification.dart';
import '../../../modules/shelf/shelf_controller.dart';
import 'page_scaffold.dart';

/// Somewhere to put something down for a minute.
///
/// Two image slots and one note, and no more. An unbounded shelf turns into a
/// second file manager that nobody ever tidies; a fixed pair of slots stays a
/// scratch space, which is the thing that was actually missing. Everything on
/// it is a real file under the application's own folder, so it survives a
/// restart and can be opened with any other program.
class ShelfPage extends StatefulWidget {
  const ShelfPage({super.key});

  @override
  State<ShelfPage> createState() => _ShelfPageState();
}

class _ShelfPageState extends State<ShelfPage> {
  final TextEditingController _text = TextEditingController();
  ShelfController? _shelf;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ShelfController shelf = AppScope.read(context).shelf;
    if (identical(_shelf, shelf)) {
      return;
    }
    _shelf = shelf;
    // The field is seeded once from the store; after that the field is the
    // source of truth while this page is on screen.
    _text.text = shelf.text;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _say(String message) {
    AppScope.read(context).notifications.post(
      IslandNotification(
        id: 'shelf.message',
        title: message,
        kind: NotificationKind.info,
        lifetime: const Duration(milliseconds: 1800),
      ),
    );
  }

  Future<void> _pasteImage(int slot) async {
    final bool ok = await _shelf!.pasteImage(slot);
    if (!ok && mounted) {
      _say('No image on the clipboard');
    }
  }

  Future<void> _pasteText() async {
    final bool ok = await _shelf!.pasteText();
    if (!mounted) {
      return;
    }
    if (ok) {
      _text.text = _shelf!.text;
    } else {
      _say('No text on the clipboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppServices services = AppScope.read(context);
    final ShelfController shelf = services.shelf;

    return AnimatedBuilder(
      animation: shelf,
      builder: (BuildContext context, _) {
        return PageScaffold(
          title: 'Shelf',
          trailing: IslandButton(
            icon: DbIcons.delete,
            tooltip: 'Empty the shelf',
            tone: IslandButtonTone.danger,
            onPressed: shelf.isEmpty
                ? null
                : () {
                    _text.clear();
                    unawaited(shelf.clearAll());
                  },
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: Reveal(
                  order: 1,
                  scaleFrom: 0.97,
                  child: Row(
                    children: <Widget>[
                      for (int slot = 0; slot < ShelfController.slots; slot++)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: slot == 0 ? DbSpace.sm : 0,
                            ),
                            child: _Slot(
                              image: shelf.imageAt(slot),
                              revision: shelf.revision,
                              highlighted: shelf.isDragging,
                              onPaste: () => _pasteImage(slot),
                              onCopy: () async {
                                final bool ok = await shelf.copyImage(slot);
                                if (mounted) {
                                  _say(ok ? 'Copied' : 'Could not copy');
                                }
                              },
                              onOpen: () => unawaited(
                                services.shell.open(shelf.imageAt(slot)!.path),
                              ),
                              onClear: () =>
                                  unawaited(shelf.clearImage(slot)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: DbSpace.md),
              Reveal(
                order: 2,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: DbTextField(
                        controller: _text,
                        placeholder: 'Anything worth keeping for a minute…',
                        maxLines: 2,
                        minLines: 2,
                        onChanged: shelf.setText,
                      ),
                    ),
                    const SizedBox(width: DbSpace.sm),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        IslandButton(
                          icon: DbIcons.clipboard,
                          tooltip: 'Paste from the clipboard',
                          size: DbSize.controlSm,
                          onPressed: _pasteText,
                        ),
                        const SizedBox(height: DbSpace.xs),
                        IslandButton(
                          icon: DbIcons.copy,
                          tooltip: 'Copy this text',
                          size: DbSize.controlSm,
                          onPressed: shelf.text.trim().isEmpty
                              ? null
                              : () {
                                  unawaited(shelf.copyText());
                                  _say('Copied');
                                },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// One image slot: a thumbnail with actions, or an invitation to fill it.
class _Slot extends StatefulWidget {
  const _Slot({
    required this.image,
    required this.revision,
    required this.highlighted,
    required this.onPaste,
    required this.onCopy,
    required this.onOpen,
    required this.onClear,
  });

  final ShelfImage? image;
  final int revision;

  /// True while something is being dragged over the island, so the slots say
  /// where it can land before the pointer gets there.
  final bool highlighted;

  final VoidCallback onPaste;
  final VoidCallback onCopy;
  final VoidCallback onOpen;
  final VoidCallback onClear;

  @override
  State<_Slot> createState() => _SlotState();
}

class _SlotState extends State<_Slot> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);
    final IslandPalette palette = theme.palette;
    final ShelfImage? image = widget.image;

    return MouseRegion(
      cursor: image == null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: image == null ? widget.onPaste : null,
        child: AnimatedContainer(
          duration: theme.motion.scale(DbDuration.micro),
          curve: DbCurve.standard,
          decoration: BoxDecoration(
            color: widget.highlighted
                ? palette.accent.withValues(alpha: 0.10)
                : palette.surfaceSunken,
            borderRadius: BorderRadius.circular(DbRadius.card),
            border: Border.all(
              color: widget.highlighted
                  ? palette.accent
                  : (_hovered ? palette.strokeStrong : palette.stroke),
              width: widget.highlighted ? 1.5 : DbSize.hairline,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: image == null
              ? _Empty(hovered: _hovered || widget.highlighted)
              : Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    Image.file(
                      image.file,
                      // Keyed on the revision so replacing the file at the same
                      // path actually shows the new picture.
                      key: ValueKey<String>('${image.path}#${widget.revision}'),
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                      errorBuilder:
                          (BuildContext context, Object error, StackTrace? s) =>
                              const _Empty(hovered: false),
                    ),
                    // A scrim under the controls, so buttons stay legible over
                    // a bright screenshot.
                    AnimatedOpacity(
                      opacity: _hovered ? 1 : 0,
                      duration: theme.motion.scale(DbDuration.quick),
                      curve: DbCurve.standard,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[
                              palette.shadow.withValues(alpha: 0.0),
                              palette.shadow.withValues(alpha: 0.72),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: DbSpace.sm,
                      child: AnimatedSlide(
                        offset: Offset(0, _hovered ? 0 : 0.6),
                        duration: theme.motion.scale(DbDuration.quick),
                        curve: DbCurve.emphasized,
                        child: AnimatedOpacity(
                          opacity: _hovered ? 1 : 0,
                          duration: theme.motion.scale(DbDuration.quick),
                          curve: DbCurve.standard,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              IslandButton(
                                icon: DbIcons.copy,
                                tooltip: 'Copy the image',
                                size: DbSize.controlSm,
                                onPressed: widget.onCopy,
                              ),
                              const SizedBox(width: DbSpace.xs),
                              IslandButton(
                                icon: DbIcons.open,
                                tooltip: 'Open the file',
                                size: DbSize.controlSm,
                                onPressed: widget.onOpen,
                              ),
                              const SizedBox(width: DbSpace.xs),
                              IslandButton(
                                icon: DbIcons.clipboard,
                                tooltip: 'Replace with the clipboard',
                                size: DbSize.controlSm,
                                onPressed: widget.onPaste,
                              ),
                              const SizedBox(width: DbSpace.xs),
                              IslandButton(
                                icon: DbIcons.delete,
                                tooltip: 'Remove',
                                tone: IslandButtonTone.danger,
                                size: DbSize.controlSm,
                                onPressed: widget.onClear,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: DbSpace.sm,
                      top: DbSpace.sm,
                      child: AnimatedOpacity(
                        opacity: _hovered ? 1 : 0,
                        duration: theme.motion.scale(DbDuration.quick),
                        curve: DbCurve.standard,
                        child: Text(
                          '${image.width} × ${image.height}',
                          style: DbType.caption.copyWith(
                            color: palette.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.hovered});

  final bool hovered;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    final Color tint = hovered ? palette.accent : palette.textTertiary;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(DbIcons.image, size: DbSize.iconLg, color: tint),
          const SizedBox(height: DbSpace.xs),
          Text(
            'Paste or drop an image',
            textAlign: TextAlign.center,
            style: DbType.caption.copyWith(color: tint),
          ),
        ],
      ),
    );
  }
}
