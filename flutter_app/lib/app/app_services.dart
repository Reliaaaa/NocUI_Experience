import 'package:flutter/widgets.dart';

import '../core/events/event_bus.dart';
import '../core/time/clock_service.dart';
import '../design/theme/theme_controller.dart';
import '../island/state/island_controller.dart';
import '../island/state/presentation_router.dart';
import '../modules/activities/activity_center.dart';
import '../modules/calendar/calendar_controller.dart';
import '../modules/clipboard/clipboard_controller.dart';
import '../modules/connectivity/connectivity_controller.dart';
import '../modules/downloads/downloads_controller.dart';
import '../modules/media/media_controller.dart';
import '../modules/notifications/notification_center.dart';
import '../modules/shelf/shelf_controller.dart';
import '../modules/system/system_controller.dart';
import '../modules/timers/timer_controller.dart';
import '../modules/weather/weather_controller.dart';
import '../native/clipboard_bridge.dart';
import '../native/connectivity_bridge.dart';
import '../native/display_bridge.dart';
import '../native/downloads_bridge.dart';
import '../native/hotkey_bridge.dart';
import '../native/media_bridge.dart';
import '../native/power_bridge.dart';
import '../native/shell_bridge.dart';
import '../native/startup_bridge.dart';
import '../native/system_bridge.dart';
import '../native/tray_bridge.dart';
import '../native/window_bridge.dart';
import '../settings/settings_controller.dart';

/// The application's service graph.
///
/// Constructed once in `bootstrap`, disposed once on shutdown, and handed to
/// the tree through [AppScope]. Explicit construction beats a service locator
/// here: the dependency order is visible, and nothing can be resolved before it
/// exists.
class AppServices {
  const AppServices({
    required this.bus,
    required this.clock,
    required this.theme,
    required this.island,
    required this.router,
    required this.settings,
    required this.notifications,
    required this.media,
    required this.downloads,
    required this.timers,
    required this.clipboard,
    required this.system,
    required this.connectivity,
    required this.weather,
    required this.calendar,
    required this.shelf,
    required this.activities,
    required this.window,
    required this.displays,
    required this.tray,
    required this.mediaBridge,
    required this.downloadsBridge,
    required this.clipboardBridge,
    required this.systemBridge,
    required this.connectivityBridge,
    required this.power,
    required this.hotkeys,
    required this.hotkeyConflicts,
    required this.shell,
    required this.startup,
  });

  final EventBus bus;
  final ClockService clock;
  final ThemeController theme;
  final IslandController island;
  final PresentationRouter router;
  final SettingsController settings;

  final NotificationCenter notifications;
  final MediaController media;
  final DownloadsController downloads;
  final TimerController timers;
  final ClipboardController clipboard;
  final SystemController system;

  /// Wi-Fi networks, paired Bluetooth devices and the two radio switches.
  /// Watching only while a view has claimed it.
  final ConnectivityController connectivity;

  /// The forecast for one place. The only module that reaches the internet,
  /// and only when it is switched on.
  final WeatherController weather;

  /// Notes and reminders written on the calendar.
  final CalendarController calendar;

  /// Two images and a note, kept for as long as they are useful.
  final ShelfController shelf;

  /// Derived view of what is happening now, for the collapsed pill.
  final ActivityCenter activities;

  final WindowBridge window;
  final DisplayBridge displays;
  final TrayBridge tray;
  final MediaBridge mediaBridge;
  final DownloadsBridge downloadsBridge;
  final ClipboardBridge clipboardBridge;
  final SystemBridge systemBridge;
  final ConnectivityBridge connectivityBridge;

  /// Lock, sleep and the three that end the session. Stateless, like
  /// [shell]: nothing to enable, nothing to tear down.
  final PowerBridge power;

  final HotkeyBridge hotkeys;

  /// Opens applications, folders, addresses and Windows panels. Stateless:
  /// nothing to enable, nothing to tear down.
  final ShellBridge shell;

  /// Shortcut ids Windows refused to register, so Shortcuts settings can say
  /// so instead of showing a binding that silently does nothing.
  final ValueNotifier<Set<String>> hotkeyConflicts;

  final StartupBridge startup;

  /// Torn down in reverse dependency order: the router listens to the modules,
  /// the modules listen to the platform.
  Future<void> dispose() async {
    await settings.flush();
    await calendar.flush();
    await shelf.flush();
    router.dispose();
    shelf.dispose();
    calendar.dispose();
    activities.dispose();
    weather.dispose();
    connectivity.dispose();
    system.dispose();
    clipboard.dispose();
    timers.dispose();
    downloads.dispose();
    media.dispose();
    notifications.dispose();
    settings.dispose();
    island.dispose();
    theme.dispose();
    clock.dispose();
    hotkeyConflicts.dispose();
    await bus.dispose();
  }
}

/// Provides [AppServices] to the widget tree.
class AppScope extends InheritedWidget {
  const AppScope({required this.services, required super.child, super.key});

  final AppServices services;

  static AppServices of(BuildContext context) {
    final AppScope? scope = context
        .dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope found in the widget tree.');
    return scope!.services;
  }

  /// Reads the services without subscribing. Services are never swapped at
  /// runtime, so this is the normal way to reach them.
  static AppServices read(BuildContext context) {
    final AppScope? scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope found in the widget tree.');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      !identical(oldWidget.services, services);
}
