# QuillStack v2

Fast image capture app for real-world information — receipts, posters, tickets, notes. Tag, organize by date, export to Obsidian.

**Target:** iOS 26+ | **Swift:** 6.0 | **Xcode:** 26.1+

## Architecture

- **SwiftData** for persistence (not Core Data)
- **MVVM** with `@Observable` ViewModels
- **XcodeGen** for project generation (`project.yml` → `QuillStack.xcodeproj`)
- Single-screen timeline architecture with modal capture flow

## Data Model

- **Capture** — date, extractedTitle, ocrText, location, tags, images
- **CaptureImage** — imageData, thumbnailData, pageIndex, ocrText (for stacks)
- **Tag** — name, colorHex (8 defaults seeded on first launch)

## Key Files

| Area | Files |
|------|-------|
| Entry | `QuillStack/App/QuillStackApp.swift`, `QuillStack/App/ContentView.swift` |
| Models | `QuillStack/Models/Capture.swift`, `QuillStack/Models/Tag.swift`, `QuillStack/Models/CaptureImage.swift` |
| Views | `QuillStack/Views/Components/CaptureCard.swift`, `QuillStack/Views/Components/TagChip.swift` |
| Utilities | `QuillStack/Utilities/Extensions.swift` |

## Design Principles

- **Minimal, utilitarian UI** — system fonts, system colors, no decorative chrome
- **Monochrome UI, colorful data** — only tags bring color (via colored chips and thumbnail borders)
- **One-handed capture** — camera → tag → done in under 3 seconds
- **Tag-only organization** — no folders, no note types. Tags are the sole organizing concept
- **Discourage tag sprawl** — ship with 8 curated defaults, make creating new tags deliberate

## Build & Project Generation

```bash
# Regenerate Xcode project after changing project.yml
xcodegen generate

# Build
xcodebuild -project QuillStack.xcodeproj -scheme QuillStack -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Camera requires physical device for full functionality.

## Development Workflow

**NEVER commit directly to `main` branch** — git hook enforced.

Branch naming: `quillstack-{issue#}-short-description`

### Automation

- **Git Hook**: Blocks commits to `main`
- **PR-Agent**: AI code review
- **Forge**: Issue tracking (QUILLSTACK-1 through QUILLSTACK-12)

## Default Tags

Receipt (amber), Event (blue), Note (green), Work (slate), Personal (gray), Ticket (purple), Document (teal), Reference (orange)
