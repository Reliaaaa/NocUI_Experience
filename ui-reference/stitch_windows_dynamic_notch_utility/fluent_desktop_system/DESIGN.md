---
name: Fluent Desktop System
colors:
  surface: '#fbf9f8'
  surface-dim: '#dbdad9'
  surface-bright: '#fbf9f8'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f5f3f3'
  surface-container: '#efeded'
  surface-container-high: '#e9e8e7'
  surface-container-highest: '#e4e2e2'
  on-surface: '#1b1c1c'
  on-surface-variant: '#404752'
  inverse-surface: '#303030'
  inverse-on-surface: '#f2f0f0'
  outline: '#717783'
  outline-variant: '#c0c7d4'
  surface-tint: '#0060ab'
  primary: '#005faa'
  on-primary: '#ffffff'
  primary-container: '#0078d4'
  on-primary-container: '#ffffff'
  inverse-primary: '#a3c9ff'
  secondary: '#0061a3'
  on-secondary: '#ffffff'
  secondary-container: '#5badff'
  on-secondary-container: '#003f6d'
  tertiary: '#006775'
  on-tertiary: '#ffffff'
  tertiary-container: '#008293'
  on-tertiary-container: '#ffffff'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#d3e3ff'
  primary-fixed-dim: '#a3c9ff'
  on-primary-fixed: '#001c39'
  on-primary-fixed-variant: '#004883'
  secondary-fixed: '#d1e4ff'
  secondary-fixed-dim: '#9ecaff'
  on-secondary-fixed: '#001d36'
  on-secondary-fixed-variant: '#00497d'
  tertiary-fixed: '#a0efff'
  tertiary-fixed-dim: '#3cd8f1'
  on-tertiary-fixed: '#001f25'
  on-tertiary-fixed-variant: '#004e59'
  background: '#fbf9f8'
  on-background: '#1b1c1c'
  surface-variant: '#e4e2e2'
typography:
  display:
    fontFamily: Work Sans
    fontSize: 68px
    fontWeight: '600'
    lineHeight: 92px
    letterSpacing: -0.02em
  title-large:
    fontFamily: Work Sans
    fontSize: 40px
    fontWeight: '600'
    lineHeight: 52px
    letterSpacing: -0.015em
  title-large-mobile:
    fontFamily: Work Sans
    fontSize: 28px
    fontWeight: '600'
    lineHeight: 36px
    letterSpacing: -0.01em
  title:
    fontFamily: Work Sans
    fontSize: 28px
    fontWeight: '600'
    lineHeight: 36px
    letterSpacing: -0.01em
  subtitle:
    fontFamily: Work Sans
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 26px
    letterSpacing: -0.005em
  body-large:
    fontFamily: Work Sans
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 22px
    letterSpacing: 0em
  body:
    fontFamily: Work Sans
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
    letterSpacing: 0em
  body-strong:
    fontFamily: Work Sans
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: 0em
  caption:
    fontFamily: Work Sans
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
    letterSpacing: 0.01em
  caption-strong:
    fontFamily: Work Sans
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
  gutter: 0.75rem
  gutter-desktop: 1rem
  margin: 1rem
  margin-desktop: 2rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 0.75rem
  space-lg: 1rem
  space-xl: 1.5rem
---

## Brand & Style
The design system embodies the serene, natural, and tactile ergonomics of modern desktop computing. It balances human warmth with precise, systematic clarity, giving tools a sense of calm purpose, focus, and fluidity. 

Drawing heavily from modern translucent computing paradigms, the style fuses **Glassmorphism**, **Subtle Layering**, and **Modern OS Desktop Ergonomics**. It relies on materials that softly tint the application canvas with desktop environment cues (Mica) while providing focused, transient contextual layers (Acrylic). The visual atmosphere is understated and structured: quiet background surfaces allow content to command attention, while responsive micro-elevations, deliberate corner radii, and high-performance tactile feedback deliver an effortless experience.

## Colors
The color palette relies on an authoritative Windows Blue as the active accent, supported by a family of layered neutral fills engineered for varying opacity and material depth.

### Surface Tokens & Materials
- **Canvas Base (Mica Background):** 
  - Light: `#F3F3F3` with ambient wallpaper bleed-through (composited opacity `0.85` over wallpaper backdrop blur).
  - Dark: `#202020` base with `0.80` composite opacity.
- **Card / Layer Background (Solid/Rest):** 
  - Light: `#FFFFFF` at `0.70` opacity or pure `#FFFFFF` over Mica.
  - Dark: `#2D2D2D` at `0.60` opacity or `#2D2D2D` solid.
