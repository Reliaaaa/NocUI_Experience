import 'package:dynamicbar/app/app_services.dart';
import 'package:dynamicbar/core/time/clock_service.dart';
import 'package:dynamicbar/design/theme/island_theme.dart';
import 'package:dynamicbar/design/tokens/db_colors.dart';
import 'package:dynamicbar/design/tokens/db_motion.dart';
import 'package:dynamicbar/island/view/pages/home/control_center.dart';
import 'package:dynamicbar/modules/connectivity/connectivity_controller.dart';
import 'package:dynamicbar/modules/system/system_controller.dart';
import 'package:dynamicbar/native/connectivity_bridge.dart';
import 'package:dynamicbar/native/system_bridge.dart';
import 'package:dynamicbar/settings/app_settings.dart';
import 'package:dynamicbar/settings/settings_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _System extends ChangeNotifier implements SystemController {
  @override
  VolumeStatus volume = const VolumeStatus();
  @override
  PowerStatus get power => const PowerStatus();
  @override
  NetworkStatus get network => const NetworkStatus();
  double? requestedVolume;

  void setStatus(VolumeStatus status) {
    volume = status;
    notifyListeners();
  }

  @override
  Future<void> setVolume(double level) async { requestedVolume = level; }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Connectivity extends ChangeNotifier implements ConnectivityController {
  @override
  WifiSnapshot get wifi => WifiSnapshot.empty;
  @override
  BluetoothSnapshot get bluetooth => BluetoothSnapshot.empty;
  @override
  Future<void> retain() async {}
  @override
  Future<void> release() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Settings extends ChangeNotifier implements SettingsController {
  @override
  AppSettings get settings => AppSettings.defaults;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Services implements AppServices {
  _Services(this.clock, this.system, this.connectivity, this.settings);
  @override
  final ClockService clock;
  @override
  final _System system;
  @override
  final _Connectivity connectivity;
  @override
  final _Settings settings;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('volume slider stays within the notch and follows availability', (tester) async {
    final semantics = tester.ensureSemantics();
    final clock = ClockService(now: () => DateTime(2026, 11, 7, 22));
    final system = _System();
    final connectivity = _Connectivity();
    final settings = _Settings();
    final services = _Services(clock, system, connectivity, settings);

    Future<void> showAtWidth(double width) async {
      await tester.pumpWidget(WidgetsApp(
        color: const Color(0xff000000),
        builder: (context, _) => AppScope(
          services: services,
          child: IslandTheme(
            data: IslandThemeData(
              palette: IslandPalette.dark(accent: AccentPreset.teal.color, opacity: 1),
              motion: MotionProfile.reduced,
              surfaceOpacity: 1,
              cornerScale: 1,
              islandScale: 1,
            ),
            child: Center(child: SizedBox(
              key: const Key('notch'),
              width: width,
              height: 260,
              child: ControlCenter(onHome: () {}),
            )),
          ),
        ),
      ));
      await tester.pump();
    }

    try {
      for (final width in [320.0, 440.0]) {
        await showAtWidth(width);
        expect(tester.takeException(), isNull);
        final slider = find.byType(VolumeSlider);
        expect(slider, findsOneWidget);
        final bounds = tester.getRect(find.byKey(const Key('notch')));
        final sliderBounds = tester.getRect(slider);
        expect(sliderBounds.left, greaterThanOrEqualTo(bounds.left));
        expect(sliderBounds.right, lessThanOrEqualTo(bounds.right));
        expect(sliderBounds.width, lessThanOrEqualTo(180));
        expect(tester.widget<VolumeSlider>(slider).onChanged, isNull);
        final sliderSemantics = find.descendant(
          of: slider,
          matching: find.byWidgetPredicate(
            (widget) => widget is Semantics && widget.properties.label == 'Volume',
          ),
        );
        expect(tester.widget<Semantics>(sliderSemantics).properties.enabled, isFalse);
        expect(tester.widget<Semantics>(sliderSemantics).properties.slider, isTrue);
        system.requestedVolume = null;
        await tester.tapAt(sliderBounds.center);
        await tester.pump();
        expect(system.requestedVolume, isNull);

        system.setStatus(const VolumeStatus(available: true, level: 0.5));
        await tester.pump();
        expect(tester.widget<VolumeSlider>(slider).onChanged, isNotNull);
        expect(tester.widget<Semantics>(sliderSemantics).properties.enabled, isTrue);
        await tester.tapAt(Offset(sliderBounds.left + sliderBounds.width * 0.75, sliderBounds.center.dy));
        await tester.pump();
        expect(system.requestedVolume, isNotNull);
        expect(system.requestedVolume!, greaterThan(0.5));
        expect(system.requestedVolume!, lessThanOrEqualTo(1));

        final target = find.descendant(of: slider, matching: find.byType(GestureDetector));
        Focus.of(tester.element(target)).requestFocus();
        await tester.pump();
        expect(Focus.of(tester.element(target)).hasPrimaryFocus, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(system.requestedVolume, closeTo(0.55, 0.0001));
        system.setStatus(const VolumeStatus());
        await tester.pump();
      }
    } finally {
      semantics.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      clock.dispose();
      system.dispose();
      connectivity.dispose();
      settings.dispose();
    }
  });
}
