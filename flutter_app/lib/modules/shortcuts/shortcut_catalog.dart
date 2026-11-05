import 'package:flutter/widgets.dart';

import '../../design/tokens/db_icons.dart';

/// Where a shortcut belongs in the picker. Only used for grouping, so a list of
/// forty entries reads as three short lists instead of one long one.
enum ShortcutGroup { web, apps, windows }

extension ShortcutGroupX on ShortcutGroup {
  String get label {
    switch (this) {
      case ShortcutGroup.web:
        return 'On the web';
      case ShortcutGroup.apps:
        return 'On this PC';
      case ShortcutGroup.windows:
        return 'Windows';
    }
  }
}

/// One launchable thing.
///
/// [target] is handed to the Windows shell unchanged: an `https://` address, an
/// executable on the path, a `shell:` known folder, or a protocol such as
/// `ms-settings:sound`. Windows resolves all four, which is why the catalogue
/// needs no per-kind logic and the native side is a single ShellExecuteW.
@immutable
class ShortcutEntry {
  const ShortcutEntry({
    required this.id,
    required this.label,
    required this.target,
    required this.icon,
    required this.group,
  });

  final String id;
  final String label;
  final String target;
  final IconData icon;
  final ShortcutGroup group;
}

/// The built-in set.
///
/// Deliberately fixed rather than scanned from the Start menu: enumerating
/// installed applications is slow, needs a watcher to stay current, and tells
/// the application something about the user it has no reason to know.
/// Everything here is a stable Windows target that either opens or reports that
/// it could not, and the user chooses which ones to pin.
class ShortcutCatalog {
  const ShortcutCatalog._();