- **Transient Surfaces (Acrylic Flyouts / Menus):** 
  - Light: `#F9F9F9` at `0.85` opacity with backdrop blur `30px` and saturation boost `125%`.
  - Dark: `#2C2C2C` at `0.85` opacity with backdrop blur `30px` and saturation boost `125%`.

### Accent Spectrum
- **Primary Accent (`#0078D4`):** Primary interactions, toggled switches, selected radio controls, active sliders, and primary action buttons.
- **Accent Hover (`#106EBE`):** Interactive state for primary accent controls.
- **Accent Pressed (`#005A9E`):** Down-press state for primary accent controls.
- **Accent Disabled:** `#CCCCCC` in light mode; `#404040` in dark mode.

### Borders & Delimiters
- **Subtle Surface Stroke:** `rgba(0, 0, 0, 0.06)` in light mode, `rgba(255, 255, 255, 0.08)` in dark mode.
- **Elevation Highlight Border:** Dual-tone border simulating top-down light; top border uses `rgba(255, 255, 255, 0.40)` in light mode, bottom border fades to `rgba(0, 0, 0, 0.06)`.

## Typography
Typography is crisp, neutral, and engineered for optimum reading comfort across density-heavy application surfaces. Using **Work Sans** as the foundational typeface provides an exacting structural match for variable desktop interface standards, mirroring the metric clarity, uniform glyph geometry, and functional legibility required for desktop windowing and controls.

### Usage Standards
- **Optical Hierarchy:** Primary headers utilize semi-bold weights (`600`) with tight letter-spacing to ground window headers and page zones.
- **Reading Comfort:** Standard desktop body elements stick to `14px` at regular weight (`400`) with an exact `20px` line-height, aligning strictly to the 4px baseline rhythm.
- **System Labels:** Captions and metadata occupy `12px` sizes, providing space-efficient status indicators, keyboard shortcuts, and helper notes.

## Layout & Spacing
The layout model employs a responsive desktop-first framework centered around structured navigation split-views, multi-column master-detail views, and adaptive grids.

### Breakpoints & Canvas Shell
- **Compact (`< 641px`):** Stacked single-column; navigation collapses to an overlay drawer; canvas margin shifts to `margin: 1rem` (`16px`).
- **Medium (`641px - 1007px`):** Collapsed rail navigation (`48px` width); card gutters scale to `0.75rem` (`12px`).
- **Expanded (`>= 1008px`):** Persistent left-side pane (`240px`–`320px`); main stage margin expands to `margin-desktop: 2rem` (`32px`); multi-column content flows across a 12-column grid with `1rem` (`16px`) gutters.

### Layout Rhythms
Strict 4px base increment grid:
- `space-xs` (`4px`): Micro-alignments, icon-to-text spacing, compact control paddings.
- `space-sm` (`8px`): Internal padding within standard buttons, list items, and form elements.
- `space-md` (`12px`): Spacing between grouped elements inside cards, input clusters, and toolbars.
- `space-lg` (`16px`): Standard card interior padding and container spacing.
- `space-xl` (`24px`): Section separation within panels and master views.

## Elevation & Depth
Elevation is realized through physical material transparency (Mica & Acrylic) paired with directional light modeling rather than aggressive, muddy drop shadows. Surfaces feel near, precise, and crisp.

### Elevation Hierarchy

1. **Base Layer (Resting Mica / Window Shell):**
   - No shadow. Translucent composite tinted with background wallpaper colors. 
   - Uses a border stroke of `1px solid rgba(0, 0, 0, 0.08)` in light mode, `1px solid rgba(255, 255, 255, 0.06)` in dark mode.

2. **Card & Surface Containers (Elevation 1):**
   - Subtle resting elevation.
   - Dual-layer border: `1px solid rgba(0, 0, 0, 0.06)` combined with an inward or top highlight edge `rgba(255, 255, 255, 0.70)` to create an illuminated edge.
   - Shadow: `0px 2px 4px rgba(0, 0, 0, 0.04), 0px 1px 2px rgba(0, 0, 0, 0.02)`.

3. **Popovers, Tooltips & Context Menus (Acrylic Flyout / Elevation 2):**
   - Translucent frosted glass effect using `backdrop-filter: blur(30px) saturate(125%)`.
   - Shadow: `0px 8px 16px rgba(0, 0, 0, 0.14), 0px 0px 2px rgba(0, 0, 0, 0.06)`.
   - Continuous crisp perimeter stroke: `1px solid rgba(0, 0, 0, 0.09)` in light, `1px solid rgba(255, 255, 255, 0.12)` in dark.

