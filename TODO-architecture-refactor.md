# Architecture Refactoring Plan

**Full plan:** `~/.claude/plans/encapsulated-tumbling-cupcake.md`

## Quick Summary

Transform QuillStack from tight coupling to integration-ready architecture.

## Phase 1: Quick Wins ✅ COMPLETED (2026-01-01)

### 1.1 Detail View Factory ✅
- Created `Services/DetailViewFactory.swift` with registration pattern
- Updated `NoteListView.swift` to use `DetailViewFactory.makeView(for:)`

### 1.2 NoteType Enum ✅
- Created `Models/NoteType.swift` with `displayName`, `icon`, `badgeColor`, `footerIcon`
- Added `Note.type` computed property
- Updated `NoteCardView` to use `note.type.icon`, `note.type.badgeColor`, etc.
- Removed duplicate enum from `TextClassifier.swift`

### 1.3 OCR Service Protocol ✅
- Created `Services/Protocols/OCRServiceProtocol.swift`
- Updated `OCRService` to conform to protocol
- Updated `CameraViewModel` with dependency injection (accepts `OCRServiceProtocol`)

## Phase 2: Service Layer Protocols ✅ COMPLETED (2026-01-01)

### 2.1 TextClassifierProtocol ✅
- Created `Services/Protocols/TextClassifierProtocol.swift`
- Updated `TextClassifier` to conform (final class, Sendable)
- Updated `CameraViewModel` with dependency injection

### 2.2 LLMServiceProtocol ✅
- Created `Services/Protocols/LLMServiceProtocol.swift`
- Covers: `enhanceOCRText`, `extractMeetingDetails`, `summarizeNote`, `expandIdea`, `validateAPIKey`, `performRequest`
- Updated `LLMService` to conform (Sendable)

### 2.3 CalendarServiceProtocol ✅
- Created `Services/Protocols/CalendarServiceProtocol.swift`
- Updated `CalendarService` to conform (final class, Sendable)

### 2.4 RemindersServiceProtocol ✅
- Created `Services/Protocols/RemindersServiceProtocol.swift`
- Updated `RemindersService` to conform (final class, Sendable)

### 2.5 DependencyContainer ✅
- Created `App/DependencyContainer.swift`
- Manages: OCR, TextClassifier, LLM, Calendar, Reminders services
- Supports full DI for testing via optional parameters
- Provides convenience method `makeCameraViewModel()`

## Phase 3: Detail View Abstraction ✅ COMPLETED (2026-01-01)

### 3.1 NoteDetailViewProtocol ✅
- Created `Views/Notes/NoteDetailViewProtocol.swift`
- Defines common interface: `note`, `saveChanges()`, `copyToClipboard()`, `shareContent()`
- Default implementations for `copyToClipboard()`, `shareContent()`, `shareableContent`
- All 12 detail views conform to protocol

### 3.2 DetailBottomBar Component ✅
- Created `Views/Components/DetailBottomBar.swift`
- Reusable bottom toolbar with AI menu, export, share, copy buttons
- Supports custom `DetailAction` for type-specific actions
- Primary action styling with gradient background
- Helper methods: `standardAIActions()`, `summarizeOnlyAIActions()`

### 3.3 View Migrations ✅
- TodoDetailView: Uses DetailBottomBar with summarize AI action
- EmailDetailView: Uses DetailBottomBar with "Open in Mail" primary action
- All other views: Conform to NoteDetailViewProtocol with saveChanges()

### 3.4 Unit Tests (Partial)
- Created `Tests/DetailBottomBarTests.swift`
- Created `Tests/NoteDetailViewProtocolTests.swift`
- Note: Xcode test target needs to be configured

## Phase 4: Long-Term ✅ COMPLETED (2026-01-01)

### 4.1 IntegrationProvider System ✅
- Created `Services/Integration/IntegrationProvider.swift`
- Protocols: `IntegrationProvider`, `ExportableProvider`, `SyncableProvider`, `ImportableProvider`
- Supporting types: `ExportResult`, `SyncResult`, `RemoteChange`, `ImportedNoteData`
- Created `Services/Integration/IntegrationRegistry.swift` for provider management
- Updated `DependencyContainer` with IntegrationRegistry access

### 4.2 NoteEventBus ✅
- Created `Services/Events/NoteEvent.swift` with event types
- Event categories: lifecycle, processing, integration, error
- Created `Services/Events/NoteEventBus.swift` for publish/subscribe
- Features: filtered subscriptions, event history, Combine publisher

### 4.3 Structured Tags ✅
- Added `Tag` entity to Core Data model with relationships
- Created `Models/Tag.swift` with Core Data accessors
- Added `Note.tagEntities` many-to-many relationship
- Created `Services/TagMigrationService.swift` for data migration

### 4.4 Plugin Architecture (Future)
- Deferred to future release
- Protocol design documented in Linear (QUI-18)

## Files Created (Phases 1-4)

```
Services/
├── DetailViewFactory.swift               ✅ Phase 1
├── Protocols/
│   ├── OCRServiceProtocol.swift          ✅ Phase 1
│   ├── TextClassifierProtocol.swift      ✅ Phase 2
│   ├── LLMServiceProtocol.swift          ✅ Phase 2
│   ├── CalendarServiceProtocol.swift     ✅ Phase 2
│   └── RemindersServiceProtocol.swift    ✅ Phase 2
├── Integration/
│   ├── IntegrationProvider.swift         ✅ Phase 4
│   └── IntegrationRegistry.swift         ✅ Phase 4
├── Events/
│   ├── NoteEvent.swift                   ✅ Phase 4
│   └── NoteEventBus.swift                ✅ Phase 4
├── TagMigrationService.swift             ✅ Phase 4
Models/
├── NoteType.swift                        ✅ Phase 1
├── Tag.swift                             ✅ Phase 4
App/
├── DependencyContainer.swift             ✅ Phase 2
Views/
├── Notes/NoteDetailViewProtocol.swift    ✅ Phase 3
├── Components/DetailBottomBar.swift      ✅ Phase 3
Tests/
├── DetailBottomBarTests.swift            ✅ Phase 3
├── NoteDetailViewProtocolTests.swift     ✅ Phase 3
```

