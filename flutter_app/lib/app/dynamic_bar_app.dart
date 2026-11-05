import 'package:flutter/widgets.dart';

import '../design/theme/island_theme.dart';
import '../design/tokens/db_typography.dart';
import '../island/view/island_stage.dart';
import 'app_services.dart';
import 'island_coordinator.dart';

/// The root of the overlay.
///
/// There is no MaterialApp and no Navigator: this window is a single always-on
/// surface, not a document with pages, and a router would only add a rebuild
/// path and an opaque background to fight with. Everything below is transparent
/// except the island itself.
class DynamicBarApp extends StatefulWidget {
  const DynamicBarApp({
    required this.services,
    required this.coordinator,
    super.key,
  });

  final AppServices services;
  final IslandCoordinator coordinator;

  @override
  State<DynamicBarApp> createState() => _DynamicBarAppState();
}

class _DynamicBarAppState extends State<DynamicBarApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Start the native side only once a frame exists, so the window is never
    // shown before there is something to show in it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.coordinator.start();
    });
  }

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    final Brightness brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    widget.services.theme.setSystemIsDark(brightness == Brightness.dark);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppServices services = widget.services;

    return AppScope(
      services: services,
      child: WidgetsApp(
        color: const Color(0x00000000),
        debugShowCheckedModeBanner: false,
        title: 'NocUI Experience',
        builder: (BuildContext context, Widget? _) {
          return AnimatedBuilder(
            animation: services.theme,
            builder: (BuildContext context, Widget? child) {
              return IslandTheme(data: services.theme.data, child: child!);
            },
            child: DefaultTextStyle(
              style: DbType.body,
              child: IslandStage(
                controller: services.island,
                onHitRectChanged: widget.coordinator.reportHitRect,
                onRequestFocus: widget.coordinator.requestFocus,
                onReleaseFocus: widget.coordinator.releaseFocus,
              ),
            ),
          );
        },
      ),
    );
  }
}
