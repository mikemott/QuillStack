# QuillStack

A SwiftUI iOS app for capturing handwritten notes via camera, performing OCR, and organizing them by type.

**Target:** iOS 26.2+ | **Swift:** 6.0 | **Xcode:** 26.1+

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
│   │   ├── CameraView.swift
│   │   ├── CameraPreviewView.swift
│   │   └── ImagePreviewView.swift
│   ├── Notes/              # Note list and detail views
│   │   ├── NoteListView.swift
│   │   ├── NoteDetailView.swift    # General notes with confidence highlighting
│   │   ├── TodoDetailView.swift    # Checkable task list view
│   │   └── EmailDetailView.swift   # Email draft with To/Subject/Body
│   ├── Meetings/
│   │   └── MeetingListView.swift
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
│   ├── SpellCorrector.swift  # Spell correction utilities
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
   - Uses `VNRecognizeTextRequestRevision3` (iOS 26+)
   - Language correction enabled with custom vocabulary support
   - Per-word confidence tracking with alternatives
   - Multiple preprocessing variants for optimal recognition
   - Parallel image processing via `withThrowingTaskGroup`

2. **LLM Post-Processing**
   - Claude API integration for OCR cleanup (claude-sonnet-4-20250514)
   - User provides API key in Settings
   - "Enhance" button in note detail view
   - Async/await network calls via URLSession

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
- `SpellCorrector.swift` - Domain-specific spell correction utilities

## Custom Colors (Extensions.swift)

- `.forestDark`, `.forestMedium`, `.forestLight` - Green theme colors
- `.creamLight`, `.paperBeige`, `.paperTan` - Background colors
- `.textDark`, `.textMedium`, `.textLight` - Text colors
- `.badgeTodo`, `.badgeMeeting`, `.badgeGeneral`, `.badgeEmail` - Type badges

## Custom Fonts

Serif fonts via `Font.serifBody()`, `Font.serifHeadline()`, `Font.serifCaption()`.

## Swift 6 Concurrency Patterns

The codebase uses modern Swift 6 concurrency throughout:

### Actor Isolation
- **@MainActor** - Applied to all ViewModels and CameraManager for UI thread safety
- **Default Actor Isolation** - Build setting `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
- **nonisolated(unsafe)** - Used sparingly for AVCaptureSession interop (review for strict concurrency)

### Async/Await Usage
```swift
// OCRService - async text recognition
func recognizeTextWithConfidence(from image: UIImage) async throws -> OCRResult

// LLMService - async API calls
func enhanceOCRText(_ text: String, context: String?) async throws -> String

// CameraViewModel - async image processing
func processImage(_ image: UIImage) async
```

### Task Groups
- `withThrowingTaskGroup` for parallel OCR preprocessing variants
- `Task { @MainActor in }` for UI updates from background work
- `Task.detached` for background OCR operations

### Observation
- **@Observable** macro for CameraManager and CameraViewModel
- **@ObservedObject** retained for Core Data NSManagedObject entities
- **Combine** used for Core Data change notifications (consider migrating to async sequences)

## Architecture Patterns

### MVVM Structure
- **Models**: Core Data entities (Note, TodoItem, Meeting)
- **Views**: SwiftUI views with @State, @Environment
- **ViewModels**: @MainActor classes with @Published properties

### Service Layer
| Service | Responsibility |
|---------|---------------|
| `OCRService` | Vision framework abstraction, preprocessing |
| `LLMService` | Claude API integration |
| `CameraManager` | AVFoundation session management |
| `ImageProcessor` | Core Image filter pipeline |
| `TextClassifier` | Note type detection logic |
| `SpellCorrector` | Domain-specific corrections |

### Dependency Management
- Singleton pattern: `CoreDataStack.shared`, `LLMService.shared`, `SettingsManager.shared`
- Environment injection for managed object context

## Build Notes

- Requires iOS 26.2+ for latest Vision OCR and Swift 6 features
- Camera usage requires physical device (not simulator)
- Core Data model: `QuillStack.xcdatamodeld`
- If xcodebuild fails, run: `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`

### Build Settings
```
IPHONEOS_DEPLOYMENT_TARGET = 26.2
SWIFT_VERSION = 6.0
SWIFT_APPROACHABLE_CONCURRENCY = YES
SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor
SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES
```

## Security Notes

- **API Key Storage**: Currently in UserDefaults (migrate to Keychain for production)
- **File Protection**: Core Data store uses `.complete` file protection
- **Network**: Standard URLSession (consider certificate pinning for production)

## Known Modernization Opportunities

1. **UIGraphicsContext** - Legacy usage in Extensions.swift, ImageProcessor.swift; migrate to `ImageRenderer`
2. **nonisolated(unsafe)** - Review for Swift 6 strict concurrency mode
3. **Combine observations** - Consider migrating to async sequences
4. **Core Data queries** - Consider @FetchRequest for simpler view integration

## Recent Changes

- Updated to iOS 26.2 deployment target
- Swift 6 concurrency patterns throughout
- @Observable macro for ViewModels
- Added Settings tab with Claude API key entry
- Implemented word-level OCR confidence tracking
- Created ConfidenceTextView for highlighting uncertain words
- Added AI enhancement feature (requires API key)
- Note types route to specialized detail views
