import 'package:flutter/widgets.dart';

import '../../island/view/island_content.dart';

/// Reveals one element as the island opens, offset by its place in the order.
///
/// The island's expansion already carries a 0..1 value, so content
/// choreography rides on it for free rather than owning a second set of
/// animation controllers that would have to be kept in step with the spring.
///
/// This is what makes an opening panel feel composed rather than pasted: the
/// heading is legible before the controls arrive, and the eye is led through
/// the surface in the order the content should be read. The stagger is small on
/// purpose - past about a fifth of the opening animation it stops reading as
/// choreography and starts reading as lag.
///
/// Composability matters more than a clever container here: [Reveal] wraps a
/// single child and can therefore sit anywhere, including inside a Column that
/// also contains Spacers and Expandeds.
class Reveal extends StatelessWidget {
  const Reveal({
    required this.order,
    required this.child,
    this.start = 0.38,
    this.step = 0.09,
    this.span = 0.42,
    this.offset = 12,
    this.scaleFrom = 1.0,
    super.key,
  });

  /// Position in the reveal order. 0 arrives first.
  final int order;

  /// Where in the expansion the first element begins to appear.
  final double start;

  /// Distance between consecutive elements.
  final double step;

  /// How much of the expansion each element takes to arrive.
  final double span;

  /// Vertical travel in logical pixels.
  final double offset;

  /// Starting scale. 1.0 means translate only, which suits text; controls look
  /// better arriving from slightly small.
  final double scaleFrom;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double progress = IslandExpansionScope.of(context);
    final double begin = start + order * step;
    final double t = ((progress - begin) / span).clamp(0.0, 1.0).toDouble();
    if (t >= 1) {
      return child;
    }
    final double eased = Curves.easeOutCubic.transform(t);

    Widget result = child;
    if (scaleFrom != 1.0) {
      result = Transform.scale(
        scale: scaleFrom + (1 - scaleFrom) * eased,
        child: result,
      );
    }
    if (offset != 0) {
      result = Transform.translate(
        offset: Offset(0, offset * (1 - eased)),
        child: result,
      );
    }
    return Opacity(opacity: eased, child: result);
  }
}

/// Wraps a column's children in [Reveal]s, numbering them as it goes.
///
/// Layout-only widgets are passed through untouched: a Spacer is an
/// instruction to the parent, not something that can be faded, and animating
/// the gaps between elements would make the spacing itself appear to move.
List<Widget> staggered(
  List<Widget> children, {
  double start = 0.38,
  double step = 0.08,
  double offset = 8,
}) {
  var order = 0;
  return <Widget>[
    for (final Widget child in children)
      if (child is Spacer ||
          child is SizedBox ||
          child is Expanded ||
          child is Flexible)
        child
      else
        Reveal(
          order: order++,
          start: start,
          step: step,
          offset: offset,
          child: child,
        ),
  ];
}
