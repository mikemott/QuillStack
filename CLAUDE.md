# QuillStack

SwiftUI iOS app for handwritten note capture via camera, OCR, and type-based organization.

**Target:** iOS 26.2+ | **Swift:** 6.0 | **Xcode:** 26.1+

## Token Optimization

- Use `limit: 10` for Linear queries unless more needed
- Start fresh conversations for unrelated tasks
- Use `/compact` when context builds up

## Development Workflow

For non-trivial features and fixes, follow this workflow:

1. **Plan & Create Issue**: Discuss approach, then create Linear issue with proper labels/project
2. **Branch Naming**: Use Linear's format: `qui-XX-short-description` (lowercase, hyphens)
3. **Implement**: Make changes, commit with clear messages
4. **Create PR**: Use `gh pr create` with `Closes QUI-XX` in description body
5. **Automated Reviews**: PR-Agent and Linear sync run automatically
6. **Merge**: After addressing feedback, merge PR (Linear issue auto-closes)

**When to use this workflow:**
- New features or significant changes
- Bug fixes requiring testing
- Refactoring touching multiple files
- Anything that benefits from code review

**When to skip:**
- Trivial changes (typos, minor tweaks)
- Documentation-only updates
- Emergency hotfixes explicitly requested

**Automation in place:**
- **PR-Agent**: AI code review with Claude Sonnet 4.5 (`.github/workflows/pr-agent.yml`)
- **Linear Sync**: Auto-updates issue to "In Review" when PR opens (`.github/workflows/linear-sync.yml`)
- **GitHub Webhook**: Auto-links commits and closes issues via magic words (`Fixes/Closes QUI-XX`)

## Key Concepts

**Note Types:** Auto-classified via hashtag triggers (`#todo#`, `#email#`, `#meeting#`, etc.) in `TextClassifier.swift`. Each type has a dedicated detail view. 12 types total, implemented as plugins in `Services/Plugins/BuiltIn/`.

**OCR Pipeline:** Apple Vision (VNRecognizeTextRequestRevision3) → optional LLM enhancement (Claude API) → user correction for low-confidence words.

**Architecture:** MVVM with service layer. Core Data for persistence. NoteTypePlugin protocol for extensible note types. NoteEventBus for loose coupling.

## Build Notes

- Camera requires physical device
- If xcodebuild fails: `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`
- Uses `@MainActor` default isolation, `@Observable` for ViewModels

## Key Files

| Area | Files |
|------|-------|
| Entry | `App/QuillStackApp.swift`, `App/ContentView.swift` |
| OCR | `Services/OCRService.swift`, `Services/LLMService.swift` |
| Classification | `Services/TextClassifier.swift`, `Services/Plugins/` |
| Camera | `Services/CameraManager.swift`, `ViewModels/CameraViewModel.swift` |
| Data | `Models/Note.swift`, `Models/CoreDataStack.swift` |
| UI | `Views/Notes/`, `Views/Components/DetailBottomBar.swift` |

## Custom Colors

`.forestDark/.forestMedium/.forestLight` (greens), `.creamLight/.paperBeige/.paperTan` (backgrounds), `.badgeTodo/.badgeEmail/etc` (type badges) - defined in `Extensions.swift`.
