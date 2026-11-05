import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../app/app_services.dart';
import '../../modules/activities/activity_center.dart';
import '../../core/logging/app_logger.dart';
import '../../design/components/island_surface.dart';
import '../../design/motion/spring_group.dart';
import '../../design/theme/island_theme.dart';
import '../../design/tokens/db_colors.dart';
import '../../design/tokens/db_motion.dart';
import '../../modules/notifications/island_notification.dart';
import '../state/island_controller.dart';
import '../state/island_metrics.dart';
import '../state/island_state.dart';
import 'island_content.dart';

/// Signature used to publish the island's mouse-interactive rectangle.
typedef HitRectReporter = void Function(Rect rect);

/// The transparent stage that fills the overlay window, and the island in it.
///
/// The stage itself paints nothing. Everything visible is the island, centred
/// horizontally and hanging from the top edge of the screen, morphing between
/// states on the shared spring engine.
class IslandStage extends StatefulWidget {
  const IslandStage({
    required this.controller,
    required this.onHitRectChanged,
    required this.onRequestFocus,
    required this.onReleaseFocus,
    super.key,
  });

  final IslandController controller;

  /// Called when the region that should receive mouse input changes. Growing
  /// regions are published immediately; shrinking ones only once the island has
  /// settled, so the pointer is never dropped mid-animation.
  final HitRectReporter onHitRectChanged;

  final VoidCallback onRequestFocus;
  final VoidCallback onReleaseFocus;

  @override
  State<IslandStage> createState() => _IslandStageState();
}

