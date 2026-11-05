#include "dynamicbar/window/window_effects.h"

#include <dwmapi.h>

#include <string>

#include "dynamicbar/core/logging.h"

namespace dynamicbar {
namespace {

constexpr const char kTag[] = "WindowEffects";

#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif
#ifndef DWMWA_WINDOW_CORNER_PREFERENCE
#define DWMWA_WINDOW_CORNER_PREFERENCE 33
#endif

// Undocumented but stable since Windows 10 1803; the mechanism used by every
// transparent desktop overlay on Windows.
enum AccentState {
  kAccentDisabled = 0,
  kAccentEnableGradient = 1,
  kAccentEnableTransparentGradient = 2,
  kAccentEnableBlurBehind = 3,
  kAccentEnableAcrylicBlurBehind = 4,
  kAccentEnableHostBackdrop = 5,
};

struct AccentPolicy {
  DWORD accent_state;
  DWORD accent_flags;
  DWORD gradient_color;  // AABBGGRR
  DWORD animation_id;
};

enum WindowCompositionAttribute {
  kWcaAccentPolicy = 19,
};

struct WindowCompositionAttributeData {
  DWORD attribute;
  PVOID data;
  SIZE_T size;
};

using SetWindowCompositionAttributeFn =
    BOOL(WINAPI*)(HWND, WindowCompositionAttributeData*);

SetWindowCompositionAttributeFn ResolveSetWindowCompositionAttribute() {
  static SetWindowCompositionAttributeFn function = [] {
    HMODULE user32 = ::GetModuleHandleW(L"user32.dll");
    if (user32 == nullptr) {
      return static_cast<SetWindowCompositionAttributeFn>(nullptr);
    }
    return reinterpret_cast<SetWindowCompositionAttributeFn>(
        ::GetProcAddress(user32, "SetWindowCompositionAttribute"));
  }();
  return function;
}

bool ApplyAccentPolicy(HWND window, AccentState state) {
  SetWindowCompositionAttributeFn apply = ResolveSetWindowCompositionAttribute();
  if (apply == nullptr) {
    return false;
  }
  AccentPolicy policy = {};
  policy.accent_state = static_cast<DWORD>(state);
  policy.accent_flags = 0;
  policy.gradient_color = 0x00000000;
  policy.animation_id = 0;

  WindowCompositionAttributeData data = {};
  data.attribute = kWcaAccentPolicy;
  data.data = &policy;
  data.size = sizeof(policy);
  return apply(window, &data) != FALSE;
}

}  // namespace

AlphaMode AlphaModeFromEnvironment(AlphaMode fallback) {
  wchar_t value[16] = {};
  const DWORD length =
      ::GetEnvironmentVariableW(L"DYNAMICBAR_ALPHA", value, 16);
  if (length == 0 || length >= 16) {
    return fallback;
  }
  const std::wstring mode(value, length);
  if (mode == L"accent") return AlphaMode::kAccent;
  if (mode == L"glass") return AlphaMode::kGlass;
  if (mode == L"both") return AlphaMode::kBoth;
  if (mode == L"none") return AlphaMode::kNone;
  return fallback;
}

bool EnablePerPixelTransparency(HWND window, AlphaMode mode) {
  if (window == nullptr) {
    return false;
  }
  bool ok = false;
  if (mode == AlphaMode::kAccent || mode == AlphaMode::kBoth) {
    ok = ApplyAccentPolicy(window, kAccentEnableTransparentGradient) || ok;
  }
  if (mode == AlphaMode::kGlass || mode == AlphaMode::kBoth) {
    // Extending the frame over the whole client area makes DWM honour the
    // alpha channel of what the window draws; alpha-zero pixels show the
    // desktop. No blur is involved.
    MARGINS margins = {-1, -1, -1, -1};
    ok = SUCCEEDED(::DwmExtendFrameIntoClientArea(window, &margins)) || ok;
  }
  DB_LOG_INFO(kTag, std::string("Alpha mode ") +
                        std::to_string(static_cast<int>(mode)) +
                        (ok ? " applied." : " refused."));
  return ok;
}

bool EnablePerPixelTransparency(HWND window) {
  return EnablePerPixelTransparency(window, AlphaMode::kGlass);
}

void DisablePerPixelTransparency(HWND window) {
  if (window == nullptr) {
    return;
  }
  ApplyAccentPolicy(window, kAccentDisabled);
  DWM_BLURBEHIND blur_behind = {};
  blur_behind.dwFlags = DWM_BB_ENABLE;
  blur_behind.fEnable = FALSE;
  ::DwmEnableBlurBehindWindow(window, &blur_behind);
}

void SetImmersiveDarkMode(HWND window, bool dark) {
  if (window == nullptr) {
    return;
  }
  BOOL value = dark ? TRUE : FALSE;
  ::DwmSetWindowAttribute(window, DWMWA_USE_IMMERSIVE_DARK_MODE, &value,
                          sizeof(value));
}

void SetCornerPreference(HWND window, int preference) {
  if (window == nullptr) {
    return;
  }
  DWORD value = static_cast<DWORD>(preference);
  ::DwmSetWindowAttribute(window, DWMWA_WINDOW_CORNER_PREFERENCE, &value,
                          sizeof(value));
}

bool SystemPrefersDarkMode() {
  DWORD light_theme = 1;
  DWORD size = sizeof(light_theme);
  LSTATUS status = ::RegGetValueW(
      HKEY_CURRENT_USER,
      L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize",
      L"AppsUseLightTheme", RRF_RT_REG_DWORD, nullptr, &light_theme, &size);
  if (status != ERROR_SUCCESS) {
    return true;
  }
  return light_theme == 0;
}

}  // namespace dynamicbar
