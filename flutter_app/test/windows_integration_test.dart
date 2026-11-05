import 'package:dynamicbar/modules/notifications/island_notification.dart';
import 'package:dynamicbar/native/hotkey_bridge.dart';
import 'package:dynamicbar/native/startup_bridge.dart';
import 'package:dynamicbar/native/system_bridge.dart';
import 'package:dynamicbar/settings/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Hotkey parsing', () {
    test('reads a full combination', () {
      final HotkeyBinding? binding = HotkeyBinding.parse(
        'toggle',
        'Ctrl + Alt + Space',
      );
      expect(binding, isNotNull);
      expect(binding!.modifiers, HotkeyModifiers.control | HotkeyModifiers.alt);
      expect(binding.keyCode, 0x20);
      expect(binding.isValid, isTrue);
    });

    test('is tolerant of spacing and case', () {
      final HotkeyBinding? binding = HotkeyBinding.parse('x', 'ctrl+SHIFT+f9');
      expect(binding, isNotNull);
      expect(
        binding!.modifiers,
        HotkeyModifiers.control | HotkeyModifiers.shift,
      );
      expect(binding.keyCode, 0x78);
    });

    test('letters and digits map to their virtual key codes', () {
      expect(HotkeyBinding.parse('x', 'Win + D')?.keyCode, 0x44);
      expect(HotkeyBinding.parse('x', 'Alt + 5')?.keyCode, 0x35);
    });

    test('an empty or modifier-only shortcut is not a binding', () {
      expect(HotkeyBinding.parse('x', ''), isNull);
      expect(HotkeyBinding.parse('x', '   '), isNull);
      expect(HotkeyBinding.parse('x', 'Ctrl + Alt'), isNull);
    });

    test('round trips through its display form', () {
      const String text = 'Ctrl + Alt + Space';
      final HotkeyBinding? binding = HotkeyBinding.parse('toggle', text);
      expect(binding?.encode(), text);
    });

    test('serialises for the platform channel', () {
      final HotkeyBinding binding = HotkeyBinding.parse('toggle', 'Win + F1')!;
      expect(binding.toMap(), <String, Object?>{
        'id': 'toggle',
        'modifiers': HotkeyModifiers.win,
        'keyCode': 0x70,
      });
    });
  });

  group('Startup status', () {
    test('a moved application is reported as stale', () {
      const StartupStatus status = StartupStatus(
        registered: true,
        healthy: false,
        command: r'"C:\Old\DynamicBar.exe" --autostart',
        expected: r'"C:\New\DynamicBar.exe" --autostart',
      );
      expect(status.isStale, isTrue);
    });

    test('an unregistered application is not stale', () {
      expect(StartupStatus.unknown.isStale, isFalse);
    });

    test('parses a null payload without throwing', () {
      expect(StartupStatus.fromMap(null).registered, isFalse);
    });
  });

  group('System sensor payloads', () {
    test('battery thresholds', () {
      const PowerStatus low = PowerStatus(
        hasBattery: true,
        percent: 15,
        charging: false,
      );
      const PowerStatus critical = PowerStatus(
        hasBattery: true,
        percent: 5,
        charging: false,
      );
      const PowerStatus charging = PowerStatus(
        hasBattery: true,
        percent: 5,
        charging: true,
      );

      expect(low.isLow, isTrue);
      expect(low.isCritical, isFalse);
      expect(critical.isCritical, isTrue);
      expect(charging.isLow, isFalse);
      expect(charging.isCritical, isFalse);
    });

    test('a desktop without a battery never warns', () {
      const PowerStatus desktop = PowerStatus(percent: -1);
      expect(desktop.isLow, isFalse);
      expect(desktop.isCritical, isFalse);
    });

    test('privacy status reports any capture', () {
      expect(const PrivacyStatus().anyInUse, isFalse);
      expect(const PrivacyStatus(microphoneInUse: true).anyInUse, isTrue);
      expect(const PrivacyStatus(cameraInUse: true).anyInUse, isTrue);
    });

    test('volume rounds to whole percent', () {
      expect(const VolumeStatus(level: 0.345).percent, 35);
    });

    test('presentation states other than normal suppress the island', () {
      expect(PresentationState.normal.shouldSuppress, isFalse);
      expect(PresentationState.fullscreen.shouldSuppress, isTrue);
      expect(PresentationState.presentation.shouldSuppress, isTrue);
      expect(PresentationState.quiet.shouldSuppress, isTrue);
      expect(PresentationStateX.fromName('nonsense'), PresentationState.normal);
      expect(
        PresentationStateX.fromName('fullscreen'),
        PresentationState.fullscreen,
      );
    });

    test('network parses a wireless payload', () {
      final NetworkStatus status = NetworkStatus.fromMap(<Object?, Object?>{
        'connected': true,
        'internet': true,
        'wifi': true,
        'ssid': 'Studio',
        'signal': 82,
      });
      expect(status.isWifi, isTrue);
      expect(status.ssid, 'Studio');
      expect(status.signal, 82);
    });
  });

  group('Windows integration settings', () {
    test('the new fields survive a round trip', () {
      const AppSettings original = AppSettings(
        launchAtStartup: true,
        startupDelaySeconds: 12,
        suppressInFullscreen: false,
        systemStatusEnabled: false,
        volumeHudEnabled: false,
        hotkeyToggle: 'Ctrl + Shift + I',
        hotkeyExpand: 'Ctrl + Alt + E',
        hotkeyHide: '',
      );
      final AppSettings restored = AppSettings.fromJson(original.toJson());

      expect(restored.launchAtStartup, isTrue);
      expect(restored.startupDelaySeconds, 12);
      expect(restored.suppressInFullscreen, isFalse);
      expect(restored.systemStatusEnabled, isFalse);
      expect(restored.volumeHudEnabled, isFalse);
      expect(restored.hotkeyToggle, 'Ctrl + Shift + I');
      expect(restored.hotkeyExpand, 'Ctrl + Alt + E');
      expect(restored.hotkeyHide, '');
    });

    test('an absurd startup delay is clamped, not rejected', () {
      final AppSettings restored = AppSettings.fromJson(<String, Object?>{
        'startupDelaySeconds': 99999,
      });
      expect(restored.startupDelaySeconds, 120);
    });

    test('clipboard and downloads monitoring are off by default', () {
      const AppSettings defaults = AppSettings.defaults;
      expect(defaults.mediaEnabled, isTrue);
      expect(defaults.downloadsEnabled, isFalse);
      expect(AppSettings.fromJson(<String, Object?>{}).downloadsEnabled, isFalse);
      expect(defaults.notificationsEnabled, isTrue);
      expect(defaults.systemStatusEnabled, isTrue);
      expect(defaults.clipboardEnabled, isFalse);
      expect(defaults.clipboardPreviewEnabled, isFalse);
    });

    test('global shortcuts are disabled by default', () {
      final HotkeyBinding? binding = HotkeyBinding.parse(
        'toggle',
        AppSettings.defaults.hotkeyToggle,
      );
      expect(binding, isNull);
    });
  });

  group('Notification kinds used by the system module', () {
    test('battery warnings escalate in priority', () {
      final IslandNotification low = IslandNotification(
        id: 'system.battery',
        title: 'Battery low',
        kind: NotificationKind.warning,
        priority: NotificationPriority.normal,
      );
      final IslandNotification critical = low.copyWith(
        kind: NotificationKind.error,
        priority: NotificationPriority.high,
      );
      expect(critical.id, low.id, reason: 'replaces in place');
      expect(critical.priority.index, greaterThan(low.priority.index));
    });
  });
}
