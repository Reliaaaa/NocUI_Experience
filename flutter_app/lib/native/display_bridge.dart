import 'models/native_models.dart';
import 'native_channel.dart';

/// Monitor topology.
///
/// There is no event channel here on purpose: the stage window already reports
/// `displaysChanged` / `dpiChanged` / `workAreaChanged`, and callers re-list on
/// those. One notification path, no duplicated truth.
class DisplayBridge extends NativeChannel {
  DisplayBridge() : super('dynamicbar/display');

  Future<List<DisplayInfo>> list() async {
    final raw = await invokeList('list');
    final displays = <DisplayInfo>[];
    for (final entry in raw) {
      final display = DisplayInfo.fromMap(entry);
      if (display != null) {
        displays.add(display);
      }
    }
    return displays;
  }
}
