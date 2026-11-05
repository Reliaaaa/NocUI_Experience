import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../../app/app_info.dart';
import '../../../design/theme/island_theme.dart';
import '../../../design/tokens/db_colors.dart';
import '../../../design/tokens/db_dimens.dart';
import '../../../design/tokens/db_icons.dart';
import '../../../design/tokens/db_motion.dart';
import '../../../design/tokens/db_typography.dart';
import '../../state/island_controller.dart';
import '../../state/island_page.dart';
import '../pages/calendar_page.dart';
import '../pages/media_page.dart';
import '../pages/now_page.dart';
import '../pages/shelf_page.dart';
import '../pages/shortcuts_page.dart';
import '../pages/system_page.dart';
import '../pages/timers_page.dart';
import 'page_dots.dart';

/// The expanded island: one page at a time, with a way to reach the others.
///
/// Navigation is deliberately over-provided, because discovery is the hard part
/// of a surface with no chrome: horizontal wheel or shift+wheel, the arrow
/// keys, the dots, and chevrons that fade in under the cursor. All four drive
/// the same [IslandController] page state, so they can never disagree.
class IslandPager extends StatefulWidget {
  const IslandPager({required this.controller, super.key});

  final IslandController controller;

  @override
  State<IslandPager> createState() => _IslandPagerState();
}

