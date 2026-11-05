/// Marker for everything that travels on the [EventBus].
///
/// Modules publish facts, never commands: an event describes something that
/// happened, and any number of listeners may or may not react to it.
abstract class AppEvent {
  const AppEvent();
}

/// The user asked for the island through a tray click, a hotkey or a second
/// launch of the application.
class IslandActivationRequested extends AppEvent {
  const IslandActivationRequested(this.source);

  /// tray, hotkey, secondInstance.
  final String source;
}

/// The desktop environment changed underneath the island in a way that
/// requires the stage to be re-placed or re-asserted.
class DesktopEnvironmentChanged extends AppEvent {
  const DesktopEnvironmentChanged(this.reason);

  /// displays, dpi, workArea, sessionResumed, sessionUnlocked, shellRestarted.
  final String reason;
}

/// The operating system light/dark preference changed.
class SystemThemeChanged extends AppEvent {
  const SystemThemeChanged({required this.isDark});

  final bool isDark;
}
