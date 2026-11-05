import 'package:flutter/widgets.dart';

import '../../design/tokens/db_icons.dart';

/// A page of the expanded island.
///
/// The expanded island is a horizontal pager rather than a single face: 480
/// logical pixels cannot hold seven features at once, and a pager is the only
/// arrangement that lets the user reach any of them in one gesture without a
/// menu.
///
/// Pages are declared here in the order they appear. A page whose module is
/// switched off is not built, not laid out and not reachable - it is absent
/// from the pager entirely rather than shown empty.
enum IslandPage {
  now,
  calendar,
  timers,
  shortcuts,
  media,
  shelf,
  system,
  notes,
  clipboard,
}

extension IslandPageX on IslandPage {
  String get label {
    switch (this) {
      case IslandPage.now:
        return 'Now';
      case IslandPage.media:
        return 'Media';
      case IslandPage.calendar:
        return 'Calendar';
      case IslandPage.shortcuts:
        return 'Shortcuts';
      case IslandPage.shelf:
        return 'Shelf';
      case IslandPage.timers:
        return 'Timers';
      case IslandPage.system:
        return 'System';
      case IslandPage.notes:
        return 'Notes';
      case IslandPage.clipboard:
        return 'Clipboard';
    }
  }

  IconData get icon {
    switch (this) {
      case IslandPage.now:
        return DbIcons.clock;
      case IslandPage.media:
        return DbIcons.play;
      case IslandPage.calendar:
        return DbIcons.calendar;
      case IslandPage.shortcuts:
        return DbIcons.grid;
      case IslandPage.shelf:
        return DbIcons.shelf;
      case IslandPage.timers:
        return DbIcons.timer;
      case IslandPage.system:
        return DbIcons.cpu;
      case IslandPage.notes:
        return DbIcons.notes;
      case IslandPage.clipboard:
        return DbIcons.clipboard;
    }
  }

  /// Identifier used in the settings document. Stable across releases even if
  /// the enum is reordered.
  String get id => name;

  /// The Now page is the home of the island and cannot be turned off; there
  /// has to be somewhere for the pager to land.
  bool get canBeDisabled => this != IslandPage.now;

  static IslandPage? fromId(String? id) {
    for (final IslandPage page in IslandPage.values) {
      if (page.id == id) {
        return page;
      }
    }
    return null;
  }
}
