# QUI-21 Review: AI Action System

**Reviewer:** Cursor AI  
**Date:** 2026-01-03  
**Status:** Comprehensive Architecture Review

---

## Executive Summary

The proposal is well-structured and aligns with existing architecture patterns. However, several critical gaps need addressing before implementation, particularly around Core Data migration, action lifecycle management, and protocol alignment. The existing `NoteAction.swift` suggests Phase A has started, which is good.

**Overall Assessment:** ✅ **Solid foundation, needs refinement before implementation**

---

## ✅ Strengths

1. **Architecture Alignment**: The separation of `ActionTriggerParser` (pre-processing) from `LLMIntegrationProvider` (execution) is excellent and matches your existing `TextClassifier` pattern.

2. **Integration with Existing Systems**: Good use of `NoteEventBus`, `IntegrationProvider` protocol, and existing `LLMService`.

3. **Phased Approach**: Breaking into phases (A-F) is smart for managing complexity.

4. **Document Type Classification**: The orthogonal `DocumentType` vs `NoteType` distinction is well thought out.

5. **Trigger Hierarchy**: The three-tier trigger system (#action#, #action: param#, @Claude:) provides good flexibility.

---

## 🔴 Critical Issues (Must Fix Before Implementation)

### 1. Core Data Migration Plan Missing

**Problem**: Adding `documentType`, `actionsData`, and `actionResultsData` to `Note` entity requires explicit migration strategy.

**Current State**: 
- `CoreDataStack.swift` has lightweight migration enabled
- But new optional fields need default values
- Legacy notes need handling

**Recommendation**:
```swift
// In Note entity (xcdatamodel):
- documentType: String? (optional, default: nil)
- actionsData: Data? (optional, default: nil) 
- actionResultsData: Data? (optional, default: nil)

// Migration strategy:
// 1. Lightweight migration should work (optional fields)
// 2. Add computed properties for type safety:
extension Note {
    var documentTypeEnum: DocumentType? {
        get { documentType.flatMap(DocumentType.init(rawValue:)) }
        set { documentType = newValue?.rawValue }
    }
    
    var actions: [NoteAction] {
        get {
            guard let data = actionsData else { return [] }
            return (try? JSONDecoder().decode([NoteAction].self, from: data)) ?? []
        }
        set {
            actionsData = try? JSONEncoder().encode(newValue)
        }
    }
}
```

**Action Items**:
- [ ] Document migration plan in issue
- [ ] Test migration on existing database
- [ ] Add default values for all new fields
- [ ] Handle legacy notes (no actions = empty array)

---

### 2. Action Lifecycle Persistence Undefined

**Problem**: `NoteAction.status` and `ActionResult` are stored, but there's no guidance on:
- How states sync with `NoteEventBus`
- How actions survive app relaunches
- How to prevent duplicate execution
- Retry logic for failed actions

**Current State**:
- `NoteAction.swift` exists with status enum (pending, executing, completed, etc.)
- `NoteEventBus` exists but no action events defined yet

**Recommendation**:
```swift
// Add to NoteEvent.swift:
enum NoteEvent {
    // ... existing events ...
    
    // Action events
    case actionQueued(noteId: UUID, actionId: UUID, actionType: ActionType)
    case actionStarted(noteId: UUID, actionId: UUID)
    case actionCompleted(noteId: UUID, actionId: UUID, result: ActionResult)
    case actionFailed(noteId: UUID, actionId: UUID, error: Error)
    case actionCancelled(noteId: UUID, actionId: UUID)
}

// ActionProcessor should:
// 1. Load pending actions on app launch
// 2. Check status before execution (prevent duplicates)
// 3. Emit events at each state transition
// 4. Persist status changes immediately
```

**State Diagram Needed**:
```
pending → awaitingConfirmation → executing → completed
                              ↓
                         cancelled
                              ↓
                         failed → (retry?) → pending
```

**Action Items**:
- [ ] Define state transition rules
- [ ] Add retry logic specification
- [ ] Document duplicate prevention (use action ID + status check)
- [ ] Specify when actions are loaded on app launch

---

### 3. Protocol Mismatch: IntegrationProvider vs ActionProvider

**Problem**: The proposal references `IntegrationProvider` for actions, but existing `IntegrationProvider` protocol is for **export/sync/import**, not actions.

**Current State**:
- `IntegrationProvider` protocol exists in `Services/Integration/IntegrationProvider.swift`
- It has `canExport`, `canSync`, `canImport` capabilities
- No action execution methods

**Recommendation**: Create a **separate protocol** for actions:

```swift
// New: ActionProvider.swift
protocol ActionProvider: Identifiable, Sendable {
    var id: String { get }
    var name: String { get }
    var supportedActions: [ActionType] { get }
    var requiresConfirmation: Bool { get }
    
    func execute(_ action: NoteAction, context: String) async throws -> ActionResult
}

// LLMIntegrationProvider implements ActionProvider
// MailIntegrationProvider implements ActionProvider
// CalendarIntegration extends existing + implements ActionProvider
```

**Why Separate?**
- `IntegrationProvider` = external service integration (export/sync)
- `ActionProvider` = action execution (summarize, email, calendar)
- Different concerns, different protocols

**Action Items**:
- [ ] Create `ActionProvider` protocol (separate from `IntegrationProvider`)
- [ ] Update proposal to use `ActionProvider` instead
- [ ] Clarify relationship: can a provider implement both?

---

### 4. Trigger Scope Ambiguity

**Problem**: Divider-based scope (`---`) and multiple triggers need deterministic parsing rules.

**Current State**:
- `TextClassifier` has `splitIntoSections()` method
- But it's for note type classification, not action triggers
- No clear rules for action scope resolution

**Recommendation**:
```swift
// ActionTriggerParser should:
// 1. Find all triggers in content
// 2. For each trigger, determine scope:
//    - If trigger is before first "---" → .wholeNote
//    - If trigger is after "---" → .beforeDivider (content above divider)
//    - Multiple triggers → each gets its own scope independently
// 3. Handle edge cases:
//    - Multiple "---" dividers → use first one
//    - Trigger on same line as "---" → ambiguous, default to .wholeNote
//    - No content before divider → .wholeNote
```

**Test Cases Needed**:
```swift
// Test 1: Trigger before divider
"#summarize#\nContent here\n---\nMore content"
// → Scope: .wholeNote

// Test 2: Trigger after divider  
"Content here\n---\n#summarize#\nMore content"
// → Scope: .beforeDivider

// Test 3: Multiple triggers
"#summarize#\nContent\n---\n#analyze#\nMore"
// → Two actions: [.wholeNote, .beforeDivider]

// Test 4: No divider
"#summarize#\nContent"
// → Scope: .wholeNote
```

**Action Items**:
- [ ] Document scope resolution rules explicitly
- [ ] Add unit tests for edge cases
- [ ] Handle OCR noise (misread "---" as "---" variations)

---

### 5. Document Classifier Inputs Unclear

**Problem**: Detection references "layout signals" but doesn't specify if OCR text alone is sufficient or if Vision geometry is required.

**Current State**:
- `OCRService` returns `OCRResult` with text and confidence
- No geometry/layout information exposed currently

**Recommendation**:
```swift
// Option A: Text-only detection (simpler, MVP)
struct DocumentClassifier {
    func classify(content: String) -> DocumentType {
        // Use keyword patterns, regex
        // Example: "Total: $X.XX" → receipt
        // "Name:" + "Phone:" + "Email:" → business card
    }
}

// Option B: Vision geometry (more accurate, Phase D+)
struct DocumentClassifier {
    func classify(ocrResult: OCRResult, geometry: VNTextObservation?) -> DocumentType {
        // Use text + layout (columns, alignment, spacing)
        // More accurate but requires OCRService changes
    }
}
```

**Recommendation**: Start with **Option A** (text-only) for Phase D, add geometry later if needed.

**Action Items**:
- [ ] Document detection patterns per `DocumentType`
- [ ] Specify if Vision geometry is required (or deferred)
- [ ] Create test cases with sample OCR text

---

### 6. Provider Coverage Gaps

**Problem**: Actions like `createContact`, `setReminder`, `buildSchedule` reference providers that don't exist yet.

**Current State**:
- `CalendarService` exists (likely)
- `RemindersService` exists (likely)
- No `ContactsIntegrationProvider` visible
- No action execution methods on existing services

**Recommendation**: **Constrain Phase A to LLM-only actions**

```swift
// Phase A: LLM-only actions
ActionType: .summarize, .analyze, .ask, .research, .proofread, 
            .expand, .translate, .generateQuestions, .extractKeyPoints

// Phase E: Add integration actions
ActionType: .email, .addToCalendar, .setReminder, .createContact
```

**Action Items**:
- [ ] Update Phase A scope to LLM-only
- [ ] Document which providers exist vs need creation
- [ ] Sequence provider rollout in phases

---

### 7. Confirmation UX Unspecified

**Problem**: Sensitive providers require confirmation, but no UI flow is defined.

**Recommendation**:
```swift
// ActionProcessor flow:
// 1. Parse triggers → create NoteAction[]
// 2. For each action:
//    - If requiresConfirmation → set status = .awaitingConfirmation
//    - Show ActionConfirmationView
//    - User approves → status = .executing
//    - User rejects → status = .cancelled
// 3. Execute approved actions
```

**UI Flow**:
```
Post-capture → ActionPickerSheet (if document detected)
              ↓
         User selects actions
              ↓
    ActionConfirmationView (for sensitive actions)
              ↓
    User approves/rejects
              ↓
    ActionProcessor executes
              ↓
    Results displayed in note
```

**Action Items**:
- [ ] Design `ActionConfirmationView` UI
- [ ] Specify when confirmations appear (per action? batched?)
- [ ] Define confirmation data structure

---

## 🟡 Medium Priority Issues

### 8. ActionTriggerParser Execution Timing

**Question**: Does `ActionTriggerParser` run every time note content changes, or only once during OCR ingestion?

**Recommendation**: 
- **Initial**: Run once during OCR ingestion (after `TextClassifier`)
- **Future**: Re-run on manual content edits (user types new trigger)

**Action Items**:
- [ ] Document execution timing
- [ ] Add hook in `CameraViewModel.processImage()` after OCR
- [ ] Consider re-parsing on note edit

---

### 9. Multiple Extended Prompts Handling

**Question**: Should multiple `@Claude:` lines concatenate into one action or run separately?

**Recommendation**: **Run separately** (more flexible)

```swift
// Input:
"@Claude: summarize this\nContent\n@Claude: what are the risks?"

// Output: Two separate actions
// Action 1: .ask with prompt "summarize this"
// Action 2: .ask with prompt "what are the risks?"
```

**Action Items**:
- [ ] Document this behavior
- [ ] Add test case

---

### 10. Document-Type Suggestions Behavior

**Question**: Are document-type suggestions optional hints, or auto-queued actions pending confirmation?

**Recommendation**: **Optional hints** (user chooses)

```swift
// Flow:
1. DocumentClassifier detects "receipt"
2. Show ActionPickerSheet with suggested actions pre-selected
3. User can:
   - Accept suggestions → actions queued
   - Modify selections → custom actions queued
   - Dismiss → no actions
```

**Action Items**:
- [ ] Document this behavior
- [ ] Design ActionPickerSheet UI

---

## 🟢 Low Priority / Nice to Have

### 11. Rate Limiting for LLM Actions

**Consideration**: Add rate limiting to prevent cost overruns.

**Recommendation**: Use existing `OfflineQueueService` pattern, add rate limiter.

---

### 12. Offline Queueing

**Consideration**: Queue actions when offline, execute when online.

**Recommendation**: Leverage existing `OfflineQueueService` for action queueing.

---

## 📋 Implementation Recommendations

### Phase A Refinement

1. **Start with LLM-only actions** (remove integration actions for now)
2. **Add Core Data migration plan** before coding
3. **Create ActionProvider protocol** (separate from IntegrationProvider)
4. **Define state machine** for action lifecycle
5. **Add unit tests** for `ActionTriggerParser` scope resolution

### Suggested File Structure

```
Models/
  - ActionType.swift ✅ (exists)
  - NoteAction.swift ✅ (exists)
  - DocumentType.swift (new)
  - ActionResult.swift (extend existing)

Services/
  - ActionTriggerParser.swift (new)
  - DocumentClassifier.swift (new)
  - ActionProcessor.swift (new)
  - Actions/
    - LLMActionProvider.swift (new, implements ActionProvider)
    - MailActionProvider.swift (Phase E)
    - CalendarActionProvider.swift (Phase E)

Services/Integration/
  - ActionProvider.swift (new protocol)
  - ActionProviderRegistry.swift (new, similar to IntegrationRegistry)
```

### Integration Points

1. **After OCR in CameraViewModel**:
```swift
// In CameraViewModel.processImage(), after OCR:
let actions = actionTriggerParser.parse(content: ocrText)
if !actions.isEmpty {
    actionProcessor.queue(actions: actions, for: noteId)
}
```

2. **NoteEventBus Events**:
```swift
// Add action events to NoteEvent enum
// ActionProcessor emits events at each state transition
```

3. **LLMService Integration**:
```swift
// LLMActionProvider uses existing LLMService methods
// May need new methods: summarize(), analyze(), etc.
```

---

## ✅ What's Already Good

1. **NoteAction.swift exists** - Good foundation
2. **ActionType enum exists** - Well defined
3. **Architecture separation** - Parser vs Provider is correct
4. **Event bus integration** - Good use of existing system
5. **Phased approach** - Manageable complexity

---

## 🎯 Next Steps

1. **Address Critical Issues** (1-7) before starting implementation
2. **Create migration plan** document
3. **Define ActionProvider protocol** (separate from IntegrationProvider)
4. **Write state machine diagram** for action lifecycle
5. **Add unit tests** for trigger parsing edge cases
6. **Update proposal** with clarifications

---

## Questions for Discussion

1. Should `ActionProvider` be separate from `IntegrationProvider`, or extend it?
2. Should actions execute immediately after OCR, or wait for user trigger?
3. How should action results be displayed? (New view? Inline in note?)
4. Should failed actions auto-retry, or require manual retry?
5. Should action history be preserved permanently, or cleaned up after X days?

---

**Overall**: The proposal is solid but needs these clarifications before implementation. The existing `NoteAction.swift` suggests good progress on Phase A. Focus on migration plan and protocol design before proceeding.

