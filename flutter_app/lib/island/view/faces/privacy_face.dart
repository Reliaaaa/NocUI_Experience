import 'package:flutter/widgets.dart';

import '../../../app/app_services.dart';
import '../../../design/components/staggered_reveal.dart';
import '../../../design/theme/island_theme.dart';
import '../../../design/tokens/db_colors.dart';
import '../../../design/tokens/db_dimens.dart';
import '../../../design/tokens/db_icons.dart';
import '../../../design/tokens/db_typography.dart';
import '../../../modules/system/system_controller.dart';
import '../../../native/system_bridge.dart';

/// The in-use indicator.
///
/// When something on this machine is listening or watching, that fact outranks
/// anything else the island might be showing. It is not a notification either:
/// notifications expire, and this must stay on screen for exactly as long as
/// the capture lasts. The reading comes from the same capability consent store
/// Windows uses for its own privacy indicator, so it agrees with the taskbar.
class PrivacyCollapsed extends StatelessWidget {
  const PrivacyCollapsed({super.key});

  @override
  Widget build(BuildContext context) {
    final SystemController system = AppScope.read(context).system;
    final IslandPalette palette = IslandTheme.of(context).palette;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DbSpace.lg),
      child: AnimatedBuilder(
        animation: system,
        builder: (BuildContext context, _) {
          final PrivacyStatus privacy = system.privacy;
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _Dot(color: palette.negative),
              const SizedBox(width: DbSpace.md),
              if (privacy.microphoneInUse) ...<Widget>[
                Icon(
                  DbIcons.microphone,
                  size: DbSize.iconSm,
                  color: palette.textPrimary,
                ),
                const SizedBox(width: DbSpace.sm),
              ],
              if (privacy.cameraInUse) ...<Widget>[
                Icon(
                  DbIcons.camera,
                  size: DbSize.iconSm,
                  color: palette.textPrimary,
                ),
                const SizedBox(width: DbSpace.sm),
              ],
              Flexible(
                child: Text(
                  _label(privacy),
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  softWrap: false,
                  style: DbType.label.copyWith(color: palette.textPrimary),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _label(PrivacyStatus privacy) {
    if (privacy.microphoneInUse && privacy.cameraInUse) {
      return 'In use';
    }
    if (privacy.cameraInUse) {
      return 'Camera';
    }
    return 'Mic';
  }
}

/// Expanded privacy face: which sensors are live, stated plainly.
class PrivacyExpanded extends StatelessWidget {
  const PrivacyExpanded({super.key});

  @override
  Widget build(BuildContext context) {
    final SystemController system = AppScope.read(context).system;
    final IslandPalette palette = IslandTheme.of(context).palette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DbSpace.xl,
        DbSpace.lg,
        DbSpace.xl,
        DbSpace.lg,
      ),
      child: AnimatedBuilder(
        animation: system,
        builder: (BuildContext context, _) {
          final PrivacyStatus privacy = system.privacy;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: staggered(<Widget>[
              Row(
                children: <Widget>[
                  _Dot(color: palette.negative),
                  const SizedBox(width: DbSpace.md),
                  Text(
                    'IN USE',
                    style: DbType.overline.copyWith(color: palette.negative),
                  ),
                ],
              ),
              const SizedBox(height: DbSpace.md),
              if (privacy.microphoneInUse)
                _SensorRow(
                  icon: DbIcons.microphone,
                  title: 'Microphone',
                  detail: 'An application is recording audio',
                ),
              if (privacy.microphoneInUse && privacy.cameraInUse)
                const SizedBox(height: DbSpace.sm),
              if (privacy.cameraInUse)
                _SensorRow(
                  icon: DbIcons.camera,
                  title: 'Camera',
                  detail: 'An application is using the camera',
                ),
              const Spacer(),
              Text(
                'Reported by Windows. Notch X cannot see what is captured.',
                style: DbType.caption.copyWith(color: palette.textTertiary),
              ),
            ]),
          );
        },
      ),
    );
  }
}

class _SensorRow extends StatelessWidget {
  const _SensorRow({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final IslandPalette palette = IslandTheme.of(context).palette;
    return Row(
      children: <Widget>[
        Icon(icon, size: DbSize.iconMd, color: palette.textPrimary),
        const SizedBox(width: DbSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                title,
                style: DbType.body.copyWith(color: palette.textPrimary),
              ),
              Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DbType.caption.copyWith(color: palette.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The recording dot. Static, like every other indicator in the product: a
/// blinking light at the top of the screen would be unbearable during a call,
/// which is exactly when this is visible.
class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
