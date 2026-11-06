import 'package:flutter/foundation.dart';

import '../../core/logging/app_logger.dart';
import '../../modules/clipboard/clipboard_controller.dart';
import '../../modules/downloads/downloads_controller.dart';
import '../../modules/media/media_controller.dart';
import '../../modules/notifications/island_notification.dart';
import '../../modules/notifications/notification_center.dart';
import '../../modules/system/system_controller.dart';
import '../../modules/timers/timer_controller.dart';
import 'island_controller.dart';
import 'island_page.dart';
import 'island_state.dart';

/// Decides what the island shows.
///
/// The island has one face, so something has to arbitrate. The rule is simple
/// and deliberately not configurable:
///
/// 1. A live notification wins, because it is the only thing here that is
///    time-critical, and it hands the island back when it expires.
/// 2. Otherwise the most active ambient state wins: a running transfer, then
///    playing media, then a running timer.
/// 3. Otherwise the clock.
///
/// Ambient priority is ordered by how quickly the information goes stale, not
/// by how interesting it is. A download that finishes in eight seconds is worth
/// more of a 200px surface than a track that will still be playing in four
/// minutes.
class PresentationRouter extends ChangeNotifier {
  PresentationRouter({
    required IslandController island,
    required NotificationCenter notifications,
    required MediaController media,
    required DownloadsController downloads,
    required TimerController timers,
    required ClipboardController clipboard,
    required SystemController system,
  }) : _island = island,
       _notifications = notifications,
       _media = media,
       _downloads = downloads,
       _timers = timers,
       _clipboard = clipboard,
       _system = system {
    _system.addListener(_reevaluate);
    _notifications.addListener(_reevaluate);
    _media.addListener(_reevaluate);
    _downloads.addListener(_reevaluate);
    _timers.addListener(_reevaluate);
    _clipboard.addListener(_reevaluate);
    _reevaluate();
  }

  static const Logger _log = Logger('Router');

  final IslandController _island;
  final NotificationCenter _notifications;
  final MediaController _media;
  final DownloadsController _downloads;
  final TimerController _timers;
  final ClipboardController _clipboard;
  final SystemController _system;

  IslandMode _mode = IslandMode.idle;
  bool _settingsOpen = false;
  String? _settingsSection;

  IslandMode get mode => _mode;
  bool get isSettingsOpen => _settingsOpen;

  /// When supplied, settings requests are handled by a separate window.
  void Function(String? section)? onSettingsRequested;

  /// Which part of settings to land on, when whoever opened it had somewhere
  /// specific in mind. A plain string rather than the panel's own enum: this
  /// layer decides *that* settings is showing, never how it is laid out.
  String? get settingsSection => _settingsSection;

  /// Settings takes the island over completely: it is the one thing here the
  /// user opened on purpose, so nothing may push it aside.
  void openSettings({String? section}) {
    final handler = onSettingsRequested;
    if (handler != null) {
      handler(section);
      return;
    }
    _settingsSection = section;
    if (_settingsOpen) {
      // Already showing, and the panel reads the section on the way in, so
      // there is nothing here for anyone to be told about.
      return;
    }
    _settingsOpen = true;
    _reevaluate();
  }

  void closeSettings() {
    _settingsSection = null;
    if (!_settingsOpen) {
      return;
    }
    _settingsOpen = false;
    _reevaluate();
  }

  /// The ambient mode the island returns to once transients have cleared.
  IslandMode get ambientMode => _resolveAmbient();

  /// The page the island should open on, given what is happening right now.
  ///
  /// Every way of opening the island - the pill, the hotkey, the tray - asks
  /// here, so a click on the pill while a track is playing lands on Media just
  /// as the hotkey does. The user moves freely from there; this only decides
  /// where the pager starts.
  ///
  /// Playing music wins over a running timer for the same reason it does in
  /// [_resolveAmbient]: it is the thing the user is most likely to want to
  /// reach for, and it is the only one of the two with controls worth landing
  /// on. A paused session does not qualify - reopening the island half an hour
  /// later should not still be showing a track nobody is listening to.
  IslandPage landingPage() {
    final List<IslandPage> pages = _island.pages;
    if (_media.hasSession &&
        _media.session.isPlaying &&
        pages.contains(IslandPage.media)) {
      return IslandPage.media;
    }
    if (_timers.hasRunning && pages.contains(IslandPage.timers)) {
      return IslandPage.timers;
    }
    return IslandPage.now;
  }

  IslandNotification? get notification => _notifications.current;

  IslandMode _resolveAmbient() {
    // A live microphone or camera outranks everything else that is ambient.
    // It is the one thing here the user may need to act on immediately, and
    // unlike a notification it must persist for as long as the capture does.
    if (_system.isRecording) {
      return IslandMode.privacy;
    }
    if (_downloads.hasActivity) {
      return IslandMode.download;
    }
    if (_media.hasSession && _media.session.isPlaying) {
      return IslandMode.media;
    }
    if (_timers.hasRunning) {
      return IslandMode.timer;
    }
    // A paused media session still outranks the clock: it is what the user was
    // last doing, and the transport controls stay one click away.
    if (_media.hasSession) {
      return IslandMode.media;
    }
    if (_timers.hasTimers) {
      return IslandMode.timer;
    }
    return IslandMode.idle;
  }

  void _reevaluate() {
    final IslandNotification? live = _notifications.current;

    // A sticky, low priority notification (an in-flight download) is a badge on
    // an ambient state, not an interruption: it should not take the island away
    // from whatever mode is already showing that same information.
    final bool interrupts =
        live != null &&
        (!live.sticky || live.priority != NotificationPriority.low);

    _island.setAttention(
      live != null && live.priority == NotificationPriority.high ? 1 : 0,
    );

    final IslandMode next = _settingsOpen
        ? IslandMode.settings
        : (interrupts ? IslandMode.notification : _resolveAmbient());

    if (next == _mode) {
      return;
    }
    _log.debug('Mode ${_mode.name} -> ${next.name}');
    _mode = next;
    _island.setMode(next);
    notifyListeners();
  }

  @override
  void dispose() {
    _system.removeListener(_reevaluate);
    _notifications.removeListener(_reevaluate);
    _media.removeListener(_reevaluate);
    _downloads.removeListener(_reevaluate);
    _timers.removeListener(_reevaluate);
    _clipboard.removeListener(_reevaluate);
    super.dispose();
  }
}
