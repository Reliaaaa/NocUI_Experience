import 'package:flutter/widgets.dart';

import '../../core/utils/formatters.dart';
import '../../design/tokens/db_icons.dart';
import '../downloads/download_activity.dart';
import '../downloads/downloads_controller.dart';
import '../media/media_controller.dart';
import '../system/system_controller.dart';
import '../timers/island_timer.dart';
import '../timers/timer_controller.dart';
import 'live_activity.dart';

/// Collects what is currently happening into a short, ordered list.
///
/// Deliberately a derived view: it holds no state of its own and stores
/// nothing. Each rebuild reads the modules that already own the truth, so an
/// activity can never disagree with the page it came from.
///
/// The collapsed island shows at most two of these, so the ordering in
/// [LiveActivity.priority] is doing real work - it decides what a glance at the
/// top of the screen tells you.
class ActivityCenter extends ChangeNotifier {
  ActivityCenter({
    required MediaController media,
    required DownloadsController downloads,
    required TimerController timers,
    required SystemController system,
  })  : _media = media,
        _downloads = downloads,
        _timers = timers,
        _system = system {
    for (final Listenable source in <Listenable>[
      _media,
      _downloads,
      _timers,
      _system,
    ]) {
      source.addListener(_onSourceChanged);
    }
  }

  /// How many fit beside the clock before the pill gets silly.
  static const int maxVisible = 2;

  final MediaController _media;
  final DownloadsController _downloads;
  final TimerController _timers;
  final SystemController _system;

  List<LiveActivity> _cache = const <LiveActivity>[];
  bool _dirty = true;

  void _onSourceChanged() {
    _dirty = true;
    notifyListeners();
  }

  /// Everything currently live, most important first.
  List<LiveActivity> get activities {
    if (_dirty) {
      _cache = _collect();
      _dirty = false;
    }
    return _cache;
  }

  /// The ones the collapsed pill has room for.
  List<LiveActivity> get visible =>
      activities.take(maxVisible).toList(growable: false);

  bool get hasActivities => activities.isNotEmpty;

  List<LiveActivity> _collect() {
    final DateTime now = DateTime.now();
    final List<LiveActivity> found = <LiveActivity>[];

    // Recording outranks everything: it is the one entry here the user may
    // need to act on immediately.
    if (_system.privacy.microphoneInUse || _system.privacy.cameraInUse) {
      final bool both =
          _system.privacy.microphoneInUse && _system.privacy.cameraInUse;
      found.add(
        LiveActivity(
          id: 'recording',
          kind: ActivityKind.recording,
          icon: _system.privacy.cameraInUse && !both
              ? DbIcons.camera
              : DbIcons.microphone,
          label: both ? 'Live' : (_system.privacy.cameraInUse ? 'Cam' : 'Mic'),
          urgent: true,
        ),
      );
    }

    final IslandTimer? timer = _timers.primary;
    if (timer != null && (timer.isRunning || timer.isFinished)) {
      final Duration value = timer.kind == TimerKind.countdown
          ? timer.remainingAt(now)
          : timer.elapsedAt(now);
      found.add(
        LiveActivity(
          id: 'timer.${timer.id}',
          kind: ActivityKind.timer,
          icon: timer.isFinished ? DbIcons.check : DbIcons.timer,
          label: Formatters.duration(value),
          progress: timer.progressAt(now),
          urgent: timer.isFinished,
        ),
      );
    }

    if (_downloads.hasActivity) {
      final DownloadActivity? lead = _downloads.primary;
      final int count = _downloads.active.length;
      found.add(
        LiveActivity(
          id: 'downloads',
          kind: ActivityKind.download,
          icon: DbIcons.download,
          label: count > 1
              ? '$count files'
              : Formatters.rate(_downloads.totalRate),
          progress: lead?.progress,
        ),
      );
    }

    // Battery only speaks up when it has something to say.
    if (_system.power.hasBattery &&
        (_system.power.isLow || _system.power.isCritical)) {
      found.add(
        LiveActivity(
          id: 'battery',
          kind: ActivityKind.battery,
          icon: DbIcons.battery,
          label: '${_system.power.percent}%',
          progress: _system.power.percent / 100,
          urgent: _system.power.isCritical,
        ),
      );
    }

    if (_media.hasSession && _media.session.isPlaying) {
      found.add(
        LiveActivity(
          id: 'media',
          kind: ActivityKind.media,
          icon: DbIcons.play,
          label: _media.session.shortLabel,
        ),
      );
    }

    found.sort((LiveActivity a, LiveActivity b) =>
        a.priority.compareTo(b.priority));
    return List<LiveActivity>.unmodifiable(found);
  }

  @override
  void dispose() {
    for (final Listenable source in <Listenable>[
      _media,
      _downloads,
      _timers,
      _system,
    ]) {
      source.removeListener(_onSourceChanged);
    }
    super.dispose();
  }
}
