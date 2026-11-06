import 'dart:async';
import 'dart:io';

import 'package:dynamicbar/design/theme/theme_controller.dart';
import 'package:dynamicbar/settings/app_settings.dart';
import 'package:dynamicbar/settings/settings_controller.dart';
import 'package:dynamicbar/settings/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('remote edits are queued, preserve pending state, and never write locally', () async {
    final directory = await Directory.systemTemp.createTemp('nocui_remote_settings_');
    final store = SettingsStore(directory: directory);
    final theme = ThemeController();
    final first = Completer<Map<String, Object?>>();
    final second = Completer<Map<String, Object?>>();
    final patches = <Map<String, Object?>>[];
    final settings = SettingsController.remote(
      theme: theme,
      store: store,
      update: (patch) {
        patches.add(patch);
        return patches.length == 1 ? first.future : second.future;
      },
    );

    try {
      settings.applyRemote(AppSettings.defaults.toJson());
      settings.mutate((s) => s.copyWith(motionIntensity: 0.5));
      settings.mutate((s) => s.copyWith(cornerScale: 1.1));
      settings.mutate((s) => s.copyWith(cornerScale: 1.2));
      await Future<void>.delayed(Duration.zero);
      expect(patches, hasLength(1));
      expect(patches.first, <String, Object?>{'motionIntensity': 0.5});

      // An older owner snapshot must not erase unacknowledged local edits.
      settings.applyRemote(AppSettings.defaults.toJson());
      expect(settings.settings.motionIntensity, 0.5);
      expect(settings.settings.cornerScale, 1.2);

      first.complete(AppSettings.defaults.copyWith(motionIntensity: 0.5).toJson());
      await Future<void>.delayed(Duration.zero);
      expect(patches, hasLength(2));
      expect(patches.last, <String, Object?>{'cornerScale': 1.2});
      expect(settings.settings.cornerScale, 1.2);

      second.complete(AppSettings.defaults.copyWith(
        motionIntensity: 0.5,
        cornerScale: 1.2,
      ).toJson());
      await settings.flush();
      expect(settings.settings.motionIntensity, 0.5);
      expect(settings.settings.cornerScale, 1.2);
      expect(store.file.existsSync(), isFalse);
    } finally {
      settings.dispose();
      theme.dispose();
      await directory.delete(recursive: true);
    }
  });

  test('a rejected remote edit rolls back to the owner snapshot', () async {
    final theme = ThemeController();
    final settings = SettingsController.remote(
      theme: theme,
      update: (_) async => throw StateError('connection lost'),
    );
    try {
      settings.applyRemote(AppSettings.defaults.toJson());
      settings.mutate((s) => s.copyWith(motionIntensity: 0.5));
      await settings.flush();
      expect(settings.settings.motionIntensity, AppSettings.defaults.motionIntensity);
      expect(settings.remoteError, isNotNull);
      settings.applyRemote(AppSettings.defaults.toJson());
      expect(settings.settings.motionIntensity, AppSettings.defaults.motionIntensity);
    } finally {
      settings.dispose();
      theme.dispose();
    }
  });
}