class _IslandStageState extends State<IslandStage>
    with SingleTickerProviderStateMixin {
  static const Logger _log = Logger('Stage');

  static const String _kWidth = 'width';
  static const String _kHeight = 'height';
  static const String _kRadius = 'radius';
  static const String _kExpansion = 'expansion';
  static const String _kShadow = 'shadow';
  static const String _kGlow = 'glow';
  static const String _kHighlight = 'highlight';

  late final SpringGroup _springs = SpringGroup(vsync: this);
  final FocusNode _focusNode = FocusNode(debugLabel: 'DynamicBar island');

  ActivityCenter? _activities;
  Size _stageSize = Size.zero;
  Rect? _publishedHitRect;
  bool _initialised = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _springs.addListener(_onSpringTick);
    _springs.addSettleListener(_onSpringsSettled);
  }

  @override
  void didUpdateWidget(IslandStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _retarget(animate: false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final IslandThemeData theme = IslandTheme.of(context);
    _springs.profile = theme.motion;
    _stageSize = MediaQuery.sizeOf(context);

    // The pill widens for each live activity, so a new activity is a geometry
    // change and has to retarget the springs.
    final ActivityCenter activities = AppScope.read(context).activities;
    if (!identical(_activities, activities)) {
      _activities?.removeListener(_onControllerChanged);
      _activities = activities;
      activities.addListener(_onControllerChanged);
    }

    if (_initialised) {
      _retarget(animate: true);
      return;
    }
    _initialised = true;

    // First layout: place the island where it would be if it were retracted
    // into the bezel, then let it drop into place on the next frame. Appearing
    // fully formed at the top of the screen is startling; arriving from the
    // edge it lives in is not.
    _springs
      ..reset(
        _kWidth,
        IslandMetrics.collapsedSizeFor(widget.controller.mode).width *
            theme.islandScale *
            0.72,
      )
      ..reset(_kHeight, 0)
      ..reset(_kRadius, 0)
      ..reset(_kExpansion, 0)
      ..reset(_kShadow, 0)
      ..reset(_kGlow, 0)
      ..reset(_kHighlight, 0);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _retarget(animate: true);
      }
    });
  }

  @override
  void dispose() {
    _activities?.removeListener(_onControllerChanged);
    widget.controller.removeListener(_onControllerChanged);
    _springs.removeSettleListener(_onSpringsSettled);
    _springs.removeListener(_onSpringTick);
    _springs.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  IslandGeometry _targetGeometry() {
    final IslandThemeData theme = IslandTheme.of(context);
    return IslandMetrics.resolve(
      intent: widget.controller.intent,
      mode: widget.controller.mode,
      hovered: widget.controller.isHovered,
      scale: theme.islandScale,
      cornerScale: theme.cornerScale,
      activities: AppScope.read(context).activities.visible.length,
    );
  }

  void _onControllerChanged() {
    if (!mounted) {
      return;
    }
    _retarget(animate: true);
    // Escape must work however the island was opened - tray, hotkey, a button
    // inside it - not only after a tap on the shell, so focus follows intent.
    if (widget.controller.isExpanded && !_focusNode.hasFocus) {
      _focusNode.requestFocus();
    }
    setState(() {});
  }

  void _retarget({required bool animate}) {
    final IslandGeometry target = _targetGeometry();
    if (!animate) {
      _springs
        ..reset(_kWidth, target.width)
        ..reset(_kHeight, target.height)
        ..reset(_kRadius, target.bottomRadius)
        ..reset(_kExpansion, target.expansion)
        ..reset(_kShadow, target.shadow)
        ..reset(_kGlow, widget.controller.attention)
        ..reset(_kHighlight, widget.controller.isHovered ? 1 : 0);
      _publishHitRect(force: true);
      return;
    }

    // Which way the island is going decides the character of the move.
    // Arriving overshoots very slightly; leaving does not, because a shape that
    // bounces on its way out reads as the interface arguing with the user who
    // just dismissed it. See docs/MOTION.md.
    final bool opening = target.height > _springs[_kHeight] + 0.5 ||
        target.expansion > _springs[_kExpansion] + 0.01;

    // The hover peek is the one move that is meant to be felt rather than
    // merely seen, so it gets its own openly bouncy spring.
    final bool peeking = !widget.controller.isExpanded &&
        widget.controller.isHovered &&
        widget.controller.intent == IslandIntent.collapsed;

    // Coming out of and going back into the bezel is a different move from
    // opening and closing: it answers a gesture the user is making right now,
    // so it is quick in both directions.
    final bool withdrawing = widget.controller.intent == IslandIntent.hidden;
    final bool returning = !withdrawing &&
        !widget.controller.isExpanded &&
        _springs[_kHeight] < 1.0 &&
        target.height > 1.0;

    final SpringDescription shape = withdrawing
        ? DbSpring.withdraw
        : (returning
              ? DbSpring.reveal
              : (peeking
                    ? DbSpring.peek
                    : DbSpring.forDirection(opening: opening)));

    _springs
      ..animateTo(_kWidth, target.width, spring: shape, epsilon: 0.1)
      ..animateTo(_kHeight, target.height, spring: shape, epsilon: 0.1)
      ..animateTo(
        _kRadius,
        target.bottomRadius,
        spring: DbSpring.contour,
        epsilon: 0.05,
      )
      // Content follows the shape rather than moving with it: a slower spring
      // on the way in, a much faster one on the way out.
      ..animateTo(
        _kExpansion,
        target.expansion,
        spring: opening ? DbSpring.contentIn : DbSpring.contentOut,
        epsilon: 0.002,
      )
      // The shadow, the halo and the edge light are atmosphere, not structure:
      // they follow the shape rather than leading it.
      ..animateTo(
        _kShadow,
        target.shadow,
        spring: DbSpring.atmosphere,
        epsilon: 0.005,
      )
      ..animateTo(
        _kGlow,
        widget.controller.attention,
        spring: DbSpring.atmosphere,
        epsilon: 0.004,
      )
      ..animateTo(
        _kHighlight,
        widget.controller.isHovered ? 1 : 0,
        spring: DbSpring.atmosphere,
        epsilon: 0.004,
      );

    _publishHitRect();
  }

  void _onSpringTick() {
    widget.controller.reportProgress(
      _springs[_kExpansion],
      _springs.velocityOf(_kExpansion),
    );
  }

  void _onSpringsSettled() {
    if (!mounted) {
      return;
    }
    _publishHitRect(force: true);
  }

  Rect _currentIslandRect() => IslandMetrics.islandRect(
    _stageSize,
    _springs[_kWidth],
    _springs[_kHeight],
  );

  /// Publishes the interactive region.
  ///
  /// While a transition is in flight the union of the live and target shapes is
  /// used, so the region only ever grows early and shrinks late. The pointer is
  /// therefore never handed back to the desktop in the middle of a morph.
  void _publishHitRect({bool force = false}) {
    if (_stageSize.isEmpty) {
      return;
    }
    final IslandGeometry target = _targetGeometry();
    final Rect live = _currentIslandRect();
    final Rect wanted = IslandMetrics.islandRect(
      _stageSize,
      target.width,
      target.height,
    );

    Rect island = force ? live : live.expandToInclude(wanted);
    if (island.height <= 0.5 || island.width <= 0.5) {
      island = Rect.zero;
    }
    final Rect hit = island.isEmpty ? Rect.zero : IslandMetrics.hitRect(island);

    final Rect? previous = _publishedHitRect;
    if (previous != null && _closeEnough(previous, hit)) {
      return;
    }
    _publishedHitRect = hit;
    _log.debug(
      'stage=${_stageSize.width.toStringAsFixed(0)}'
      'x${_stageSize.height.toStringAsFixed(0)} '
      'island=${island.left.toStringAsFixed(0)},${island.top.toStringAsFixed(0)}'
      ' ${island.width.toStringAsFixed(0)}x${island.height.toStringAsFixed(0)}'
      ' dpr=${MediaQuery.devicePixelRatioOf(context).toStringAsFixed(2)}',
    );
    widget.onHitRectChanged(hit);
  }

  static bool _closeEnough(Rect a, Rect b) {
    const double tolerance = 0.5;
    return (a.left - b.left).abs() < tolerance &&
        (a.top - b.top).abs() < tolerance &&
        (a.right - b.right).abs() < tolerance &&
        (a.bottom - b.bottom).abs() < tolerance;
  }

  /// A tap on the shell opens the island, and does nothing once it is open.
  ///
  /// It used to close it, which was right when the island was a pill and wrong
  /// now that it is a surface with text fields, a calendar grid and a shelf on
  /// it: every click that missed a control by two pixels threw the page away
  /// mid-sentence. Closing has four other ways to happen - Escape, a click
  /// outside, the auto-collapse timer, and the tray - and all four are
  /// deliberate in a way that a stray tap is not.
  /// It opens on the page that matches the moment - Media while a track is
  /// playing - because a click on the pill is the same request as the hotkey,
  /// and answering it with whichever page happened to be showing last time
  /// would make the pill the one way in that ignores what the machine is doing.
  void _handleTap() {
    final IslandController controller = widget.controller;
    if (controller.isExpanded) {
      return;
    }
    controller.expand(page: AppScope.read(context).router.landingPage());
    widget.onRequestFocus();
    _focusNode.requestFocus();
  }

  void _handleEscape() {
    if (widget.controller.isExpanded) {
      widget.controller.collapse();
      widget.onReleaseFocus();
    }
  }

  /// The halo colour comes from what is asking for attention, so an error and
  /// a finished timer never look the same.
  Color _glowColour(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    final IslandNotification? notification = AppScope.read(
      context,
    ).notifications.current;
    if (notification == null) {
      return palette.accent;
    }
    switch (notification.kind) {
      case NotificationKind.error:
        return palette.negative;
      case NotificationKind.warning:
        return palette.warning;
      case NotificationKind.success:
        return palette.positive;
      default:
        return notification.accent ?? palette.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final IslandController controller = widget.controller;
    final Color glow = _glowColour(context);

    final Widget island = Align(
      alignment: Alignment.topCenter,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _springs,
          builder: (BuildContext context, Widget? child) {
            final double width = math.max(0, _springs[_kWidth]);
            final double height = math.max(0, _springs[_kHeight]);
            if (height < 0.5) {
              return const SizedBox.shrink();
            }
            return SizedBox(
              width: width,
              height: height,
              child: IslandSurface(
                topRadius: 0,
                bottomRadius: _springs[_kRadius],
                shadowStrength: _springs[_kShadow],
                glowColor: glow,
                glowStrength: _springs[_kGlow],
                highlight: _springs[_kHighlight],
                surfaceOpacity: controller.mode.needsPanelStage ? 0.985 : null,
                child: child!,
              ),
            );
          },
          child: _InteractionLayer(
            controller: controller,
            focusNode: _focusNode,
            onTap: _handleTap,
            onEscape: _handleEscape,
            onHoverChanged: controller.setHovered,
            onFocusChanged: controller.setFocused,
            child: IslandContent(
              controller: controller,
              expansion: _springs,
              expansionKey: _kExpansion,
            ),
          ),
        ),
      ),
    );

    return island;
  }
}

