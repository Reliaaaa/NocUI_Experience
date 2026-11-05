import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

import '../../core/logging/app_logger.dart';
import '../../native/models/native_models.dart';
import '../../native/shelf_bridge.dart';

/// One shelved image.
@immutable
class ShelfImage {
  const ShelfImage({
    required this.slot,
    required this.path,
    required this.width,
    required this.height,
    required this.savedAt,
  });

  /// 0 or 1. The shelf holds two, in fixed places, so a slot can be replaced
  /// without the other one moving.
  final int slot;

  final String path;
  final int width;
  final int height;
  final DateTime savedAt;

  File get file => File(path);

  Map<String, Object?> toJson() => <String, Object?>{
    'slot': slot,
    'path': path,
    'width': width,
    'height': height,
    'savedAt': savedAt.toIso8601String(),
  };

  static ShelfImage? fromJson(Map<String, Object?> json) {
    final Object? slot = json['slot'];
    final Object? path = json['path'];
    if (slot is! num || path is! String) {
      return null;
    }
    return ShelfImage(
      slot: slot.toInt(),
      path: path,
      width: (json['width'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
      savedAt:
          DateTime.tryParse(json['savedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

/// A scratch space: two images and one piece of text.
///
/// Deliberately small and deliberately fixed. An unbounded shelf becomes a
/// second file manager that nobody tidies; two slots and a note stay a place
/// you *put something down for a minute*, which is the thing that was actually
/// missing.
///
/// The images live as PNG files under the application's own folder, so they
/// survive a restart and can be opened with any other program, and the whole
/// shelf can be emptied in one action.
class ShelfController extends ChangeNotifier {
  ShelfController({required ShelfBridge bridge, Directory? directory})
    : _bridge = bridge,
      _directoryOverride = directory;

  static const Logger _log = Logger('Shelf');
  static const String _fileName = 'shelf.json';

  /// How many images the shelf holds.
  static const int slots = 2;

  final ShelfBridge _bridge;
  final Directory? _directoryOverride;

  final Map<int, ShelfImage> _images = <int, ShelfImage>{};
  String _text = '';
  DateTime? _textSavedAt;
  bool _loaded = false;
  StreamSubscription<NativeEvent>? _events;

  /// True while something draggable is being held over the island. The page
  /// lights up so the drop has a visible target.
  bool _dragging = false;
  bool get isDragging => _dragging;

  /// Raised when a drop actually lands, so the island can open on the shelf and
  /// show the user where their image went.
  VoidCallback? onDropped;

  /// Bumped whenever a slot's file is rewritten, so the image widget can be
  /// keyed on it. Flutter caches decoded images by path, and a replaced file
  /// at the same path would otherwise keep showing the old picture.
  int _revision = 0;

  int get revision => _revision;
  String get text => _text;
  DateTime? get textSavedAt => _textSavedAt;
  bool get isLoaded => _loaded;

  ShelfImage? imageAt(int slot) => _images[slot];
  bool get isEmpty => _images.isEmpty && _text.trim().isEmpty;

  Directory get directory {
    final Directory? override = _directoryOverride;
    if (override != null) {
      return override;
    }
    final String local =
        Platform.environment['LOCALAPPDATA'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.systemTemp.path;
    return Directory(
      '$local${Platform.pathSeparator}DynamicBar${Platform.pathSeparator}shelf',
    );
  }

  File get _index =>
      File('${directory.path}${Platform.pathSeparator}$_fileName');

  String _pathForSlot(int slot) =>
      '${directory.path}${Platform.pathSeparator}slot$slot.png';

  Future<void> load() async {
    if (_loaded) {
      return;
    }
    _loaded = true;
    _events ??= _bridge.events.listen(_onNativeEvent);
    try {
      if (_index.existsSync()) {
        final String raw = await _index.readAsString();
        if (raw.trim().isNotEmpty) {
          final Object? decoded = jsonDecode(raw);
          if (decoded is Map) {
            _text = decoded['text'] is String ? decoded['text']! as String : '';
            _textSavedAt = DateTime.tryParse(
              decoded['textSavedAt'] as String? ?? '',
            );
            final Object? images = decoded['images'];
            if (images is List) {
              for (final Object? row in images) {
                if (row is Map) {
                  final ShelfImage? image = ShelfImage.fromJson(
                    row.cast<String, Object?>(),
                  );
                  // A slot whose file was deleted from outside is dropped
                  // rather than shown as a broken thumbnail.
                  if (image != null && image.file.existsSync()) {
                    _images[image.slot] = image;
                  }
                }
              }
            }
          }
        }
      }
    } on FormatException catch (error) {
      _log.warn('Shelf index is corrupt; starting empty.', error);
    } on FileSystemException catch (error) {
      _log.warn('Shelf index could not be read; starting empty.', error);
    }
    notifyListeners();
  }

  /// True when there is an image on the clipboard worth offering to shelve.
  Future<bool> clipboardHasImage() => _bridge.hasImage();

  // --- Drag and drop --------------------------------------------------------

  void _onNativeEvent(NativeEvent event) {
    switch (event.type) {
      case 'dragging':
        final bool inside = event.read<bool>('inside') ?? false;
        if (_dragging != inside) {
          _dragging = inside;
          notifyListeners();
        }

      case 'drop':
        final List<Object?> raw =
            event.data['paths'] as List<Object?>? ?? const <Object?>[];
        unawaited(
          acceptDropped(<String>[
            for (final Object? path in raw)
              if (path is String) path,
          ]),
        );

      default:
        break;
    }
  }

  /// Takes dropped images and puts them away without asking anything.
  ///
  /// The point of dropping something on a shelf is that you do not have to
  /// decide where it goes, so the first free slot wins, and when both are full
  /// the older of the two is replaced. Only the first two files of a drop are
  /// kept - the shelf holds two, and silently discarding the rest is better
  /// than pretending otherwise, which is why the caller is told how many
  /// landed.
  Future<int> acceptDropped(List<String> sources) async {
    if (sources.isEmpty) {
      return 0;
    }
    int accepted = 0;
    for (final String source in sources) {
      if (accepted >= slots) {
        break;
      }
      if (await _importInto(_nextSlot(), source)) {
        accepted++;
      }
    }
    if (accepted > 0) {
      onDropped?.call();
    }
    return accepted;
  }

  /// The first empty slot, or the one holding the older image.
  int _nextSlot() {
    for (int slot = 0; slot < slots; slot++) {
      if (!_images.containsKey(slot)) {
        return slot;
      }
    }
    final ShelfImage? first = _images[0];
    final ShelfImage? second = _images[1];
    if (first == null || second == null) {
      return 0;
    }
    return first.savedAt.isAfter(second.savedAt) ? 1 : 0;
  }

  Future<bool> _importInto(int slot, String source) async {
    if (!await _ensureDirectory()) {
      return false;
    }
    final String path = _pathForSlot(slot);
    final CapturedImage imported = await _bridge.importImage(source, path);
    if (!imported.ok) {
      _log.warn('Could not import a dropped image: $source');
      return false;
    }
    _images[slot] = ShelfImage(
      slot: slot,
      path: path,
      width: imported.width,
      height: imported.height,
      savedAt: DateTime.now(),
    );
    _revision++;
    await _evict(path);
    // An image dragged out of a browser arrives as a scratch file in the
    // temporary folder; it has been copied now, so it should not be left
    // behind.
    if (source.contains('dynamicbar-drop-')) {
      try {
        final File scratch = File(source);
        if (scratch.existsSync()) {
          await scratch.delete();
        }
      } on FileSystemException {
        // Windows will clear the temporary folder eventually.
      }
    }
    _log.info(
      'Image dropped into slot $slot '
      '(${imported.width}x${imported.height}).',
    );
    unawaited(_save());
    notifyListeners();
    return true;
  }

  Future<bool> _ensureDirectory() async {
    try {
      if (!directory.existsSync()) {
        await directory.create(recursive: true);
      }
      return true;
    } on FileSystemException catch (error) {
      _log.error('Could not create the shelf folder.', error);
      return false;
    }
  }

  /// Pulls whatever image is on the clipboard into [slot].
  ///
  /// Returns false when the clipboard holds no image, which the caller shows:
  /// a paste button that silently does nothing is worse than no button.
  Future<bool> pasteImage(int slot) async {
    if (slot < 0 || slot >= slots || !await _ensureDirectory()) {
      return false;
    }

    final String path = _pathForSlot(slot);
    final CapturedImage captured = await _bridge.captureImage(path);
    if (!captured.ok) {
      return false;
    }
    _images[slot] = ShelfImage(
      slot: slot,
      path: path,
      width: captured.width,
      height: captured.height,
      savedAt: DateTime.now(),
    );
    _revision++;
    // The file at this path has changed underneath Flutter's image cache.
    await _evict(path);
    _log.info('Image shelved in slot $slot (${captured.width}x'
        '${captured.height}).');
    unawaited(_save());
    notifyListeners();
    return true;
  }

  Future<bool> copyImage(int slot) async {
    final ShelfImage? image = _images[slot];
    if (image == null) {
      return false;
    }
    return _bridge.copyImage(image.path);
  }

  Future<void> clearImage(int slot) async {
    final ShelfImage? image = _images.remove(slot);
    if (image == null) {
      return;
    }
    _revision++;
    try {
      if (image.file.existsSync()) {
        await image.file.delete();
      }
    } on FileSystemException catch (error) {
      _log.warn('Could not delete a shelved image.', error);
    }
    await _evict(image.path);
    unawaited(_save());
    notifyListeners();
  }

  void setText(String value) {
    if (_text == value) {
      return;
    }
    _text = value;
    _textSavedAt = value.trim().isEmpty ? null : DateTime.now();
    _scheduleSave();
    notifyListeners();
  }

  /// Puts the clipboard's text on the shelf. Returns false when there is none.
  Future<bool> pasteText() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    final String? value = data?.text;
    if (value == null || value.isEmpty) {
      return false;
    }
    setText(value);
    return true;
  }

  Future<void> copyText() =>
      Clipboard.setData(ClipboardData(text: _text));

  Future<void> clearAll() async {
    for (final int slot in _images.keys.toList(growable: false)) {
      await clearImage(slot);
    }
    setText('');
    await flush();
  }

  /// Drops a decoded image from Flutter's cache so a replaced file is re-read
  /// rather than served from memory at its old contents.
  Future<void> _evict(String path) async {
    await FileImage(File(path)).evict();
  }

  Timer? _saveDebounce;

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 600), () {
      unawaited(_save());
    });
  }

  Future<void> _save() async {
    _saveDebounce?.cancel();
    _saveDebounce = null;
    try {
      if (!directory.existsSync()) {
        await directory.create(recursive: true);
      }
      final File temporary = File('${_index.path}.tmp');
      const JsonEncoder encoder = JsonEncoder.withIndent('  ');
      await temporary.writeAsString(
        encoder.convert(<String, Object?>{
          'text': _text,
          'textSavedAt': _textSavedAt?.toIso8601String(),
          'images': <Object?>[
            for (final ShelfImage image in _images.values) image.toJson(),
          ],
        }),
        flush: true,
      );
      await temporary.rename(_index.path);
    } on FileSystemException catch (error, stackTrace) {
      _log.error('Could not save the shelf.', error, stackTrace);
    }
  }

  Future<void> flush() => _save();

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _events?.cancel();
    _events = null;
    super.dispose();
  }
}
