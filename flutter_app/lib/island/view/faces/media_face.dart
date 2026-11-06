import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../../../app/app_services.dart';
import '../../../core/time/seconds_scope.dart';
import '../../../core/utils/formatters.dart';
import '../../../design/components/island_button.dart';
import '../../../design/components/island_progress.dart';
import '../../../design/components/sound_bars.dart';
import '../../../design/components/staggered_reveal.dart';
import '../../../design/theme/island_theme.dart';
import '../../../design/tokens/db_colors.dart';
import '../../../design/tokens/db_dimens.dart';
import '../../../design/tokens/db_icons.dart';
import '../../../design/tokens/db_motion.dart';
import '../../../design/tokens/db_typography.dart';
import '../../../modules/media/media_controller.dart';
import '../../../native/media_bridge.dart';

/// Collapsed media face: what is playing, and that it is playing.
class MediaCollapsed extends StatelessWidget {
  const MediaCollapsed({super.key});

  @override
  Widget build(BuildContext context) {
    final MediaController media = AppScope.read(context).media;
    final IslandPalette palette = IslandTheme.of(context).palette;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DbSpace.lg),
      child: AnimatedBuilder(
        animation: media,
        builder: (BuildContext context, _) {
          final MediaSession session = media.session;
          return Row(
            children: <Widget>[
              _Artwork(
                bytes: media.artwork,
                artworkId: media.artworkId,
                size: 20,
                radius: 6,
              ),
              const SizedBox(width: DbSpace.md),
              Expanded(
                child: Text(
                  session.shortLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: DbType.label.copyWith(color: palette.textPrimary),
                ),
              ),
              const SizedBox(width: DbSpace.md),
              SoundBars(
                active: session.isPlaying,
                color: palette.accent,
                height: 11,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Expanded media face: artwork, metadata, timeline and transport.
class MediaExpanded extends StatelessWidget {
  const MediaExpanded({super.key});

  @override
  Widget build(BuildContext context) {
    final AppServices services = AppScope.read(context);
    final MediaController media = services.media;
    final IslandPalette palette = IslandTheme.of(context).palette;

    return SecondsScope(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          DbSpace.xl,
          DbSpace.lg,
          DbSpace.xl,
          DbSpace.lg,
        ),
        child: AnimatedBuilder(
          animation: media,
          builder: (BuildContext context, _) {
            final MediaSession session = media.session;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Reveal(
                      order: 0,
                      scaleFrom: 0.9,
                      child: _Artwork(
                        bytes: media.artwork,
                        artworkId: media.artworkId,
                        size: 72,
                        radius: DbRadius.card,
                      ),
                    ),
                    const SizedBox(width: DbSpace.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const SizedBox(height: DbSpace.xxs),
                          Reveal(
                            order: 1,
                            child: Text(
                              session.title.isEmpty
                                  ? 'Nothing playing'
                                  : session.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DbType.title.copyWith(
                                color: palette.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(height: DbSpace.xxs),
                          Text(
                            session.artist.isEmpty ? '—' : session.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DbType.body.copyWith(
                              color: palette.textSecondary,
                            ),
                          ),
                          if (session.album.isNotEmpty) ...<Widget>[
                            const SizedBox(height: DbSpace.xxs),
                            Text(
                              session.album,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DbType.caption.copyWith(
                                color: palette.textTertiary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Reveal(order: 2, child: _Timeline(session: session)),
                const SizedBox(height: DbSpace.md),
                Reveal(
                  order: 3,
                  scaleFrom: 0.94,
                  child: _Transport(media: media, session: session),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Elapsed / remaining readout and the seek rail.
///
/// The position is interpolated from the session snapshot, so this advances
/// smoothly while costing one rebuild per second and no platform calls at all.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.session});

  final MediaSession session;

  @override
  Widget build(BuildContext context) {
    final AppServices services = AppScope.read(context);
    final IslandPalette palette = IslandTheme.of(context).palette;

    if (!session.hasTimeline) {
      return const SizedBox(height: 3);
    }

    return AnimatedBuilder(
      animation: services.clock,
      builder: (BuildContext context, _) {
        final Duration position = session.positionAt(services.clock.now);
        final Duration total = Duration(milliseconds: session.durationMs);
        final double value = total.inMilliseconds <= 0
            ? 0
            : (position.inMilliseconds / total.inMilliseconds)
                  .clamp(0.0, 1.0)
                  .toDouble();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // A one second linear tween between samples, so the rail glides
            // instead of stepping once per second.
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: value, end: value),
              duration: Duration(seconds: session.isPlaying ? 1 : 0),
              curve: Curves.linear,
              builder: (BuildContext context, double animated, _) {
                return IslandProgressBar(
                  value: animated,
                  color: palette.accent,
                  animateChanges: false,
                );
              },
            ),
            const SizedBox(height: DbSpace.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  Formatters.duration(position),
                  style: DbType.caption.copyWith(color: palette.textTertiary),
                ),
                Text(
                  Formatters.duration(total),
                  style: DbType.caption.copyWith(color: palette.textTertiary),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _Transport extends StatelessWidget {
  const _Transport({required this.media, required this.session});

  final MediaController media;
  final MediaSession session;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    final bool playing = session.isPlaying;

    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            _appLabel(session.sourceAppId),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DbType.caption.copyWith(color: palette.textTertiary),
          ),
        ),
        IslandButton(
          icon: DbIcons.previous,
          tooltip: 'Previous track',
          onPressed: session.canPrevious ? media.previous : null,
        ),
        const SizedBox(width: DbSpace.sm),
        IslandButton(
          icon: playing ? DbIcons.pause : DbIcons.play,
          tone: IslandButtonTone.accent,
          size: DbSize.controlLg,
          tooltip: playing ? 'Pause' : 'Play',
          onPressed: session.canPause || session.canPlay
              ? media.playPause
              : null,
        ),
        const SizedBox(width: DbSpace.sm),
        IslandButton(
          icon: DbIcons.next,
          tooltip: 'Next track',
          onPressed: session.canNext ? media.next : null,
        ),
      ],
    );
  }

  /// Windows reports a raw AppUserModelId. The executable stem is the closest
  /// thing to a friendly name available without a package manifest.
  static String _appLabel(String sourceAppId) {
    if (sourceAppId.isEmpty) {
      return '';
    }
    final String trimmed = sourceAppId.split('!').first;
    final String file = trimmed.split(RegExp(r'[\\/]')).last;
    return file.toLowerCase().endsWith('.exe')
        ? file.substring(0, file.length - 4)
        : file;
  }
}

/// Album art, or a tinted placeholder when the track has none.
class _Artwork extends StatelessWidget {
  const _Artwork({
    required this.bytes,
    required this.artworkId,
    required this.size,
    required this.radius,
  });

  final Uint8List bytes;
  final int artworkId;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final IslandThemeData theme = IslandTheme.of(context);
    final IslandPalette palette = theme.palette;

    final Widget placeholder = DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surfaceSunken,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Center(
        child: Icon(
          DbIcons.play,
          size: size * 0.5,
          color: palette.textTertiary,
        ),
      ),
    );

    return SizedBox(
      width: size,
      height: size,
      child: AnimatedSwitcher(
        duration: theme.motion.scale(DbDuration.standard),
        switchInCurve: DbCurve.standard,
        switchOutCurve: DbCurve.exit,
        // Artwork cross-fades and eases in a touch, which is what makes a
        // track change feel like a change of subject rather than a redraw.
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.94, end: 1).animate(animation),
              child: child,
            ),
          );
        },
        child: bytes.isEmpty
            ? KeyedSubtree(
                key: const ValueKey<String>('no-art'),
                child: placeholder,
              )
            : ClipRRect(
                key: ValueKey<int>(artworkId),
                borderRadius: BorderRadius.circular(radius),
                child: Image.memory(
                  bytes,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.medium,
                  errorBuilder:
                      (
                        BuildContext context,
                        Object error,
                        StackTrace? stackTrace,
                      ) => placeholder,
                ),
              ),
      ),
    );
  }
}
