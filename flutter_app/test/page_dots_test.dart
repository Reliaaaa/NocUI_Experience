import 'dart:ui' show SemanticsFlag;

import 'package:dynamicbar/design/theme/island_theme.dart';
import 'package:dynamicbar/design/tokens/db_colors.dart';
import 'package:dynamicbar/design/tokens/db_motion.dart';
import 'package:dynamicbar/island/view/pager/page_dots.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('page indicators select a page and expose its selected state',
      (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);
    int selected = 0;

    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: IslandTheme(
        data: IslandThemeData(
          palette: IslandPalette.dark(accent: AccentPreset.teal.color, opacity: 1),
          motion: MotionProfile.reduced,
          surfaceOpacity: 1,
          cornerScale: 1,
          islandScale: 1,
        ),
        child: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) => Center(
            child: PageDots(
              count: 3,
              index: selected,
              onSelected: (int index) => setState(() => selected = index),
            ),
          ),
        ),
      ),
    ));

    expect(find.bySemanticsLabel('Page 1 of 3'), findsOneWidget);
    final Finder thirdPage = find.bySemanticsLabel('Page 3 of 3');
    await tester.tap(thirdPage);
    await tester.pumpAndSettle();

    expect(selected, 2);
    expect(tester.getSemantics(thirdPage).hasFlag(SemanticsFlag.isSelected), isTrue);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Page 1 of 3'))
          .hasFlag(SemanticsFlag.isSelected),
      isFalse,
    );
  });
}
