// DynamicBar - DWM / composition attributes used by the overlay window.
//
// The island is drawn by Flutter into a window that must composite with
// per-pixel alpha so that anti-aliased rounded corners and soft shadows blend
// against the desktop instead of a rectangle of solid colour.
#ifndef DYNAMICBAR_WINDOW_WINDOW_EFFECTS_H_
#define DYNAMICBAR_WINDOW_WINDOW_EFFECTS_H_

#include <windows.h>

namespace dynamicbar {

// Asks DWM to honour the alpha channel of the window surface using the default
// mechanism (glass). See EnablePerPixelTransparency(HWND, AlphaMode).
bool EnablePerPixelTransparency(HWND window);

// Which composition mechanism to use. The default is glass, which is the only
// one that composited correctly on Windows 11 25H2 (see
// docs/WINDOWS_INTEGRATION.md). DYNAMICBAR_ALPHA overrides it for diagnosis:
//   accent  SetWindowCompositionAttribute(ACCENT_ENABLE_TRANSPARENTGRADIENT)
//   glass   DwmExtendFrameIntoClientArea over the whole client area
//   both    accent + glass
//   none    leave the window opaque
enum class AlphaMode { kAccent, kGlass, kBoth, kNone };
AlphaMode AlphaModeFromEnvironment(AlphaMode fallback);
bool EnablePerPixelTransparency(HWND window, AlphaMode mode);

// Restores an opaque window surface.
void DisablePerPixelTransparency(HWND window);

// Windows 11 title bar / border colouring for the settings-style surfaces.
void SetImmersiveDarkMode(HWND window, bool dark);

// DWMWCP_DEFAULT(0) / DONOTROUND(1) / ROUND(2) / ROUNDSMALL(3).
void SetCornerPreference(HWND window, int preference);

// Reads the current "apps use light theme" preference.
bool SystemPrefersDarkMode();

}  // namespace dynamicbar

#endif  // DYNAMICBAR_WINDOW_WINDOW_EFFECTS_H_
