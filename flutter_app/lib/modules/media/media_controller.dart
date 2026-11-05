import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/logging/app_logger.dart';
import '../../native/media_bridge.dart';
import '../../native/models/native_models.dart';

/// Live view of whatever Windows is playing.
///
/// The controller holds a snapshot and the artwork bytes; it never polls. The
/// playing position is derived from the snapshot at render time, so a track can
/// run for an hour without this object doing anything at all.
class MediaController extends ChangeNotifier {
  MediaController({required MediaBridge bridge}) : _bridge = bridge;

  static const Logger _log = Logger('Media');

  final MediaBridge _bridge;
  StreamSubscription<NativeEvent>? _subscription;

  MediaSession _session = MediaSession.none;
  Uint8List _artwork = Uint8List(0);
  int _artworkId = 0;
  bool _enabled = false;

  MediaSession get session => _session;

  /// Raw album art bytes, or an empty list when the track has none.
  Uint8List get artwork => _artwork;
  int get artworkId => _artworkId;

  bool get isEnabled => _enabled;
  bool get hasSession => _session.hasSession && _session.title.isNotEmpty;

  Future<void> setEnabled(bool value) async {
    if (_enabled == value) {
      return;
    }
    _enabled = value;
    if (value) {
      _subscription ??= _bridge.events.listen(_onEvent);
      await _bridge.start();
      _log.info('Media integration enabled.');
    } else {
      await _subscription?.cancel();
      _subscription = null;
      _session = MediaSession.none;
      _artwork = Uint8List(0);
      _artworkId = 0;
      _log.info('Media integration disabled.');
      notifyListeners();
    }
  }

  void _onEvent(NativeEvent event) {
    switch (event.type) {
      case 'session':
        final MediaSession next = MediaSession.fromMap(event.data);
        final bool trackChanged =
            next.title != _session.title ||
            next.artist != _session.artist ||
            next.sourceAppId != _session.sourceAppId;
        _session = next;
        if (trackChanged) {
          _log.debug('Now playing: ${next.artist} - ${next.title}');
        }
        notifyListeners();

      case 'artwork':
        final Object? bytes = event.data['bytes'];
        _artworkId = (event.data['artworkId'] as num?)?.toInt() ?? 0;
        _artwork = bytes is Uint8List ? bytes : Uint8List(0);
        notifyListeners();

      default:
        break;
    }
  }

  Future<void> playPause() => _bridge.playPause();
  Future<void> play() => _bridge.play();
  Future<void> pause() => _bridge.pause();
  Future<void> next() => _bridge.next();
  Future<void> previous() => _bridge.previous();
  Future<void> seek(Duration position) => _bridge.seek(position);

  /// Re-reads the session. Used after a resume from sleep, where a media
  /// application may have been restarted while we were not running.
  Future<void> refresh() => _bridge.refresh();

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }
}
