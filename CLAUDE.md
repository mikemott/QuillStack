# QuillStack

SwiftUI iOS app for handwritten note capture via camera, OCR, and type-based organization.

**Target:** iOS 26.2+ | **Swift:** 6.0 | **Xcode:** 26.1+

## Token Optimization

- Use `limit: 10` for Linear queries unless more needed
- Start fresh conversations for unrelated tasks
- Use `/compact` when context builds up

## Development Workflow

**⚠️ CRITICAL: NEVER commit directly to `main` branch!**

A git pre-commit hook is installed to prevent this. Follow this workflow:

### Required Steps for All Non-Trivial Work

1. **Create Feature Branch FIRST**
   ```bash
   git checkout -b qui-XXX-short-description
   ```
   Branch naming: Linear's format (`qui-XX-short-description`, lowercase, hyphens)

2. **Implement & Commit**
   - Make changes on feature branch
   - Commit with clear messages
   - Multiple commits are fine

3. **Push & Create PR**
   ```bash
   git push -u origin qui-XXX-short-description
   gh pr create --title "..." --body "Closes QUI-XXX\n\n[description]"
   ```
   - Include `Closes QUI-XXX` in PR body
   - PR-Agent will auto-review
   - Linear issue auto-updates to "In Review"

4. **Merge After Review**
   - Address any PR-Agent feedback
   - Merge when ready (Linear issue auto-closes)

### When to Use This Workflow

**ALWAYS use for:**
- New features or significant changes
- Bug fixes requiring testing
- Refactoring touching multiple files
- Anything that benefits from code review
- **Any work on Linear issues**

**Can skip ONLY for:**
- Trivial typo fixes in documentation
- Emergency hotfixes explicitly requested by user

### Automation in Place

- **Git Hook**: Blocks commits to `main` (`.git/hooks/pre-commit`)
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
