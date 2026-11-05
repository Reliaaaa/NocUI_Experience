import '../design/theme/theme_controller.dart';
import '../design/tokens/db_colors.dart';
import '../modules/shortcuts/shortcut_catalog.dart';

/// The persisted configuration document.
///
/// Immutable, with explicit serialisation. Every field is read back through a
/// tolerant parser so that a settings file written by an older version, hand
/// edited, or truncated by a power loss degrades to defaults for the fields it
/// cannot supply instead of failing the whole load.
class AppSettings {
  const AppSettings({
    this.appearance = AppearanceMode.system,
    this.accent = AccentPreset.graphite,
    this.surfaceOpacity = 0.94,
    this.cornerScale = 1.0,
    this.islandScale = 1.0,
    this.motionIntensity = 1.0,
    this.monitorId = '',
    this.offsetX = 0,
    this.offsetY = 0,
    this.useWorkArea = false,
    this.use24HourClock = true,
    this.startPaused = false,
    this.mediaEnabled = true,
    this.notificationsEnabled = true,
    this.downloadsEnabled = false,
    this.timersEnabled = true,
    this.clipboardEnabled = false,
    this.clipboardPreviewEnabled = false,
    this.systemStatusEnabled = true,
    this.volumeHudEnabled = true,
    this.launchAtStartup = false,
    this.startupDelaySeconds = 0,
    this.suppressInFullscreen = true,
    this.hideWhenCovered = true,
    this.autoCollapseSeconds = 8,
    this.wheelAdjustsVolume = true,
    this.hoverToPeek = true,
    this.autoHide = true,
    this.autoHideSeconds = 3,
    this.pinnedShortcuts = ShortcutCatalog.defaultPinned,
    this.homeShortcuts = ShortcutCatalog.defaultHome,
    this.homeDeckEnabled = true,
    this.weatherEnabled = false,
    this.weatherAutoLocate = false,
    this.weatherMetric = true,
    this.weatherPlace = '',
    this.weatherLatitude,
    this.weatherLongitude,
    this.disabledPages = const <String>[],
    this.introSeen = false,
    this.hotkeyToggle = 'Ctrl + Alt + Space',
    this.hotkeyExpand = '',
    this.hotkeyHide = '',
  });

  static const AppSettings defaults = AppSettings();

  /// Schema version, so a future migration has something to branch on.
  static const int schemaVersion = 1;

  final AppearanceMode appearance;
  final AccentPreset accent;
  final double surfaceOpacity;
  final double cornerScale;
  final double islandScale;
  final double motionIntensity;

  /// Empty means "whichever monitor is primary right now".
  final String monitorId;
  final double offsetX;
  final double offsetY;
  final bool useWorkArea;

  final bool use24HourClock;
  final bool startPaused;

  // Clipboard and Downloads monitoring are opt-in. Weather and automatic
  // location lookup are also opt-in because they can make network requests.
  final bool mediaEnabled;
  final bool notificationsEnabled;
  final bool downloadsEnabled;
  final bool timersEnabled;
  final bool clipboardEnabled;
  final bool clipboardPreviewEnabled;
  final bool systemStatusEnabled;
  final bool volumeHudEnabled;

  final bool launchAtStartup;

  /// Seconds to wait before showing the island when Windows started it. Gives
  /// the desktop time to settle before an overlay appears over it.
  final int startupDelaySeconds;

  /// Hide the island while a game, a presentation or Do Not Disturb is on.
  final bool suppressInFullscreen;

  /// Hide while a maximised or full-screen app is in front, return when it is
  /// minimised or restored.
  final bool hideWhenCovered;

  /// Seconds of no interaction before an open island closes itself. 0 keeps it
  /// open until dismissed. Every competitor that lacks this is reported as
  /// "gets in the way".
  final int autoCollapseSeconds;

  /// Scrolling the collapsed pill changes the volume.
  final bool wheelAdjustsVolume;

  /// The island grows slightly when the pointer reaches it.
  final bool hoverToPeek;

  /// The pill withdraws into the bezel when it is not being used, and comes
  /// back the moment the pointer approaches the top of the screen.
  final bool autoHide;

  /// Seconds of no interaction before the pill withdraws on its own - at
  /// launch, or after being used and left alone. Leaving the reveal zone with
  /// the pointer is handled separately and much faster: the user has just said
  /// where they are going.
  final int autoHideSeconds;

  /// Shortcut ids on the Shortcuts page, in the order they appear. An empty
  /// list is a real answer - a page the user has cleared - and is kept.
  final List<String> pinnedShortcuts;

