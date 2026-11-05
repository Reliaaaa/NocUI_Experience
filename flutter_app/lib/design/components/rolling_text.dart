import 'package:flutter/widgets.dart';

import '../theme/island_theme.dart';
import '../tokens/db_motion.dart';

/// Text where only the characters that changed move.
///
/// A clock that re-renders the whole string every minute is a clock that
/// twitches. This compares the new string to the old one character by
/// character and rolls just the differences: `09:59` to `10:00` moves three
/// digits and leaves the colon and the leading zero exactly where they are.
///
/// Digits roll upward when the value goes up and downward when it goes back,
/// which is the difference between a clock advancing and a clock being
/// corrected.
///
/// The text must be monospaced for this to hold still - every caller here uses
/// `DbType.clock` or `DbType.numeric`, both of which are.
class RollingText extends StatelessWidget {
  const RollingText(
    this.text, {
    required this.style,
    this.descending = false,
    super.key,
  });

  final String text;
  final TextStyle style;

  /// Rolls downward instead of up. For a countdown, where the numbers are
  /// getting smaller and rolling up would look wrong.
  final bool descending;

  @override
  Widget build(BuildContext context) {
    if (IslandTheme.of(context).motion.isInstant) {
      return Text(text, style: style, maxLines: 1, softWrap: false);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        for (int i = 0; i < text.length; i++)
          _RollingChar(
            // Keyed by position, so character 3 is always the same widget and
            // an unchanged character is never rebuilt as a new one.
            key: ValueKey<int>(i),
            character: text[i],
            style: style,
            descending: descending,
          ),
      ],
    );
  }
}

class _RollingChar extends StatelessWidget {
  const _RollingChar({
    required this.character,
    required this.style,
    required this.descending,
    super.key,
  });

  final String character;
  final TextStyle style;
  final bool descending;

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);
    // Punctuation does not roll. A colon that slid every minute would be the
    // most distracting thing on the screen.
    final bool rolls = character.codeUnitAt(0) >= 0x30 &&
        character.codeUnitAt(0) <= 0x39;

    final Widget glyph = Text(
      character,
      style: style,
      maxLines: 1,
      softWrap: false,
    );
    if (!rolls) {
      return glyph;
    }

    return ClipRect(
      child: AnimatedSwitcher(
        duration: theme.motion.scale(DbDuration.standard),
        switchInCurve: DbCurve.standard,
        switchOutCurve: DbCurve.exit,
        // The two glyphs must travel together rather than stack, so the
        // outgoing one is laid out on top of the incoming one at its own
        // position instead of being centred in a growing box.
        layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
          alignment: Alignment.center,
          children: <Widget>[...previous, ?current],
        ),
        transitionBuilder: (Widget child, Animation<double> animation) {
          final bool incoming = animation.status != AnimationStatus.reverse;
          final double from = descending == incoming ? -1.0 : 1.0;
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: Offset(0, from),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(key: ValueKey<String>(character), child: glyph),
      ),
    );
  }
}
