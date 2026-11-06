import 'package:dynamicbar/design/theme/island_theme.dart';
import 'package:dynamicbar/design/tokens/db_colors.dart';
import 'package:dynamicbar/design/tokens/db_motion.dart';
import 'package:dynamicbar/settings/ui/settings_controls.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('manual percentage entry converts and clamps the value', (tester) async {
    double result = 0.8;
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: IslandTheme(
          data: IslandThemeData(
            palette: IslandPalette.dark(accent: AccentPreset.teal.color, opacity: 1),
            motion: MotionProfile.reduced,
            surfaceOpacity: 1,
            cornerScale: 1,
            islandScale: 1,
          ),
          child: Center(child: DbSlider(
            value: 0.8,
            min: 0.55,
            max: 1,
            displayFactor: 100,
            unit: '%',
            onChanged: (value) => result = value,
          )),
        ),
      ),
    ));
    await tester.enterText(find.byType(EditableText), '75');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(result, closeTo(0.75, 0.0001));

    await tester.enterText(find.byType(EditableText), '200');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(result, 1);
  });
}
