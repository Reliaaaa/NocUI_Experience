# NocUI Experience 1.0.0

NocUI Experience is a Windows desktop notch application built with Flutter and native Windows integration. This release includes the interactive notch, media controls, customizable appearance, and the Windows installer.

## Installation

Download `NocUI-Experience-Setup-x64.exe` and run it on Windows x64. Close any running older NocUI application before starting the Flutter version.

## Known limitations

- The installer is unsigned. Installation, uninstall, and runtime behavior still require validation on target Windows systems.
- Automated build and test success is not Windows runtime acceptance. Animation, keyboard focus, media, transparency, click-through, monitor and DPI behavior remain to be tested.
- Migration from the unpackaged WinUI version imports only the media-enabled setting and the zero-animation preference. Other settings and MSIX LocalSettings are not migrated.
- Weather and location services are opt-in and may make network requests when enabled.
- Licensing and redistribution terms for source and dependencies should be confirmed; the repository does not yet include a LICENSE file.
