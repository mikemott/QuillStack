# QuillStack

A SwiftUI iOS app for capturing handwritten notes via camera, performing OCR, and organizing them by type.

## Project Structure

```
QuillStack/
├── App/                    # App entry point and main views
│   ├── QuillStackApp.swift
│   └── ContentView.swift   # TabView with Notes, Meetings, Settings
├── Models/
│   ├── Note.swift          # Core Data Note entity
│   ├── TodoItem.swift      # Core Data TodoItem entity
│   ├── Meeting.swift       # Core Data Meeting entity
│   ├── CoreDataStack.swift # Core Data stack management
│   └── QuillStack.xcdatamodeld
├── Views/
│   ├── Capture/            # Camera capture views
│   ├── Notes/              # Note list and detail views
│   │   ├── NoteListView.swift
│   │   ├── NoteDetailView.swift    # General notes with confidence highlighting
│   │   ├── TodoDetailView.swift    # Checkable task list view
│   │   └── EmailDetailView.swift   # Email draft with To/Subject/Body
│   ├── Meetings/
│   ├── Settings/
│   │   └── SettingsView.swift      # API key, OCR settings
│   └── Components/
│       └── ConfidenceTextView.swift # Low-confidence word highlighting
├── ViewModels/
│   ├── CameraViewModel.swift
│   ├── NoteViewModel.swift
│   └── MeetingViewModel.swift
├── Services/
│   ├── OCRService.swift      # Vision framework OCR with word-level confidence
│   ├── LLMService.swift      # Claude API for text enhancement
│   ├── TextClassifier.swift  # Note type detection via triggers
│   ├── TodoParser.swift
│   ├── MeetingParser.swift
│   ├── CameraManager.swift
│   └── ImageProcessor.swift
└── Utilities/
    ├── Constants.swift
    └── Extensions.swift      # Custom colors, fonts
```

## Note Types

Notes are automatically classified based on hashtag triggers in the content:

| Type | Triggers | Detail View | Features |
|------|----------|-------------|----------|
| **Todo** | `#todo#`, `#to-do#`, `#tasks#`, `#task#` | `TodoDetailView` | Checkable tasks, progress bar |
| **Email** | `#email#`, `#mail#` | `EmailDetailView` | Parses To:/Subject:, "Open in Mail" button |
| **Meeting** | `#meeting#`, `#notes#`, `#minutes#` | `NoteDetailView` | Meeting entity with attendees, agenda |
| **General** | (default) | `NoteDetailView` | Standard note view |

Classification happens in `TextClassifier.swift` via `detectExplicitTrigger()`.

## OCR System

### Three-Pronged Accuracy Approach

1. **Apple Vision (Latest)**
   - Uses `VNRecognizeTextRequestRevision3` (iOS 16+)
   - Language correction enabled
   - Per-word confidence tracking with alternatives

2. **LLM Post-Processing**
   - Claude API integration for OCR cleanup
   - User provides API key in Settings
   - "Enhance" button in note detail view

3. **User Correction Flow**
   - Low-confidence words underlined in orange
   - Tap word to see alternatives or type correction
   - Configurable confidence threshold (default 70%)

### Key Files
- `OCRService.swift` - Returns `OCRResult` with `RecognizedWord` array (text, confidence, alternatives)
- `LLMService.swift` - `enhanceOCRText()` calls Claude API
- `SettingsManager` - Stores API key, confidence threshold, highlight toggle
- `ConfidenceTextView.swift` - Displays text with tappable low-confidence words
- `Note.ocrResultData` - Stores encoded `OCRResult` for confidence display

## Custom Colors (Extensions.swift)

- `.forestDark`, `.forestMedium`, `.forestLight` - Green theme colors
- `.creamLight`, `.paperBeige`, `.paperTan` - Background colors
- `.textDark`, `.textMedium`, `.textLight` - Text colors
- `.badgeTodo`, `.badgeMeeting`, `.badgeGeneral`, `.badgeEmail` - Type badges

## Custom Fonts

Serif fonts via `Font.serifBody()`, `Font.serifHeadline()`, `Font.serifCaption()`.

## Build Notes

- Requires iOS 16+ for latest Vision OCR revision
- Camera usage requires physical device (not simulator)
- Core Data model: `QuillStack.xcdatamodeld`
- If xcodebuild fails, run: `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`

## Recent Changes

- Added Settings tab with Claude API key entry
- Implemented word-level OCR confidence tracking
- Created ConfidenceTextView for highlighting uncertain words
- Added AI enhancement feature (requires API key)
- Note types route to specialized detail views