  static const List<ShortcutEntry> all = <ShortcutEntry>[
    // --- The web ---------------------------------------------------------
    ShortcutEntry(
      id: 'youtube',
      label: 'YouTube',
      target: 'https://www.youtube.com',
      icon: DbIcons.play,
      group: ShortcutGroup.web,
    ),
    ShortcutEntry(
      id: 'ytmusic',
      label: 'YT Music',
      target: 'https://music.youtube.com',
      icon: DbIcons.music,
      group: ShortcutGroup.web,
    ),
    ShortcutEntry(
      id: 'spotify',
      label: 'Spotify',
      target: 'https://open.spotify.com',
      icon: DbIcons.music,
      group: ShortcutGroup.web,
    ),
    ShortcutEntry(
      id: 'netflix',
      label: 'Netflix',
      target: 'https://www.netflix.com',
      icon: DbIcons.movie,
      group: ShortcutGroup.web,
    ),
    ShortcutEntry(
      id: 'twitch',
      label: 'Twitch',
      target: 'https://www.twitch.tv',
      icon: DbIcons.movie,
      group: ShortcutGroup.web,
    ),
    ShortcutEntry(
      id: 'gmail',
      label: 'Gmail',
      target: 'https://mail.google.com',
      icon: DbIcons.mail,
      group: ShortcutGroup.web,
    ),
    ShortcutEntry(
      id: 'gcalendar',
      label: 'Calendar',
      target: 'https://calendar.google.com',
      icon: DbIcons.calendar,
      group: ShortcutGroup.web,
    ),
    ShortcutEntry(
      id: 'gdrive',
      label: 'Drive',
      target: 'https://drive.google.com',
      icon: DbIcons.cloud,
      group: ShortcutGroup.web,
    ),
    ShortcutEntry(
      id: 'maps',
      label: 'Maps',
      target: 'https://www.google.com/maps',
      icon: DbIcons.map,
      group: ShortcutGroup.web,
    ),
    ShortcutEntry(
      id: 'translate',
      label: 'Translate',
      target: 'https://translate.google.com',
      icon: DbIcons.translate,
      group: ShortcutGroup.web,
    ),
    ShortcutEntry(
      id: 'github',
      label: 'GitHub',
      target: 'https://github.com',
      icon: DbIcons.code,
      group: ShortcutGroup.web,
    ),
    ShortcutEntry(
      id: 'claude',
      label: 'Claude',
      target: 'https://claude.ai',
      icon: DbIcons.chat,
      group: ShortcutGroup.web,
    ),
    ShortcutEntry(
      id: 'chatgpt',
      label: 'ChatGPT',
      target: 'https://chatgpt.com',
      icon: DbIcons.chat,
      group: ShortcutGroup.web,
    ),
    ShortcutEntry(
      id: 'whatsapp',
      label: 'WhatsApp',
      target: 'https://web.whatsapp.com',
      icon: DbIcons.chat,
      group: ShortcutGroup.web,
    ),
    ShortcutEntry(
      id: 'x',
      label: 'X',
      target: 'https://x.com',
      icon: DbIcons.chat,
      group: ShortcutGroup.web,
    ),
    ShortcutEntry(
      id: 'reddit',
      label: 'Reddit',
      target: 'https://www.reddit.com',
      icon: DbIcons.chat,
      group: ShortcutGroup.web,
    ),

    // --- This PC ---------------------------------------------------------
    ShortcutEntry(
      id: 'explorer',
      label: 'Explorer',
      target: 'shell:MyComputerFolder',
      icon: DbIcons.folder,
      group: ShortcutGroup.apps,
    ),
    ShortcutEntry(
      id: 'downloads',
      label: 'Downloads',
      target: 'shell:Downloads',
      icon: DbIcons.download,
      group: ShortcutGroup.apps,
    ),
    ShortcutEntry(
      id: 'documents',
      label: 'Documents',
      target: 'shell:Personal',
      icon: DbIcons.notes,
      group: ShortcutGroup.apps,
    ),
    ShortcutEntry(
      id: 'pictures',
      label: 'Pictures',
      target: 'shell:My Pictures',
      icon: DbIcons.image,
      group: ShortcutGroup.apps,
    ),
    ShortcutEntry(
      id: 'recycle',
      label: 'Recycle Bin',
      target: 'shell:RecycleBinFolder',
      icon: DbIcons.delete,
      group: ShortcutGroup.apps,
    ),
    ShortcutEntry(
      id: 'terminal',
      label: 'Terminal',
      target: 'wt.exe',
      icon: DbIcons.terminal,
      group: ShortcutGroup.apps,
    ),
    ShortcutEntry(
      id: 'taskmgr',
      label: 'Task Manager',
      target: 'taskmgr.exe',
      icon: DbIcons.cpu,
      group: ShortcutGroup.apps,
    ),
    ShortcutEntry(
      id: 'calculator',
      label: 'Calculator',
      target: 'calc.exe',
      icon: DbIcons.calculator,
      group: ShortcutGroup.apps,
    ),
    ShortcutEntry(
      id: 'notepad',
      label: 'Notepad',
      target: 'notepad.exe',
      icon: DbIcons.notes,
      group: ShortcutGroup.apps,
    ),
    ShortcutEntry(
      id: 'paint',
      label: 'Paint',
      target: 'mspaint.exe',
      icon: DbIcons.image,
      group: ShortcutGroup.apps,
    ),
    ShortcutEntry(
      id: 'snip',
      label: 'Screen snip',
      target: 'ms-screenclip:',
      icon: DbIcons.crop,
      group: ShortcutGroup.apps,
    ),
    ShortcutEntry(
      id: 'camera',
      label: 'Camera',
      target: 'microsoft.windows.camera:',
      icon: DbIcons.camera,
      group: ShortcutGroup.apps,
    ),
    ShortcutEntry(
      id: 'store',
      label: 'Store',
      target: 'ms-windows-store:',
      icon: DbIcons.store,
      group: ShortcutGroup.apps,
    ),

    // --- Windows panels --------------------------------------------------
    ShortcutEntry(
      id: 'settings',
      label: 'Settings',
      target: 'ms-settings:',
      icon: DbIcons.settings,
      group: ShortcutGroup.windows,
    ),
    ShortcutEntry(
      id: 'sound',
      label: 'Sound',
      target: 'ms-settings:sound',
      icon: DbIcons.volume,
      group: ShortcutGroup.windows,
    ),
    ShortcutEntry(
      id: 'bluetooth',
      label: 'Bluetooth',
      target: 'ms-settings:bluetooth',
      icon: DbIcons.bluetooth,
      group: ShortcutGroup.windows,
    ),
    ShortcutEntry(
      id: 'wifi',
      label: 'Wi-Fi',
      target: 'ms-settings:network-wifi',
      icon: DbIcons.wifi,
      group: ShortcutGroup.windows,
    ),
    ShortcutEntry(
      id: 'displaysettings',
      label: 'Display',
      target: 'ms-settings:display',
      icon: DbIcons.display,
      group: ShortcutGroup.windows,
    ),
    ShortcutEntry(
      id: 'nightlight',
      label: 'Night light',
      target: 'ms-settings:nightlight',
      icon: DbIcons.nightLight,
      group: ShortcutGroup.windows,
    ),
    ShortcutEntry(
      id: 'batterysettings',
      label: 'Battery',
      target: 'ms-settings:batterysaver',
      icon: DbIcons.battery,
      group: ShortcutGroup.windows,
    ),
    ShortcutEntry(
      id: 'focus',
      label: 'Focus',
      target: 'ms-settings:quiethours',
      icon: DbIcons.focus,
      group: ShortcutGroup.windows,
    ),
    ShortcutEntry(
      id: 'notificationsettings',
      label: 'Notifications',
      target: 'ms-settings:notifications',
      icon: DbIcons.bell,
      group: ShortcutGroup.windows,
    ),
    ShortcutEntry(
      id: 'appsfeatures',
      label: 'Installed apps',
      target: 'ms-settings:appsfeatures',
      icon: DbIcons.features,
      group: ShortcutGroup.windows,
    ),
    ShortcutEntry(
      id: 'storage',
      label: 'Storage',
      target: 'ms-settings:storagesense',
      icon: DbIcons.storage,
      group: ShortcutGroup.windows,
    ),
    ShortcutEntry(
      id: 'update',
      label: 'Windows Update',
      target: 'ms-settings:windowsupdate',
      icon: DbIcons.restart,
      group: ShortcutGroup.windows,
    ),
  ];

