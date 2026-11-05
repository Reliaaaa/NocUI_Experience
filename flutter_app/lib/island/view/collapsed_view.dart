import 'package:flutter/widgets.dart';

import '../../design/theme/island_theme.dart';
import '../../design/tokens/db_motion.dart';
import '../../settings/ui/settings_panel.dart';
import '../state/island_controller.dart';
import '../state/island_state.dart';
import 'collapsed/collapsed_face.dart';
import 'faces/notification_face.dart';
import 'faces/privacy_face.dart';
import 'pager/island_pager.dart';

/// Chooses the collapsed face for the current mode.
///
/// Most modes share one face - a clock flanked by live activities - because the
/// collapsed pill is a *summary*, not a place for each module to express
/// itself. Only the two that carry a different meaning get their own: a
/// notification, and the recording indicator.
class CollapsedView extends StatelessWidget {
  const CollapsedView({required this.controller, super.key});

  final IslandController controller;

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);

    return AnimatedSwitcher(
      duration: theme.motion.scale(DbDuration.quick),
      switchInCurve: DbCurve.standard,
      switchOutCurve: DbCurve.exit,
      layoutBuilder: _stackFromTop,
      transitionBuilder: _slideFade,
      child: KeyedSubtree(
        key: ValueKey<IslandMode>(_faceKeyFor(controller.mode)),
        child: _faceFor(controller.mode),
      ),
    );
  }

  /// Modes that share the summary face must also share a key, or the switcher
  /// would cross-fade the face with itself every time the mode changed.
  static IslandMode _faceKeyFor(IslandMode mode) {
    switch (mode) {
      case IslandMode.notification:
      case IslandMode.privacy:
        return mode;
      case IslandMode.idle:
      case IslandMode.media:
      case IslandMode.download:
      case IslandMode.timer:
      case IslandMode.settings:
        return IslandMode.idle;
    }
  }

  static Widget _faceFor(IslandMode mode) {
    switch (mode) {
      case IslandMode.notification:
        return const NotificationCollapsed();
      case IslandMode.privacy:
        return const PrivacyCollapsed();
      case IslandMode.idle:
      case IslandMode.media:
      case IslandMode.download:
      case IslandMode.timer:
      case IslandMode.settings:
        return const CollapsedFace();
    }
  }
}

/// Shared transition for both faces: the arriving content rises a little and
/// fades in while the leaving content falls away.
Widget _slideFade(Widget child, Animation<double> animation) {
  return FadeTransition(
    opacity: animation,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.22),
        end: Offset.zero,
      ).animate(animation),
      child: child,
    ),
  );
}

/// Faces are pinned to the top of the island so a taller arriving face does not
/// push the outgoing one around while both are on screen.
Widget _stackFromTop(Widget? currentChild, List<Widget> previousChildren) {
  return Stack(
    alignment: Alignment.topCenter,
    children: <Widget>[...previousChildren, ?currentChild],
  );
}

/// Chooses the expanded face for the current mode.
///
/// Everything that is not a transient message opens into the pager, so the user
/// always lands somewhere they can navigate from.
class ExpandedView extends StatelessWidget {
  const ExpandedView({required this.controller, super.key});

  final IslandController controller;

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);

    return AnimatedSwitcher(
      duration: theme.motion.scale(DbDuration.standard),
      switchInCurve: DbCurve.standard,
      switchOutCurve: DbCurve.exit,
      layoutBuilder: _stackFromTop,
      transitionBuilder: _slideFade,
      child: KeyedSubtree(
        key: ValueKey<IslandMode>(_expandedKeyFor(controller.mode)),
        child: _faceFor(controller.mode, controller),
      ),
    );
  }

  static IslandMode _expandedKeyFor(IslandMode mode) {
    switch (mode) {
      case IslandMode.notification:
      case IslandMode.privacy:
      case IslandMode.settings:
        return mode;
      case IslandMode.idle:
      case IslandMode.media:
      case IslandMode.download:
      case IslandMode.timer:
        // One key for the pager: swapping pages is the pager's own business,
        // and must not restart this switcher.
        return IslandMode.idle;
    }
  }

  static Widget _faceFor(IslandMode mode, IslandController controller) {
    switch (mode) {
      case IslandMode.notification:
        return const NotificationExpanded();
      case IslandMode.privacy:
        return const PrivacyExpanded();
      case IslandMode.settings:
        // Collapse first; the coordinator switches the face back only once the
        // island has closed, so the panel is never swapped out mid-animation.
        return SettingsPanel(
          onClose: () => controller.collapse(trigger: IslandTrigger.user),
        );
      case IslandMode.idle:
      case IslandMode.media:
      case IslandMode.download:
      case IslandMode.timer:
        return IslandPager(controller: controller);
    }
  }
}
