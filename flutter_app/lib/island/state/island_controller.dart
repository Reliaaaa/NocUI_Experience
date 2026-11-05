import 'package:flutter/foundation.dart';

import '../../core/logging/app_logger.dart';
import 'island_page.dart';
import 'island_state.dart';

/// The island state machine.
///
/// Holds intent, hover, focus and mode; knows nothing about pixels, springs or
/// Windows. The view observes it and animates towards whatever it says, and
/// reports the resulting progress back so that [phase] describes what is
/// actually on screen rather than what was asked for.
class IslandController extends ChangeNotifier {
  IslandController();

  static const Logger _log = Logger('Island');

  IslandIntent _intent = IslandIntent.collapsed;
  IslandMode _mode = IslandMode.idle;
  IslandTrigger _lastTrigger = IslandTrigger.system;

  bool _hovered = false;
  bool _focused = false;
  bool _paused = false;

  IslandPage _page = IslandPage.now;
  List<IslandPage> _pages = const <IslandPage>[IslandPage.now];

  double _attention = 0;
  double _progress = 0;
  double _velocity = 0;
  IslandPhase _phase = IslandPhase.collapsed;

  IslandIntent get intent => _intent;

  /// The page the expanded island is showing.
  IslandPage get page => _page;

  /// Pages currently reachable, in order. Modules that are switched off are
  /// absent rather than shown empty.
  List<IslandPage> get pages => _pages;

  int get pageIndex {
    final int index = _pages.indexOf(_page);
    return index < 0 ? 0 : index;
  }

  bool get canGoBack => pageIndex > 0;
  bool get canGoForward => pageIndex < _pages.length - 1;

  /// Replaces the reachable set. Keeps the current page if it survived, and
  /// otherwise falls back to the first one, which is always Now.
  void setPages(List<IslandPage> pages) {
    if (pages.isEmpty || _listEquals(pages, _pages)) {
      return;
    }
    _pages = List<IslandPage>.unmodifiable(pages);
    if (!_pages.contains(_page)) {
      _page = _pages.first;
    }
    notifyListeners();
  }

  void goToPage(IslandPage page) {
    if (_page == page || !_pages.contains(page)) {
      return;
    }
    _page = page;
    notifyListeners();
  }

  void goToPageIndex(int index) {
    if (index < 0 || index >= _pages.length) {
      return;
    }
    goToPage(_pages[index]);
  }

  void nextPage() => goToPageIndex(pageIndex + 1);
  void previousPage() => goToPageIndex(pageIndex - 1);

