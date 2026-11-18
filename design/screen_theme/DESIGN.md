---
name: Tactical Grandmaster Dark
colors:
  surface: '#0e141c'
  surface-dim: '#0e141c'
  surface-bright: '#343a42'
  surface-container-lowest: '#090f16'
  surface-container-low: '#161c24'
  surface-container: '#1a2028'
  surface-container-high: '#242a33'
  surface-container-highest: '#2f353e'
  on-surface: '#dde3ee'
  on-surface-variant: '#b9cbb9'
  inverse-surface: '#dde3ee'
  inverse-on-surface: '#2b3139'
  outline: '#849585'
  outline-variant: '#3b4b3d'
  surface-tint: '#00e479'
  primary: '#f1ffef'
  on-primary: '#003919'
  primary-container: '#00ff88'
  on-primary-container: '#007139'
  inverse-primary: '#006d37'
  secondary: '#fff9ef'
  on-secondary: '#3a3000'
  secondary-container: '#ffdb3c'
  on-secondary-container: '#725f00'
  tertiary: '#fffaf9'
  on-tertiary: '#68000a'
  tertiary-container: '#ffd5d1'
  on-tertiary-container: '#bf1f27'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#60ff99'
  primary-fixed-dim: '#00e479'
  on-primary-fixed: '#00210c'
  on-primary-fixed-variant: '#005228'
  secondary-fixed: '#ffe16d'
  secondary-fixed-dim: '#e9c400'
  on-secondary-fixed: '#221b00'
  on-secondary-fixed-variant: '#544600'
  tertiary-fixed: '#ffdad7'
  tertiary-fixed-dim: '#ffb3ad'
  on-tertiary-fixed: '#410004'
  on-tertiary-fixed-variant: '#930013'
  background: '#0e141c'
  on-background: '#dde3ee'
  surface-variant: '#2f353e'
typography:
  headline-xl:
    fontFamily: Space Grotesk
    fontSize: 40px
    fontWeight: '700'
    lineHeight: 48px
  headline-xl-mobile:
    fontFamily: Space Grotesk
    fontSize: 30px
    fontWeight: '700'
    lineHeight: 36px
  headline-lg:
    fontFamily: Space Grotesk
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
  headline-lg-mobile:
    fontFamily: Space Grotesk
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  headline-md:
    fontFamily: Space Grotesk
    fontSize: 22px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  body-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
  label-clock:
    fontFamily: JetBrains Mono
    fontSize: 36px
    fontWeight: '700'
    lineHeight: 40px
  label-clock-mobile:
    fontFamily: JetBrains Mono
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 32px
  label-notation:
    fontFamily: JetBrains Mono
    fontSize: 13px
    fontWeight: '500'
    lineHeight: 18px
  label-sm:
    fontFamily: JetBrains Mono
    fontSize: 11px
    fontWeight: '600'
    lineHeight: 14px
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  gutter: 1rem
  gutter-mobile: 0.5rem
  margin: 1.5rem
  margin-mobile: 1rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2rem
---

## Brand & Style

This design system is tailored for a cross-platform, local-first chess engine and tournament interface. The aesthetic bridges competitive sports analytics, precision esports, and high-performance tactile interfaces.

- **Brand Personality**: Analytical, razor-sharp, immediate, and commanding. The interface recedes into the background to allow maximum cognitive focus during tactical play, stepping forward with high-energy luminescence only to communicate critical game state changes.
- **Target Audience**: Competitive chess players, blitz/bullet enthusiasts, analysts, and mobile-first chess software users who demand instantaneous response times and zero UI friction.
- **Emotional Response**: Focused intensity, calculated confidence, and the tactile thrill of playing over-the-board speed chess.
- **Design Style**: Modern Dark Cyber-Minimalism. It integrates deep slate surface stepping, high-contrast digital phosphors (matrix emerald, electric amber, signal crimson), subtle micro-borders, and disciplined monospace telemetry.

## Colors

The palette is engineered specifically for OLED displays and long, eye-straining play sessions in low ambient light.

- **Primary Accent (`#00FF88`)**: Phosphor green used for active player readiness, positive material imbalance (+3, +5), engine evaluation spikes, and legal move landing targets.
- **Secondary Accent (`#FFD700`)**: Electric gold assigned to low-time clock alerts, last move origin/destination highlight overlays, winning crown badges, and tournament match points.
- **Tertiary Alert (`#EF4444`)**: Signal crimson reserved strictly for king in check, blunder telemetry, draw declines, and immediate flag fall (time expired).
- **Surface Hierarchy**:
  - `Canvas / Background`: Deep Void (`#0B0F14`)
  - `Surface 1 (Cards, Bottom Sheets)`: Dark Slate (`#121820`)
  - `Surface 2 (Elevated Tiles, Floating Overlays)`: Elevated Charcoal (`#1A222D`)
  - `Subtle Outlines`: Low-opacity stroke (`rgba(255, 255, 255, 0.08)`)