## Files Modified (Phases 1-4)

```
Services/OCRService.swift            ✅ Phase 1: Conforms to OCRServiceProtocol
Services/TextClassifier.swift        ✅ Phase 1: Removed duplicate NoteType enum
                                     ✅ Phase 2: Conforms to TextClassifierProtocol (final, Sendable)
Services/LLMService.swift            ✅ Phase 2: Conforms to LLMServiceProtocol (Sendable)
Services/CalendarService.swift       ✅ Phase 2: Conforms to CalendarServiceProtocol (final, Sendable)
Services/RemindersService.swift      ✅ Phase 2: Conforms to RemindersServiceProtocol (final, Sendable)
ViewModels/CameraViewModel.swift     ✅ Phase 1: Accepts OCRServiceProtocol via DI
                                     ✅ Phase 2: Accepts TextClassifierProtocol via DI
Views/Notes/NoteListView.swift       ✅ Phase 1: Uses DetailViewFactory.makeView(for:)
Views/Notes/NoteCardView             ✅ Phase 1: Uses note.type.icon, .badgeColor, .footerIcon

Views/Notes/TodoDetailView.swift     ✅ Phase 3: Conforms to NoteDetailViewProtocol, uses DetailBottomBar
Views/Notes/EmailDetailView.swift    ✅ Phase 3: Conforms to NoteDetailViewProtocol, uses DetailBottomBar
Views/Notes/NoteDetailView.swift     ✅ Phase 3: Conforms to NoteDetailViewProtocol
Views/Notes/MeetingDetailView.swift  ✅ Phase 3: Conforms to NoteDetailViewProtocol
Views/Notes/ReminderDetailView.swift ✅ Phase 3: Conforms to NoteDetailViewProtocol
Views/Notes/ContactDetailView.swift  ✅ Phase 3: Conforms to NoteDetailViewProtocol
Views/Notes/ExpenseDetailView.swift  ✅ Phase 3: Conforms to NoteDetailViewProtocol
Views/Notes/ShoppingDetailView.swift ✅ Phase 3: Conforms to NoteDetailViewProtocol
Views/Notes/RecipeDetailView.swift   ✅ Phase 3: Conforms to NoteDetailViewProtocol
Views/Notes/EventDetailView.swift    ✅ Phase 3: Conforms to NoteDetailViewProtocol
Views/Notes/IdeaDetailView.swift     ✅ Phase 3: Conforms to NoteDetailViewProtocol

App/DependencyContainer.swift        ✅ Phase 4: Added IntegrationRegistry access
Models/Note.swift                    ✅ Phase 4: Added tagEntities relationship (via Tag.swift extension)
Models/QuillStack.xcdatamodeld       ✅ Phase 4: Added Tag entity with Note relationship
```

## Success Metrics

### Phase 1 Results (Achieved)

| Metric | Before | After Phase 1 |
|--------|--------|---------------|
| Detail view routing | 25-line switch | 1-line factory call |
| Badge/icon code | 3 switches × 12 cases | NoteType computed properties |
| OCR service testability | Direct instantiation | Protocol + DI |

### Phase 2 Results (Achieved)

| Metric | Before | After Phase 2 |
|--------|--------|---------------|
| Testable services | 1 (OCR) | 5 (OCR, TextClassifier, LLM, Calendar, Reminders) |
| Service instantiation | 5 scattered `.shared` | 1 DependencyContainer |
| CameraViewModel DI | 1 protocol param | 2 protocol params |
| Service thread-safety | Mixed | All `Sendable` conforming |

### Phase 3 Results (Achieved)

| Metric | Before | After Phase 3 |
|--------|--------|---------------|
| Protocol conformance | 0 detail views | 12 detail views |
| Bottom bar code | ~60 lines × 12 views | Shared DetailBottomBar component |
| Copy/share implementation | Duplicated in each view | Default protocol implementations |
| Common interface | None | NoteDetailViewProtocol |

### Phase 4 Results (Achieved)

| Metric | Before | After Phase 4 |
|--------|--------|---------------|
| Integration extensibility | Hard-coded exports | IntegrationProvider protocol system |
| Event-driven decoupling | Direct method calls | NoteEventBus pub/sub |
| Tag data model | Comma-separated strings | Core Data Tag entity with relationships |
| Tag migration | Manual | Automatic TagMigrationService |
| Integration registry | None | Central IntegrationRegistry |

### Target (All Phases)

| Metric | Before | After |
|--------|--------|-------|
| Lines to add note type | 50+ | 5 |
| Lines to add integration | 400+ | 200 |
| Testable services | 1 | All ✅ (achieved in Phase 2) |
| Detail view protocol | None | All 12 views ✅ (achieved in Phase 3) |

## Next Steps

- [ ] Configure Xcode test target (QUI-19)
- [ ] Add unit tests for Phase 4 components
- [ ] Implement concrete IntegrationProvider (e.g., NotesAppProvider)
- [ ] Wire up NoteEventBus in app lifecycle
- [ ] Create TagManagementView for tag CRUD operations
