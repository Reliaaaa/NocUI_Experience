import 'package:dynamicbar/design/theme/island_theme.dart';
import 'package:dynamicbar/design/tokens/db_colors.dart';
import 'package:dynamicbar/design/tokens/db_motion.dart';
import 'package:dynamicbar/settings/ui/settings_controls.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('settings switch responds to keyboard activation', (tester) async {
    final semantics = tester.ensureSemantics();
    bool value = false;
    await tester.pumpWidget(WidgetsApp(
      color: const Color(0xff000000),
      builder: (context, _) => IslandTheme(
        data: IslandThemeData(
          palette: IslandPalette.dark(accent: AccentPreset.teal.color, opacity: 1),
          motion: MotionProfile.reduced,
          surfaceOpacity: 1,
          cornerScale: 1,
          islandScale: 1,
        ),
        child: StatefulBuilder(
          builder: (context, setState) => Center(
            child: SettingsRow(
              label: 'Keep notch visible',
              description: 'Show the notch on your desktop.',
              control: DbSwitch(
                value: value,
                onChanged: (next) => setState(() => value = next),
              ),
            ),
          ),
        ),
      ),
    ));
    expect(find.bySemanticsLabel('Keep notch visible'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(value, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(value, isFalse);
    semantics.dispose();
  });
}
