import 'dart:ui';

import 'package:dynamicbar/design/tokens/db_dimens.dart';
import 'package:dynamicbar/island/state/island_metrics.dart';
import 'package:dynamicbar/island/state/island_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IslandMetrics', () {
    test('hovering peeks without expanding', () {
      final IslandGeometry resting = IslandMetrics.resolve(
        intent: IslandIntent.collapsed,
        mode: IslandMode.idle,
        hovered: false,
      );
      final IslandGeometry peeking = IslandMetrics.resolve(
        intent: IslandIntent.collapsed,
        mode: IslandMode.idle,
        hovered: true,
      );

      expect(peeking.width, greaterThan(resting.width));
      expect(peeking.height, greaterThan(resting.height));
      expect(peeking.expansion, 0);
    });

    test('hidden retracts to zero height', () {
      final IslandGeometry hidden = IslandMetrics.resolve(
        intent: IslandIntent.hidden,
        mode: IslandMode.idle,
        hovered: false,
      );
      expect(hidden.height, 0);
      expect(hidden.shadow, 0);
    });

    test('user scaling applies to every state', () {
      final IslandGeometry scaled = IslandMetrics.resolve(
        intent: IslandIntent.collapsed,
        mode: IslandMode.idle,
        hovered: false,
        scale: 1.25,
      );
      expect(scaled.width, closeTo(DbSize.collapsedWidth * 1.25, 1e-9));
    });

    test('the island is centred and pinned to the top of the stage', () {
      const Size stage = Size(800, 400);
      final Rect rect = IslandMetrics.islandRect(stage, 200, 40);
      expect(rect.top, 0);
      expect(rect.center.dx, closeTo(stage.width / 2, 1e-9));
      expect(rect.height, 40);
    });

    test('the hit region is larger than the island but never above it', () {
      final Rect island = IslandMetrics.islandRect(
        const Size(800, 400),
        200,
        40,
      );
      final Rect hit = IslandMetrics.hitRect(island);

      expect(hit.top, island.top);
      expect(hit.left, lessThan(island.left));
      expect(hit.right, greaterThan(island.right));
      expect(hit.bottom, greaterThan(island.bottom));
    });

    test(
      'the stage is large enough for the widest island plus shadow room',
      () {
        final Size stage = IslandMetrics.stageSize();
        final IslandGeometry expanded = IslandMetrics.resolve(
          intent: IslandIntent.expanded,
          mode: IslandMode.idle,
          hovered: false,
        );
        expect(stage.width, greaterThan(expanded.width));
        expect(stage.height, greaterThan(expanded.height));
      },
    );
  });
}
