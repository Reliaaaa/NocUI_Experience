---
name: Fluent Desktop Mica Dark
colors:
  surface: '#131313'
  surface-dim: '#131313'
  surface-bright: '#393939'
  surface-container-lowest: '#0e0e0e'
  surface-container-low: '#1b1c1c'
  surface-container: '#202020'
  surface-container-high: '#2a2a2a'
  surface-container-highest: '#353535'
  on-surface: '#e5e2e1'
  on-surface-variant: '#bdc8cf'
  inverse-surface: '#e5e2e1'
  inverse-on-surface: '#303030'
  outline: '#889299'
  outline-variant: '#3e484e'
  surface-tint: '#74d1ff'
  primary: '#b4e4ff'
  on-primary: '#003548'
  primary-container: '#60cdff'
  on-primary-container: '#005572'
  inverse-primary: '#006687'
  secondary: '#a3c9ff'
  on-secondary: '#00315c'
  secondary-container: '#3b93f1'
  on-secondary-container: '#002a51'
  tertiary: '#cadfff'
  on-tertiary: '#00315b'
  tertiary-container: '#98c4ff'
  on-tertiary-container: '#00518e'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#c1e8ff'
  primary-fixed-dim: '#74d1ff'
  on-primary-fixed: '#001e2b'
  on-primary-fixed-variant: '#004d67'
  secondary-fixed: '#d3e3ff'
  secondary-fixed-dim: '#a3c9ff'
  on-secondary-fixed: '#001c39'
  on-secondary-fixed-variant: '#004883'
  tertiary-fixed: '#d3e4ff'
  tertiary-fixed-dim: '#a2c9ff'
  on-tertiary-fixed: '#001c38'
  on-tertiary-fixed-variant: '#004881'
  background: '#131313'
  on-background: '#e5e2e1'
  surface-variant: '#353535'
typography:
  display:
    fontFamily: Segoe UI Variable
    fontSize: 68px
    fontWeight: '600'
    lineHeight: 92px
    letterSpacing: -0.02em
  title-large:
    fontFamily: Segoe UI Variable
    fontSize: 40px
    fontWeight: '600'
    lineHeight: 52px
    letterSpacing: -0.015em
  title:
    fontFamily: Segoe UI Variable
    fontSize: 28px
    fontWeight: '600'
    lineHeight: 36px
    letterSpacing: -0.01em
  subtitle:
    fontFamily: Segoe UI Variable
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 26px
    letterSpacing: 0em
  body-large:
    fontFamily: Segoe UI Variable
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 22px
    letterSpacing: 0em
  body:
    fontFamily: Segoe UI Variable
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
    letterSpacing: 0em
  body-strong:
    fontFamily: Segoe UI Variable
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: 0em
  caption:
    fontFamily: Segoe UI Variable
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
    letterSpacing: 0.01em
  caption-strong:
    fontFamily: Segoe UI Variable
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.01em
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  gutter: 1rem
  gutter-dense: 0.5rem
  margin: 1.5rem
  margin-compact: 0.75rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 0.75rem
  space-lg: 1rem
  space-xl: 1.5rem
---

## Brand & Style

This design system targets modern native Windows desktop productivity, engineering, and enterprise tooling. The visual identity aligns with the Windows 11 Fluent aesthetic, emphasizing spatial depth, optical physics, and material authenticity.

### Aesthetic Principles
- **Materiality & Light:** Depth is communicated through simulated optical physical layers: Mica material that subtly samples desktop wallpaper luminescence, Acrylic frosted sheets for transient popouts, and layered solid dark surfaces for foundational canvases.
- **Precision Engineering:** UI components use low-profile height metrics, discrete pixel-aligned inset strokes, and micro-elevation cues designed specifically for mouse, keyboard, and pen-driven workstation workflows.
- **Intentional Restraint:** Dark mode relies on deep neutral tones rather than saturated hues. Color is exclusively functional: indicating active selection, state changes, and direct interactions.

