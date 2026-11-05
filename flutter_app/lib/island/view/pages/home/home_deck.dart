import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../../app/app_services.dart';
import '../../../../design/theme/island_theme.dart';
import '../../../../design/tokens/db_dimens.dart';
import '../../../../design/tokens/db_motion.dart';
import 'apps_panel.dart';
import 'connections_sheet.dart';
import 'connectivity_panel.dart';
import 'power_panel.dart';
import 'weather_panel.dart';

/// The four panels under the clock.
///
/// Apps, power, weather, network - the four things a person reaches past the
/// clock for. They open on hover rather than on click, and only one at a time:
/// the deck is always exactly as wide as the page, so the one being read takes
/// its space from the other three instead of from the layout.
///
/// The width maths is the whole trick. Each panel is
///
///     w = rest + open * (E - rest) + (S - open) * (C - rest)
///
/// where `open` is that panel's own progress, `S` is the sum of all four, `E`
/// is the open width and `C` what a panel shrinks to beside an open one. With
/// `E + 3C` fixed to the space available, the four widths always add up to
/// exactly that, whatever is animating - so nothing ever jumps at the end of a
/// transition, and moving the pointer across the deck mid-animation is an
/// ordinary event rather than a special case.
class HomeDeck extends StatefulWidget {
  const HomeDeck({
    required this.onOpenConnections,
    this.height = HomeDeck.fullHeight,
    super.key,
  });

  /// Called when the Wi-Fi or Bluetooth row is clicked.
  final ValueChanged<ConnectionsTarget> onOpenConnections;

  /// How tall this deck is, which is [fullHeight] unless the page had to give
  /// some of it back to the agenda above.
  final double height;

  /// The deck at full size: enough for a six-button power grid and a weather
  /// reading with its numbers under it.
  static const double fullHeight = 104;

  /// The least it will accept before the panels would start clipping. Below a
  /// point, the honest answer is a shorter agenda rather than a broken deck.
  static const double minHeight = 88;

  /// Below this the panels tighten their padding and drop the line they can
  /// most afford to lose.
  static const double compactBelow = 100;

  /// How many panels there are, and what share of the deck an open one takes.
  /// The share is wide enough for four app tiles with readable labels, and
  /// narrow enough that the other three stay legible rather than becoming
  /// decoration.
  static const int panelCount = 4;
  static const double openShare = 0.46;

  /// The width of one panel.
  ///
  /// [progress] is that panel's own openness and [sum] the total across all
  /// four. Because the open width and the shrunken width are defined to add
  /// back up to [available], the four results always do too - whatever is
  /// mid-flight, and however many panels are moving at once. That is what
  /// makes crossing the deck with the pointer an ordinary event rather than a
  /// special case.
  static double panelWidth({
    required double available,
    required double progress,
    required double sum,
  }) {
    final double rest = available / panelCount;
    final double open = available * openShare;
    final double shrunk = (available - open) / (panelCount - 1);
    return rest + progress * (open - rest) + (sum - progress) * (shrunk - rest);
  }

  @override
  State<HomeDeck> createState() => _HomeDeckState();
}

class _HomeDeckState extends State<HomeDeck> with TickerProviderStateMixin {
  static const int _count = HomeDeck.panelCount;
  static const double _gap = DbSpace.sm;

  late final List<AnimationController> _progress = <AnimationController>[
    for (int i = 0; i < _count; i++)
      AnimationController(
        vsync: this,
        duration: DbDuration.quick,
        reverseDuration: DbDuration.standard,
      ),
  ];

  int? _hovered;
  int? _focused;