class _IslandPagerState extends State<IslandPager> {
  late final PageController _pages = PageController(
    initialPage: widget.controller.pageIndex,
  );
  bool _hovered = false;
  bool _wheelBusy = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncFromController);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncFromController);
    _pages.dispose();
    super.dispose();
  }

  /// The controller is the source of truth; the PageView follows it.
  void _syncFromController() {
    if (!mounted || !_pages.hasClients) {
      return;
    }
    final int target = widget.controller.pageIndex;
    final double current = _pages.page ?? _pages.initialPage.toDouble();
    if ((current - target).abs() < 0.01) {
      return;
    }
    final IslandThemeData theme = IslandTheme.of(context);
    if (theme.motion.isInstant) {
      _pages.jumpToPage(target);
      return;
    }
    _pages.animateToPage(
      target,
      duration: theme.motion.scale(DbDuration.standard),
      curve: DbCurve.emphasized,
    );
  }

  void _onWheel(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) {
      return;
    }
    // Through the resolver, so a control inside a page that takes the wheel
    // - a dial, a list - gets it first and the page does not turn under it.
    GestureBinding.instance.pointerSignalResolver.register(event, _turnPage);
  }

  void _turnPage(PointerEvent event) {
    if (event is! PointerScrollEvent) {
      return;
    }
    // A trackpad sends a stream of small deltas; one page per gesture is the
    // only sane reading of that, so the wheel is latched until it settles.
    final double delta = event.scrollDelta.dx.abs() > event.scrollDelta.dy.abs()
        ? event.scrollDelta.dx
        : event.scrollDelta.dy;
    if (delta.abs() < 6) {
      return;
    }
    if (_wheelBusy) {
      return;
    }
    _wheelBusy = true;
    Future<void>.delayed(const Duration(milliseconds: 260), () {
      _wheelBusy = false;
    });
    if (delta > 0) {
      widget.controller.nextPage();
    } else {
      widget.controller.previousPage();
    }
  }

  Widget _pageFor(IslandPage page) {
    switch (page) {
      case IslandPage.now:
        return NowPage(controller: widget.controller);
      case IslandPage.media:
        return const MediaPage();
      case IslandPage.timers:
        return const TimersPage();
      case IslandPage.system:
        return const SystemPage();
      case IslandPage.calendar:
        return const CalendarPage();
      case IslandPage.shortcuts:
        return const ShortcutsPage();
      case IslandPage.shelf:
        return const ShelfPage();
      // Pages that arrive in later phases are not yet offered by the
      // coordinator, so they are unreachable rather than empty.
      case IslandPage.notes:
      case IslandPage.clipboard:
        return NowPage(controller: widget.controller);
    }
  }

  @override
  Widget build(BuildContext context) {
    final IslandController controller = widget.controller;
    final List<IslandPage> pages = controller.pages;

    // Arrow keys are handled by the island's focus node, which is an ancestor
    // of this widget; a Shortcuts here would never receive them.
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Listener(
        onPointerSignal: _onWheel,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: PageView.builder(
                controller: _pages,
                itemCount: pages.length,
                physics: const _SnappyPageScrollPhysics(),
                onPageChanged: controller.goToPageIndex,
                itemBuilder: (BuildContext context, int index) =>
                    _Parallax(
                      controller: _pages,
                      index: index,
                      child: _pageFor(pages[index]),
                    ),
              ),
            ),
            _Chevron(
              visible: _hovered && controller.canGoBack,
              leading: true,
              onTap: controller.previousPage,
            ),
            _Chevron(
              visible: _hovered && controller.canGoForward,
              leading: false,
              onTap: controller.nextPage,
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: DbSpace.sm,
              child: Center(
                child: PageDots(
                  count: pages.length,
                  index: controller.pageIndex,
                  onSelected: controller.goToPageIndex,
                ),
              ),
            ),
            // The signature shares the strip with the dots, on every page, at
            // the smallest size the type scale allows. It should be findable
            // rather than noticeable.
            Positioned(
              left: DbSpace.lg,
              bottom: DbSpace.sm,
              child: IgnorePointer(
                child: Text(
                  '© ${AppInfo.developer}',
                  style: DbType.fineprint.copyWith(
                    color: IslandTheme.of(context)
                        .palette
                        .textTertiary
                        .withValues(alpha: 0.55),
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

/// Depth for the page that is on its way out.
///
/// The page being left behind drifts a little slower than the swipe, shrinks
/// very slightly and loses opacity, so the two pages read as being at different
/// distances rather than as one flat strip sliding past. The numbers are small
/// on purpose: at this size, anything more turns a page change into an event.
class _Parallax extends StatelessWidget {
  const _Parallax({
    required this.controller,
    required this.index,
    required this.child,
  });

  final PageController controller;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (IslandTheme.of(context).motion.isInstant) {
      return child;
    }
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (BuildContext context, Widget? built) {
        // Before the first layout the controller has no page; the page being
        // built is the one that is about to be centred.
        final double page = controller.hasClients && controller.page != null
            ? controller.page!
            : controller.initialPage.toDouble();
        final double delta = (page - index).clamp(-1.0, 1.0).toDouble();
        final double distance = delta.abs();

        return Opacity(
          opacity: 1 - distance * 0.55,
          child: Transform.translate(
            // Positive delta means this page is to the left of centre and
            // leaving, so it lags in the direction the finger came from.
            offset: Offset(delta * 34, 0),
            child: Transform.scale(
              scale: 1 - distance * 0.06,
              child: built,
            ),
          ),
        );
      },
    );
  }
}

/// Page snapping with a little more resistance than the default, so a stray
/// trackpad nudge does not change page.
class _SnappyPageScrollPhysics extends PageScrollPhysics {
  const _SnappyPageScrollPhysics({super.parent});

  @override
  _SnappyPageScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      _SnappyPageScrollPhysics(parent: buildParent(ancestor));

  @override
  SpringDescription get spring =>
      const SpringDescription(mass: 0.6, stiffness: 260, damping: 28);
}

/// An edge affordance that only exists while the pointer is inside the island.
class _Chevron extends StatelessWidget {
  const _Chevron({
    required this.visible,
    required this.leading,
    required this.onTap,
  });

  final bool visible;
  final bool leading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);
    final IslandPalette palette = theme.palette;

    return Positioned(
      left: leading ? 0 : null,
      right: leading ? null : 0,
      top: 0,
      bottom: 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: theme.motion.scale(DbDuration.micro),
          curve: DbCurve.standard,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: SizedBox(
                width: 26,
                child: Center(
                  child: Icon(
                    leading ? DbIcons.chevronLeft : DbIcons.chevronRight,
                    size: DbSize.iconMd,
                    color: palette.textTertiary,
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
