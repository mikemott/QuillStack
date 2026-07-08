# QuillStack

Fast image capture app for real-world information — receipts, posters, tickets, notes. Tag, organize by date, export to Obsidian.

**Target:** iOS 26+ | **Swift:** 6.0 | **Xcode:** 26.1+

## Architecture

- SwiftData for persistence (not Core Data)
- MVVM with `@Observable` ViewModels
- XcodeGen for project generation (`project.yml`)
- Single-screen timeline with modal capture flow

## Conventions

- Branch naming: `quillstack-{number}-short-description`
- Issue refs: `QUILLSTACK-123`
- Minimal, utilitarian UI — system fonts/colors, no decorative chrome
- Monochrome UI, colorful data (only tags bring color)
- Tag-only organization — no folders, 10 curated default tags

## Key Files

| File | Purpose |
|------|---------|
| `QuillStack/App/QuillStackApp.swift` | App entry |
| `QuillStack/Models/Capture.swift` | Core data model |
| `QuillStack/Models/Tag.swift` | Tag model + 10 defaults |
| `project.yml` | XcodeGen project spec |

## Commands

```bash
xcodegen generate    # Regenerate .xcodeproj after editing project.yml
```

## Agent Notes

- Camera requires physical device for full functionality
- Discourage tag sprawl — creating new tags should be deliberate
- 10 default tags: Receipt, Event, Work, Contact, Food, To-Do, Project, Ticket, Reference, Quote — see `QuillStack/Models/Tag.swift` for the canonical list and colors
