import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

/// The icon set, declared in one place.
///
/// Material's rounded variants are used because their geometry (circular
/// terminals, even stroke weight) sits comfortably next to Segoe UI Variable,
/// and because they ship with the framework — no font asset, no download, no
/// licence question. Confining the `material` import to this file keeps the
/// rest of the application free of Material widgets and theming.
class DbIcons {
  const DbIcons._();

  // Transport
  static const IconData play = Icons.play_arrow_rounded;
  static const IconData pause = Icons.pause_rounded;
  static const IconData next = Icons.skip_next_rounded;
  static const IconData previous = Icons.skip_previous_rounded;

  // Status
  static const IconData clock = Icons.schedule_rounded;
  static const IconData calendar = Icons.calendar_today_rounded;
  static const IconData battery = Icons.battery_std_rounded;
  static const IconData wifi = Icons.wifi_rounded;
  static const IconData network = Icons.lan_rounded;
  static const IconData cpu = Icons.memory_rounded;
  static const IconData bluetooth = Icons.bluetooth_rounded;
  static const IconData volume = Icons.volume_up_rounded;
  static const IconData microphone = Icons.mic_rounded;
  static const IconData camera = Icons.videocam_rounded;
  static const IconData download = Icons.download_rounded;
  static const IconData timer = Icons.timer_outlined;
  static const IconData clipboard = Icons.content_paste_rounded;
  static const IconData bell = Icons.notifications_none_rounded;

  // Actions
  static const IconData settings = Icons.tune_rounded;
  static const IconData close = Icons.close_rounded;
  static const IconData collapse = Icons.keyboard_arrow_up_rounded;
  static const IconData expand = Icons.keyboard_arrow_down_rounded;
  static const IconData power = Icons.power_settings_new_rounded;
  static const IconData visibilityOff = Icons.visibility_off_rounded;
  static const IconData check = Icons.check_rounded;
  static const IconData warning = Icons.error_outline_rounded;

  // Pages and navigation
  static const IconData shelf = Icons.inbox_rounded;
  static const IconData notes = Icons.sticky_note_2_outlined;
  static const IconData chevronLeft = Icons.chevron_left_rounded;
  static const IconData chevronRight = Icons.chevron_right_rounded;
  static const IconData add = Icons.add_rounded;
  static const IconData search = Icons.search_rounded;
  static const IconData pin = Icons.push_pin_outlined;
  static const IconData pinned = Icons.push_pin_rounded;
  static const IconData delete = Icons.delete_outline_rounded;
  static const IconData copy = Icons.copy_rounded;
  static const IconData open = Icons.open_in_new_rounded;
  static const IconData folder = Icons.folder_open_rounded;
  static const IconData focus = Icons.center_focus_strong_rounded;
  static const IconData weather = Icons.wb_sunny_rounded;
  static const IconData restart = Icons.restart_alt_rounded;

  // Shortcut targets. Generic glyphs rather than brand marks: shipping a
  // recognisable logo for someone else's product is a trademark question, and
  // a consistent icon set reads better in a grid than a row of logos anyway.
  static const IconData music = Icons.library_music_rounded;
  static const IconData movie = Icons.movie_rounded;
  static const IconData mail = Icons.mail_outline_rounded;
  static const IconData cloud = Icons.cloud_outlined;
  static const IconData map = Icons.map_outlined;
  static const IconData translate = Icons.translate_rounded;
  static const IconData code = Icons.code_rounded;
  static const IconData chat = Icons.forum_outlined;
  static const IconData image = Icons.image_outlined;
  static const IconData terminal = Icons.terminal_rounded;
  static const IconData calculator = Icons.calculate_outlined;
  static const IconData crop = Icons.crop_rounded;
  static const IconData store = Icons.storefront_outlined;
  static const IconData nightLight = Icons.nightlight_round;
  static const IconData storage = Icons.storage_rounded;
  static const IconData grid = Icons.apps_rounded;
  static const IconData muted = Icons.volume_off_rounded;
  static const IconData upload = Icons.upload_rounded;
  static const IconData today = Icons.today_rounded;

  // Power and session. Kept apart from the page glyphs above because these
  // are the only icons in the set attached to an irreversible action.
  static const IconData lock = Icons.lock_outline_rounded;
  static const IconData lockSmall = Icons.lock_rounded;
  static const IconData sleep = Icons.bedtime_outlined;
  static const IconData hibernate = Icons.snooze_rounded;
  static const IconData screenOff = Icons.desktop_access_disabled_rounded;
  static const IconData signOut = Icons.logout_rounded;

  // Connectivity
  static const IconData wifiOff = Icons.wifi_off_rounded;
  static const IconData bluetoothConnected = Icons.bluetooth_connected_rounded;
  static const IconData bluetoothOff = Icons.bluetooth_disabled_rounded;
  static const IconData headphones = Icons.headphones_rounded;
  static const IconData mouse = Icons.mouse_rounded;
  static const IconData phone = Icons.smartphone_rounded;
  static const IconData laptop = Icons.laptop_rounded;
  static const IconData watch = Icons.watch_rounded;
  static const IconData printer = Icons.print_rounded;
  static const IconData devices = Icons.devices_other_rounded;

  // Weather. Enough distinct glyphs to tell the six kinds of sky apart, and
  // no more: a forecast rendered at thirteen pixels does not need forty.
  static const IconData weatherClear = Icons.wb_sunny_rounded;
  static const IconData weatherNight = Icons.nightlight_round;
  static const IconData weatherPartly = Icons.wb_cloudy_rounded;
  static const IconData weatherCloudy = Icons.cloud_rounded;
  static const IconData weatherRain = Icons.grain_rounded;
  static const IconData weatherSnow = Icons.ac_unit_rounded;
  static const IconData weatherStorm = Icons.flash_on_rounded;
  static const IconData weatherFog = Icons.blur_on_rounded;
  static const IconData wind = Icons.air_rounded;
  static const IconData humidity = Icons.water_drop_outlined;
  static const IconData thermostat = Icons.thermostat_rounded;
  static const IconData place = Icons.place_outlined;

  // Small actions
  static const IconData refresh = Icons.refresh_rounded;
  static const IconData edit = Icons.edit_outlined;
  static const IconData back = Icons.arrow_back_rounded;

  // Settings navigation
  static const IconData appearance = Icons.palette_outlined;
  static const IconData display = Icons.desktop_windows_rounded;
  static const IconData features = Icons.widgets_rounded;
  static const IconData keyboard = Icons.keyboard_rounded;
  static const IconData privacy = Icons.shield_outlined;
  static const IconData about = Icons.info_outline_rounded;
}
