/// What the island is being asked to be.
///
/// Intent is a decision; [IslandPhase] is the observed reality while the shape
/// catches up. Keeping them apart is what allows a collapse to be requested
/// mid-expansion without inventing a fictional in-between state.
enum IslandIntent { hidden, collapsed, expanded }

/// The lifecycle reported to the rest of the application.
enum IslandPhase {
  hidden,
  collapsed,
  expanding,
  expanded,

  /// Expanded and holding keyboard focus, so Escape and arrow keys apply.
  interactive,
  collapsing,
}

extension IslandPhaseX on IslandPhase {
  bool get isOpen =>
      this == IslandPhase.expanded || this == IslandPhase.interactive;

  bool get isMoving =>
      this == IslandPhase.expanding || this == IslandPhase.collapsing;

  bool get isVisible => this != IslandPhase.hidden;
}

/// What the island is currently showing.
///
/// One mode at a time, chosen by the presentation router. Clipboard activity
/// and system messages arrive as [notification]s rather than as modes of their
/// own: they are events, not states, and giving each its own island face would
/// mean five ways of saying the same small thing.
enum IslandMode {
  idle,
  media,
  notification,
  download,
  timer,
  privacy,
  settings,
}

extension IslandModeX on IslandMode {
  /// Ambient modes reflect something that is still happening; transient ones
  /// are shown for a moment and then hand the island back.
  bool get isTransient => this == IslandMode.notification;

  /// Settings needs far more room than any island face, so it runs on a larger
  /// stage. Everything else shares the one island-sized stage.
  bool get needsPanelStage => this == IslandMode.settings;
}

/// Why the island was opened. Used to decide whether taking keyboard focus is
/// appropriate: a click should focus, an automatic reveal should not.
enum IslandTrigger { user, hover, system, hotkey, tray }