  /// Held rather than looked up again on the way out: by the time dispose runs
  /// the element is no longer able to answer an ancestor lookup.
  AppServices? _services;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_services == null) {
      final AppServices services = AppScope.read(context);
      _services = services;
      // The weather and the network lists are worth keeping current only while
      // this deck is on screen, which is only while the island is open.
      unawaited(services.connectivity.retain());
      unawaited(services.weather.retain());
    }
  }

  @override
  void dispose() {
    final AppServices? services = _services;
    if (services != null) {
      unawaited(services.connectivity.release());
      services.weather.release();
    }
    for (final AnimationController controller in _progress) {
      controller.dispose();
    }
    super.dispose();
  }

  void _setOpen(int index, {required bool hovered, required bool value}) {
    setState(() {
      if (hovered) {
        if (value) {
          _hovered = index;
        } else if (_hovered == index) {
          _hovered = null;
        }
      } else {
        if (value) {
          _focused = index;
        } else if (_focused == index) {
          _focused = null;
        }
      }
    });
    _sync();
  }

  /// Drives every panel towards where it should be. Retargeting mid-flight is
  /// ordinary: the controller keeps its position and finishes from there.
  void _sync() {
    final int? open = _hovered ?? _focused;
    for (int i = 0; i < _count; i++) {
      if (i == open) {
        _progress[i].forward();
      } else {
        _progress[i].reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);
    for (final AnimationController controller in _progress) {
      controller
        ..duration = theme.motion.scale(DbDuration.quick)
        ..reverseDuration = theme.motion.scale(DbDuration.quick);
    }

    final bool compact = widget.height < HomeDeck.compactBelow;

    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // The gaps come out of the total first, so the four panels only ever
          // share what is genuinely theirs.
          // Half a pixel is left on the table so that a rounding error in the
          // width maths can never present the Row with more than it has.
          final double available =
              constraints.maxWidth - _gap * (_count - 1) - 0.5;
          final double open = available * HomeDeck.openShare;

          return AnimatedBuilder(
            animation: Listenable.merge(_progress),
            builder: (BuildContext context, _) {
              double sum = 0;
              for (final AnimationController controller in _progress) {
                sum += DbCurve.emphasized.transform(controller.value);
              }

              double widthOf(int index) => HomeDeck.panelWidth(
                available: available,
                progress: DbCurve.emphasized.transform(_progress[index].value),
                sum: sum,
              );

              return Row(
                children: <Widget>[
                  for (int i = 0; i < _count; i++)
                    _HoverTarget(
                      leadingGap: i == 0 ? 0 : _gap / 2,
                      trailingGap: i == _count - 1 ? 0 : _gap / 2,
                      onHover: (bool value) =>
                          _setOpen(i, hovered: true, value: value),
                      onFocus: (bool value) =>
                          _setOpen(i, hovered: false, value: value),
                      child: _panel(
                        i,
                        DbCurve.emphasized.transform(_progress[i].value),
                        widthOf(i),
                        open,
                        compact,
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _panel(
    int index,
    double progress,
    double width,
    double openWidth,
    bool compact,
  ) {
    switch (index) {
      case 0:
        return AppsPanel(
          progress: progress,
          width: width,
          expandedWidth: openWidth,
          compact: compact,
        );
      case 1:
        return PowerPanel(
          progress: progress,
          width: width,
          expandedWidth: openWidth,
          compact: compact,
        );
      case 2:
        return WeatherPanel(
          progress: progress,
          width: width,
          expandedWidth: openWidth,
          compact: compact,
        );
      default:
        return ConnectivityPanel(
          progress: progress,
          width: width,
          expandedWidth: openWidth,
          compact: compact,
          onOpen: widget.onOpenConnections,
        );
    }
  }
}

/// The area that counts as being on a panel.
///
/// The gap between two panels belongs to the panels on either side of it, so
/// crossing from one to the next hands the deck straight over instead of
/// collapsing for the frame it takes to get there.
class _HoverTarget extends StatelessWidget {
  const _HoverTarget({
    required this.leadingGap,
    required this.trailingGap,
    required this.onHover,
    required this.onFocus,
    required this.child,
  });

  final double leadingGap;
  final double trailingGap;
  final ValueChanged<bool> onHover;
  final ValueChanged<bool> onFocus;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      // Keyboard users get the same panel by tabbing to it; there is no
      // gesture here that only a mouse can perform.
      onShowHoverHighlight: onHover,
      onShowFocusHighlight: onFocus,
      child: Padding(
        padding: EdgeInsets.only(left: leadingGap, right: trailingGap),
        child: child,
      ),
    );
  }
}
