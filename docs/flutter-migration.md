# Flutter migration preview

`flutter_app/` contains the notchX / DynamicBar source at revision `96b865c`, adapted with the user's stated permission. The original copyright and README remain in that directory. This is a migration preview, not a release or a verified replacement for the existing WinUI application.

The Flutter preview uses separate NocUI identifiers and settings under `%APPDATA%\NocUIExperience`. It attempts a one-way import of the unpackaged WinUI media-enabled setting and the zero-animation preference from `%LOCALAPPDATA%\NotchUI\settings.json`; the original remains untouched. Other settings and MSIX LocalSettings are not migrated. Weather, automatic location, downloads monitoring, and global shortcuts default to disabled for new settings. Existing explicitly stored Flutter settings are preserved.

The separate Flutter Windows workflow builds a portable preview bundle and an Inno Setup preview installer and runs analysis and tests. The existing .NET workflow, installer, and MSIX still target WinUI. The upstream Store identity was removed from the Flutter configuration. Installer and migration verification, remaining settings compatibility, keyboard and overlay behavior, security review, and Windows runtime acceptance remain open.
