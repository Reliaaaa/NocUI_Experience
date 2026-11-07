import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../../../app/app_services.dart';
import '../../../core/time/seconds_scope.dart';
import '../../../core/utils/formatters.dart';
import '../../../design/components/island_button.dart';
import '../../../design/components/marquee_text.dart';
import '../../../design/components/morph_icon.dart';
import '../../../design/components/sound_bars.dart';
import '../../../design/components/staggered_reveal.dart';
import '../../../design/theme/island_theme.dart';
import '../../../design/tokens/db_colors.dart';
import '../../../design/tokens/db_dimens.dart';
import '../../../design/tokens/db_icons.dart';
import '../../../design/tokens/db_motion.dart';
import '../../../design/tokens/db_shadows.dart';
import '../../../design/tokens/db_typography.dart';
import '../../../modules/media/artwork_tint.dart';
import '../../../modules/media/media_controller.dart';
import '../../../native/media_bridge.dart';
import 'page_scaffold.dart';

/// The music page: artwork, what is playing, a scrubbable timeline, transport.
///
/// This is the one page in the product that is about something the user chose
/// rather than about something the machine is doing, and it is designed that
/// way: the cover is the largest object on the surface, the title is the only
/// piece of type set at display size, and the page borrows a single colour from
/// the album art for the scrub fill, the play control and a faint wash behind
/// the cover. Everything else stays on the theme accent - see [ArtworkTint].
///
/// Motion here is state, never decoration. The equaliser runs while sound is
/// actually coming out of the machine, the title travels only when it does not
/// fit and only while playing, the scrub thumb appears under the pointer
/// because that is when it can be used, and a track change cross-fades because
/// the alternative is text that appears to have been corrected.
class MediaPage extends StatelessWidget {
  const MediaPage({super.key});

  @override
  Widget build(BuildContext context) {
    final MediaController media = AppScope.read(context).media;

    return SecondsScope(
      child: AnimatedBuilder(
        animation: media,
        builder: (BuildContext context, _) {
          if (!media.hasSession) {
            return const _NothingPlaying();
          }
          return _NowPlaying(media: media);
        },
      ),
    );
  }
}

/// No session at all: not an error, just a quiet page.
class _NothingPlaying extends StatelessWidget {
  const _NothingPlaying();

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;

    return PageScaffold(
      title: 'Media',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Reveal(
            order: 1,
            scaleFrom: 0.9,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: palette.surfaceSunken,
                shape: BoxShape.circle,
              ),
              child: SizedBox(
                width: 46,
                height: 46,
                child: Center(
                  child: Icon(
                    DbIcons.music,
                    size: DbSize.iconLg,
                    color: palette.textTertiary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: DbSpace.md),
          const Reveal(
            order: 2,
            child: PageEmptyState(
              message: 'Nothing playing',
              hint: 'Anything using the Windows media controls shows here.',
            ),
          ),
        ],
      ),
    );
  }
}

/// A live session, and everything that can be done with it.
class _NowPlaying extends StatefulWidget {
  const _NowPlaying({required this.media});

  final MediaController media;

  @override
  State<_NowPlaying> createState() => _NowPlayingState();
}

class _NowPlayingState extends State<_NowPlaying> {
  static const double _artworkSize = 116;

  /// The artwork the current tint was taken from. Kept so the page can tell a
  /// new cover from a rebuild without comparing image bytes.
  int _tintSource = -1;
  Color? _tint;

  @override
  void initState() {
    super.initState();
    _syncTint();
  }

  @override
  void didUpdateWidget(_NowPlaying oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTint();
  }

