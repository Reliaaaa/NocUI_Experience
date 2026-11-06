/// Spacing, radii and sizing scale.
///
/// Every measurement in the island comes from here. A 4pt base grid keeps the
/// collapsed pill legible at 100% scaling and still correct at 200%.
class DbSpace {
  const DbSpace._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 14;
  static const double xl = 20;
  static const double xxl = 28;
  static const double xxxl = 40;
}

class DbRadius {
  const DbRadius._();

  /// The island hugs the top edge of the screen, so its top corners stay
  /// square: it should read as a shape cut into the bezel, not a floating card.
  static const double islandTop = 0;
  static const double islandCollapsedBottom = 17;
  static const double islandPeekBottom = 20;
  static const double islandExpandedBottom = 28;

  static const double card = 14;
  static const double control = 11;
  static const double pill = 999;
  static const double panel = 18;
}

class DbSize {
  const DbSize._();

  /// Collapsed notch pill. Proportioned to match the sleek Apple notch aesthetic
  /// on desktop screens (~6:1 aspect ratio), with breathing room for status indicators.
  static const double collapsedWidth = 204;
  static const double collapsedHeight = 34;

  /// Hover peek: the same shape, breathing.
  static const double peekWidth = 248;
  static const double peekHeight = 40;

  /// Expanded panel defaults; individual modules refine these.
  static const double expandedWidth = 424;
  static const double expandedHeight = 232;

  /// Widest and tallest the island is ever allowed to be. The stage is sized
  /// from these, so they are the contract between Dart and the native window.
  static const double maxWidth = 560;
  static const double maxHeight = 360;

  /// Room around the island inside the stage for shadow and glow.
  static const double stagePadding = 96;

  static const double iconSm = 13;
  static const double iconMd = 16;
  static const double iconLg = 20;
  static const double iconXl = 26;

  static const double controlSm = 26;
  static const double controlMd = 32;
  static const double controlLg = 40;

  static const double hairline = 1;

  /// Extra hit area around the collapsed island so the cursor is caught just
  /// before it touches the shape.
  static const double hoverPaddingX = 10;
  static const double hoverPaddingY = 6;
}

/// Depth levels. Higher levels get more separation from what is behind them.
enum SurfaceLevel { island, raised, overlay }
