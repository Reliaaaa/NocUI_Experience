import 'dart:convert';
import 'dart:io';

import 'package:dynamicbar/design/theme/theme_controller.dart';
import 'package:dynamicbar/design/tokens/db_colors.dart';
import 'package:dynamicbar/settings/app_settings.dart';
import 'package:dynamicbar/settings/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppSettings serialisation', () {
    test('round trips every field', () {
      const AppSettings original = AppSettings(
        appearance: AppearanceMode.light,
        accent: AccentPreset.emerald,
        surfaceOpacity: 0.8,
        cornerScale: 1.2,
        islandScale: 1.1,
        motionIntensity: 0.6,
        monitorId: r'\\.\DISPLAY2',
        offsetX: 12,
        offsetY: -4,
        useWorkArea: true,
        use24HourClock: false,
        startPaused: true,
      );

      final AppSettings restored = AppSettings.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, Object?>,
      );

      expect(restored.appearance, AppearanceMode.light);
      expect(restored.accent, AccentPreset.emerald);
      expect(restored.surfaceOpacity, closeTo(0.8, 1e-9));
      expect(restored.cornerScale, closeTo(1.2, 1e-9));
      expect(restored.islandScale, closeTo(1.1, 1e-9));
      expect(restored.motionIntensity, closeTo(0.6, 1e-9));
      expect(restored.monitorId, r'\\.\DISPLAY2');
      expect(restored.offsetX, 12);
      expect(restored.offsetY, -4);
      expect(restored.useWorkArea, isTrue);
      expect(restored.use24HourClock, isFalse);
      expect(restored.startPaused, isTrue);
    });

    test('unknown and malformed values fall back to defaults', () {
      final AppSettings restored = AppSettings.fromJson(<String, Object?>{
        'appearance': 'neon',
        'accent': 'chartreuse',
        'surfaceOpacity': 'very',
        'islandScale': double.nan,
        'offsetX': null,
      });

      expect(restored.appearance, AppearanceMode.system);
      expect(restored.accent, AccentPreset.graphite);
      expect(restored.surfaceOpacity, AppSettings.defaults.surfaceOpacity);
      expect(restored.islandScale, AppSettings.defaults.islandScale);
      expect(restored.offsetX, AppSettings.defaults.offsetX);
    });

    test('out of range values are clamped rather than rejected', () {
      final AppSettings restored = AppSettings.fromJson(<String, Object?>{
        'surfaceOpacity': 4.0,
        'motionIntensity': -3.0,
      });
      expect(restored.surfaceOpacity, 1.0);
      expect(restored.motionIntensity, 0.0);
    });
  });

  group('SettingsStore', () {
    late Directory temporary;

    setUp(() async {
      temporary = await Directory.systemTemp.createTemp('dynamicbar_test');
    });

    tearDown(() async {
      if (temporary.existsSync()) {
        await temporary.delete(recursive: true);
      }
    });

    test('returns defaults when nothing has been written', () async {
      final SettingsStore store = SettingsStore(directory: temporary);
      final AppSettings loaded = await store.load();
      expect(loaded.accent, AppSettings.defaults.accent);
    });

    test('persists and reloads', () async {
      final SettingsStore store = SettingsStore(directory: temporary);
      const AppSettings settings = AppSettings(
        accent: AccentPreset.purple,
        islandScale: 1.25,
      );

      expect(await store.save(settings), isTrue);
      final AppSettings loaded = await store.load();
      expect(loaded.accent, AccentPreset.purple);
      expect(loaded.islandScale, closeTo(1.25, 1e-9));
    });

    test('survives a corrupt file', () async {
      final SettingsStore store = SettingsStore(directory: temporary);
      await store.file.create(recursive: true);
      await store.file.writeAsString('{ not json');

      final AppSettings loaded = await store.load();
      expect(loaded.accent, AppSettings.defaults.accent);
    });
  });
}
