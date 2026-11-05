import 'package:dynamicbar/core/utils/formatters.dart';
import 'package:dynamicbar/island/state/island_metrics.dart';
import 'package:dynamicbar/island/state/island_state.dart';
import 'package:dynamicbar/modules/downloads/download_activity.dart';
import 'package:dynamicbar/native/media_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MediaSession', () {
    final DateTime measured = DateTime(2026, 9, 7, 12);

    MediaSession session({
      required MediaStatus status,
      int positionMs = 30000,
      int durationMs = 180000,
    }) {
      return MediaSession(
        hasSession: true,
        sourceAppId: r'C:\Program Files\Player\player.exe',
        title: 'Track',
        artist: 'Artist',
        album: 'Album',
        status: status,
        canPlay: true,
        canPause: true,
        canNext: true,
        canPrevious: true,
        positionMs: positionMs,
        durationMs: durationMs,
        updatedAt: measured,
        artworkId: 1,
      );
    }

    test('projects the playing position forward from the last report', () {
      final MediaSession playing = session(status: MediaStatus.playing);
      expect(
        playing.positionAt(measured.add(const Duration(seconds: 10))),
        const Duration(seconds: 40),
      );
    });

    test('a paused session holds its reported position', () {
      final MediaSession paused = session(status: MediaStatus.paused);
      expect(
        paused.positionAt(measured.add(const Duration(minutes: 5))),
        const Duration(seconds: 30),
      );
    });

    test('never projects past the end of the track', () {
      final MediaSession playing = session(status: MediaStatus.playing);
      expect(
        playing.positionAt(measured.add(const Duration(hours: 1))),
        const Duration(milliseconds: 180000),
      );
    });

    test('parses a native payload and its absences', () {
      final MediaSession parsed = MediaSession.fromMap(<Object?, Object?>{
        'hasSession': true,
        'title': 'Song',
        'status': 'playing',
        'positionMs': 1000,
      });
      expect(parsed.hasSession, isTrue);
      expect(parsed.title, 'Song');
      expect(parsed.status, MediaStatus.playing);
      expect(parsed.artist, '');
      expect(parsed.updatedAt, isNull);
      expect(parsed.hasTimeline, isFalse);
    });

    test('an unknown status does not throw', () {
      final MediaSession parsed = MediaSession.fromMap(<Object?, Object?>{
        'status': 'levitating',
      });
      expect(parsed.status, MediaStatus.unknown);
    });

    test('falls back to the artist when a track has no title', () {
      const MediaSession noTitle = MediaSession(
        hasSession: true,
        sourceAppId: '',
        title: '',
        artist: 'Artist',
        album: '',
        status: MediaStatus.playing,
        canPlay: true,
        canPause: true,
        canNext: false,
        canPrevious: false,
        positionMs: 0,
        durationMs: 0,
        updatedAt: null,
        artworkId: 0,
      );
      expect(noTitle.shortLabel, 'Artist');
    });
  });

  group('DownloadActivity', () {
    test('reports no progress when the total size is unknown', () {
      final DownloadActivity activity = DownloadActivity(
        id: '1',
        name: 'film.mkv',
        bytes: 1024,
        startedAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      expect(activity.progress, isNull);
      expect(activity.isActive, isTrue);
    });

    test('reports progress once the total is known', () {
      final DownloadActivity activity = DownloadActivity(
        id: '1',
        name: 'film.mkv',
        bytes: 512,
        totalBytes: 1024,
        startedAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      expect(activity.progress, closeTo(0.5, 1e-9));
    });

    test('maps native outcome names', () {
      expect(
        DownloadActivity.outcomeFromName('completed'),
        DownloadOutcome.completed,
      );
      expect(
        DownloadActivity.outcomeFromName('cancelled'),
        DownloadOutcome.cancelled,
      );
      expect(DownloadActivity.outcomeFromName(null), DownloadOutcome.active);
    });
  });

  group('Formatters', () {
    test('byte sizes', () {
      expect(Formatters.bytes(0), '0 B');
      expect(Formatters.bytes(512), '512 B');
      expect(Formatters.bytes(1536), '1.5 KB');
      expect(Formatters.bytes(1024 * 1024 * 3), '3.0 MB');
    });

    test('transfer rates', () {
      expect(Formatters.rate(0), '--');
      expect(Formatters.rate(1024), '1.0 KB/s');
    });

    test('durations', () {
      expect(Formatters.duration(const Duration(seconds: 65)), '1:05');
      expect(
        Formatters.duration(const Duration(hours: 1, minutes: 2)),
        '1:02:00',
      );
      expect(Formatters.duration(const Duration(seconds: -5)), '0:00');
    });

    test('remaining time is null when it cannot be known', () {
      expect(Formatters.remaining(10, 0, 100), isNull);
      expect(Formatters.remaining(10, 100, 0), isNull);
      expect(Formatters.remaining(0, 100, 10), const Duration(seconds: 10));
    });

    test('file names shorten from the middle and keep the extension', () {
      const String long = 'a-very-long-download-file-name-indeed-really.mkv';
      final String short = Formatters.fileName(long, maxLength: 20);
      expect(short.length, lessThanOrEqualTo(20));
      expect(short.endsWith('.mkv'), isTrue);
      expect(Formatters.fileName('short.txt'), 'short.txt');
    });
  });

  group('Island geometry contract', () {
    test('every mode fits inside the declared stage maximum', () {
      for (final IslandMode mode in IslandMode.values) {
        expect(
          IslandMetrics.fitsInStage(mode),
          isTrue,
          reason: '${mode.name} is larger than the stage can hold',
        );
      }
    });

    test('every mode has a collapsed form smaller than its expanded one', () {
      for (final IslandMode mode in IslandMode.values) {
        final collapsed = IslandMetrics.collapsedSizeFor(mode);
        final expanded = IslandMetrics.expandedSizeFor(mode);
        expect(collapsed.width, lessThan(expanded.width));
        expect(collapsed.height, lessThan(expanded.height));
      }
    });

    test('only notifications are transient', () {
      expect(IslandMode.notification.isTransient, isTrue);
      expect(IslandMode.media.isTransient, isFalse);
      expect(IslandMode.idle.isTransient, isFalse);
    });
  });
}
