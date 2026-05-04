---
name: Pacwin Technical System
colors:
  surface: '#f9f9f9'
  surface-dim: '#dadada'
  surface-bright: '#f9f9f9'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f3f3f4'
  surface-container: '#eeeeee'
  surface-container-high: '#e8e8e8'
  surface-container-highest: '#e2e2e2'
  on-surface: '#1a1c1c'
  on-surface-variant: '#3f4850'
  inverse-surface: '#2f3131'
  inverse-on-surface: '#f0f1f1'
  outline: '#6f7881'
  outline-variant: '#bfc7d1'
  surface-tint: '#006494'
  primary: '#006190'
  on-primary: '#ffffff'
  primary-container: '#007bb5'
  on-primary-container: '#fcfcff'
  inverse-primary: '#8ecdff'
  secondary: '#3e692b'
  on-secondary: '#ffffff'
  secondary-container: '#bef1a3'
  on-secondary-container: '#446f30'
  tertiary: '#5c5c5c'
  on-tertiary: '#ffffff'
  tertiary-container: '#747474'
  on-tertiary-container: '#fefcfc'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#cbe6ff'
  primary-fixed-dim: '#8ecdff'
  on-primary-fixed: '#001e30'
  on-primary-fixed-variant: '#004b71'
  secondary-fixed: '#bef1a3'
  secondary-fixed-dim: '#a3d489'
  on-secondary-fixed: '#062100'
  on-secondary-fixed-variant: '#275015'
  tertiary-fixed: '#e3e2e2'
  tertiary-fixed-dim: '#c7c6c6'
  on-tertiary-fixed: '#1b1c1c'
  on-tertiary-fixed-variant: '#464747'
  background: '#f9f9f9'
  on-background: '#1a1c1c'
  surface-variant: '#e2e2e2'
typography:
  display-lg:
    fontFamily: Inter
    fontSize: 40px
    fontWeight: '700'
    lineHeight: '1.2'
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: '1.3'
    letterSpacing: -0.01em
  body-base:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: '1.5'
    letterSpacing: '0'
  label-caps:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '600'
    lineHeight: '1.0'
    letterSpacing: 0.05em
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  base: 4px
  xs: 0.25rem
  sm: 0.5rem
  md: 1rem
  lg: 1.5rem
  xl: 2rem
  gutter: 1rem
  container-max: 1280px
---

## Brand & Style

This design system is engineered for the modern developer, bridging the gap between high-performance CLI tools and sophisticated GUI environments. The visual language has evolved into a **High-Clarity Technical Aesthetic**, shifting to a clean, light-mode interface that emphasizes precision, readability, and structural integrity.

The aesthetic prioritizes "daylight productivity"—using clean, off-white surfaces to provide a neutral canvas for data-heavy workflows. It retains its technical edge through high-contrast accents and structural integrity, evoking the reliability of a modern IDE. Every element is designed to feel "built, not decorated," using sharp lines and intentional spacing to guide the user through complex package management workflows with absolute clarity.

## Colors

The palette is derived directly from the pacwin_ identity, optimized for a high-clarity light environment.

- **Primary (Pac-Blue):** Used for primary actions, active states, and branding elements. It provides a professional, stable anchor for the interface.
- **Secondary (Terminal Green):** Reserved for success states, "ready" indicators, and validated status outputs.
- **Neutral (Off-White):** The foundation of the UI (#FEFEFE). Backgrounds use a clean off-white to reduce visual noise, while UI borders and secondary surfaces use subtle grey tones to create depth.
- **Tertiary (Technical Grey):** Used for supporting structural elements, secondary iconography, and muted metadata (#777777). This mid-tone grey provides a softer alternative to black for non-critical information while maintaining sufficient legibility.

## Typography

This design system utilizes **Inter** as its primary typeface to ensure exceptional legibility across administrative UI and technical data labels.

- **UI Interface:** Inter is utilized for headlines, body copy, and primary navigation. Its geometric clarity and balanced proportions provide a modern, professional feel at all sizes.
- **Technical Data:** While Inter handles the metadata, JetBrains Mono remains the standard for all code snippets and terminal outputs to ensure character distinction (e.g., `0` vs `O`).
- **Formatting:** Use all-caps with increased tracking for labels and section headers to create a "blueprint" or "manifest" aesthetic.

## Layout & Spacing

The layout follows a **Rigid Grid System** based on a 4px baseline. This ensures all elements align to a predictable rhythm, essential for a tool that displays tabular data and logs.

- **Grid:** A 12-column fluid grid is used for dashboard views, while utility panels use a fixed-width sidebar (240px or 320px).
- **Density:** High-density layouts are preferred. Padding should be sufficient for touch targets but compact enough to maximize the information displayed on a single screen.
- **Rhythm:** Vertical spacing should be consistent, using `1rem` (md) for most component gaps and `1.5rem` (lg) for section separation.

## Elevation & Depth

To maintain the "Modern Technical" feel, this design system avoids heavy shadows in favor of **Tonal Layering and Low-Contrast Outlines**.

- **Surface Tiers:** Depth is created by subtle tonal shifts in the background greys for each successive layer (e.g., Background -> Card -> Modal).
- **Borders:** Instead of shadows, use 1px solid borders in a light grey to define element boundaries.
- **Active States:** 2px primary-colored borders indicate focus and active selection, providing clear feedback on the light canvas.

## Shapes

The shape language is **Soft (0.25rem)**. This provides a professional, "software-industrial" look that is cleaner than sharp 90-degree angles but more serious than highly rounded consumer interfaces.

- **Buttons & Inputs:** Use the standard `rounded` (4px) radius.
- **Large Containers:** Use `rounded-lg` (8px) for cards and modals to slightly soften the technical edge.
- **Status Indicators:** Use 100% rounding (pills) for status chips (e.g., "Stable", "Deprecated") to make them instantly recognizable as non-structural elements.

## Components

- **Buttons:** Primary buttons use the Pac-Blue background with white text. Ghost buttons use the tertiary grey or primary outlines for secondary actions.
- **Input Fields:** White backgrounds with a 1px grey border that turns Pac-Blue on focus.
- **Terminal View:** A dedicated component for logs. It preserves the classic look with a pure black background (#000000), Terminal Green text, and no rounded corners on the bottom.
- **Data Tables:** Border-only construction with no zebra striping. Use a primary-colored vertical bar on the left of a row to indicate selection.
- **Package Cards:** Minimalist blocks showing package name (Inter Bold), version (Monospace), and a status chip.