## Colors

The palette establishes high-contrast optical legibility against deep obsidian and graphite foundations.

### Surface System
- **Background Base (Mica Tint Canvas):** `#181818` (Primary app frame and titlebar backdrop)
- **Layer Default (Content Canvas):** `#202020` (Main document/view area)
- **Card / Layer On Solid:** `#2c2c2c` (Elevated modules, controls, and grouped containers)
- **Layer Alt / Inset:** `#1c1c1c` (Recessed areas, split-views, and sidebar tracks)
- **Flyout / Popover:** Acrylic material layered over `#2c2c2c` at 85% opacity with 30px blur.

### Accent & Interaction Spectrum
- **Accent Primary (Default Interactive):** `#60cdff` (Text links, checked states, focus rings, primary button background in dark mode)
- **Accent Hover:** `#7adaff`
- **Accent Pressed:** `#4cb8ed`
- **Accent Secondary / Legacy Blue:** `#0078d4` (Used for system-level identity and subtle gradients)
- **Accent Tertiary / Deep Wash:** `#005a9e` (Selected state backgrounds and muted focus indicators)

### Foreground System
- **Text Primary:** `#ffffff` (Pure optical white for headers, labels, and high-priority reads)
- **Text Secondary:** `#d0d4d9` (Soft slate for body copy, descriptions, and metadata)
- **Text Tertiary:** `#8a929b` (Placeholder text, disabled copy, structural hints)

### Stroke System
- **Subtle Surface Stroke:** `rgba(255, 255, 255, 0.08)`
- **Elevation Inset Highlight:** `rgba(255, 255, 255, 0.04)` on outer bottom, `rgba(255, 255, 255, 0.11)` on top edge
- **Accent Border Focus:** `#60cdff`

## Typography

The typographic hierarchy is built on Microsoft’s native `Segoe UI Variable` engine, leveraging optical size axes (`opsz` Text, Display, Small) to maintain clarity at dense information densities.

### Rules of Usage
- **Display & Title Large:** Reserved for setup flows, feature landings, and zero-state welcome dashboards.
- **Title & Subtitle:** Section dividers and window sub-headers. Always set in pure white (`#ffffff`).
- **Body & Body-Strong:** Primary data displays, table values, list rows, and navigation items. Default rendering is soft slate (`#d0d4d9`).
- **Caption & Caption-Strong:** Contextual helper micro-copy, timestamps, file sizes, and keyboard shortcuts.

## Layout & Spacing

Desktop WinUI 3 structures require a rigid hierarchy balanced with adaptive window resizing.

### Grid & Canvas Structure
- **Navigation Shell:** Left-docked navigation pane (`NavigationView`) fixed at 48px collapsed (compact icon view) and 280px expanded.
- **Master-Detail Splitting:** Two-to-three pane architectures using flexible splitter grips with minimum panel widths of 320px.
- **App Canvas Padding:** Desktop main viewport maintains a consistent outer margin of `1.5rem` (`24px`). When windows are snap-docked under `640px` wide, margin drops to `0.75rem` (`12px`).
- **Rhythm Engine:** Built on a strict 4px base increment. Controls have normalized heights: standard buttons and inputs sit at 32px height, dense table rows at 28px, and touch/relaxed mode targets at 40px.

## Elevation & Depth

Depth in this system is created via physical materials, edge highlights, and directional lighting rather than heavy ambient drop shadows.

### Material Stack
1. **Mica Base (Canvas Layer):** Ambient system wallpaper refraction through an opaque `#181818` substrate. Applied across window root backdrops and title bars.
2. **Layer Container (`#2c2c2c`):** Solid opaque card resting directly on the Mica base. Demarcated by a 1px boundary stroke using `rgba(255, 255, 255, 0.08)`.
3. **Acrylic Transient Layer:** Used for menus, tooltips, flyouts, and command bars. Features `backdrop-filter: blur(30px)`, background tint `rgba(44, 44, 44, 0.85)`, and a bright top-rim highlight.

