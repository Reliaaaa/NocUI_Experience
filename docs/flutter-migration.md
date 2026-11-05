# Flutter migration preview

`flutter_app/` contains the notchX / DynamicBar source at revision `96b865c`, adapted with the user's stated permission. The original copyright and README remain in that directory. This is a migration preview, not a release or a verified replacement for the existing WinUI application.

The Flutter application retains its upstream internal executable, single-instance identifiers, and `%APPDATA%\DynamicBar` settings location. It does not read or migrate the existing `%LOCALAPPDATA%\NotchUI\settings.json` or MSIX LocalSettings. Do not overwrite those stores or claim settings compatibility without a tested migration. Weather, automatic location, and downloads monitoring default to disabled for new settings. Existing explicitly enabled upstream settings are preserved.

The separate Flutter Windows workflow builds a portable preview bundle and runs analysis and tests. The existing .NET workflow, installer, and MSIX still target WinUI; none is an installer for the Flutter preview. The upstream Store identity was removed from the Flutter configuration. Packaging, storage protections and migration, branding, keyboard and overlay behavior, security review, and Windows runtime acceptance remain open.
