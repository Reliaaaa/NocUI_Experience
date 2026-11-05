import 'package:dynamicbar/island/state/island_controller.dart';
import 'package:dynamicbar/island/state/island_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IslandController state machine', () {
    late IslandController controller;

    setUp(() => controller = IslandController());
    tearDown(() => controller.dispose());

    test('starts collapsed and visible', () {
      expect(controller.intent, IslandIntent.collapsed);
      expect(controller.phase, IslandPhase.collapsed);
      expect(controller.isPaused, isFalse);
    });

    test('expanding reports expanding until the shape catches up', () {
      controller.expand();
      expect(controller.intent, IslandIntent.expanded);

      controller.reportProgress(0.4, 3.2);
      expect(controller.phase, IslandPhase.expanding);

      controller.reportProgress(1.0, 0);
      expect(controller.phase, IslandPhase.expanded);
    });

    test('focus turns an expanded island into an interactive one', () {
      controller.expand();
      controller.reportProgress(1.0, 0);
      expect(controller.phase, IslandPhase.expanded);

      controller.setFocused(true);
      expect(controller.phase, IslandPhase.interactive);

      controller.setFocused(false);
      expect(controller.phase, IslandPhase.expanded);
    });

    test(
      'collapsing mid-expansion is reported as collapsing, not expanding',
      () {
        controller.expand();
        controller.reportProgress(0.6, 2.0);
        controller.collapse();
        controller.reportProgress(0.55, -2.4);
        expect(controller.phase, IslandPhase.collapsing);
      },
    );

    test('hover never expands on its own', () {
      controller.setHovered(true);
      expect(controller.intent, IslandIntent.collapsed);
      expect(controller.isHovered, isTrue);
    });

    test('hidden stays hidden until the shape has fully retracted', () {
      controller.hide();
      controller.reportProgress(0.3, -1.0);
      expect(controller.phase, IslandPhase.collapsing);

      controller.reportProgress(0.0, 0);
      expect(controller.phase, IslandPhase.hidden);
    });

    test('pausing hides the island and blocks expansion', () {
      controller.setPaused(true);
      controller.reportProgress(0, 0);
      expect(controller.phase, IslandPhase.hidden);

      controller.expand();
      expect(controller.intent, IslandIntent.hidden);

      controller.setPaused(false);
      expect(controller.intent, IslandIntent.collapsed);
    });

    test('reveal is ignored while paused', () {
      controller.setPaused(true);
      controller.reveal();
      expect(controller.intent, IslandIntent.hidden);
    });

    test('progress reports do not notify unless the phase changes', () {
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.reportProgress(0.0, 0);
      controller.reportProgress(0.005, 0);
      expect(notifications, 0);

      controller.reportProgress(0.5, 1.0);
      expect(notifications, 1);
    });

    test('toggle alternates intent', () {
      controller.toggle();
      expect(controller.intent, IslandIntent.expanded);
      controller.toggle();
      expect(controller.intent, IslandIntent.collapsed);
    });
  });
}
