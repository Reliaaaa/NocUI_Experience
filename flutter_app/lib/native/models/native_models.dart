import 'dart:ui';

/// Geometry and identity of one monitor, as reported by the native layer.
class DisplayInfo {
  const DisplayInfo({
    required this.id,
    required this.name,
    required this.isPrimary,
    required this.bounds,
    required this.workArea,
    required this.dpi,
    required this.scale,
  });

  /// Stable device name, for example `\\.\DISPLAY1`.
  final String id;

  /// Friendly monitor name reported by the display driver.
  final String name;
  final bool isPrimary;

  /// Physical pixel bounds in virtual desktop space.
  final Rect bounds;

  /// Physical pixel work area (screen minus taskbar and app bars).
  final Rect workArea;
  final int dpi;
  final double scale;

  /// Logical size as Flutter would measure it on this monitor.
  Size get logicalSize => Size(bounds.width / scale, bounds.height / scale);

  static DisplayInfo? fromMap(Object? value) {
    if (value is! Map) {
      return null;
    }
    final map = value.cast<Object?, Object?>();
    final bounds = _rect(map['bounds']);
    final workArea = _rect(map['workArea']);
    if (bounds == null) {
      return null;
    }
    return DisplayInfo(
      id: (map['id'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      isPrimary: (map['primary'] as bool?) ?? false,
      bounds: bounds,
      workArea: workArea ?? bounds,
      dpi: (map['dpi'] as num?)?.toInt() ?? 96,
      scale: (map['scale'] as num?)?.toDouble() ?? 1.0,
    );
  }

  static Rect? _rect(Object? value) {
    if (value is! Map) {
      return null;
    }
    final map = value.cast<Object?, Object?>();
    final left = (map['left'] as num?)?.toDouble();
    final top = (map['top'] as num?)?.toDouble();
    final width = (map['width'] as num?)?.toDouble();
    final height = (map['height'] as num?)?.toDouble();
    if (left == null || top == null || width == null || height == null) {
      return null;
    }
    return Rect.fromLTWH(left, top, width, height);
  }

  @override
  String toString() => 'DisplayInfo($id, $name, ${scale}x, primary=$isPrimary)';
}

/// Current state of the stage window.
class StageInfo {
  const StageInfo({
    required this.monitorId,
    required this.scale,
    required this.dpi,
    required this.size,
    required this.isVisible,
    required this.isFocusable,
  });

  static const StageInfo unknown = StageInfo(
    monitorId: '',
    scale: 1.0,
    dpi: 96,
    size: Size.zero,
    isVisible: false,
    isFocusable: false,
  );

  final String monitorId;
  final double scale;
  final int dpi;

  /// Logical size of the stage.
  final Size size;
  final bool isVisible;
  final bool isFocusable;

  static StageInfo fromMap(Object? value) {
    if (value is! Map) {
      return unknown;
    }
    final map = value.cast<Object?, Object?>();
    return StageInfo(
      monitorId: (map['monitorId'] as String?) ?? '',
      scale: (map['scale'] as num?)?.toDouble() ?? 1.0,
      dpi: (map['dpi'] as num?)?.toInt() ?? 96,
      size: Size(
        (map['width'] as num?)?.toDouble() ?? 0,
        (map['height'] as num?)?.toDouble() ?? 0,
      ),
      isVisible: (map['visible'] as bool?) ?? false,
      isFocusable: (map['focusable'] as bool?) ?? false,
    );
  }
}

/// A `{type, ...}` message from one of the native event channels.
class NativeEvent {
  const NativeEvent(this.type, this.data);

  final String type;
  final Map<Object?, Object?> data;

  T? read<T>(String key) {
    final value = data[key];
    return value is T ? value : null;
  }

  static NativeEvent? fromMap(Object? value) {
    if (value is! Map) {
      return null;
    }
    final map = value.cast<Object?, Object?>();
    final type = map['type'];
    if (type is! String) {
      return null;
    }
    return NativeEvent(type, map);
  }

  @override
  String toString() => 'NativeEvent($type)';
}

/// One entry of the notification area menu.
class TrayMenuEntry {
  const TrayMenuEntry.item({
    required this.id,
    required this.label,
    this.enabled = true,
    this.isDefault = false,
  }) : type = 'normal',
       checked = false,
       children = const <TrayMenuEntry>[];

  const TrayMenuEntry.checkbox({
    required this.id,
    required this.label,
    required this.checked,
    this.enabled = true,
  }) : type = 'checkbox',
       isDefault = false,
       children = const <TrayMenuEntry>[];

  const TrayMenuEntry.submenu({
    required this.label,
    required this.children,
    this.enabled = true,
  }) : id = '',
       type = 'submenu',
       checked = false,
       isDefault = false;

  const TrayMenuEntry.separator()
    : id = '',
      label = '',
      type = 'separator',
      enabled = true,
      checked = false,
      isDefault = false,
      children = const <TrayMenuEntry>[];

  final String id;
  final String label;
  final String type;
  final bool enabled;
  final bool checked;
  final bool isDefault;
  final List<TrayMenuEntry> children;

  Map<String, Object?> toMap() => <String, Object?>{
    'id': id,
    'label': label,
    'type': type,
    'enabled': enabled,
    'checked': checked,
    'isDefault': isDefault,
    if (children.isNotEmpty)
      'items': children.map((child) => child.toMap()).toList(),
  };
}
