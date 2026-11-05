import 'native_channel.dart';

/// The state of the launch-at-sign-in registration.
class StartupStatus {
  const StartupStatus({
    required this.registered,
    required this.healthy,
    required this.command,
    required this.expected,
  });

  static const StartupStatus unknown = StartupStatus(
    registered: false,
    healthy: false,
    command: '',
    expected: '',
  );

  /// An entry exists.
  final bool registered;

  /// The entry exists and points at this copy of the application.
  final bool healthy;

  /// What is currently registered.
  final String command;

  /// What should be registered.
  final String expected;

  /// Registered, but pointing somewhere else: the application was moved or
  /// reinstalled and the entry needs rewriting.
  bool get isStale => registered && !healthy;

  static StartupStatus fromMap(Map<Object?, Object?>? map) {
    if (map == null) {
      return unknown;
    }
    return StartupStatus(
      registered: (map['registered'] as bool?) ?? false,
      healthy: (map['healthy'] as bool?) ?? false,
      command: (map['command'] as String?) ?? '',
      expected: (map['expected'] as String?) ?? '',
    );
  }
}

/// Launch at Windows sign-in.
class StartupBridge extends NativeChannel {
  StartupBridge() : super('dynamicbar/startup');

  Future<StartupStatus> status() async =>
      StartupStatus.fromMap(await invokeMap('status'));

  Future<bool> setEnabled(bool enabled) async =>
      await invoke<bool>('setEnabled', <String, Object?>{'enabled': enabled}) ??
      false;

  /// Rewrites a registration that points at an old location. Returns true when
  /// a repair was actually needed and made.
  Future<bool> repair() async => await invoke<bool>('repair') ?? false;
}