  /// The four shortcuts on the home page's Apps panel, in the order they
  /// appear. Kept apart from [pinnedShortcuts]: the Shortcuts page is a
  /// drawer, and this is the shelf by the door.
  final List<String> homeShortcuts;

  /// The four panels under the clock. Switched off, the home page is the clock
  /// and today's agenda, as it was.
  final bool homeDeckEnabled;

  /// The one module that reaches the internet. Off means no request is ever
  /// made, not a hidden tile that keeps fetching.
  final bool weatherEnabled;

  /// Whether an unset location may be looked up from this connection's address.
  /// Off leaves the tile asking for a place until one is chosen by hand.
  final bool weatherAutoLocate;

  /// Celsius and km/h, or Fahrenheit and mph.
  final bool weatherMetric;

  /// Display name of the chosen place, for example `Erbil, Iraq`.
  final String weatherPlace;

  /// Null until a place has been chosen or found.
  final double? weatherLatitude;
  final double? weatherLongitude;

  /// Page ids the user has switched off. Absent pages are not built at all.
  final List<String> disabledPages;

  /// Whether the one-time explanation of how to use the island has been
  /// dismissed. An overlay with no chrome is undiscoverable without it.
  final bool introSeen;

  /// Shortcuts, stored in their display form (`Ctrl + Alt + Space`). Empty
  /// means the action has no shortcut.
  final String hotkeyToggle;
  final String hotkeyExpand;
  final String hotkeyHide;