### Edge Luminescence & Rim Lighting
Every elevated card, control, and container features an internal directional lighting illusion:
- **Top Edge Inset:** `inset 0 1px 0 0 rgba(255, 255, 255, 0.09)` simulating an overhead light source.
- **Bottom Edge Inset:** `inset 0 -1px 0 0 rgba(0, 0, 0, 0.35)` providing visual anchoring.

### Shadows
- **Resting Elements:** No ambient shadow; boundary definition relies strictly on subtle border strokes.
- **Overlays & Dialogs:** `0 16px 32px rgba(0, 0, 0, 0.40), 0 4px 8px rgba(0, 0, 0, 0.25)`.
- **Flyouts & Menus:** `0 8px 16px rgba(0, 0, 0, 0.30), 0 2px 4px rgba(0, 0, 0, 0.15)`.

## Shapes

The geometric signature uses refined, consistent rounding to soften the desktop canvas while preserving data density.

### Corner Radius System
- **Small Controls (Buttons, Inputs, Checkboxes, Sliders, Chips):** `4px` corner radius.
- **Containers & Cards (Standard Panels, Content Tiles, Split Views):** `8px` corner radius.
- **Overlays, Flyouts & Modals (Dialogs, Popovers, System Banners):** `8px` corner radius.
- **System Windows:** Managed natively by DWM with `8px` outer window corners.

## Components

### Buttons
- **Primary / Accent Button:**
  - Background: `#60cdff`
  - Text: `#000000` (`Segoe UI Variable` SemiBold 14px)
  - Height: `32px`, Padding: `0 12px`, Radius: `4px`
  - Inset Rim: `inset 0 1px 0 0 rgba(255, 255, 255, 0.35)`
  - Hover: Background transitions to `#7adaff`
  - Pressed: Background shifts to `#4cb8ed`, transformed down `1px`
- **Standard Button:**
  - Background: `rgba(255, 255, 255, 0.06)`
  - Border: `1px solid rgba(255, 255, 255, 0.08)`
  - Text: `#ffffff`
  - Hover: Background shifts to `rgba(255, 255, 255, 0.10)`
  - Pressed: Background shifts to `rgba(255, 255, 255, 0.04)`

### Text Fields & Inputs
- Height: `32px`
- Background: `rgba(255, 255, 255, 0.06)`
- Bottom Border: `2px solid rgba(255, 255, 255, 0.40)` at rest; becomes `#60cdff` upon focus.
- Top/Side Border: `1px solid rgba(255, 255, 255, 0.08)`.
- Text: `#ffffff`, Placeholder: `#8a929b`.

### Checkboxes & Radios
- Size: `18px` by `18px`, radius `4px` (checkbox) or circular (radio).
- Rest: Border `1px solid rgba(255, 255, 255, 0.50)`, Background: `rgba(255, 255, 255, 0.04)`.
- Checked: Background `#60cdff`, border color `#60cdff`, glyph `#000000`.

### Cards & Grouping Containers
- Background: `#2c2c2c`
- Border: `1px solid rgba(255, 255, 255, 0.08)`
- Top Inset Highlight: `inset 0 1px 0 0 rgba(255, 255, 255, 0.04)`
- Padding: `16px` or `20px` depending on density.

### TreeView & DataGrid
- Alternating row zebra strips are prohibited. 
- Row Hover: `rgba(255, 255, 255, 0.04)` with rounded pill corners (`4px`).
- Row Selected: `rgba(255, 255, 255, 0.07)`, with a vertical accent bar on the left edge (`3px` wide, `#60cdff`, `16px` height centered).

### CommandBar & Menus
- Rendered using Acrylic material.
- Dividers: `1px` vertical or horizontal rules with `rgba(255, 255, 255, 0.08)`.
- Keyboard accelerators (`Ctrl+S`, `F5`) aligned to the right in `#8a929b`.