  static bool _listEquals(List<IslandPage> a, List<IslandPage> b) {
    if (a.length != b.length) {
      return false;
    }
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
  IslandMode get mode => _mode;
  IslandTrigger get lastTrigger => _lastTrigger;
  IslandPhase get phase => _phase;

  bool get isHovered => _hovered;
  bool get isFocused => _focused;

  /// Paused means the island stays out of the way entirely: hidden, ignoring
  /// the mouse, and not reacting to events. Toggled from the tray.
  bool get isPaused => _paused;

  bool get isExpanded => _intent == IslandIntent.expanded;
  bool get isHidden => _intent == IslandIntent.hidden;

  /// 0 at the collapsed size, 1 fully expanded. Reported by the view.
  double get progress => _progress;

  /// How much the island should be asking to be looked at, 0..1.
  ///
  /// Drives a single soft halo, and nothing else. It is set only for high
  /// priority notifications, so the effect keeps its meaning: if everything
  /// glowed, the glow would say nothing.
  double get attention => _attention;

  void setAttention(double value) {
    final double clamped = value.clamp(0.0, 1.0).toDouble();
    if ((_attention - clamped).abs() < 0.001) {
      return;
    }
    _attention = clamped;
    notifyListeners();
  }

  // --- Intent ---------------------------------------------------------------

  void expand({
    IslandTrigger trigger = IslandTrigger.user,
    IslandPage? page,
  }) {
    if (_paused) {
      return;
    }
    if (page != null && _pages.contains(page)) {
      _page = page;
    }
    if (_intent == IslandIntent.expanded) {
      return;
    }
    _lastTrigger = trigger;
    _intent = IslandIntent.expanded;
    _log.debug('Expand (${trigger.name}).');
    _refreshPhase(force: true);
  }

  void collapse({IslandTrigger trigger = IslandTrigger.user}) {
    if (_intent == IslandIntent.collapsed) {
      return;
    }
    _lastTrigger = trigger;
    _intent = IslandIntent.collapsed;
    _focused = false;
    _log.debug('Collapse (${trigger.name}).');
    _refreshPhase(force: true);
  }

  void toggle({IslandTrigger trigger = IslandTrigger.user}) {
    if (_intent == IslandIntent.expanded) {
      collapse(trigger: trigger);
    } else {
      expand(trigger: trigger);
    }
  }

  void hide({IslandTrigger trigger = IslandTrigger.system}) {
    if (_intent == IslandIntent.hidden) {
      return;
    }
    _lastTrigger = trigger;
    _intent = IslandIntent.hidden;
    _hovered = false;
    _focused = false;
    _log.debug('Hide (${trigger.name}).');
    _refreshPhase(force: true);
  }

  void reveal({IslandTrigger trigger = IslandTrigger.system}) {
    if (_paused || _intent != IslandIntent.hidden) {
      return;
    }
    _lastTrigger = trigger;
    _intent = IslandIntent.collapsed;
    _log.debug('Reveal (${trigger.name}).');
    _refreshPhase(force: true);
  }

  void setPaused(bool value) {
    if (_paused == value) {
      return;
    }
    _paused = value;
    _log.info(value ? 'Paused.' : 'Resumed.');
    if (value) {
      _intent = IslandIntent.hidden;
      _hovered = false;
      _focused = false;
    } else {
      _intent = IslandIntent.collapsed;
    }
    _refreshPhase(force: true);
  }

  void setMode(IslandMode mode) {
    if (_mode == mode) {
      return;
    }
    _mode = mode;
    notifyListeners();
  }

  // --- Pointer and focus ----------------------------------------------------

  void setHovered(bool value) {
    if (_hovered == value || _paused) {
      return;
    }
    _hovered = value;
    // Hover never expands on its own; it only peeks. Accidental expansion from
    // a cursor crossing the top of the screen would be intolerable all day.
    _refreshPhase(force: true);
  }

  void setFocused(bool value) {
    if (_focused == value) {
      return;
    }
    _focused = value;
    _refreshPhase(force: true);
  }

  /// Called by the view every animation frame. Deliberately does not notify
  /// unless the derived [phase] actually changed: the view is already
  /// rebuilding from the spring, and a second notification per frame would
  /// rebuild everything else with it.
  void reportProgress(double progress, double velocity) {
    _progress = progress;
    _velocity = velocity;
    _refreshPhase();
  }

  void _refreshPhase({bool force = false}) {
    final IslandPhase next = _derivePhase();
    if (next == _phase && !force) {
      return;
    }
    _phase = next;
    notifyListeners();
  }

  IslandPhase _derivePhase() {
    const double epsilon = 0.02;
    if (_intent == IslandIntent.hidden && _progress <= epsilon) {
      return IslandPhase.hidden;
    }
    if (_progress >= 1 - epsilon) {
      return _focused ? IslandPhase.interactive : IslandPhase.expanded;
    }
    if (_progress <= epsilon) {
      return _intent == IslandIntent.hidden
          ? IslandPhase.hidden
          : IslandPhase.collapsed;
    }
    if (_velocity > 0) {
      return IslandPhase.expanding;
    }
    if (_velocity < 0) {
      return IslandPhase.collapsing;
    }
    return _intent == IslandIntent.expanded
        ? IslandPhase.expanding
        : IslandPhase.collapsing;
  }
}
