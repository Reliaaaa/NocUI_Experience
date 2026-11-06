# NocUI Experience 1.1.1

This update fixes a build error in the expanded notch layout and includes the latest settings and appearance changes.

## Changes

- Restores the expanded-view layout builder, fixing a Dart analysis and build failure.
- Adds a separate Windows Settings window with sidebar navigation and a fallback inside the notch.
- Allows manual numeric entry for Settings sliders.
- Updates the notch appearance, uses the Inter font, and introduces a new Windows application and installer icon.

## Installation

Download `NocUI-Experience-Setup-x64.exe` and run it on Windows x64. Close the running NocUI application before installing the update.

## Known limitations

- The installer is unsigned. Installation, uninstall, and runtime behavior need interactive Windows testing.
- The separate Settings window, its synchronization, and the updated appearance have not yet been confirmed through interactive Windows testing.
- Verify click-through, keyboard focus, monitor and DPI changes, media, and fullscreen behavior on the target system.
- Migration from the unpackaged WinUI version imports only the media-enabled setting and zero-animation preference. Other settings and MSIX LocalSettings are not migrated.
- Weather and location services are opt-in and may make network requests when enabled.
- The repository does not currently include a LICENSE file; licensing and redistribution terms for source and dependencies should be confirmed.
