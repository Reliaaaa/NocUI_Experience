import 'dart:ui' show FontVariation;

import 'package:flutter/widgets.dart';

/// Typography.
///
/// Inter is bundled so the notch and settings use the same typeface on every
/// installation. Windows fonts remain as fallbacks for missing glyphs.
class DbType {
  const DbType._();

  static const List<String> _fallback = <String>[
    'Segoe UI Variable Text',
    'Segoe UI',
    'Roboto',
  ];

  static const String _display = 'Inter';
  static const String _text = 'Inter';

  /// Digits that do not jitter as they change. Essential for clocks, timers,
  /// transfer rates and progress readouts.
  static const List<FontFeature> _tabular = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  static const TextStyle clock = TextStyle(
    fontFamily: _display,
    fontFamilyFallback: _fallback,
    fontSize: 13,
    height: 1.0,
    fontWeight: FontWeight.w600,
    fontVariations: <FontVariation>[FontVariation('wght', 600)],
    letterSpacing: 0.2,
    fontFeatures: _tabular,
  );

  static const TextStyle headline = TextStyle(
    fontFamily: _display,
    fontFamilyFallback: _fallback,
    fontSize: 22,
    height: 1.15,
    fontWeight: FontWeight.w600,
    fontVariations: <FontVariation>[FontVariation('wght', 600)],
    letterSpacing: -0.4,
  );

  static const TextStyle title = TextStyle(
    fontFamily: _display,
    fontFamilyFallback: _fallback,
    fontSize: 14.5,
    height: 1.25,
    fontWeight: FontWeight.w600,
    fontVariations: <FontVariation>[FontVariation('wght', 600)],
    letterSpacing: -0.1,
  );

  static const TextStyle body = TextStyle(
    fontFamily: _text,
    fontFamilyFallback: _fallback,
    fontSize: 12.5,
    height: 1.35,
    fontWeight: FontWeight.w500,
    fontVariations: <FontVariation>[FontVariation('wght', 500)],
  );

  static const TextStyle label = TextStyle(
    fontFamily: _text,
    fontFamilyFallback: _fallback,
    fontSize: 11.5,
    height: 1.2,
    fontWeight: FontWeight.w600,
    fontVariations: <FontVariation>[FontVariation('wght', 600)],
    letterSpacing: 0.1,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: _text,
    fontFamilyFallback: _fallback,
    fontSize: 10.5,
    height: 1.2,
    fontWeight: FontWeight.w500,
    fontVariations: <FontVariation>[FontVariation('wght', 500)],
    letterSpacing: 0.2,
  );

  /// Small all-caps section headers used in the settings panel.
  static const TextStyle overline = TextStyle(
    fontFamily: _text,
    fontFamilyFallback: _fallback,
    fontSize: 10,
    height: 1.2,
    fontWeight: FontWeight.w700,
    fontVariations: <FontVariation>[FontVariation('wght', 700)],
    letterSpacing: 0.9,
  );

  /// The hero clock on the Now page.
  ///
  /// Light rather than semibold, and tracked slightly tight. Large numerals
  /// carry their own weight; setting them bold as well makes a clock look like
  /// a warning. Tabular figures keep the colon still as the minutes change.
  static const TextStyle display = TextStyle(
    fontFamily: _display,
    fontFamilyFallback: _fallback,
    fontSize: 42,
    height: 1.0,
    fontWeight: FontWeight.w300,
    fontVariations: <FontVariation>[FontVariation('wght', 300)],
    letterSpacing: -1.6,
    fontFeatures: _tabular,
  );

  /// The date under it: small, wide-tracked and quiet, so the pair reads as one
  /// composition rather than as two lines of text.
  static const TextStyle dateline = TextStyle(
    fontFamily: _text,
    fontFamilyFallback: _fallback,
    fontSize: 11,
    height: 1.2,
    fontWeight: FontWeight.w600,
    fontVariations: <FontVariation>[FontVariation('wght', 600)],
    letterSpacing: 1.4,
  );

  /// The smallest thing in the product: the developer label at the foot of every
  /// page. Deliberately at the threshold of legibility - it is a signature, not
  /// a message.
  static const TextStyle fineprint = TextStyle(
    fontFamily: _text,
    fontFamilyFallback: _fallback,
    fontSize: 8.5,
    height: 1.1,
    fontWeight: FontWeight.w500,
    fontVariations: <FontVariation>[FontVariation('wght', 500)],
    letterSpacing: 0.5,
  );

  static const TextStyle numeric = TextStyle(
    fontFamily: _display,
    fontFamilyFallback: _fallback,
    fontSize: 12,
    height: 1.1,
    fontWeight: FontWeight.w600,
    fontVariations: <FontVariation>[FontVariation('wght', 600)],
    fontFeatures: _tabular,
  );
}