/// Pointer, keyboard and focus handling for the island shell.
///
/// Kept in its own widget so it is built once and reused as the
/// `AnimatedBuilder` child, instead of being rebuilt on every spring frame.
class _InteractionLayer extends StatelessWidget {
  const _InteractionLayer({
    required this.controller,
    required this.focusNode,
    required this.onTap,
    required this.onEscape,
    required this.onHoverChanged,
    required this.onFocusChanged,
    required this.child,
  });

  final IslandController controller;
  final FocusNode focusNode;
  final VoidCallback onTap;
  final VoidCallback onEscape;
  final ValueChanged<bool> onHoverChanged;
  final ValueChanged<bool> onFocusChanged;
  final Widget child;

  /// Scrolling the closed pill changes the volume.
  ///
  /// Only while closed: once the island is open the wheel belongs to the pager,
  /// and a gesture that did two different things depending on an invisible
  /// state would be worse than not having it at all.
  void _onPointerSignal(BuildContext context, PointerSignalEvent event) {
    if (event is! PointerScrollEvent || controller.isExpanded) {
      return;
    }
    final AppServices services = AppScope.read(context);
    if (!services.settings.settings.wheelAdjustsVolume ||
        !services.system.volume.available) {
      return;
    }
    final double step = event.scrollDelta.dy > 0 ? -0.04 : 0.04;
    final double next = (services.system.volume.level + step)
        .clamp(0.0, 1.0)
        .toDouble();
    unawaited(services.system.setVolume(next));
  }

