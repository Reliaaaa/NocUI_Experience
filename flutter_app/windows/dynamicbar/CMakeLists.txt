# DynamicBar native library.
#
# Kept out of the runner target so that Windows integration code has its own
# compile settings and can grow without touching Flutter's generated build
# rules. Settings mirror APPLY_STANDARD_SETTINGS (C++17, /W4, /EHsc,
# _HAS_EXCEPTIONS=0) so that the STL ABI matches the Flutter C++ wrapper it
# links against. Warnings-as-errors is deliberately not enabled here: Windows
# SDK headers evolve, and a new SDK should not break the build of a shipped
# application.
cmake_minimum_required(VERSION 3.14)

set(DYNAMICBAR_NATIVE "dynamicbar_native")

add_library(${DYNAMICBAR_NATIVE} STATIC
  "core/logging.cpp"
  "core/dispatcher.cpp"
  "core/encodable.cpp"
  "window/window_effects.cpp"
  "window/island_window.cpp"
  "window/window_channel.cpp"
  "window/settings_window.cpp"
  "display/display_channel.cpp"
  "shell/shell_channel.cpp"
  "shelf/shelf_channel.cpp"
  "tray/tray_channel.cpp"
  "media/media_service.cpp"
  "clipboard/clipboard_service.cpp"
  "downloads/downloads_service.cpp"
  "system/system_service.cpp"
  "connectivity/connectivity_service.cpp"
  "power/power_channel.cpp"
  "hotkey/hotkey_service.cpp"
  "startup/startup_service.cpp"
  "app/native_app.cpp"
)

target_compile_features(${DYNAMICBAR_NATIVE} PUBLIC cxx_std_17)
target_compile_options(${DYNAMICBAR_NATIVE} PRIVATE /W4 /wd4100 /EHsc)
target_compile_definitions(${DYNAMICBAR_NATIVE} PRIVATE
  "_HAS_EXCEPTIONS=0"
  "NOMINMAX"
  "WIN32_LEAN_AND_MEAN"
  "$<$<CONFIG:Debug>:_DEBUG>"
)

# Headers are included as "dynamicbar/<area>/<file>.h" from both this library
# and the runner.
target_include_directories(${DYNAMICBAR_NATIVE} PUBLIC
  "${CMAKE_CURRENT_SOURCE_DIR}/.."
)

target_link_libraries(${DYNAMICBAR_NATIVE} PUBLIC flutter flutter_wrapper_app)
target_link_libraries(${DYNAMICBAR_NATIVE} PRIVATE
  "dwmapi.lib"
  "shell32.lib"
  "shlwapi.lib"
  "user32.lib"
  "gdi32.lib"
  "ole32.lib"
  "wtsapi32.lib"
  "runtimeobject.lib"
  "iphlpapi.lib"
  "wlanapi.lib"
  "bthprops.lib"
  "powrprof.lib"
  "windowscodecs.lib"
  "uuid.lib"
)

add_dependencies(${DYNAMICBAR_NATIVE} flutter_assemble)
