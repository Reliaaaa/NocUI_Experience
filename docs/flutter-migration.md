# Flutter migration preview

`flutter_app/` contains the notchX / DynamicBar source at revision `96b865c`. Flutter is the primary build, but it is not yet a verified release or an acceptance-tested replacement for the existing WinUI application.

The Flutter preview uses separate NocUI identifiers and settings under `%APPDATA%\NocUIExperience`. It attempts a one-way import of the unpackaged WinUI media-enabled setting and the zero-animation preference from `%LOCALAPPDATA%\NotchUI\settings.json`; the original remains untouched. Other settings and MSIX LocalSettings are not migrated. Weather, automatic location, downloads monitoring, and global shortcuts default to disabled for new settings. Existing explicitly stored Flutter settings are preserved.

The primary Flutter Windows workflow builds a portable bundle and an Inno Setup installer and runs analysis and tests. The .NET workflow remains manually runnable as a legacy reference; its MSIX targets WinUI, not Flutter. The Flutter installer upgrades the prior Flutter preview but remains separate from the WinUI installation, so both applications can run at once. The upstream Store identity was removed. Installer and migration verification, remaining settings compatibility, keyboard and overlay behavior, security review, and Windows runtime acceptance remain open.
