/// Static facts about this build.
///
/// Kept as constants rather than read from the package metadata at runtime:
/// the alternative is a plugin and an async call for two strings that are fixed
/// at compile time. Keep [version] in step with `pubspec.yaml`.
class AppInfo {
  const AppInfo._();

  static const String name = 'NocUI Experience';
  static const String version = '1.1.1';

  static const String tagline = 'A Dynamic Island for Windows 11.';

  /// Who made it. One person, named in full in the one place a person would
  /// look for it.
  static const String developer = 'Reliaaaa';
  static const String developerRole = 'Design and engineering';

  /// The name as an HTTP product token: User-Agent has no room for the space.
  static String get userAgentToken => name.replaceAll(' ', '');

  /// The monogram, derived rather than typed twice.
  static String get developerInitials => developer
      .split(' ')
      .where((String part) => part.isNotEmpty)
      .map((String part) => part[0].toUpperCase())
      .take(2)
      .join();

  /// Third party code in the shipped binary. There is deliberately very little
  /// of it: the application takes no runtime package dependencies, so this is
  /// the framework and the platform, and nothing else.
  static const List<({String name, String licence})> licences =
      <({String name, String licence})>[
        (name: 'Flutter', licence: 'BSD 3-Clause'),
        (name: 'Dart SDK', licence: 'BSD 3-Clause'),
        (name: 'Material Icons', licence: 'Apache 2.0'),
      ];
}
