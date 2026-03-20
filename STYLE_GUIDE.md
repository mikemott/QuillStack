# QuillStack Style Guide

## Design Philosophy

Dark, utilitarian, editorial. Structure through tonal shifts, not borders. Color is reserved for data (tags) and the primary action (capture button). Everything else is monochrome.

## Color System

### Surfaces (Tonal Stepping)

| Token | Hex | Usage |
|-------|-----|-------|
| `lowest` / `base` | `#0E0E0E` | Deepest background |
| `containerLow` | `#131313` | Secondary areas, nav bar |
| `container` | `#1A1919` | Cards, input fields |
| `containerHigh` | `#222222` | Drawer cards, elevated content |
| `containerHighest` | `#262626` | Highest elevation |
| `bright` | `#393939` | Hover states |

### Primary

| Token | Hex | Usage |
|-------|-----|-------|
| `primary` | `#E0E0E0` | Header text, capture button |
| `onPrimaryDark` | `#0E0E0E` | Text on primary backgrounds |

### Text Hierarchy

| Token | Hex | Usage |
|-------|-----|-------|
| `onSurface` | `#E5E2E1` | Headlines, primary text |
| `onSurfaceVariant` | `#ADAAAA` | Body text, secondary |
| `onSurfaceMuted` | `#737070` | Timestamps, tertiary, icons |

**Rule:** Never use `#FFFFFF` for body text. It causes haloing on OLED.

## Typography

Dual-font system: **IBM Plex Sans** for display/body, **IBM Plex Mono** for data/labels.

| Context | Font | Size | Weight |
|---------|------|------|--------|
| App header | System | 26pt | Black, tracking 8 |
| Card title | Plex Sans Medium | 18pt | — |
| Card body / summary | Plex Sans Regular | 14pt | — |
| Card timestamp | Plex Mono Regular | 11pt | — |
| Tag chips | Plex Mono Regular | 10pt | Bold, tracking 1.5 |
| Section headers | Plex Mono Regular | 10pt | — |
| Date headers | Plex Sans Light | 24pt | — |

## Tag Chips

Sharp rectangles. No border radius. Solid background color. `#` prefix. Bold monospace.

### Tag Color Palette

| Tag | Hex | Text Color |
|-----|-----|------------|
| Receipt | `#D4FF00` | Dark `#1A1C1C` |
| Event | `#007AFF` | White |
| Note | `#FFB6C1` | Dark |
| Work | `#FFC107` | Dark |
| Document | `#008080` | White |
| Contact | `#E0E0E0` | Dark |
| Travel | `#FF7F50` | White |
| Inspiration | `#90EE90` | Dark |
| Food | `#FFFF00` | Dark |

**Text color rule:** Use luminance threshold (0.5). Below → white text. Above → dark text `#1A1C1C`.

### Filter Bar Behavior

- All chips fully vibrant at all times (no dimming)
- Selecting a tag collapses others with scale+opacity animation
- Deselecting restores all chips
- Sorted by capture count (most used first)

## Components

### Capture Card (Full)

- Image section: 58% of card height, scaledToFill
- Glass overlay metadata area with radial glow
- Title → Summary (1-2 lines) → Timestamp → Tags → Location + page count
- Share button overlay on image (top-right, glass style)

### Drawer Card (Compact)

- 72x72 thumbnail on left
- Title (1 line), timestamp, location, up to 3 tag chips
- `containerHigh` background, 8pt corner radius

### Capture Button

- Bottom-right positioned
- 64x64 circle, `#E0E0E0` background
- Camera icon 22pt semibold
- Dual-layer glow: 12px at 25% + 30px at 8%

### Header

- "QUILLSTACK" in system black 26pt, tracking 8
- `#E0E0E0` with dual-layer glow: 20px at 20% + 50px at 8%
- Icons right-aligned: grid toggle, search, settings
- No system navigation bar title

### Search

- Triggered by magnifying glass icon in header
- Slides in below header as dark-themed text field
- Cancel button dismisses and clears
- Matches against: title, OCR text, summary, location, tag names

## Elevation & Depth

- No drop shadows on cards (depth through tonal stepping)
- Ambient shadows: 40-60px blur, 10% max, tinted black
- Glass effect: radial gradient glow + ultraThinMaterial + surface overlay

## Spacing

- Card horizontal padding: 16pt
- Content padding: 20pt
- Tag chip spacing: 10pt (filter bar), 6-8pt (on cards)
- Section spacing: 28pt (drawer), 12pt (between drawer cards)