  AppSettings copyWith({
    AppearanceMode? appearance,
    AccentPreset? accent,
    double? surfaceOpacity,
    double? cornerScale,
    double? islandScale,
    double? motionIntensity,
    String? monitorId,
    double? offsetX,
    double? offsetY,
    bool? useWorkArea,
    bool? use24HourClock,
    bool? startPaused,
    bool? mediaEnabled,
    bool? notificationsEnabled,
    bool? downloadsEnabled,
    bool? timersEnabled,
    bool? clipboardEnabled,
    bool? clipboardPreviewEnabled,
    bool? systemStatusEnabled,
    bool? volumeHudEnabled,
    bool? launchAtStartup,
    int? startupDelaySeconds,
    bool? suppressInFullscreen,
    bool? hideWhenCovered,
    int? autoCollapseSeconds,
    bool? wheelAdjustsVolume,
    bool? hoverToPeek,
    bool? autoHide,
    int? autoHideSeconds,
    List<String>? pinnedShortcuts,
    List<String>? homeShortcuts,
    bool? homeDeckEnabled,
    bool? weatherEnabled,
    bool? weatherAutoLocate,
    bool? weatherMetric,
    String? weatherPlace,
    double? weatherLatitude,
    double? weatherLongitude,
    List<String>? disabledPages,
    bool? introSeen,
    String? hotkeyToggle,
    String? hotkeyExpand,
    String? hotkeyHide,
  }) {
    return AppSettings(
      appearance: appearance ?? this.appearance,
      accent: accent ?? this.accent,
      surfaceOpacity: surfaceOpacity ?? this.surfaceOpacity,
      cornerScale: cornerScale ?? this.cornerScale,
      islandScale: islandScale ?? this.islandScale,
      motionIntensity: motionIntensity ?? this.motionIntensity,
      monitorId: monitorId ?? this.monitorId,
      offsetX: offsetX ?? this.offsetX,
      offsetY: offsetY ?? this.offsetY,
      useWorkArea: useWorkArea ?? this.useWorkArea,
      use24HourClock: use24HourClock ?? this.use24HourClock,
      startPaused: startPaused ?? this.startPaused,
      mediaEnabled: mediaEnabled ?? this.mediaEnabled,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      downloadsEnabled: downloadsEnabled ?? this.downloadsEnabled,
      timersEnabled: timersEnabled ?? this.timersEnabled,
      clipboardEnabled: clipboardEnabled ?? this.clipboardEnabled,
      clipboardPreviewEnabled:
          clipboardPreviewEnabled ?? this.clipboardPreviewEnabled,
      systemStatusEnabled: systemStatusEnabled ?? this.systemStatusEnabled,
      volumeHudEnabled: volumeHudEnabled ?? this.volumeHudEnabled,
      launchAtStartup: launchAtStartup ?? this.launchAtStartup,
      startupDelaySeconds: startupDelaySeconds ?? this.startupDelaySeconds,
      suppressInFullscreen: suppressInFullscreen ?? this.suppressInFullscreen,
      hideWhenCovered: hideWhenCovered ?? this.hideWhenCovered,
      autoCollapseSeconds: autoCollapseSeconds ?? this.autoCollapseSeconds,
      wheelAdjustsVolume: wheelAdjustsVolume ?? this.wheelAdjustsVolume,
      hoverToPeek: hoverToPeek ?? this.hoverToPeek,
      autoHide: autoHide ?? this.autoHide,
      autoHideSeconds: autoHideSeconds ?? this.autoHideSeconds,
      pinnedShortcuts: pinnedShortcuts ?? this.pinnedShortcuts,
      homeShortcuts: homeShortcuts ?? this.homeShortcuts,
      homeDeckEnabled: homeDeckEnabled ?? this.homeDeckEnabled,
      weatherEnabled: weatherEnabled ?? this.weatherEnabled,
      weatherAutoLocate: weatherAutoLocate ?? this.weatherAutoLocate,
      weatherMetric: weatherMetric ?? this.weatherMetric,
      weatherPlace: weatherPlace ?? this.weatherPlace,
      weatherLatitude: weatherLatitude ?? this.weatherLatitude,
      weatherLongitude: weatherLongitude ?? this.weatherLongitude,
      disabledPages: disabledPages ?? this.disabledPages,
      introSeen: introSeen ?? this.introSeen,
      hotkeyToggle: hotkeyToggle ?? this.hotkeyToggle,
      hotkeyExpand: hotkeyExpand ?? this.hotkeyExpand,
      hotkeyHide: hotkeyHide ?? this.hotkeyHide,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'appearance': appearance.name,
    'accent': accent.name,
    'surfaceOpacity': surfaceOpacity,
    'cornerScale': cornerScale,
    'islandScale': islandScale,
    'motionIntensity': motionIntensity,
    'monitorId': monitorId,
    'offsetX': offsetX,
    'offsetY': offsetY,
    'useWorkArea': useWorkArea,
    'use24HourClock': use24HourClock,
    'startPaused': startPaused,
    'mediaEnabled': mediaEnabled,
    'notificationsEnabled': notificationsEnabled,
    'downloadsEnabled': downloadsEnabled,
    'timersEnabled': timersEnabled,
    'clipboardEnabled': clipboardEnabled,
    'clipboardPreviewEnabled': clipboardPreviewEnabled,
    'systemStatusEnabled': systemStatusEnabled,
    'volumeHudEnabled': volumeHudEnabled,
    'launchAtStartup': launchAtStartup,
    'startupDelaySeconds': startupDelaySeconds,
    'suppressInFullscreen': suppressInFullscreen,
    'hideWhenCovered': hideWhenCovered,
    'autoCollapseSeconds': autoCollapseSeconds,
    'wheelAdjustsVolume': wheelAdjustsVolume,
    'hoverToPeek': hoverToPeek,
    'autoHide': autoHide,
    'autoHideSeconds': autoHideSeconds,
    'pinnedShortcuts': pinnedShortcuts,
    'homeShortcuts': homeShortcuts,
    'homeDeckEnabled': homeDeckEnabled,
    'weatherEnabled': weatherEnabled,
    'weatherAutoLocate': weatherAutoLocate,
    'weatherMetric': weatherMetric,
    'weatherPlace': weatherPlace,
    'weatherLatitude': weatherLatitude,
    'weatherLongitude': weatherLongitude,
    'disabledPages': disabledPages,
    'introSeen': introSeen,
    'hotkeyToggle': hotkeyToggle,
    'hotkeyExpand': hotkeyExpand,
    'hotkeyHide': hotkeyHide,
  };

  static AppSettings fromJson(Map<String, Object?> json) {
    return AppSettings(
      appearance: AppearanceModeX.fromName(json['appearance'] as String?),
      accent: AccentPresetX.fromName(json['accent'] as String?),
      surfaceOpacity: _double(
        json['surfaceOpacity'],
        defaults.surfaceOpacity,
        0.55,
        1.0,
      ),
      cornerScale: _double(json['cornerScale'], defaults.cornerScale, 0.4, 1.6),
      islandScale: _double(
        json['islandScale'],
        defaults.islandScale,
        0.85,
        1.35,
      ),
      motionIntensity: _double(
        json['motionIntensity'],
        defaults.motionIntensity,
        0.0,
        1.4,
      ),
      monitorId: json['monitorId'] is String
          ? json['monitorId'] as String
          : defaults.monitorId,
      offsetX: _double(json['offsetX'], defaults.offsetX, -4000, 4000),
      offsetY: _double(json['offsetY'], defaults.offsetY, -2000, 2000),
      useWorkArea: _bool(json['useWorkArea'], defaults.useWorkArea),
      use24HourClock: _bool(json['use24HourClock'], defaults.use24HourClock),
      startPaused: _bool(json['startPaused'], defaults.startPaused),
      mediaEnabled: _bool(json['mediaEnabled'], defaults.mediaEnabled),
      notificationsEnabled: _bool(
        json['notificationsEnabled'],
        defaults.notificationsEnabled,
      ),
      downloadsEnabled: _bool(
        json['downloadsEnabled'],
        defaults.downloadsEnabled,
      ),
      timersEnabled: _bool(json['timersEnabled'], defaults.timersEnabled),
      clipboardEnabled: _bool(
        json['clipboardEnabled'],
        defaults.clipboardEnabled,
      ),
      clipboardPreviewEnabled: _bool(
        json['clipboardPreviewEnabled'],
        defaults.clipboardPreviewEnabled,
      ),
      systemStatusEnabled: _bool(
        json['systemStatusEnabled'],
        defaults.systemStatusEnabled,
      ),
      volumeHudEnabled: _bool(
        json['volumeHudEnabled'],
        defaults.volumeHudEnabled,
      ),
      launchAtStartup: _bool(json['launchAtStartup'], defaults.launchAtStartup),
      startupDelaySeconds: _double(
        json['startupDelaySeconds'],
        defaults.startupDelaySeconds.toDouble(),
        0,
        120,
      ).round(),
      suppressInFullscreen: _bool(
        json['suppressInFullscreen'],
        defaults.suppressInFullscreen,
      ),
      hideWhenCovered: _bool(json['hideWhenCovered'], defaults.hideWhenCovered),
      autoCollapseSeconds: _double(
        json['autoCollapseSeconds'],
        defaults.autoCollapseSeconds.toDouble(),
        0,
        120,
      ).round(),
      wheelAdjustsVolume: _bool(
        json['wheelAdjustsVolume'],
        defaults.wheelAdjustsVolume,
      ),
      hoverToPeek: _bool(json['hoverToPeek'], defaults.hoverToPeek),
      autoHide: _bool(json['autoHide'], defaults.autoHide),
      autoHideSeconds: _double(
        json['autoHideSeconds'],
        defaults.autoHideSeconds.toDouble(),
        1,
        60,
      ).round(),
      pinnedShortcuts: _stringList(
        json['pinnedShortcuts'],
        defaults.pinnedShortcuts,
      ),
      homeShortcuts: _stringList(json['homeShortcuts'], defaults.homeShortcuts),
      homeDeckEnabled: _bool(json['homeDeckEnabled'], defaults.homeDeckEnabled),
      weatherEnabled: _bool(json['weatherEnabled'], defaults.weatherEnabled),
      weatherAutoLocate: _bool(
        json['weatherAutoLocate'],
        defaults.weatherAutoLocate,
      ),
      weatherMetric: _bool(json['weatherMetric'], defaults.weatherMetric),
      weatherPlace: _string(json['weatherPlace'], defaults.weatherPlace),
      weatherLatitude: _nullableDouble(json['weatherLatitude'], 90),
      weatherLongitude: _nullableDouble(json['weatherLongitude'], 180),
      disabledPages: _stringList(json['disabledPages'], defaults.disabledPages),
      introSeen: _bool(json['introSeen'], defaults.introSeen),
      hotkeyToggle: _string(json['hotkeyToggle'], defaults.hotkeyToggle),
      hotkeyExpand: _string(json['hotkeyExpand'], defaults.hotkeyExpand),
      hotkeyHide: _string(json['hotkeyHide'], defaults.hotkeyHide),
    );
  }

  static double _double(
    Object? value,
    double fallback,
    double min,
    double max,
  ) {
    if (value is num && value.isFinite) {
      return value.toDouble().clamp(min, max).toDouble();
    }
    return fallback;
  }

  /// A coordinate, or null when there is not a usable one. Out of range means
  /// the file was hand edited into something no forecast could answer, which
  /// is the same as not having a place at all.
  static double? _nullableDouble(Object? value, double limit) {
    if (value is num && value.isFinite && value.abs() <= limit) {
      return value.toDouble();
    }
    return null;
  }

  static bool _bool(Object? value, bool fallback) =>
      value is bool ? value : fallback;

  static List<String> _stringList(Object? value, List<String> fallback) {
    if (value is! List) {
      return fallback;
    }

    return value.whereType<String>().toList(growable: false);
  }

  static String _string(Object? value, String fallback) =>
      value is String ? value : fallback;
}
