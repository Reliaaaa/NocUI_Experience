import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../design/theme/island_theme.dart';
import '../design/tokens/db_typography.dart';
import '../settings/ui/settings_panel.dart';
import 'app_services.dart';
import 'bootstrap.dart';

const MethodChannel _channel = MethodChannel('nocui/settings_window');

Future<void> bootstrapSettingsWindow() async {
  WidgetsFlutterBinding.ensureInitialized();
  final services = await buildSettingsServices();
  runApp(_SettingsWindowApp(services: services));
}

class _SettingsWindowApp extends StatefulWidget {
  const _SettingsWindowApp({required this.services});
  final AppServices services;

  @override
  State<_SettingsWindowApp> createState() => _SettingsWindowAppState();
}

class _SettingsWindowAppState extends State<_SettingsWindowApp> {
  bool _hasState = false;
  bool _connectionFailed = false;
  String? _section;
  int _openGeneration = 0;
  Timer? _stateTimeout;

  @override
  void initState() {
    super.initState();
    _channel.setMethodCallHandler(_onCall);
    unawaited(_connect());
  }

  Future<void> _connect() async {
    for (var attempt = 0; attempt < 30 && mounted; attempt++) {
      try {
        await _channel.invokeMethod<void>('ready');
        _stateTimeout = Timer(const Duration(seconds: 5), () {
          if (mounted && !_hasState) unawaited(_failConnection());
        });
        return;
      } on MissingPluginException {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      } on PlatformException {
        break;
      }
    }
    if (mounted) await _failConnection();
  }

  Future<void> _failConnection() async {
    if (!mounted) return;
    setState(() => _connectionFailed = true);
    try {
      await _channel.invokeMethod<void>('failed');
    } on MissingPluginException {
      // Leave an explicit error in the child if even the native bridge failed.
    } on PlatformException {
      // The owner may already be shutting down.
    }
  }

  Future<Object?> _onCall(MethodCall call) async {
    if (call.method == 'flush') {
      FocusManager.instance.primaryFocus?.unfocus();
      await Future<void>.delayed(Duration.zero);
      await widget.services.settings.flush();
      if (widget.services.settings.remoteError != null) {
        throw PlatformException(code: 'settings_update_failed');
      }
      return null;
    }
    if (call.method == 'closing') {
      FocusManager.instance.primaryFocus?.unfocus();
      return null;
    }
    final raw = call.arguments;
    if (raw is! Map) return null;
    if (call.method == 'state') {
      final settings = raw['settings'];
      if (settings is! Map) return null;
      widget.services.settings.applyRemote(settings.cast<String, Object?>());
      final conflicts = raw['hotkeyConflicts'];
      if (conflicts is List) {
        widget.services.hotkeyConflicts.value = conflicts.whereType<String>().toSet();
      }
      if (mounted) {
        setState(() {
          if (!_hasState) _section = raw['section'] as String?;
          _hasState = true;
          _connectionFailed = false;
        });
      }
    } else if (call.method == 'openSection' && mounted) {
      setState(() {
        _section = raw['section'] as String?;
        _openGeneration++;
        _hasState = false;
      });
      _stateTimeout?.cancel();
      unawaited(_connect());
    }
    return null;
  }

  @override
  void dispose() {
    _stateTimeout?.cancel();
    _channel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      services: widget.services,
      child: WidgetsApp(
        color: const Color(0xFF131313),
        title: 'NocUI Experience Settings',
        debugShowCheckedModeBanner: false,
        builder: (context, _) => AnimatedBuilder(
          animation: widget.services.theme,
          builder: (context, child) {
            final theme = widget.services.theme.data;
            return IslandTheme(
              data: theme,
              child: ColoredBox(
                color: theme.palette.surface.withValues(alpha: 1),
                child: DefaultTextStyle(
                  style: DbType.body.copyWith(color: theme.palette.textPrimary),
                  child: _hasState
                      ? SettingsPanel(
                          key: ValueKey<int>(_openGeneration),
                          initialSection: _section,
                          onClose: () {
                            FocusManager.instance.primaryFocus?.unfocus();
                            unawaited(_channel.invokeMethod<void>('close'));
                          },
                        )
                      : Center(child: Text(_connectionFailed
                          ? 'Could not connect to NocUI. Close this window and try again.'
                          : 'Connecting to NocUI…')),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