  @override
  Widget build(BuildContext context) {
    final bool peek = AppScope.read(context).settings.settings.hoverToPeek;

    return Focus(
      focusNode: focusNode,
      onFocusChange: onFocusChanged,
      onKeyEvent: (FocusNode node, KeyEvent event) {
        // Escape is matched on the key alone, deliberately ignoring
        // modifier state: after the global shortcut fires, Windows has
        // swallowed part of the chord and the framework can be left
        // believing a modifier is still held, which would make a
        // SingleActivator refuse the very key that closes the island.
        if (event is! KeyDownEvent) {
          return KeyEventResult.ignored;
        }
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          onEscape();
          return KeyEventResult.handled;
        }
        // Page navigation is handled here rather than in the pager: the island
        // owns the focus node, and a Shortcuts widget below it would never see
        // a key event, which travels up from the focused node and not down.
        if (controller.isExpanded) {
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            controller.nextPage();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            controller.previousPage();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        opaque: true,
        cursor: SystemMouseCursors.click,
        onEnter: (_) => onHoverChanged(peek),
        onExit: (_) => onHoverChanged(false),
        child: Listener(
          onPointerSignal: (PointerSignalEvent event) =>
              _onPointerSignal(context, event),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: child,
          ),
        ),
      ),
    );
  }
}
