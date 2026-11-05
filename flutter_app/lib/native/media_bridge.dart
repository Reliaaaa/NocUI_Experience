import 'dart:typed_data';

import 'native_channel.dart';

/// Playback state reported by the Windows media session.
enum MediaStatus { closed, opened, changing, stopped, playing, paused, unknown }

MediaStatus _statusFromName(String? name) {
  for (final status in MediaStatus.values) {
    if (status.name == name) {
      return status;
    }
  }
  return MediaStatus.unknown;
}

/// An immutable view of the current media session.
///
/// [positionMs] is the position *at the moment [updatedAt] was recorded*, not
/// now. Windows reports timeline updates as they happen rather than on a tick,
/// so the live position is derived from this snapshot; see [positionAt].
class MediaSession {
  const MediaSession({
    required this.hasSession,
    required this.sourceAppId,
    required this.title,
    required this.artist,
    required this.album,
    required this.status,
    required this.canPlay,
    required this.canPause,
    required this.canNext,
    required this.canPrevious,
    required this.positionMs,
    required this.durationMs,
    required this.updatedAt,
    required this.artworkId,
  });

  static const MediaSession none = MediaSession(
    hasSession: false,
    sourceAppId: '',
    title: '',
    artist: '',
    album: '',
    status: MediaStatus.closed,
    canPlay: false,
    canPause: false,
    canNext: false,
    canPrevious: false,
    positionMs: 0,
    durationMs: 0,
    updatedAt: null,
    artworkId: 0,
  );

  final bool hasSession;
  final String sourceAppId;
  final String title;
  final String artist;
  final String album;
  final MediaStatus status;
  final bool canPlay;
  final bool canPause;
  final bool canNext;
  final bool canPrevious;
  final int positionMs;
  final int durationMs;
  final DateTime? updatedAt;
  final int artworkId;

  bool get isPlaying => status == MediaStatus.playing;
  bool get hasTimeline => durationMs > 0;

  /// Position interpolated to [now].
  ///
  /// This is why the progress bar can move smoothly without a single platform
  /// call: while playing, elapsed wall time is added to the last reported
  /// position and clamped to the track length.
  Duration positionAt(DateTime now) {
    final DateTime? measured = updatedAt;
    if (!isPlaying || measured == null) {
      return Duration(milliseconds: positionMs);
    }
    final int elapsed = now.difference(measured).inMilliseconds;
    final int projected = positionMs + (elapsed < 0 ? 0 : elapsed);
    if (durationMs > 0 && projected > durationMs) {
      return Duration(milliseconds: durationMs);
    }
    return Duration(milliseconds: projected);
  }

  /// A one line description of what is playing, for the collapsed island.
  String get shortLabel {
    if (title.isEmpty) {
      return artist.isEmpty ? 'Playing' : artist;
    }
    return title;
  }

  static MediaSession fromMap(Map<Object?, Object?> map) {
    final int updatedAtMs = (map['updatedAtMs'] as num?)?.toInt() ?? 0;
    return MediaSession(
      hasSession: (map['hasSession'] as bool?) ?? false,
      sourceAppId: (map['sourceAppId'] as String?) ?? '',
      title: (map['title'] as String?) ?? '',
      artist: (map['artist'] as String?) ?? '',
      album: (map['album'] as String?) ?? '',
      status: _statusFromName(map['status'] as String?),
      canPlay: (map['canPlay'] as bool?) ?? false,
      canPause: (map['canPause'] as bool?) ?? false,
      canNext: (map['canNext'] as bool?) ?? false,
      canPrevious: (map['canPrevious'] as bool?) ?? false,
      positionMs: (map['positionMs'] as num?)?.toInt() ?? 0,
      durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
      updatedAt: updatedAtMs > 0
          ? DateTime.fromMillisecondsSinceEpoch(updatedAtMs)
          : null,
      artworkId: (map['artworkId'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Album art bytes plus the identity of the track they belong to.
class MediaArtwork {
  const MediaArtwork({required this.id, required this.bytes});

  final int id;
  final Uint8List bytes;

  bool get isEmpty => bytes.isEmpty;
}

/// Transport control for the active Windows media session.
class MediaBridge extends NativeChannel {
  MediaBridge()
    : super('dynamicbar/media', eventChannelName: 'dynamicbar/media/events');

  Future<void> start() => invoke<void>('start');
  Future<void> refresh() => invoke<void>('refresh');

  Future<bool> play() async => await invoke<bool>('play') ?? false;
  Future<bool> pause() async => await invoke<bool>('pause') ?? false;
  Future<bool> playPause() async => await invoke<bool>('playPause') ?? false;
  Future<bool> next() async => await invoke<bool>('next') ?? false;
  Future<bool> previous() async => await invoke<bool>('previous') ?? false;

  Future<bool> seek(Duration position) async =>
      await invoke<bool>('seek', <String, Object?>{
        'positionMs': position.inMilliseconds.toDouble(),
      }) ??
      false;
}