- **Chess Board Matrix**:
  - Dark Squares: Deep Indigo Slate (`#263342`)
  - Light Squares: Desaturated Silver Mist (`#DDE6ED`)
  - Legal Move Indicator: Solid circular phosphor dot or ghost ring (`rgba(0, 255, 136, 0.6)`)

## Typography

The typographic hierarchy separates structural layout, conversational interface copy, and critical numerical data.

- **Headlines (`Space Grotesk`)**: Geometric, sharp, and confident. Used for match intros, victory declarations, sheet headers, and drawer titles.
- **Body & Controls (`Inter`)**: High-legibility neutral grotesque for settings, player bios, chat, and system alerts.
- **Telemetry & Clocks (`JetBrains Mono`)**: Strict tabular alignment. Indispensable for preventing clock jitter when fractional tenths-of-seconds tick down. Also applied to chess algebraic notation (SAN), rank/file board markers (`a-h`, `1-8`), and eval scores (`+1.4`, `-M3`).

## Layout & Spacing

The layout adapts between touch-first Flutter mobile viewports and landscape desktop / tablet engine workspaces.

- **Chess Board Primacy**: The 1:1 aspect ratio board anchors the experience.
  - On **Mobile (<768px)**: The board spans full width minus `margin-mobile` (16px safe margin). Player info banners are pinned directly above and below the board. Game log, clock drawers, and controls occupy the bottom sheet or vertical space balance.
  - On **Tablet / Desktop (>=768px)**: A 12-column asymmetric split. The board occupies 7 columns; notation logs, eval graph, captured piece counters, and clock timers take the remaining 5 columns.
- **Rhythm**: Everything aligns to a strict 4px/8px incremental grid. Interactive tap targets meet or exceed 48×48dp for tournament blitz play where rapid touch precision is mandatory.

## Elevation & Depth

Depth is conveyed through dark tonal layering paired with phosphor-tinted luminescent borders, rather than heavy diffuse drop shadows.

- **Level 0 (Canvas)**: Background `#0B0F14`.
- **Level 1 (Panels & Boards)**: `#121820` with a 1px border of `rgba(255, 255, 255, 0.06)`.
- **Level 2 (Cards & Active States)**: `#1A222D` with an internal highlight border of `rgba(255, 255, 255, 0.1)`.
- **Level 3 (Modals, Overlays & Dragged Pieces)**: Lifted via a direct ambient glow: `box-shadow: 0 12px 32px rgba(0, 0, 0, 0.8), 0 0 16px rgba(0, 255, 136, 0.15)`.
- **Tactical Active Glow**: Active timers and check statuses use targeted luminescence (e.g., active timer: subtle exterior spread of `rgba(255, 215, 0, 0.25)`; King in check: square flood `rgba(239, 68, 68, 0.35)` with a 1px inner pulse).

## Shapes

The design uses a restrained, sharp architectural shape language (Level 1: Soft).

- **Standard Elements**: 4px radius (`0.25rem`) on buttons, inputs, move notation cells, and dialogs.
- **Containers & Panels**: 8px radius (`0.5rem`) on major sheets, cards, and chess board outer boundaries.
- **Board Squares**: 0px radius (pure geometric edge-to-edge squares) to preserve standard board grid geometry.
- **Indicator Pills**: Rounded capsules used solely for material advantage badges (`+3`) and online status dots.

## Components

- **Chess Clock**:
  - Monospace numeral container rendered in `JetBrains Mono`.
  - Default state: Background `#121820`, text `#DDE6ED`.
  - Active turn state: Background `#1A222D`, 1.5px border `#FFD700`, text `#FFD700` with slight 4px bloom.
  - Low time (<30s): Pulsing border `#EF4444`, text `#EF4444`.
- **Buttons**:
  - *Primary (Action/Resign/Offer)*: High-contrast emerald fill (`#00FF88`) with black typography (`#0B0F14`) in `Space Grotesk` bold.
  - *Secondary (Flip Board/Analysis)*: Transparent fill, 1px border `rgba(255, 255, 255, 0.12)`, text `#DDE6ED`, hover state `#1A222D`.
  - *Destructive (Resign confirm)*: Crimson tint (`#EF4444`) with white typography.
- **Move List / Notation Table**:
  - Horizontal alternating row striping in JetBrains Mono.
  - Active move highlighted in solid `#1A222D` with a left border strip of `#00FF88` (2px).
  - Annotations (!, ?, !?) rendered in electric gold and crimson superscript.
- **Evaluation Bar (Engine)**:
  - Vertical 12px pill strip running alongside the board.
  - White eval filled with `#DDE6ED`, Black eval with `#0B0F14`. Midpoint zero-line locked with 1px neon line.
- **Flutter Bottom Sheet**:
  - Anchored at the screen bottom with 8px top radius, backdrop blur (12px), background `#121820` at 92% opacity, topped with a 32×4px drag handle in `rgba(255, 255, 255, 0.2)`.