import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// One colour, taken from the album art.
///
/// The media page is the only surface in the product that is *about* something
/// the user chose, so it is the only one allowed to borrow a colour from it.
/// Everything else stays on the accent. The tint is used for the scrub fill,
/// the play control and a very faint wash behind the artwork - a colour cast,
/// never a glow.
///
/// The extraction is deliberately conservative. A cover is averaged in hue
/// space rather than in RGB, because averaging red and green channels gives
/// mud; pixels are weighted by how vivid and how mid-toned they are, so the
/// black frame around a square cover and the blown-out highlight in the middle
/// of it both count for almost nothing; and a cover with no agreement between
/// its hues - a photo collage, a greyscale sleeve - returns null rather than a
/// confident wrong answer, which leaves the page on the user's accent.
class ArtworkTint {
  const ArtworkTint._();

  /// The art is decoded to this edge before sampling. 576 pixels is more than
  /// enough to describe a cover's colour and small enough that the whole
  /// operation costs less than a frame.
  static const int _sampleEdge = 24;

  /// Artwork ids are monotonic and a session changes track a few times an
  /// hour, so a handful of entries covers every back-and-forth the user can
  /// make through the pager without decoding anything twice.
  static const int _cacheLimit = 8;
  static final Map<int, Color?> _cache = <int, Color?>{};

  /// The tint for [artworkId] if it has already been resolved. Lets a page
  /// paint the right colour on its first frame instead of fading into it.
  static Color? cached(int artworkId) => _cache[artworkId];

  static bool isCached(int artworkId) => _cache.containsKey(artworkId);

  /// Resolves and remembers the tint for one piece of album art.
  static Future<Color?> resolve(int artworkId, Uint8List bytes) async {
    if (_cache.containsKey(artworkId)) {
      return _cache[artworkId];
    }
    final Color? colour = bytes.isEmpty ? null : await _extract(bytes);
    if (_cache.length >= _cacheLimit) {
      _cache.remove(_cache.keys.first);
    }
    _cache[artworkId] = colour;
    return colour;
  }

  /// The tint as it should appear on the island's glass.
  ///
  /// A cover's own lightness is useless here: a black metal sleeve would be
  /// invisible on dark glass and a pastel one would be invisible on light. The
  /// hue survives, the saturation is kept within a band that reads as colour
  /// rather than as neon, and the lightness is set by the theme.
  static Color onSurface(Color tint, {required bool isDark}) {
    final HSLColor hsl = HSLColor.fromColor(tint);
    return hsl
        .withSaturation(hsl.saturation.clamp(0.40, 0.80))
        .withLightness(isDark ? 0.68 : 0.42)
        .toColor();
  }

  static Future<Color?> _extract(Uint8List bytes) async {
    ui.Image? image;
    try {
      final ui.Codec codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: _sampleEdge,
        targetHeight: _sampleEdge,
      );
      final ui.FrameInfo frame = await codec.getNextFrame();
      image = frame.image;
      codec.dispose();
      final ByteData? data = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (data == null) {
        return null;
      }
      return _dominantHue(data.buffer.asUint8List());
    } catch (_) {
      // The art comes from whatever application is playing. A file this
      // process cannot decode costs the page its tint and nothing else.
      return null;
    } finally {
      image?.dispose();
    }
  }

  static Color? _dominantHue(Uint8List rgba) {
    // Hue is an angle, so it is accumulated as a vector: the length of the sum
    // is how much the cover agrees with itself, which is exactly the
    // confidence measure needed to reject a collage.
    double x = 0;
    double y = 0;
    double saturationSum = 0;
    double weightSum = 0;

    for (int i = 0; i + 3 < rgba.length; i += 4) {
      if (rgba[i + 3] < 32) {
        continue;
      }
      final double r = rgba[i] / 255;
      final double g = rgba[i + 1] / 255;
      final double b = rgba[i + 2] / 255;
      final double high = math.max(r, math.max(g, b));
      final double low = math.min(r, math.min(g, b));
      final double chroma = high - low;
      if (chroma < 0.06) {
        continue;
      }
      final double lightness = (high + low) / 2;
      final double saturation = chroma / (1 - (2 * lightness - 1).abs());
      final double weight =
          saturation *
          saturation *
          (1 - (lightness - 0.5).abs() * 1.8).clamp(0.0, 1.0);
      if (weight <= 0) {
        continue;
      }

      final double sextant;
      if (high == r) {
        sextant = ((g - b) / chroma) % 6;
      } else if (high == g) {
        sextant = (b - r) / chroma + 2;
      } else {
        sextant = (r - g) / chroma + 4;
      }
      final double radians = sextant * math.pi / 3;
      x += weight * math.cos(radians);
      y += weight * math.sin(radians);
      saturationSum += weight * saturation;
      weightSum += weight;
    }

    // Too little colour to speak for the cover at all.
    if (weightSum < 0.5) {
      return null;
    }
    // The hues cancelled each other out; whatever came through is noise.
    final double coherence = math.sqrt(x * x + y * y) / weightSum;
    if (coherence < 0.25) {
      return null;
    }

    final double degrees = (math.atan2(y, x) * 180 / math.pi + 360) % 360;
    final double saturation = (saturationSum / weightSum).clamp(0.35, 0.85);
    return HSLColor.fromAHSL(1, degrees, saturation, 0.55).toColor();
  }
}
