# NocUI Experience 1.1.0

This update addresses the notch blocking clicks in other applications and disappearing when another window is opened.

## Changes

- Bounds the native overlay window to the notch's interactive area instead of leaving the entire Flutter stage over other applications.
- Adds **Keep notch visible**, enabled by default, while preserving the existing optional hiding preferences.
- Retains the Flutter notch, settings, media controls, and Windows installer from 1.0.0.

The user reported that the fix passed their test. Automated checks also cover settings compatibility, Flutter analysis, tests, Windows build, and installer creation; these do not replace broader runtime acceptance.

## Installation

Download `NocUI-Experience-Setup-x64.exe` and run it on Windows x64. Close the running NocUI application before installing the update.

## Known limitations

- The installer is unsigned. Installation, uninstall, and behavior on additional Windows configurations require verification.
- Windows does not guarantee a normal topmost window will appear over secure desktops, exclusive-fullscreen applications, or every other topmost window.
- Check click-through, shadow clipping, keyboard focus, monitor changes, and DPI scaling on the target system.
- Migration from the unpackaged WinUI version imports only the media-enabled setting and zero-animation preference. Other settings and MSIX LocalSettings are not migrated.
- Weather and location services are opt-in and may make network requests when enabled.
- The repository does not currently include a LICENSE file; licensing and redistribution terms for source and dependencies should be confirmed.
