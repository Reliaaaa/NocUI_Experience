import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/events/event_bus.dart';
import '../core/logging/app_logger.dart';
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
import '../modules/weather/weather_service.dart';
import '../native/clipboard_bridge.dart';
import '../native/connectivity_bridge.dart';
import '../native/display_bridge.dart';
import '../native/downloads_bridge.dart';
import '../native/hotkey_bridge.dart';
import '../native/media_bridge.dart';
import '../native/power_bridge.dart';
import '../native/shelf_bridge.dart';
import '../native/shell_bridge.dart';
import '../native/startup_bridge.dart';
import '../native/system_bridge.dart';
import '../native/tray_bridge.dart';
import '../native/window_bridge.dart';
import '../native/native_channel.dart';
import '../settings/settings_controller.dart';
import '../settings/settings_store.dart';
import 'app_services.dart';
import 'dynamic_bar_app.dart';
import 'island_coordinator.dart';

const Logger _log = Logger('Bootstrap');

/// Builds the service graph and starts the overlay.
///
/// Errors are captured rather than allowed to tear the process down: this is a
/// utility that is expected to sit in the tray for days, so a failure in one
/// module must leave the island running with that module degraded.
Future<void> bootstrap([List<String> arguments = const <String>[]]) async {
  await runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (FlutterErrorDetails details) {
        AppLog.write(
          LogLevel.error,
          'Flutter',
          _describe(details),
          error: details.exception,
          stackTrace: details.stack,
        );
        if (kDebugMode) {
          FlutterError.presentError(details);
        }
      };

      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        AppLog.write(
          LogLevel.error,
          'Platform',
          'Uncaught platform error.',
          error: error,
          stackTrace: stack,
        );
        return true;
      };

      if (kReleaseMode) {
        AppLog.minimumLevel = LogLevel.info;
      }

      final AppServices services = await _buildServices();
      final IslandCoordinator coordinator = IslandCoordinator(
        services: services,
        launchArguments: arguments,
      );

      runApp(DynamicBarApp(services: services, coordinator: coordinator));
    },
    (Object error, StackTrace stack) {
      AppLog.write(
        LogLevel.error,
        'Zone',
        'Unhandled asynchronous error.',
        error: error,
        stackTrace: stack,
      );
    },
  );
}

/// The exception, and - for a layout error - which widget it was.
///
/// A RenderFlex overflow names the file and line of the widget that caused it,
/// but only in the long form of the report. That line is the whole difference
/// between a log entry that can be fixed and one that can only be noticed, so
/// it is kept and the rest of the report is not.
String _describe(FlutterErrorDetails details) {
  final String summary = details.exceptionAsString();
  final List<String> lines = details.toString().split('\n');
  for (int i = 0; i < lines.length - 1; i++) {
    if (lines[i].contains('error-causing widget')) {
      // The widget is on the line that follows, and where it was made on
      // the lines after that.
      final Iterable<String> where = lines
          .skip(i + 1)
          .take(3)
          .map((String l) => l.trim())
          .where((String l) => l.isNotEmpty);
      return '$summary | ${where.join(' ')}';
    }
  }
  return summary;
}

Future<AppServices> buildSettingsServices() async {
  NativeChannel.settingsProxy = true;
  return _buildServices(settingsWindow: true);
}

Future<AppServices> _buildServices({bool settingsWindow = false}) async {
  final EventBus bus = EventBus();
  final ClockService clock = ClockService();
  final ThemeController theme = ThemeController();
  final IslandController island = IslandController();

  final WindowBridge window = WindowBridge();

  // From here on, every Dart log line also lands in the native log file.
  if (!settingsWindow) {
    AppLog.sink = (LogRecord record) {
      window.writeLog(
        level: record.level.name,
        tag: record.tag,
        message: record.error == null
            ? record.message
            : '${record.message} | ${record.error}',
      );
    };
  }
  final DisplayBridge displays = DisplayBridge();
  final TrayBridge tray = TrayBridge();
  final MediaBridge mediaBridge = MediaBridge();
  final DownloadsBridge downloadsBridge = DownloadsBridge();
  final ClipboardBridge clipboardBridge = ClipboardBridge();
  final SystemBridge systemBridge = SystemBridge();
  final ConnectivityBridge connectivityBridge = ConnectivityBridge();
  final PowerBridge powerBridge = PowerBridge();
  final ShellBridge shellBridge = ShellBridge();
  final ShelfBridge shelfBridge = ShelfBridge();
  final HotkeyBridge hotkeys = HotkeyBridge();
  final StartupBridge startup = StartupBridge();

  final SettingsController settings = settingsWindow
      ? SettingsController.remote(
          theme: theme,
          update: (patch) async {
            const channel = MethodChannel('nocui/settings_window');
            final result = await channel.invokeMapMethod<String, Object?>('update', patch);
            if (result == null) throw StateError('Settings owner returned no state.');
            return result;
          },
        )
      : SettingsController(store: SettingsStore(), theme: theme);

  if (!settingsWindow) await settings.load();

  // Seed the system brightness before the first frame so the island never
  // flashes the wrong appearance on launch.
  theme.setSystemIsDark(await window.systemPrefersDarkMode());

  if (!Platform.isWindows) {
    _log.warn(
      'NocUI Experience targets Windows; native integration is unavailable here.',
    );
  }

  final NotificationCenter notifications = NotificationCenter();
  final MediaController media = MediaController(bridge: mediaBridge);
  final DownloadsController downloads = DownloadsController(
    bridge: downloadsBridge,
    notifications: notifications,
  );
  final TimerController timers = TimerController(notifications: notifications);
  final ClipboardController clipboard = ClipboardController(
    bridge: clipboardBridge,
    notifications: notifications,
  );
  final SystemController system = SystemController(
    bridge: systemBridge,
    notifications: notifications,
  );

  final ConnectivityController connectivity = ConnectivityController(
    bridge: connectivityBridge,
    notifications: notifications,
  );
  // Constructed with the settings it reads, and idle until a view claims it:
  // nothing leaves this machine because the island happens to be running.
  final WeatherController weather = WeatherController(
    service: WeatherService(),
    settings: settings,
  );

  final CalendarController calendar = CalendarController(
    notifications: notifications,
  );
  final ShelfController shelf = ShelfController(bridge: shelfBridge);
  // Both read a small file from disk; doing it now means the first time either
  // page is opened it already has its contents.
  if (!settingsWindow) {
    await calendar.load();
    await shelf.load();
  }

  final ActivityCenter activities = ActivityCenter(
    media: media,
    downloads: downloads,
    timers: timers,
    system: system,
  );

  final PresentationRouter router = PresentationRouter(
    island: island,
    notifications: notifications,
    media: media,
    downloads: downloads,
    timers: timers,
    clipboard: clipboard,
    system: system,
  );

  return AppServices(
    bus: bus,
    clock: clock,
    theme: theme,
    island: island,
    router: router,
    settings: settings,
    notifications: notifications,
    media: media,
    downloads: downloads,
    timers: timers,
    clipboard: clipboard,
    system: system,
    connectivity: connectivity,
    weather: weather,
    calendar: calendar,
    shelf: shelf,
    activities: activities,
    window: window,
    displays: displays,
    tray: tray,
    mediaBridge: mediaBridge,
    downloadsBridge: downloadsBridge,
    clipboardBridge: clipboardBridge,
    systemBridge: systemBridge,
    connectivityBridge: connectivityBridge,
    power: powerBridge,
    shell: shellBridge,
    hotkeys: hotkeys,
    hotkeyConflicts: ValueNotifier<Set<String>>(const <String>{}),
    startup: startup,
  );
}
