import '../design/tokens/db_icons.dart';
import 'native_channel.dart';

import 'package:flutter/widgets.dart' show IconData;

/// The things Windows will do to this session.
///
/// Ordered from the harmless to the irreversible, which is also the order they
/// are shown in: locking the screen costs nothing, shutting down costs whatever
/// was unsaved.
enum PowerAction { lock, screenOff, sleep, hibernate, signOut, restart, shutdown }

extension PowerActionX on PowerAction {
  /// Sent to the native side. Stable across releases.
  String get id {
    switch (this) {
      case PowerAction.lock:
        return 'lock';
      case PowerAction.screenOff:
        return 'screenOff';
      case PowerAction.sleep:
        return 'sleep';
      case PowerAction.hibernate:
        return 'hibernate';
      case PowerAction.signOut:
        return 'signOut';
      case PowerAction.restart:
        return 'restart';
      case PowerAction.shutdown:
        return 'shutdown';
    }
  }

  String get label {
    switch (this) {
      case PowerAction.lock:
        return 'Lock';
      case PowerAction.screenOff:
        return 'Screen off';
      case PowerAction.sleep:
        return 'Sleep';
      case PowerAction.hibernate:
        return 'Hibernate';
      case PowerAction.signOut:
        return 'Sign out';
      case PowerAction.restart:
        return 'Restart';
      case PowerAction.shutdown:
        return 'Shut down';
    }
  }

  String get description {
    switch (this) {
      case PowerAction.lock:
        return 'Lock the screen and keep everything running';
      case PowerAction.screenOff:
        return 'Turn the displays off without locking';
      case PowerAction.sleep:
        return 'Suspend to memory';
      case PowerAction.hibernate:
        return 'Save the session to disk and power down';
      case PowerAction.signOut:
        return 'Close every app and sign out';
      case PowerAction.restart:
        return 'Close every app and restart Windows';
      case PowerAction.shutdown:
        return 'Close every app and turn the PC off';
    }
  }

  IconData get icon {
    switch (this) {
      case PowerAction.lock:
        return DbIcons.lock;
      case PowerAction.screenOff:
        return DbIcons.screenOff;
      case PowerAction.sleep:
        return DbIcons.sleep;
      case PowerAction.hibernate:
        return DbIcons.hibernate;
      case PowerAction.signOut:
        return DbIcons.signOut;
      case PowerAction.restart:
        return DbIcons.restart;
      case PowerAction.shutdown:
        return DbIcons.power;
    }
  }

  /// Whether running this loses unsaved work. Those ask for a second click
  /// before they do anything, because an overlay that sits under the cursor all
  /// day must never be one stray click away from ending the session.
  bool get needsConfirmation {
    switch (this) {
      case PowerAction.lock:
      case PowerAction.screenOff:
      case PowerAction.sleep:
      case PowerAction.hibernate:
        return false;
      case PowerAction.signOut:
      case PowerAction.restart:
      case PowerAction.shutdown:
        return true;
    }
  }
}

/// What this machine can actually do. A desktop with hibernation switched off
/// should not be offered a hibernate button that quietly does nothing.
class PowerCapabilities {
  const PowerCapabilities({
    this.sleep = true,
    this.hibernate = false,
    this.lock = true,
    this.screenOff = true,
    this.shutdown = true,
    this.restart = true,
    this.signOut = true,
  });

  static const PowerCapabilities unknown = PowerCapabilities();

  final bool sleep;
  final bool hibernate;
  final bool lock;
  final bool screenOff;
  final bool shutdown;
  final bool restart;
  final bool signOut;

  bool supports(PowerAction action) {
    switch (action) {
      case PowerAction.lock:
        return lock;
      case PowerAction.screenOff:
        return screenOff;
      case PowerAction.sleep:
        return sleep;
      case PowerAction.hibernate:
        return hibernate;
      case PowerAction.signOut:
        return signOut;
      case PowerAction.restart:
        return restart;
      case PowerAction.shutdown:
        return shutdown;
    }
  }

  static PowerCapabilities fromMap(Map<Object?, Object?> map) =>
      PowerCapabilities(
        sleep: (map['sleep'] as bool?) ?? true,
        hibernate: (map['hibernate'] as bool?) ?? false,
        lock: (map['lock'] as bool?) ?? true,
        screenOff: (map['screenOff'] as bool?) ?? true,
        shutdown: (map['shutdown'] as bool?) ?? true,
        restart: (map['restart'] as bool?) ?? true,
        signOut: (map['signOut'] as bool?) ?? true,
      );
}

/// Session and machine power actions.
///
/// Stateless, like [ShellBridge]: nothing here observes anything, and every
/// call happens because someone clicked something.
class PowerBridge extends NativeChannel {
  PowerBridge() : super('dynamicbar/power');

  Future<PowerCapabilities> capabilities() async {
    final Map<Object?, Object?>? map = await invokeMap('capabilities');
    return map == null
        ? PowerCapabilities.unknown
        : PowerCapabilities.fromMap(map);
  }

  Future<bool> run(PowerAction action) async =>
      await invoke<bool>('run', <String, Object?>{'action': action.id}) ?? false;
}