  /// Fields are assigned directly rather than through setState: this runs
  /// during a rebuild that is already happening. Only the asynchronous result,
  /// which arrives a frame or two later, needs to ask for one.
  void _syncTint() {
    final int id = widget.media.artworkId;
    if (id == _tintSource) {
      return;
    }
    _tintSource = id;

    if (ArtworkTint.isCached(id)) {
      _tint = ArtworkTint.cached(id);
      return;
    }
    final Uint8List bytes = widget.media.artwork;
    if (bytes.isEmpty) {
      _tint = null;
      return;
    }
    // The previous tint is left in place while the new one resolves, so a
    // track change moves through two colours rather than three.
    unawaited(
      ArtworkTint.resolve(id, bytes).then((Color? colour) {
        if (!mounted || _tintSource != id) {
          return;
        }
        setState(() => _tint = colour);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);
    final IslandPalette palette = theme.palette;
    final MediaSession session = widget.media.session;
    final bool playing = session.isPlaying;

    final Color? fromArt = _tint;
    final Color tint = fromArt == null
        ? palette.accent
        : ArtworkTint.onSurface(fromArt, isDark: palette.isDark);

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // Only art earns the wash. Casting the theme accent over the page
        // would put colour on it that says nothing about what is playing.
        _TintWash(colour: tint, strength: fromArt == null ? 0 : 1),
        PageScaffold(
          title: playing ? 'Media · Playing' : 'Media · Paused',
          trailing: _SourceChip(session: session, tint: tint),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Reveal(
                    order: 1,
                    start: 0.36,
                    step: 0.07,
                    scaleFrom: 0.9,
                    child: _Artwork(
                      bytes: widget.media.artwork,
                      artworkId: widget.media.artworkId,
                      size: _artworkSize,
                      tint: tint,
                      playing: playing,
                      onToggle: session.canPause || session.canPlay
                          ? widget.media.playPause
                          : null,
                    ),
                  ),
                  const SizedBox(width: DbSpace.lg),
                  Expanded(
                    child: Reveal(
                      order: 2,
                      start: 0.36,
                      step: 0.07,
                      child: _TrackText(session: session),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Reveal(
                order: 3,
                start: 0.36,
                step: 0.07,
                child: _Scrubber(session: session, tint: tint),
              ),
              const SizedBox(height: DbSpace.md),
              Reveal(
                order: 4,
                start: 0.36,
                step: 0.07,
                scaleFrom: 0.94,
                child: _Transport(
                  media: widget.media,
                  session: session,
                  tint: tint,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A colour cast taken from the cover, behind everything else on the page.
///
/// Deliberately a wash and not a glow: the island has exactly one halo and it
/// belongs to urgent notifications. This is light falling on glass from the
/// direction the artwork sits in, at an alpha low enough that text over it
/// never has to work for contrast.
class _TintWash extends StatelessWidget {
  const _TintWash({required this.colour, required this.strength});

  final Color colour;

  /// 0 leaves the page untinted, for art with no colour to give.
  final double strength;

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);
    final double peak = (theme.palette.isDark ? 0.20 : 0.14) * strength;

    return IgnorePointer(
      child: AnimatedContainer(
        duration: theme.motion.scale(DbDuration.slow),
        curve: DbCurve.standard,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            // Centred on the cover, so the page looks lit by it.
            center: const Alignment(-0.74, -0.5),
            radius: 1.2,
            colors: <Color>[
              colour.withValues(alpha: peak),
              colour.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

/// Where the sound is coming from, and whether it is moving.
class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.session, required this.tint});

  final MediaSession session;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    final String label = appLabel(session.sourceAppId);

    return Container(
      padding: const EdgeInsets.fromLTRB(
        DbSpace.sm,
        3,
        DbSpace.md,
        3,
      ),
      decoration: BoxDecoration(
        color: palette.surfaceSunken,
        borderRadius: BorderRadius.circular(DbRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SoundBars(
            active: session.isPlaying,
            color: tint,
            height: 10,
            barWidth: 2,
            spacing: 2,
            barCount: 3,
          ),
          if (label.isNotEmpty) ...<Widget>[
            const SizedBox(width: DbSpace.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DbType.caption.copyWith(color: palette.textSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Title, artist and album, cross-faded when the track changes.
class _TrackText extends StatelessWidget {
  const _TrackText({required this.session});

  final MediaSession session;

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);
    final IslandPalette palette = theme.palette;

    final Widget lines = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // The one piece of display type on the page. A long title travels
        // rather than being cut, because the part an ellipsis eats is usually
        // the part that tells two songs apart.
        MarqueeText(
          session.title.isEmpty ? 'Unknown track' : session.title,
          style: DbType.headline.copyWith(
            color: palette.textPrimary,
            fontSize: 20,
          ),
          enabled: session.isPlaying,
        ),
        const SizedBox(height: DbSpace.xs),
        Text(
          session.artist.isEmpty ? '—' : session.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: DbType.title.copyWith(
            color: palette.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (session.album.isNotEmpty) ...<Widget>[
          const SizedBox(height: DbSpace.xxs),
          Text(
            session.album,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DbType.caption.copyWith(color: palette.textTertiary),
          ),
        ],
      ],
    );

    return AnimatedSwitcher(
      duration: theme.motion.scale(DbDuration.standard),
      switchInCurve: DbCurve.standard,
      switchOutCurve: DbCurve.exit,
      // Left aligned rather than centred: the outgoing lines must leave from
      // exactly where the incoming ones arrive, or the block appears to shift.
      layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
        alignment: Alignment.centerLeft,
        children: <Widget>[...previous, ?current],
      ),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.24),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey<String>('${session.title}|${session.artist}'),
        child: lines,
      ),
    );
  }
}

/// Album art: a raised card with the cover in it, and a play control under the
/// pointer.
///
/// The cover is the obvious place to click to stop the music, so it is one -
/// and it says so on hover instead of hiding the behaviour.
class _Artwork extends StatefulWidget {
  const _Artwork({
    required this.bytes,
    required this.artworkId,
    required this.size,
    required this.tint,
    required this.playing,
    required this.onToggle,
  });

  final Uint8List bytes;
  final int artworkId;
  final double size;
  final Color tint;
  final bool playing;
  final VoidCallback? onToggle;

  @override
  State<_Artwork> createState() => _ArtworkState();
}

class _ArtworkState extends State<_Artwork> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);
    final IslandPalette palette = theme.palette;
    final BorderRadius radius = BorderRadius.circular(DbRadius.card);
    final Duration micro = theme.motion.scale(DbDuration.micro);

    final Widget placeholder = DecoratedBox(
      key: const ValueKey<String>('no-art'),
      decoration: BoxDecoration(
        color: palette.surfaceSunken,
        borderRadius: radius,
      ),
      child: Center(
        child: Icon(
          DbIcons.music,
          size: widget.size * 0.34,
          color: palette.textTertiary,
        ),
      ),
    );

    final Widget cover = AnimatedSwitcher(
      duration: theme.motion.scale(DbDuration.standard),
      switchInCurve: DbCurve.standard,
      switchOutCurve: DbCurve.exit,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1).animate(animation),
            child: child,
          ),
        );
      },
      child: widget.bytes.isEmpty
          ? placeholder
          : Image.memory(
              widget.bytes,
              key: ValueKey<int>(widget.artworkId),
              width: widget.size,
              height: widget.size,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
              errorBuilder:
                  (BuildContext context, Object error, StackTrace? stack) =>
                      placeholder,
            ),
    );

    final Widget card = DecoratedBox(
      // The plate carries the shadow and a trace of the cover's own colour, so
      // art with transparent corners still sits on a body rather than floating.
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          widget.tint.withValues(alpha: 0.12),
          palette.surfaceSunken,
        ),
        borderRadius: radius,
        boxShadow: DbShadow.raised(palette),
      ),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ClipRRect(borderRadius: radius, child: cover),
            IgnorePointer(
              child: AnimatedOpacity(
                opacity: _hovered && widget.onToggle != null ? 1 : 0,
                duration: micro,
                curve: DbCurve.standard,
                child: ClipRRect(
                  borderRadius: radius,
                  child: ColoredBox(
                    color: const Color(0xFF000000).withValues(alpha: 0.46),
                    child: Center(
                      child: MorphIcon(
                        icon: widget.playing ? DbIcons.pause : DbIcons.play,
                        size: DbSize.iconXl,
                        color: const Color(0xFFFFFFFF),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // The hairline that separates a dark cover from dark glass.
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color: palette.stroke,
                    width: DbSize.hairline,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return MouseRegion(
      cursor: widget.onToggle == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onToggle,
        child: AnimatedScale(
          // Paused art sits back a fraction. It is the quietest possible way
          // to say "stopped" on a page where the transport is already saying
          // it in words and glyphs.
          scale: widget.playing ? 1 : 0.965,
          duration: theme.motion.scale(DbDuration.quick),
          curve: DbCurve.standard,
          child: card,
        ),
      ),
    );
  }
}

/// Elapsed, remaining, and a rail that can be dragged to seek.
class _Scrubber extends StatefulWidget {
  const _Scrubber({required this.session, required this.tint});

  final MediaSession session;
  final Color tint;

  @override
  State<_Scrubber> createState() => _ScrubberState();
}

class _ScrubberState extends State<_Scrubber> {
  /// Height of the band the rail is centred in. Reserved whether or not the
  /// session has a timeline, so a stream and a track lay the page out the same.
  static const double _band = 14;
  static const double _thumb = 11;

  double? _dragValue;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final AppServices services = AppScope.read(context);
    final IslandThemeData theme = IslandTheme.of(context);
    final IslandPalette palette = theme.palette;
    final MediaSession session = widget.session;
    final Duration micro = theme.motion.scale(DbDuration.micro);

    // A live stream has no length to scrub through. It gets the same band and
    // an empty rail rather than a bar that pretends to know where it is.
    if (!session.hasTimeline) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: DbSpace.sm),
        child: SizedBox(
          height: _band,
          child: Center(
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                color: palette.surfaceSunken,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      );
    }

    final Duration total = Duration(milliseconds: session.durationMs);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;

        void seekTo(double dx) {
          final double fraction = (dx / width).clamp(0.0, 1.0).toDouble();
          setState(() => _dragValue = fraction);
        }

        void commit() {
          final double? value = _dragValue;
          if (value != null) {
            services.media.seek(
              Duration(milliseconds: (total.inMilliseconds * value).round()),
            );
          }
          setState(() => _dragValue = null);
        }

        return AnimatedBuilder(
          animation: services.clock,
          builder: (BuildContext context, _) {
            final Duration position = session.positionAt(services.clock.now);
            final double live = total.inMilliseconds <= 0
                ? 0
                : (position.inMilliseconds / total.inMilliseconds)
                      .clamp(0.0, 1.0)
                      .toDouble();
            final double shown = _dragValue ?? live;
            final bool dragging = _dragValue != null;
            final bool active = dragging || _hovered;
            final Duration shownPosition = dragging
                ? Duration(milliseconds: (total.inMilliseconds * shown).round())
                : position;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => setState(() => _hovered = true),
                  onExit: (_) => setState(() => _hovered = false),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (TapDownDetails d) => seekTo(d.localPosition.dx),
                    onTapUp: (_) => commit(),
                    onHorizontalDragUpdate: (DragUpdateDetails d) =>
                        seekTo(d.localPosition.dx),
                    onHorizontalDragEnd: (_) => commit(),
                    child: Padding(
                      // A 3px rail is impossible to hit; the gesture area is
                      // several times taller than the mark it controls.
                      padding: const EdgeInsets.symmetric(vertical: DbSpace.sm),
                      child: SizedBox(
                        height: _band,
                        child: TweenAnimationBuilder<double>(
                          // The position is already interpolated from the
                          // clock, so this only carries it the one second to
                          // the next tick - linearly, or it would lag the
                          // audio it is describing.
                          tween: Tween<double>(begin: shown, end: shown),
                          duration: Duration(
                            seconds: session.isPlaying && !dragging ? 1 : 0,
                          ),
                          curve: Curves.linear,
                          builder:
                              (BuildContext context, double animated, _) {
                                return _Rail(
                                  value: animated,
                                  width: width,
                                  active: active,
                                  tint: widget.tint,
                                  palette: palette,
                                  duration: micro,
                                  band: _band,
                                  thumb: _thumb,
                                );
                              },
                        ),
                      ),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    // Deliberately not rolled digit by digit: a numeral
                    // animating once a second at the top of the screen is the
                    // ambient motion this design exists to avoid.
                    Text(
                      Formatters.duration(shownPosition),
                      style: DbType.numeric.copyWith(
                        fontSize: 11,
                        color: dragging ? widget.tint : palette.textSecondary,
                      ),
                    ),
                    Text(
                      Formatters.duration(total),
                      style: DbType.numeric.copyWith(
                        fontSize: 11,
                        color: palette.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// The rail itself: a track, a fill, and a handle that exists while it can be
/// used and not before.
class _Rail extends StatelessWidget {
  const _Rail({
    required this.value,
    required this.width,
    required this.active,
    required this.tint,
    required this.palette,
    required this.duration,
    required this.band,
    required this.thumb,
  });

  final double value;
  final double width;
  final bool active;
  final Color tint;
  final IslandPalette palette;
  final Duration duration;
  final double band;
  final double thumb;

  @override
  Widget build(BuildContext context) {
    // The rail thickens under the pointer to say it can be grabbed. The height
    // is animated once, here, and the fill is then drawn at an exact width:
    // an implicit animation on the fill itself would be restarted every frame
    // by the clock and would trail the audio it is describing.
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: active ? 5 : 3, end: active ? 5 : 3),
      duration: duration,
      curve: DbCurve.standard,
      builder: (BuildContext context, double height, _) {
        final double filled = (width * value.clamp(0.0, 1.0)).clamp(0.0, width);

        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(
              child: Center(
                child: Container(
                  height: height,
                  decoration: BoxDecoration(
                    color: palette.surfaceSunken,
                    borderRadius: BorderRadius.circular(height),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: (band - height) / 2,
              child: Container(
                width: filled,
                height: height,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(height),
                ),
              ),
            ),
            Positioned(
              left: filled - thumb / 2,
              top: (band - thumb) / 2,
              child: AnimatedScale(
                scale: active ? 1 : 0,
                duration: duration,
                curve: DbCurve.standard,
                child: Container(
                  width: thumb,
                  height: thumb,
                  decoration: BoxDecoration(
                    color: tint,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: palette.isDark
                          ? const Color(0x33000000)
                          : const Color(0x22FFFFFF),
                      width: DbSize.hairline,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Previous, play/pause, next - centred, because a music player's controls
/// belong under the music rather than off to one side of it.
class _Transport extends StatelessWidget {
  const _Transport({
    required this.media,
    required this.session,
    required this.tint,
  });

  final MediaController media;
  final MediaSession session;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final bool playing = session.isPlaying;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        IslandButton(
          icon: DbIcons.previous,
          tooltip: 'Previous track',
          onPressed: session.canPrevious ? media.previous : null,
        ),
        const SizedBox(width: DbSpace.lg),
        IslandButton(
          icon: playing ? DbIcons.pause : DbIcons.play,
          tone: IslandButtonTone.accent,
          tint: tint,
          size: DbSize.controlLg,
          tooltip: playing ? 'Pause' : 'Play',
          onPressed: session.canPause || session.canPlay
              ? media.playPause
              : null,
        ),
        const SizedBox(width: DbSpace.lg),
        IslandButton(
          icon: DbIcons.next,
          tooltip: 'Next track',
          onPressed: session.canNext ? media.next : null,
        ),
      ],
    );
  }
}

/// Windows reports a raw AppUserModelId. The executable stem is the closest
/// thing to a friendly name available without a package manifest, and it is
/// capitalised here because `spotify` in a chip looks like a bug.
String appLabel(String sourceAppId) {
  if (sourceAppId.isEmpty) {
    return '';
  }
  final String trimmed = sourceAppId.split('!').first;
  final String file = trimmed.split(RegExp(r'[\\/]')).last;
  final String stem = file.toLowerCase().endsWith('.exe')
      ? file.substring(0, file.length - 4)
      : file;
  if (stem.isEmpty) {
    return '';
  }
  return stem[0].toUpperCase() + stem.substring(1);
}
