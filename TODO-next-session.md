# QuillStack - Next Session TODO

Priority tasks identified from codebase analysis. Work through these in order.

---

## COMPLETED (2025-12-31)

### 1. ~~Fix Contact Integration~~ ✓
ContactDetailView already had proper error handling. Contact identifier storage requires Core Data model update (deferred).

### 2. ~~Add Error Handling - ReminderDetailView~~ ✓
Replaced `try?` at line 228 with do/catch + alert.

### 3. ~~Add Error Handling - ShoppingDetailView~~ ✓
Replaced `try?` at line 300 with do/catch + alert.

### 4. ~~Add Error Handling - ExpenseDetailView~~ ✓
Replaced `try?` at line 562 with do/catch + alert.

### 5. ~~Permission Denied Handling - Calendar~~ ✓
Updated EventDetailView with:
- "Open Settings" button in alert when access denied
- Disabled "Add to Calendar" button when permission denied
- Fixed additional `try?` instances

### 6. ~~Permission Denied Handling - Reminders~~ ✓
Updated ReminderDetailView's ExportToRemindersSheet with:
- "Open Settings" button when access denied
- Proper error state management
- ShoppingDetailView already had proper handling

### 7. ~~Add Unit Tests for TextClassifier~~ ✓
Created `Tests/TextClassifierTests.swift` with comprehensive tests:
- All 11 note type exact triggers
- Case insensitivity tests
- Fuzzy OCR matching tests
- Edge cases (empty, no hashtag, multiple hashtags)
- Content analysis fallback tests
- extractTriggerTag() tests
- extractAllTriggerTags() tests

### 8. ~~Replace Debug Prints with OSLog~~ ✓
MeetingDetailView now uses `Logger(subsystem: "com.quillstack", category: "Meeting")` for all logging.

### 9. ~~Fix Recipe Scaling Bug~~ ✓
Updated `RecipeDetailView.swift`:
- Expanded fractionMap with ⅛, ⅜, ⅝, ⅞ Unicode fractions and text equivalents
- Improved `formatQuantity()` to output mixed numbers (e.g., 1.5 → "1½", 2.75 → "2¾")
- Updated `looksLikeIngredient()` with additional fraction patterns
- Unit conversions deferred to future enhancement

### 10. ~~Improve Email Detail View~~ ✓
Updated `EmailDetailView.swift`:
- Added CC/BCC fields with toggle visibility ("Add Cc/Bcc" button)
- Email validation with visual indicators (green checkmark/red exclamation)
- Multiple recipients support via comma separation
- Updated MailComposerView and mailto: fallback with CC/BCC
- Updated saveChanges()/parseEmailContent() to persist CC/BCC

---

## ARCHITECTURE REFACTORING

See `TODO-architecture-refactor.md` for full details.

### Phase 1: Quick Wins ✅ (2026-01-01)
- NoteType enum, DetailViewFactory, OCRServiceProtocol

### Phase 2: Service Layer Protocols ✅ (2026-01-01)
- TextClassifierProtocol, LLMServiceProtocol, CalendarServiceProtocol, RemindersServiceProtocol
- DependencyContainer for centralized service management
- All 5 major services now testable via protocol abstraction

### Phase 3: Detail View Abstraction (Next)
- NoteDetailViewProtocol
- DetailBottomBar shared component

---

## REMAINING TASKS

### FUTURE ENHANCEMENTS

#### 11. Store Contact Identifier
**Requires:** Core Data model update

Add `savedContactIdentifier` property to Note entity to track saved contacts for future reference/updates.

---

## INTEGRATION STATUS REFERENCE

| Note Type | Integration | Status |
|-----------|-------------|--------|
| Event | Calendar (EventKit) | ✓ Functional with permission handling |
| Reminder | Reminders (EventKit) | ✓ Functional with permission handling |
| Contact | Contacts (CNContact) | ✓ Functional (identifier linking deferred) |
| Email | Mail | ✓ Functional with CC/BCC, validation |
| Shopping | Reminders export | ✓ Functional with permission handling |
| Recipe | Reminders export | ✓ Functional with improved scaling |
| Meeting | Calendar | ✓ Functional |
| Idea | Claude API | Partial |
| GitHub Issue | GitHub API | OAuth incomplete |
| Expense | CSV export | ✓ Functional |

---

*Updated 2026-01-01 by Claude Code (Phase 2 architecture complete)*