  /// What a new installation shows: a dozen covering media, mail, files and the
  /// two Windows panels people actually reach for.
  static const List<String> defaultPinned = <String>[
    'youtube',
    'ytmusic',
    'spotify',
    'gmail',
    'gcalendar',
    'github',
    'explorer',
    'downloads',
    'terminal',
    'snip',
    'sound',
    'settings',
  ];

  /// The four on the home page's Apps panel until the user picks their own.
  /// Deliberately one from each kind of thing a person opens: a folder, a
  /// tool, a mailbox and something to watch.
  static const List<String> defaultHome = <String>[
    'explorer',
    'terminal',
    'gmail',
    'youtube',
  ];

  /// How many the home panel shows. Four fit across it without shrinking the
  /// labels into decoration.
  static const int homeSlots = 4;

  static ShortcutEntry? byId(String id) {
    for (final ShortcutEntry entry in all) {
      if (entry.id == id) {
        return entry;
      }
    }
    return null;
  }

  /// Ids that no longer exist are dropped rather than shown as a broken tile.
  static List<ShortcutEntry> resolve(List<String> ids) => <ShortcutEntry>[
    for (final String id in ids) ?byId(id),
  ];

  static List<ShortcutEntry> inGroup(ShortcutGroup group) => <ShortcutEntry>[
    for (final ShortcutEntry entry in all)
      if (entry.group == group) entry,
  ];
}
