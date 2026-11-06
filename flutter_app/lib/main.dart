import 'app/bootstrap.dart';
import 'app/settings_window_app.dart';

/// DynamicBar - a Dynamic Island style overlay for Windows 11.
///
/// Arguments come from the Windows runner; `--autostart` marks a launch made
/// by Windows at sign-in rather than by the user.
void main(List<String> args) => bootstrap(args);

/// Entry point for the native settings window's separate Flutter engine.
@pragma('vm:entry-point')
void settingsMain(List<String> args) => bootstrapSettingsWindow();
