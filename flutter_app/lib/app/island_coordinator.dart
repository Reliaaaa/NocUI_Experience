import 'dart:async';
import 'dart:ui';

import '../core/events/app_event.dart';
import '../core/logging/app_logger.dart';
import '../island/state/island_metrics.dart';
import '../island/state/island_page.dart';
import '../island/state/island_state.dart';
import '../native/hotkey_bridge.dart';
import '../native/models/native_models.dart';
import '../native/startup_bridge.dart';
import '../native/system_bridge.dart';
import '../settings/app_settings.dart';
import 'app_services.dart';

/// Wires the native desktop to the island state machine.
///
/// Everything that crosses the boundary between Windows and the UI passes
/// through here: window, tray, hotkey and sensor events in; placement, focus
/// policy, startup registration and shortcut registration out. Keeping it in
/// one object means the widgets never touch a platform channel, and the rules
/// for recovering from a changed desktop live in a single readable place.
class IslandCoordinator {
  IslandCoordinator({required this.services, this.launchArguments = const []});

  static const Logger _log = Logger('Coordinator');

  static const String _menuOpen = 'open';
  static const String _menuPause = 'pause';
  static const String _menuStartup = 'startup';
  static const String _menuSettings = 'settings';
  static const String _menuQuit = 'quit';
  static const String _menuDisplayPrefix = 'display:';
  static const String _menuDisplayAuto = 'display:auto';

  /// A pointer crossing the top of the screen on its way somewhere else must
  /// not wake the island up, and a hand resting on the boundary must not make
  /// it flicker. Both numbers come from docs/MOTION.md.
  static const Duration _hoverOpenDelay = Duration(milliseconds: 70);
  static const Duration _hoverCancelGrace = Duration(milliseconds: 180);

  /// How long after the pointer leaves the reveal zone the island withdraws
  /// again, when it is only on screen *because* the pointer arrived.
  ///
  /// Short on purpose. The full [AppSettings.autoHideSeconds] countdown is for
  /// an island that has been used and left alone; a pointer that has moved on
  /// has already said where it is going, and making it wait several seconds
  /// would be the "always showing" behaviour this feature exists to avoid.
  static const Duration _pointerLeaveHide = Duration(milliseconds: 260);

  static const String _hotkeyToggle = 'toggle';
  static const String _hotkeyExpand = 'expand';
  static const String _hotkeyHide = 'hide';

  final AppServices services;

  /// Command line the process was started with. `--autostart` means Windows
  /// launched us at sign-in, which is the only case where the start delay
  /// applies.
  final List<String> launchArguments;

  StreamSubscription<NativeEvent>? _windowEvents;
  StreamSubscription<NativeEvent>? _trayEvents;
  StreamSubscription<NativeEvent>? _hotkeyEvents;

  List<DisplayInfo> _displays = const <DisplayInfo>[];
  Timer? _autoCollapse;
  Timer? _autoHide;
  Timer? _proximityDebounce;
  bool _proximityWatch = false;
  bool _hiddenForAutoHide = false;
  bool _cursorNear = false;

  /// True while the island is visible only because the pointer approached it,
  /// rather than because the user opened it.
  bool _revealedByPointer = false;
  bool _wasPaused = false;
  StartupStatus _startupStatus = StartupStatus.unknown;
  bool _suppressedForPresentation = false;
  bool _started = false;
  Timer? _startupDelay;

  bool get isAutoStart => launchArguments.contains('--autostart');
  StartupStatus get startupStatus => _startupStatus;
  List<DisplayInfo> get displays => _displays;

  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;

    _windowEvents = services.window.events.listen(_onWindowEvent);
    _trayEvents = services.tray.events.listen(_onTrayEvent);
    _hotkeyEvents = services.hotkeys.events.listen(_onHotkeyEvent);
    services.island.addListener(_onIslandChanged);
    services.settings.addListener(_onSettingsChanged);
    services.system.addListener(_onSystemChanged);
    services.router.addListener(_onRouterChanged);

