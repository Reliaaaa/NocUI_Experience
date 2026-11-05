import 'package:flutter/widgets.dart';

import '../../app/app_services.dart';
import 'clock_service.dart';

/// Holds a claim on second-precision clock ticks for as long as it is mounted.
///
/// The clock ticks once a minute unless something asks for more. Wrapping the
/// faces that show seconds - the expanded clock, the media timeline - in this
/// means the faster timer exists exactly while it is being looked at, and stops
/// the moment the island closes.
class SecondsScope extends StatefulWidget {
  const SecondsScope({required this.child, super.key});

  final Widget child;

  @override
  State<SecondsScope> createState() => _SecondsScopeState();
}

class _SecondsScopeState extends State<SecondsScope> {
  ClockService? _clock;
  bool _holding = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ClockService clock = AppScope.read(context).clock;
    if (identical(_clock, clock)) {
      return;
    }
    _release();
    _clock = clock;
    clock.acquireSeconds();
    _holding = true;
  }

  void _release() {
    if (_holding) {
      _clock?.releaseSeconds();
      _holding = false;
    }
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
