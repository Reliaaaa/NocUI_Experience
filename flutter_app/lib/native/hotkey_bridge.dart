import 'package:flutter/services.dart';

import 'native_channel.dart';

/// Win32 modifier flags, as RegisterHotKey expects them.
class HotkeyModifiers {
  const HotkeyModifiers._();

  static const int alt = 0x0001;
  static const int control = 0x0002;
  static const int shift = 0x0004;
  static const int win = 0x0008;
}

/// One shortcut: what to press, and what it does.
class HotkeyBinding {
  const HotkeyBinding({
    required this.id,
    required this.modifiers,
    required this.keyCode,
  });

  /// Action identifier, matched against the event the native side sends back.
  final String id;

  /// Bitwise OR of [HotkeyModifiers].
  final int modifiers;

  /// Win32 virtual key code.
  final int keyCode;

  bool get isValid => keyCode != 0;

  Map<String, Object?> toMap() => <String, Object?>{
    'id': id,
    'modifiers': modifiers,
    'keyCode': keyCode,
  };

  /// A human readable rendering, e.g. `Ctrl + Alt + Space`.
  String get label {
    final List<String> parts = <String>[];
    if (modifiers & HotkeyModifiers.control != 0) {
      parts.add('Ctrl');
    }
    if (modifiers & HotkeyModifiers.alt != 0) {
      parts.add('Alt');
    }
    if (modifiers & HotkeyModifiers.shift != 0) {
      parts.add('Shift');
    }
    if (modifiers & HotkeyModifiers.win != 0) {
      parts.add('Win');
    }
    parts.add(HotkeyCodes.nameOf(keyCode));
    return parts.join(' + ');
  }

  static HotkeyBinding? parse(String id, String value) {
    if (value.trim().isEmpty) {
      return null;
    }
    var modifiers = 0;
    var keyCode = 0;
    for (final String raw in value.split('+')) {
      final String part = raw.trim().toLowerCase();
      switch (part) {
        case 'ctrl':
        case 'control':
          modifiers |= HotkeyModifiers.control;
        case 'alt':
          modifiers |= HotkeyModifiers.alt;
        case 'shift':
          modifiers |= HotkeyModifiers.shift;
        case 'win':
        case 'meta':
          modifiers |= HotkeyModifiers.win;
        default:
          keyCode = HotkeyCodes.codeOf(part);
      }
    }
    if (keyCode == 0) {
      return null;
    }
    return HotkeyBinding(id: id, modifiers: modifiers, keyCode: keyCode);
  }

  /// Serialises back to the `Ctrl + Alt + Space` form stored in settings.
  String encode() => label;
}

/// Virtual key codes for the keys a shortcut is likely to use.
///
/// Deliberately a short list rather than a full keyboard map: a global shortcut
/// on a printable letter without modifiers would be hostile, and the settings
/// screen only offers what is here.
class HotkeyCodes {
  const HotkeyCodes._();

  static const Map<String, int> _byName = <String, int>{
    'space': 0x20,
    'escape': 0x1B,
    'tab': 0x09,
    'enter': 0x0D,
    'backspace': 0x08,
    'up': 0x26,
    'down': 0x28,
    'left': 0x25,
    'right': 0x27,
    'home': 0x24,
    'end': 0x23,
    'pageup': 0x21,
    'pagedown': 0x22,
    'insert': 0x2D,
    'delete': 0x2E,
    'f1': 0x70,
    'f2': 0x71,
    'f3': 0x72,
    'f4': 0x73,
    'f5': 0x74,
    'f6': 0x75,
    'f7': 0x76,
    'f8': 0x77,
    'f9': 0x78,
    'f10': 0x79,
    'f11': 0x7A,
    'f12': 0x7B,
  };

  static int codeOf(String name) {
    final String key = name.trim().toLowerCase();
    final int? known = _byName[key];
    if (known != null) {
      return known;
    }
    // Single letters and digits map to their ASCII upper case value.
    if (key.length == 1) {
      final int code = key.toUpperCase().codeUnitAt(0);
      final bool isLetter = code >= 0x41 && code <= 0x5A;
      final bool isDigit = code >= 0x30 && code <= 0x39;
      if (isLetter || isDigit) {
        return code;
      }
    }
    return 0;
  }

  static String nameOf(int code) {
    for (final MapEntry<String, int> entry in _byName.entries) {
      if (entry.value == code) {
        return _titleCase(entry.key);
      }
    }
    if ((code >= 0x41 && code <= 0x5A) || (code >= 0x30 && code <= 0x39)) {
      return String.fromCharCode(code);
    }
    return 'Key $code';
  }

  /// Maps a key pressed in the shortcut recorder to a virtual key code.
  static int fromLogicalKey(LogicalKeyboardKey key) {
    final String label = key.keyLabel;
    if (label.isNotEmpty) {
      final int code = codeOf(label);
      if (code != 0) {
        return code;
      }
    }
    return codeOf(key.debugName ?? '');
  }

  static String _titleCase(String value) {
    if (value.isEmpty) {
      return value;
    }
    if (value.startsWith('f') && value.length <= 3) {
      return value.toUpperCase();
    }
    return value[0].toUpperCase() + value.substring(1);
  }
}

/// Result of trying to register one shortcut.
class HotkeyOutcome {
  const HotkeyOutcome({
    required this.id,
    required this.registered,
    required this.error,
  });

  final String id;
  final bool registered;

  /// `alreadyInUse` when another application owns the combination.
  final String error;

  static HotkeyOutcome? fromMap(Object? value) {
    if (value is! Map) {
      return null;
    }
    final map = value.cast<Object?, Object?>();
    return HotkeyOutcome(
      id: (map['id'] as String?) ?? '',
      registered: (map['registered'] as bool?) ?? false,
      error: (map['error'] as String?) ?? '',
    );
  }
}

/// System wide keyboard shortcuts.
class HotkeyBridge extends NativeChannel {
  HotkeyBridge()
    : super(
        'dynamicbar/hotkeys',
        eventChannelName: 'dynamicbar/hotkeys/events',
      );

  /// Replaces every registration with this set, and reports which ones took.
  Future<List<HotkeyOutcome>> apply(List<HotkeyBinding> bindings) async {
    final List<Object?> raw = await invokeList('apply', <String, Object?>{
      'bindings': bindings
          .where((HotkeyBinding binding) => binding.isValid)
          .map((HotkeyBinding binding) => binding.toMap())
          .toList(growable: false),
    });
    final List<HotkeyOutcome> outcomes = <HotkeyOutcome>[];
    for (final Object? entry in raw) {
      final HotkeyOutcome? outcome = HotkeyOutcome.fromMap(entry);
      if (outcome != null) {
        outcomes.add(outcome);
      }
    }
    return outcomes;
  }

  Future<void> clear() => invoke<void>('clear');
}