4. **Dialogs & Modal Windows (Elevation 3):**
   - Centered focal layer with underlying translucent smoke scrim (`rgba(0, 0, 0, 0.30)` light, `rgba(0, 0, 0, 0.55)` dark).
   - Shadow: `0px 32px 64px rgba(0, 0, 0, 0.24), 0px 2px 21px rgba(0, 0, 0, 0.12)`.
   - Dual-tone edge lighting around full perimeter.

## Shapes
Geometry is calm and friendly yet distinctly architectural. The system applies a controlled rounded corner philosophy:
- **Base Geometry (`roundedness: 1`):** Core interactive components (standard buttons, text inputs, list tiles, checkboxes) share an outer radius of `4px` (`0.25rem`).
- **Container Geometry (`rounded-lg`):** Content cards, surface group containers, flyouts, and contextual menus adopt an `8px` (`0.5rem`) corner radius.
- **Top-Level Geometry (`rounded-xl`):** Primary application dialogs, detached app windows, and major modal structures adopt a `12px` (`0.75rem`) corner radius.
- **Full Radius / Pill:** Reserved solely for toggle switches, status pill badges, and slider thumb handles.

## Components

### Buttons
- **Standard Button:** Background `rgba(255, 255, 255, 0.70)`, bottom border highlight `rgba(0, 0, 0, 0.12)`, radius `4px`, padding `6px 14px`, text `14px` weight `400`. Hover state darkens background to `rgba(245, 245, 245, 0.90)`. Active state triggers `scale(0.98)` transform and inset dimming.
- **Accent Button:** Solid `#0078D4`, white text `weight 600`, border bottom `1px solid rgba(0, 0, 0, 0.20)`. Hover: `#106EBE`. Pressed: `#005A9E`.

### Toggle Switches (ToggleSwitch)
- Container pill size `44px × 22px`. 
- Unchecked: Track border `1px solid rgba(0, 0, 0, 0.40)`, track background transparent, thumb diameter `14px` tinted `rgba(0, 0, 0, 0.75)`.
- Checked: Track background `#0078D4`, track border `transparent`, thumb diameter `16px` pure `#FFFFFF`.
- Motion: Thumb transition `160ms cubic-bezier(0.1, 0.9, 0.2, 1.0)`.

### Sliders (Slider Controls)
- Track height `4px`, rounded full. Inactive segment `#E5E5E5` (`#404040` dark), active segment `#0078D4`.
- Thumb: Circle diameter `18px`, white center with a `1px` subtle outline and an inner `#0078D4` central dot (`10px` diameter) when hovered/pressed.
- Elevation: Thumb carries `0px 2px 4px rgba(0,0,0,0.18)`.

### Input Fields (TextBox)
- Height `32px`, padding `4px 10px`, background `rgba(255, 255, 255, 0.70)` (light) / `rgba(255, 255, 255, 0.06)` (dark).
- Border: `1px solid rgba(0, 0, 0, 0.08)`, with an underline bottom border `1px solid rgba(0, 0, 0, 0.40)`.
- Focus State: Bottom underline transforms into a `2px` thick line colored `#0078D4` with smooth ease-out expansion.

### Checkboxes & Radio Buttons
- **Checkbox:** `18px × 18px`, `4px` radius. Rest state has a `1px solid rgba(0,0,0,0.50)` outline. Checked state fills `#0078D4` with an inverted white checkmark path.
- **Radio Button:** `18px × 18px`, full circle. Checked state creates an inner concentric dot of diameter `10px` filled with `#0078D4`.

### Lists & Navigation Rails
- List items feature transparent rest states with a `4px` corner radius.
- Hover brings an interactive light acrylic plate (`rgba(0, 0, 0, 0.03)` light / `rgba(255, 255, 255, 0.04)` dark).
- Selected state displays a vertical accent pill marker (`3px` width, `16px` height, `#0078D4`) pinned to the immediate left border of the list row.

### Cards
- Surface: Mica-compatible solid fill `#FFFFFF` (light) / `#2B2B2B` (dark) at `80%` opacity.
- Border: `1px solid rgba(0, 0, 0, 0.05)`, top-edge highlight `1px solid rgba(255, 255, 255, 0.45)`.
- Border-radius: `8px`. Padding: `16px`.

### Command Bar & Toolbars
- Floating horizontal surface with `8px` rounded corners, Acrylic material blur (`30px`), containing grouped icon buttons (`32px × 32px`) separated by `1px` vertical divider lines.