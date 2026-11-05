import 'package:flutter/widgets.dart';

import '../../design/motion/spring_group.dart';
import '../../app/app_services.dart';
import '../../design/theme/island_theme.dart';
import '../state/island_controller.dart';
import '../state/island_metrics.dart';
import '../state/island_state.dart';
import 'collapsed_view.dart';

/// Exposes the island's current expansion to the content below it.
///
/// Faces use this to stagger their own contents against the shape change,
/// instead of each of them owning a controller that would have to be kept in
/// step with the spring. Dependants rebuild only while the value is actually
/// moving, and stop the moment it settles.
class IslandExpansionScope extends InheritedWidget {
  const IslandExpansionScope({
    required this.value,
    required super.child,
    super.key,
  });

  /// 0 collapsed, 1 fully expanded.
  final double value;

  static double of(BuildContext context) {
    final IslandExpansionScope? scope = context
        .dependOnInheritedWidgetOfExactType<IslandExpansionScope>();
    return scope?.value ?? 1;
  }

  @override
  bool updateShouldNotify(IslandExpansionScope oldWidget) =>
      oldWidget.value != value;
}

/// Cross-fades the collapsed and expanded faces of the island.
///
/// Both faces are laid out at their own natural size and clipped by the shell,
/// never at the animating size. That is the difference between a shape that
/// morphs and a layout that reflows: text never re-wraps, icons never jump, and
/// the only per-frame work is a clip and two opacity layers.
class IslandContent extends StatelessWidget {
  const IslandContent({
    required this.controller,
    required this.expansion,
    required this.expansionKey,
    super.key,
  });

  final IslandController controller;
  final SpringGroup expansion;
  final String expansionKey;

  /// The collapsed face has faded out well before the expanded face arrives,
  /// so the two never overlap into mud.
  static double _collapsedOpacity(double t) =>
      (1 - t * 2.4).clamp(0.0, 1.0).toDouble();

  static double _expandedOpacity(double t) =>
      ((t - 0.42) / 0.48).clamp(0.0, 1.0).toDouble();

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);
    final int activities = AppScope.read(context).activities.visible.length;

    final IslandGeometry collapsedGeometry = IslandMetrics.resolve(
      intent: IslandIntent.collapsed,
      mode: controller.mode,
      hovered: controller.isHovered,
      scale: theme.islandScale,
      cornerScale: theme.cornerScale,
      activities: activities,
    );
    final IslandGeometry expandedGeometry = IslandMetrics.resolve(
      intent: IslandIntent.expanded,
      mode: controller.mode,
      hovered: false,
      scale: theme.islandScale,
      cornerScale: theme.cornerScale,
    );

    final Widget collapsed = CollapsedView(controller: controller);
    final Widget expanded = ExpandedView(controller: controller);

    return AnimatedBuilder(
      animation: expansion,
      builder: (BuildContext context, _) {
        final double t = expansion[expansionKey].clamp(0.0, 1.0).toDouble();
        final double collapsedOpacity = _collapsedOpacity(t);
        final double expandedOpacity = _expandedOpacity(t);

        return IslandExpansionScope(
          value: t,
          child: Stack(
            alignment: Alignment.topCenter,
            clipBehavior: Clip.none,
            children: <Widget>[
              if (collapsedOpacity > 0.004)
                _Face(
                  size: collapsedGeometry.size,
                  opacity: collapsedOpacity,
                  // Sinks very slightly as it hands over.
                  offsetY: -3 * t,
                  scale: 1 - 0.04 * t,
                  child: collapsed,
                ),
              if (expandedOpacity > 0.004)
                _Face(
                  size: expandedGeometry.size,
                  opacity: expandedOpacity,
                  // Rises into place from just below, so it reads as content
                  // emerging from inside the shape rather than appearing on
                  // top of it.
                  offsetY: 10 * (1 - t),
                  scale: 0.97 + 0.03 * t,
                  child: expanded,
                ),
            ],
          ),
        );
      },
    );
  }
}

/// One face of the island, pinned to its natural size regardless of the
/// current shell size.
class _Face extends StatelessWidget {
  const _Face({
    required this.size,
    required this.opacity,
    required this.offsetY,
    required this.scale,
    required this.child,
  });

  final Size size;
  final double opacity;
  final double offsetY;
  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return OverflowBox(
      alignment: Alignment.topCenter,
      minWidth: size.width,
      maxWidth: size.width,
      minHeight: size.height,
      maxHeight: size.height,
      child: Opacity(
        opacity: opacity,
        child: Transform.translate(
          offset: Offset(0, offsetY),
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
