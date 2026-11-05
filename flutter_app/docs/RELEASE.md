# Release

## Build

```powershell
flutter pub get
flutter analyze          # must be clean
flutter test             # must be green
flutter build windows --release
```

Output: `build\windows\x64\runner\Release\`

```
DynamicBar.exe          the application
flutter_windows.dll     the Flutter runtime
data\                   assets and the AOT snapshot
```

The whole folder ships together. `DynamicBar.exe` on its own will not start.

## What is already production-shaped

- **Subsystem.** The runner is a `WIN32` subsystem binary. It attaches to a
  parent console when started from one (`flutter run`) and creates one only under
  a debugger, so a release launch from Explorer shows no console window.
- **Metadata.** `Runner.rc` carries the product name, description, company and
  version. `FileVersion` and `ProductVersion` are generated from `pubspec.yaml`,
  so bumping `version:` there is the only edit a release needs — keep
  `AppInfo.version` in step for the About screen.
- **Icon.** `windows/runner/resources/app_icon.ico` is original artwork, nine
  sizes from 16 to 256 px, used for the executable, the window class and the
  notification area.
- **Single instance.** A named mutex; a second launch reveals the first.
- **No debug UI.** The checked-mode banner is off, and error presentation is
  gated on `kDebugMode`. Logging drops to info level in release builds.
- **Startup.** The per-user Run key is written on demand and repaired if the
  application has been moved.

## Renaming the application

The internal name is deliberately confined to four places:

| What | Where |
|---|---|
| Dart package | `pubspec.yaml` → `name:`, and the `package:dynamicbar/...` imports |
| Executable | `windows/CMakeLists.txt` → `BINARY_NAME` |
| Metadata | `windows/runner/Runner.rc` |
| Display name | `lib/app/app_info.dart` |

Channel names (`dynamicbar/window`, and so on) are internal identifiers and do
not need to change.

## Packaging, when it is wanted

Nothing here is Store-specific yet; that complexity is deliberately deferred
until the application has been lived with.

**MSIX** is the natural next step, and it buys one real feature: package identity
would make `Windows.UI.Notifications.Management.UserNotificationListener`
available, which is the only thing standing between DynamicBar and showing the
system's own notifications (see `WINDOWS_INTEGRATION.md`). The notification
centre is already an internal abstraction, so a second source can be added
without touching the presentation layer.

Note that a packaged build must drop the Run-key startup registration in favour
of the package's own startup task declaration; `StartupService` is the only place
that would change.

**A plain installer** (Inno Setup, WiX) needs nothing from the application: copy
the Release folder, create a Start menu shortcut, and let the in-application
setting manage startup.
