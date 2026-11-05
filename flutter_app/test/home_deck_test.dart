import 'package:dynamicbar/island/state/island_metrics.dart';
import 'package:dynamicbar/island/state/island_state.dart';
import 'package:dynamicbar/island/view/pages/home/home_deck.dart';
import 'package:dynamicbar/modules/shortcuts/shortcut_catalog.dart';
import 'package:dynamicbar/native/connectivity_bridge.dart';
import 'package:dynamicbar/native/power_bridge.dart';
import 'package:dynamicbar/settings/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Deck widths', () {
    const double available = 428;

    double total(List<double> progress) {
      final double sum = progress.fold(0, (double a, double b) => a + b);
      double width = 0;
      for (final double value in progress) {
        width += HomeDeck.panelWidth(
          available: available,
          progress: value,
          sum: sum,
        );
      }
      return width;
    }

    test('four resting panels share the deck equally', () {
      final double rest = HomeDeck.panelWidth(
        available: available,
        progress: 0,
        sum: 0,
      );
      expect(rest, closeTo(available / HomeDeck.panelCount, 1e-9));
    });

    test('an open panel takes its share and the rest give it up', () {
      final double open = HomeDeck.panelWidth(
        available: available,
        progress: 1,
        sum: 1,
      );
      final double shrunk = HomeDeck.panelWidth(
        available: available,
        progress: 0,
        sum: 1,
      );

      expect(open, closeTo(available * HomeDeck.openShare, 1e-9));
      expect(open, greaterThan(shrunk * 2));
      expect(open + shrunk * 3, closeTo(available, 1e-9));
    });

    // The whole reason the width maths is written the way it is: crossing the
    // deck with the pointer leaves two panels animating in opposite directions
    // at once, and the row must never be handed more or less than it has.
    test('the four always add up, whatever is mid-flight', () {
      const List<List<double>> states = <List<double>>[
        <double>[0, 0, 0, 0],
        <double>[1, 0, 0, 0],
        <double>[0.5, 0.5, 0, 0],
        <double>[0.62, 0.31, 0, 0],
        <double>[0.2, 0.9, 0.1, 0],
        <double>[1, 1, 1, 1],
      ];
      for (final List<double> state in states) {
        expect(total(state), closeTo(available, 1e-9), reason: '$state');
      }
    });

    test('no panel is ever given a negative width', () {
      for (final List<double> state in <List<double>>[
        <double>[0.9, 0.9, 0, 0],
        <double>[1, 1, 1, 1],
      ]) {
        final double sum = state.fold(0, (double a, double b) => a + b);
        for (final double value in state) {
          expect(
            HomeDeck.panelWidth(
              available: available,
              progress: value,
              sum: sum,
            ),
            greaterThan(0),
          );
        }
      }
    });
  });

  group('The home page still fits', () {
    test('the pager holds the clock, the agenda and the deck', () {
      // Clock block, agenda, deck and the action row, plus the scaffold's own
      // padding. If this stops being true the deck has outgrown the island and
      // something has to give.
      const double padding = 14 + 28;
      const double clock = 62;
      const double actions = 26;
      const double gaps = 10 * 3;
      final double left =
          IslandMetrics.pagerSize.height -
          padding -
          clock -
          actions -
          gaps -
          HomeDeck.fullHeight;

      expect(left, greaterThan(70), reason: 'no room left for the agenda');
      expect(IslandMetrics.fitsInStage(IslandMode.idle), isTrue);
    });
  });

  group('The shelf', () {
    test('has a default for every slot', () {
      expect(ShortcutCatalog.defaultHome.length, ShortcutCatalog.homeSlots);
      for (final String id in ShortcutCatalog.defaultHome) {
        expect(ShortcutCatalog.byId(id), isNotNull, reason: id);
      }
    });

    test('a shortcut that no longer exists is dropped, not drawn broken', () {
      final List<ShortcutEntry> resolved = ShortcutCatalog.resolve(
        <String>['explorer', 'a-shortcut-from-2019', 'terminal'],
      );
      expect(resolved.map((ShortcutEntry e) => e.id), <String>[
        'explorer',
        'terminal',
      ]);
    });
  });

  group('Power actions', () {
    test('only the three that lose work ask twice', () {
      final List<PowerAction> confirmed = PowerAction.values
          .where((PowerAction action) => action.needsConfirmation)
          .toList();
      expect(confirmed, <PowerAction>[
        PowerAction.signOut,
        PowerAction.restart,
        PowerAction.shutdown,
      ]);
    });

    test('every action has a stable id for the platform channel', () {
      final Set<String> ids = PowerAction.values
          .map((PowerAction action) => action.id)
          .toSet();
      expect(ids.length, PowerAction.values.length);
      expect(PowerAction.shutdown.id, 'shutdown');
      expect(PowerAction.screenOff.id, 'screenOff');
    });

    test('a machine without hibernation is not offered it', () {
      const PowerCapabilities capabilities = PowerCapabilities(
        hibernate: false,
      );
      expect(capabilities.supports(PowerAction.hibernate), isFalse);
      expect(capabilities.supports(PowerAction.sleep), isTrue);
    });

    test('capabilities parse from a partial payload', () {
      final PowerCapabilities capabilities = PowerCapabilities.fromMap(
        <Object?, Object?>{'sleep': false, 'hibernate': true},
      );
      expect(capabilities.sleep, isFalse);
      expect(capabilities.hibernate, isTrue);
      // Anything the payload omits keeps the safe default rather than
      // disabling a button that does work.
      expect(capabilities.lock, isTrue);
    });
  });

  group('Connectivity payloads', () {
    test('a Wi-Fi list parses, and the connected network is findable', () {
      final WifiSnapshot wifi = WifiSnapshot.fromMap(<Object?, Object?>{
        'available': true,
        'radio': 'on',
        'scanning': false,
        'networks': <Object?>[
          <Object?, Object?>{
            'ssid': 'Hallway',
            'signal': 82,
            'secured': true,
            'saved': true,
            'connected': true,
          },
          <Object?, Object?>{'ssid': 'Cafe', 'signal': 30},
          // Nameless entries are hidden networks: nothing to show, nothing to
          // click, so they are dropped rather than listed blank.
          <Object?, Object?>{'ssid': '', 'signal': 90},
        ],
      });

      expect(wifi.available, isTrue);
      expect(wifi.radio, RadioState.on);
      expect(wifi.networks.length, 2);
      expect(wifi.connected?.ssid, 'Hallway');
      expect(wifi.networks.first.bars, 4);
      expect(wifi.networks.last.bars, 2);
      expect(wifi.networks.last.saved, isFalse);
    });

    test('an unreadable radio is not the same as one switched off', () {
      expect(RadioStateX.fromName('off'), RadioState.off);
      expect(RadioStateX.fromName('absent'), RadioState.absent);
      expect(RadioStateX.fromName(null), RadioState.unknown);
      expect(RadioState.unknown.isControllable, isFalse);
      expect(RadioState.absent.isControllable, isFalse);
      expect(RadioState.off.isControllable, isTrue);
    });

    test('paired devices parse and connected ones are counted', () {
      final BluetoothSnapshot bluetooth = BluetoothSnapshot.fromMap(
        <Object?, Object?>{
          'available': true,
          'radio': 'on',
          'devices': <Object?>[
            <Object?, Object?>{
              'address': 'AA:BB:CC:DD:EE:FF',
              'name': 'Studio Buds',
              'connected': true,
              'paired': true,
              'kind': 'audio',
            },
            <Object?, Object?>{
              'address': '11:22:33:44:55:66',
              'name': 'Keyboard',
              'paired': true,
              'kind': 'input',
            },
            <Object?, Object?>{'name': 'No address'},
          ],
        },
      );

      expect(bluetooth.devices.length, 2);
      expect(bluetooth.connectedCount, 1);
      expect(bluetooth.devices.first.kind, 'audio');
    });

    test('an empty payload is a real answer, not a crash', () {
      final WifiSnapshot wifi = WifiSnapshot.fromMap(<Object?, Object?>{});
      expect(wifi.available, isFalse);
      expect(wifi.networks, isEmpty);
      expect(wifi.connected, isNull);
      expect(wifi.radio, RadioState.unknown);
    });
  });

  group('Home settings', () {
    test('weather and location lookup are off by default', () {
      const AppSettings defaults = AppSettings.defaults;
      expect(defaults.homeDeckEnabled, isTrue);
      expect(defaults.homeShortcuts, ShortcutCatalog.defaultHome);
      expect(defaults.weatherEnabled, isFalse);
      expect(defaults.weatherAutoLocate, isFalse);
      expect(defaults.weatherMetric, isTrue);
      // Nothing is known about where the user is until they say or ask.
      expect(defaults.weatherLatitude, isNull);
      expect(defaults.weatherLongitude, isNull);
      final AppSettings restored = AppSettings.fromJson(<String, Object?>{});
      expect(restored.weatherEnabled, isFalse);
      expect(restored.weatherAutoLocate, isFalse);
    });
  });
}