    services.activities.addListener(_onActivitiesChanged);
    // A dropped image should be visible where it landed. Anything else - a
    // silent save, a toast - leaves the user wondering whether it worked.
    services.shelf.onDropped = _onShelfDrop;
    applyPages();

    await _refreshDisplays();
    await applyPlacement();
    await applyFeatureFlags();
    await applyAutoHide();
    await applyStartup();
    await applyHotkeys();

    await services.tray.install(tooltip: 'Notch X');
    await _publishTrayMenu(force: true);

    await _revealAtLaunch();
    _log.info('Coordinator started.');
  }

  Future<void> stop() async {
    if (!_started) {
      return;
    }
    _started = false;
    _startupDelay?.cancel();
    _autoCollapse?.cancel();
    _autoHide?.cancel();
    _proximityDebounce?.cancel();
    services.shelf.onDropped = null;
    services.activities.removeListener(_onActivitiesChanged);
    services.island.removeListener(_onIslandChanged);
    services.settings.removeListener(_onSettingsChanged);
    services.system.removeListener(_onSystemChanged);
    services.router.removeListener(_onRouterChanged);
    await _windowEvents?.cancel();
    await _trayEvents?.cancel();
    await _hotkeyEvents?.cancel();
    await services.hotkeys.clear();
    await services.tray.remove();
  }

  /// Shows the island, honouring the start delay when Windows launched us.
  ///
  /// An overlay that appears in the middle of the sign-in animation looks
  /// broken; waiting for the desktop to settle costs nothing.
  Future<void> _revealAtLaunch() async {
    final AppSettings current = services.settings.settings;
    if (current.startPaused) {
      services.island.setPaused(true);
      return;
    }

    final int delay = isAutoStart ? current.startupDelaySeconds : 0;
    if (delay <= 0) {
      await services.window.setVisible(true);
      await services.window.setFocusable(false);
      return;
    }

    _log.info('Auto-start: waiting ${delay}s before showing the island.');
    _startupDelay = Timer(Duration(seconds: delay), () async {
      await services.window.setVisible(true);
      await services.window.setFocusable(false);
    });
  }

  // --- Placement ------------------------------------------------------------

  /// Sizes and positions the stage from the current settings.
  ///
  /// The stage is sized from the island's declared maximum, not from whatever
  /// the island happens to be showing, so this runs on monitor and DPI changes
  /// only, never during an animation.
  Future<void> applyPlacement() async {
    final AppSettings current = services.settings.settings;
    final Size stage = IslandMetrics.stageSize(
      scale: services.theme.islandScale,
      panel: services.router.mode.needsPanelStage,
    );
    final StageInfo info = await services.window.setPlacement(
      monitorId: current.monitorId,
      width: stage.width,
      height: stage.height,
      alignX: 0.5,
      offsetX: current.offsetX,
      offsetY: current.offsetY,
      useWorkArea: current.useWorkArea,
    );
    // The zone the cursor has to reach for a hidden island to come back moves
    // with the stage, so it is published from the same place rather than
    // recomputed from a guess about where the island ended up.
    await services.window.setRevealZone(
      IslandMetrics.revealZone(stage, scale: services.theme.islandScale),
    );
    _log.debug(
      'Stage placed on ${info.monitorId} at ${info.scale}x '
      '(${stage.width.toStringAsFixed(0)}x${stage.height.toStringAsFixed(0)}).',
    );
  }

  Future<void> _refreshDisplays() async {
    _displays = await services.displays.list();
    _log.debug('${_displays.length} display(s) detected.');
  }

  // --- Feature switches -----------------------------------------------------

  /// Turns the observation modules on and off to match the settings document.
  ///
  /// Each module owns its own native subscription, so a feature that is off
  /// costs nothing at all: no watcher, no channel, no timer.
  Future<void> applyFeatureFlags() async {
    final AppSettings current = services.settings.settings;
    services.notifications.enabled = current.notificationsEnabled;
    services.system.volumeHudEnabled = current.volumeHudEnabled;

    await services.media.setEnabled(current.mediaEnabled);
    await services.downloads.setEnabled(current.downloadsEnabled);
    await services.clipboard.setPreviewEnabled(current.clipboardPreviewEnabled);
    await services.clipboard.setEnabled(current.clipboardEnabled);
    await services.system.setEnabled(current.systemStatusEnabled);
    if (!current.timersEnabled) {
      services.timers.clear();
    }
  }

  // --- Pages ----------------------------------------------------------------

  /// Publishes the reachable pages, in order.
  ///
  /// A page whose module is switched off, or which the user has turned off, is
  /// left out of the list entirely rather than shown empty - the pager should
  /// never carry a page that has nothing to say.
  void applyPages() {
    final AppSettings current = services.settings.settings;
    final Set<String> disabled = current.disabledPages.toSet();

    bool on(IslandPage page, bool moduleEnabled) =>
        moduleEnabled && !disabled.contains(page.id);

    // Order matters: the first three are one arrow key apart from the clock,
    // so they are the three a person reaches for without thinking - what is
    // on today, and what they want to open. Everything that reacts to the
    // machine rather than to the user sits behind them.
    services.island.setPages(<IslandPage>[
      IslandPage.now,
      // Calendar and Shortcuts need no module: one is arithmetic on the clock,
      // the other is a list of things to open. Neither observes anything, so
      // neither has a switch to be off.
      if (on(IslandPage.calendar, true)) IslandPage.calendar,
      // Timers sit beside the calendar: both are about time, and a timer is
      // the thing most often started right after looking at what is next.
      if (on(IslandPage.timers, current.timersEnabled)) IslandPage.timers,
      if (on(IslandPage.shortcuts, true)) IslandPage.shortcuts,
      if (on(IslandPage.media, current.mediaEnabled)) IslandPage.media,
      if (on(IslandPage.shelf, true)) IslandPage.shelf,
      if (on(IslandPage.system, current.systemStatusEnabled)) IslandPage.system,
    ]);
  }

  /// Opens the island on the page that matches the moment.
  void openIsland({IslandTrigger trigger = IslandTrigger.user}) {
    if (services.island.isPaused) {
      services.island.setPaused(false);
    }
    _hiddenForAutoHide = false;
    _revealedByPointer = false;
    services.island.reveal(trigger: trigger);
    services.island.expand(
      trigger: trigger,
      page: services.router.landingPage(),
    );
  }

  // --- Auto-collapse --------------------------------------------------------

  /// Closes an island that has been left open and untouched.
  ///
  /// Restarted by any interaction, and suspended entirely while the pointer is
  /// over the island - taking the surface away from under someone's cursor
  /// would be worse than leaving it open.
  void _restartAutoCollapse() {
    _autoCollapse?.cancel();
    final int seconds = services.settings.settings.autoCollapseSeconds;
    if (seconds <= 0 ||
        !services.island.isExpanded ||
        services.island.isHovered ||
        services.router.isSettingsOpen) {
      return;
    }
    _autoCollapse = Timer(Duration(seconds: seconds), () {
      if (services.island.isExpanded &&
          !services.island.isHovered &&
          !services.router.isSettingsOpen) {
        _log.debug('Auto-collapsing after ${seconds}s of no interaction.');
        services.island.collapse(trigger: IslandTrigger.system);
        unawaited(releaseFocus());
      }
    });
  }

  // --- Auto-hide ------------------------------------------------------------

  /// Turns the proximity watch on or off to match the setting.
  ///
  /// The watch is the only always-on hook in the application, so it exists
  /// exactly while auto-hide is on and the island is not paused, and the
  /// handler behind it does nothing but compare a point to a rectangle.
  Future<void> applyAutoHide() async {
    final AppSettings current = services.settings.settings;
    final bool wanted = current.autoHide && !services.island.isPaused;

    if (wanted != _proximityWatch) {
      _proximityWatch = wanted;
      await services.window.setProximityWatch(wanted);
      _log.info(wanted ? 'Auto-hide on.' : 'Auto-hide off.');
    }

    if (!wanted) {
      _autoHide?.cancel();
      _autoHide = null;
      _proximityDebounce?.cancel();
      _proximityDebounce = null;
      _cursorNear = false;
      if (_hiddenForAutoHide) {
        // Switching auto-hide off must bring the island back; leaving it in
        // the bezel with nothing watching for the cursor would strand it.
        _hiddenForAutoHide = false;
        services.island.reveal(trigger: IslandTrigger.system);
      }
      return;
    }
    _restartAutoHide();
  }

  /// Starts the countdown to withdrawing into the bezel.
  ///
  /// Every condition here is a reason the island is being used right now:
  /// it is open, the pointer is near it, settings are showing, or it is
  /// already away.
  void _restartAutoHide() {
    _autoHide?.cancel();
    final AppSettings current = services.settings.settings;
    if (!current.autoHide ||
        _cursorNear ||
        _hiddenForAutoHide ||
        services.island.isPaused ||
        services.island.isHidden ||
        services.island.isExpanded ||
        services.island.isHovered ||
        services.router.isSettingsOpen) {
      return;
    }
    // A pointer that has moved on gets a quick answer; an island that was
    // used and then left alone gets the configured pause.
    final Duration wait = _revealedByPointer
        ? _pointerLeaveHide
        : Duration(seconds: current.autoHideSeconds);
    _autoHide = Timer(wait, () {
      if (_cursorNear ||
          services.island.isExpanded ||
          services.island.isHovered ||
          services.island.isHidden ||
          services.island.isPaused) {
        return;
      }
      _hiddenForAutoHide = true;
      _log.debug('Auto-hiding; the pointer is elsewhere.');
      services.island.hide(trigger: IslandTrigger.system);
    });
  }

  /// The cursor crossed into or out of the reveal zone.
  ///
  /// Neither direction acts immediately. Coming in waits [_hoverOpenDelay] so a
  /// pointer travelling across the top of the screen does not summon anything;
  /// going out waits [_hoverCancelGrace] so a hand resting on the boundary does
  /// not make the island flicker. The native side already applies hysteresis to
  /// the zone itself; this is the second line of defence, and the one that can
  /// see what the island is doing.
  void _onProximityChanged(bool near) {
    _cursorNear = near;
    _log.debug('Pointer ${near ? 'approached' : 'left'} the island.');
    _proximityDebounce?.cancel();

    if (near) {
      _autoHide?.cancel();
      _proximityDebounce = Timer(_hoverOpenDelay, () {
        if (!_cursorNear || _suppressedForPresentation) {
          return;
        }
        if (_hiddenForAutoHide) {
          _hiddenForAutoHide = false;
          _revealedByPointer = true;
          _log.info('Pointer approached; returning from the bezel.');
          services.island.reveal(trigger: IslandTrigger.hover);
        }
      });
      return;
    }

    _proximityDebounce = Timer(_hoverCancelGrace, () {
      if (_cursorNear) {
        return;
      }
      _restartAutoHide();
    });
  }

  /// Opens the island on the shelf, so a dropped image is seen arriving.
  void _onShelfDrop() {
    if (services.island.isPaused) {
      services.island.setPaused(false);
    }
    _hiddenForAutoHide = false;
    _revealedByPointer = false;
    services.island.reveal(trigger: IslandTrigger.system);
    services.island.expand(
      trigger: IslandTrigger.system,
      page: IslandPage.shelf,
    );
  }

  void _onActivitiesChanged() {
    // A new activity widens the pill; nothing else here needs to react.
  }

  // --- Startup --------------------------------------------------------------

  Future<void> applyStartup() async {
    final bool wanted = services.settings.settings.launchAtStartup;
    _startupStatus = await services.startup.status();

    if (wanted && _startupStatus.isStale) {
      // The application was moved or reinstalled; the stale entry would launch
      // nothing. Rewriting it is the whole reason health is tracked.
      _log.warn('Startup entry was stale; repairing it.');
      await services.startup.repair();
    } else if (wanted != _startupStatus.registered) {
      await services.startup.setEnabled(wanted);
    }
    _startupStatus = await services.startup.status();
  }

  // --- Shortcuts ------------------------------------------------------------

  Future<List<HotkeyOutcome>> applyHotkeys() async {
    final AppSettings current = services.settings.settings;
    final List<HotkeyBinding> bindings = <HotkeyBinding>[
      ?HotkeyBinding.parse(_hotkeyToggle, current.hotkeyToggle),
      ?HotkeyBinding.parse(_hotkeyExpand, current.hotkeyExpand),
      ?HotkeyBinding.parse(_hotkeyHide, current.hotkeyHide),
    ];
    final List<HotkeyOutcome> outcomes = await services.hotkeys.apply(bindings);
    final Set<String> conflicts = <String>{};
    for (final HotkeyOutcome outcome in outcomes) {
      if (!outcome.registered) {
        conflicts.add(outcome.id);
        _log.warn('Shortcut "${outcome.id}" not registered: ${outcome.error}');
      }
    }
    services.hotkeyConflicts.value = conflicts;
    return outcomes;
  }

  void _onHotkeyEvent(NativeEvent event) {
    if (event.type != 'pressed') {
      return;
    }
    final String id = event.read<String>('id') ?? '';
    services.bus.emit(IslandActivationRequested('hotkey:$id'));
    switch (id) {
      case _hotkeyToggle:
        if (services.island.isExpanded) {
          services.island.collapse(trigger: IslandTrigger.hotkey);
        } else {
          openIsland(trigger: IslandTrigger.hotkey);
          unawaited(requestFocus());
        }

      case _hotkeyExpand:
        openIsland(trigger: IslandTrigger.hotkey);
        unawaited(requestFocus());

      case _hotkeyHide:
        services.island.hide(trigger: IslandTrigger.hotkey);

      default:
        _log.warn('Unknown shortcut fired: $id');
    }
  }

  // --- Focus and hit testing ------------------------------------------------

  /// Published by the island view whenever its mouse-interactive region moves.
  void reportHitRect(Rect rect) {
    unawaited(
      services.window.setInteractiveRects(
        rect.isEmpty ? const <Rect>[] : <Rect>[rect],
      ),
    );
  }

  /// The island was opened by a real click, so it may take keyboard focus.
  Future<void> requestFocus() async {
    await services.window.setFocusable(true);
    await services.window.requestFocus();
  }

  Future<void> releaseFocus() async {
    await services.window.setFocusable(false);
  }

  // --- Native events --------------------------------------------------------

  void _onWindowEvent(NativeEvent event) {
    switch (event.type) {
      case 'focusLost':
        // Clicking anywhere else is the natural way to dismiss an overlay.
        if (services.island.isExpanded) {
          services.island.collapse(trigger: IslandTrigger.system);
          unawaited(releaseFocus());
        }

      case 'clickOutside':
        if (services.island.isExpanded) {
          services.island.collapse(trigger: IslandTrigger.system);
          unawaited(releaseFocus());
        }

      case 'proximity':
        _onProximityChanged(event.read<bool>('inside') ?? false);

      case 'activationRequested':
        services.bus.emit(const IslandActivationRequested('secondInstance'));
        openIsland();
        unawaited(requestFocus());

      case 'systemThemeChanged':
        final bool dark = event.read<bool>('dark') ?? true;
        services.theme.setSystemIsDark(dark);
        services.bus.emit(SystemThemeChanged(isDark: dark));

      case 'displaysChanged':
      case 'workAreaChanged':
      case 'dpiChanged':
      case 'sessionResumed':
      case 'sessionUnlocked':
      case 'shellRestarted':
        _log.info('Desktop changed (${event.type}); re-placing the stage.');
        services.bus.emit(DesktopEnvironmentChanged(event.type));
        unawaited(_recoverFrom(event.type));

      case 'sessionSuspended':
      case 'sessionLocked':
      case 'systemShutdown':
        services.bus.emit(DesktopEnvironmentChanged(event.type));

      default:
        _log.debug('Unhandled window event: ${event.type}');
    }
  }

  /// Re-establishes everything that a desktop change can invalidate.
  Future<void> _recoverFrom(String reason) async {
    await _refreshDisplays();
    await applyPlacement();
    await services.window.assertTopmost();
    await _publishTrayMenu(force: true);

    if (reason == 'sessionResumed' || reason == 'sessionUnlocked') {
      // Applications may have started or stopped while the machine was asleep,
      // and no event would have reached us.
      await services.media.refresh();
      await services.system.refresh();
    }
    if (reason == 'shellRestarted') {
      // Explorer takes the notification icon with it when it goes.
      await services.tray.install(tooltip: 'Notch X');
      await _publishTrayMenu(force: true);
    }
  }

  void _onTrayEvent(NativeEvent event) {
    switch (event.type) {
      case 'activate':
      case 'doubleClick':
        services.bus.emit(const IslandActivationRequested('tray'));
        if (services.island.isExpanded) {
          services.island.collapse(trigger: IslandTrigger.tray);
        } else {
          openIsland(trigger: IslandTrigger.tray);
          unawaited(requestFocus());
        }

      case 'menu':
        _handleMenuCommand(event.read<String>('id') ?? '');

      default:
        break;
    }
  }

  void _handleMenuCommand(String id) {
    if (id.startsWith(_menuDisplayPrefix)) {
      final String monitorId = id == _menuDisplayAuto
          ? ''
          : id.substring(_menuDisplayPrefix.length);
      services.settings.mutate(
        (AppSettings current) => current.copyWith(monitorId: monitorId),
      );
      return;
    }

    switch (id) {
      case _menuOpen:
        openIsland(trigger: IslandTrigger.tray);
        unawaited(requestFocus());

      case _menuPause:
        services.island.setPaused(!services.island.isPaused);

      case _menuSettings:
        openSettings();

      case _menuStartup:
        services.settings.mutate(
          (AppSettings current) =>
              current.copyWith(launchAtStartup: !current.launchAtStartup),
        );

      case _menuQuit:
        unawaited(_quit());

      default:
        _log.warn('Unknown tray command: $id');
    }
  }

  Future<void> _quit() async {
    _log.info('Quit requested from the tray.');
    await stop();
    await services.settings.flush();
    await services.window.quit();
  }

  // --- Reacting to our own state -------------------------------------------

  /// Opens the settings panel, growing the stage before the island reaches
  /// for the extra room. Doing it the other way round shows a clipped panel
  /// for a frame.
  Future<void> openSettings() async {
    if (services.island.isPaused) {
      services.island.setPaused(false);
    }
    services.island.reveal(trigger: IslandTrigger.user);
    services.router.openSettings();
    await applyPlacement();
    services.island.expand(trigger: IslandTrigger.user);
    await requestFocus();
  }

  bool _stageIsPanel = false;

  /// Follows the router into and out of the settings stage. Growing happens
  /// immediately; shrinking waits for the island to finish closing, so the
  /// panel is never clipped on its way out.
  void _onRouterChanged() {
    final bool wantsPanel = services.router.mode.needsPanelStage;
    if (wantsPanel == _stageIsPanel) {
      return;
    }
    _stageIsPanel = wantsPanel;
    if (wantsPanel) {
      unawaited(applyPlacement());
    } else {
      services.island.collapse(trigger: IslandTrigger.user);
      unawaited(releaseFocus());
    }
    unawaited(_publishTrayMenu(force: true));
  }

  bool _watchingOutside = false;

  void _onIslandChanged() {
    final bool open = services.island.isExpanded;
    if (open != _watchingOutside) {
      _watchingOutside = open;
      unawaited(services.window.setOutsideClickWatch(open));
    }
    _restartAutoCollapse();
    if (!services.island.isHidden) {
      // Whatever brought it back - a hotkey, the tray, the pointer - it is on
      // screen now, so it is no longer away because of auto-hide.
      _hiddenForAutoHide = false;
    }
    if (services.island.isExpanded) {
      // Opening it is a decision; from here on it keeps the full countdown.
      _revealedByPointer = false;
    }
    _restartAutoHide();
    if (services.island.isPaused != _wasPaused) {
      _wasPaused = services.island.isPaused;
      unawaited(applyAutoHide());
    }
    // Closing the island closes settings with it: leaving the panel "open"
    // behind a collapsed island would keep the oversized stage alive and put
    // the wrong face back on screen next time.
    if (services.router.isSettingsOpen &&
        !services.island.isExpanded &&
        !services.island.phase.isMoving) {
      services.router.closeSettings();
    }
    // The settings stage shrinks only once the island has actually closed.
    if (!_stageIsPanel && services.island.phase == IslandPhase.collapsed) {
      unawaited(applyPlacement());
    }
    unawaited(services.window.setVisible(!services.island.isHidden));
    unawaited(services.window.setIgnoreMouse(services.island.isPaused));
    unawaited(_publishTrayMenu());
  }

  /// Steps aside for games, presentations and Do Not Disturb.
  void _onSystemChanged() {
    final AppSettings current = services.settings.settings;
    final PresentationState state = services.system.presentation;
    final bool presentation =
        current.suppressInFullscreen && state.shouldSuppress;
    final bool covered =
        current.hideWhenCovered && services.system.foregroundCovers;
    final bool shouldStepAside = presentation || covered;

    if (shouldStepAside && !_suppressedForPresentation) {
      _suppressedForPresentation = true;
      _log.info(
        'Stepping aside for ${presentation ? state.name : 'a maximised app'}.',
      );
      services.island.hide(trigger: IslandTrigger.system);
    } else if (!shouldStepAside && _suppressedForPresentation) {
      _suppressedForPresentation = false;
      _log.info('Foreground cleared; returning.');
      services.island.reveal(trigger: IslandTrigger.system);
    }
  }

  String? _menuSignature;

  Future<void> _publishTrayMenu({bool force = false}) async {
    final AppSettings current = services.settings.settings;
    final String signature = <String>[
      services.island.isPaused.toString(),
      current.launchAtStartup.toString(),
      current.monitorId,
      _displays.map((DisplayInfo d) => d.id).join(','),
    ].join('|');
    if (!force && _menuSignature == signature) {
      return;
    }
    _menuSignature = signature;

    final List<TrayMenuEntry> displayItems = <TrayMenuEntry>[
      TrayMenuEntry.checkbox(
        id: _menuDisplayAuto,
        label: 'Primary display',
        checked: current.monitorId.isEmpty,
      ),
      for (final DisplayInfo display in _displays)
        TrayMenuEntry.checkbox(
          id: '$_menuDisplayPrefix${display.id}',
          label: display.name.isEmpty ? display.id : display.name,
          checked: current.monitorId == display.id,
        ),
    ];

    await services.tray.setMenu(<TrayMenuEntry>[
      const TrayMenuEntry.item(
        id: _menuOpen,
        label: 'Open Notch X',
        isDefault: true,
      ),
      TrayMenuEntry.checkbox(
        id: _menuPause,
        label: 'Pause Notch X',
        checked: services.island.isPaused,
      ),
      const TrayMenuEntry.separator(),
      const TrayMenuEntry.item(id: _menuSettings, label: 'Settings…'),
      TrayMenuEntry.submenu(label: 'Display', children: displayItems),
      TrayMenuEntry.checkbox(
        id: _menuStartup,
        label: 'Launch at sign-in',
        checked: current.launchAtStartup,
      ),
      const TrayMenuEntry.separator(),
      const TrayMenuEntry.item(id: _menuQuit, label: 'Quit Notch X'),
    ]);
  }

  void _onSettingsChanged() {
    applyPages();
    _restartAutoCollapse();
    _onSystemChanged();
    unawaited(applyPlacement());
    unawaited(applyFeatureFlags());
    unawaited(applyAutoHide());
    unawaited(applyStartup());
    unawaited(applyHotkeys());
    unawaited(_publishTrayMenu());
  }
}
