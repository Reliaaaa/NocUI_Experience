# NocUI Experience 1.2.0 — Final Flutter Version

Version 1.2.0 is the final planned release of the Flutter edition of NocUI Experience. Future development will migrate the application to WinUI 3 and C#. The migration is in progress; the WinUI edition is not yet a replacement for this release.

## Changes since 1.1.1

- Adds a compact Control Center with Wi-Fi, Bluetooth, notifications and volume controls, and preserves access to the existing home overview.
- Updates the notch and Settings appearance, adds an Appearance preview, and improves keyboard and screen-reader access to Settings switches.
- Adds Notes using today's untimed calendar entries and a Clipboard page that shows only the most recent activity. Clipboard monitoring and text previews remain opt-in.
- Improves the System page and adds a battery indicator to the collapsed notch when a battery reading is available.
- Replaces the volume slider that required a missing Material overlay with a bounded control that supports pointer, keyboard and accessibility actions.

## Installation

Download `NocUI-Experience-Setup-x64.exe` and run it on Windows x64. Close NocUI before installing the update.

## Known limitations

- The installer is unsigned. Installation, uninstall, and runtime behavior require interactive Windows testing.
- The updated Control Center, volume slider, Settings window and synchronization have not yet been confirmed through interactive Windows testing.
- Verify click-through, keyboard focus, monitor and DPI changes, media, and fullscreen behavior on the target system.
- Flutter settings are stored separately from the older WinUI installation. Migration to the future WinUI edition is not complete.
- Weather and location services are opt-in and may make network requests when enabled.
- The repository does not currently include a project LICENSE file; licensing and redistribution terms for source and dependencies should be confirmed.
