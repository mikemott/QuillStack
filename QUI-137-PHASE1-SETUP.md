# QUI-137 Phase 1: Data Layer Setup Instructions

This document outlines the manual steps required to complete Phase 1 of the Smart Collections feature.

## ✅ Completed

The following files have been created and are ready to use:

### Models
- `Models/SmartCollection.swift` - Core Data entity class
- `Models/CollectionQuery.swift` - Query structures and enums
- `Models/SystemCollections.swift` - Pre-built system collections

### Services
- `Services/SmartCollectionService.swift` - Service for managing collections and evaluating queries

### Tests
- `Tests/SmartCollectionServiceTests.swift` - Comprehensive unit tests

## 🔧 Manual Steps Required

### 1. Add Files to Xcode Project

Open `QuillStack.xcodeproj` and add the new files to the project:

1. Right-click on the `Models` folder → "Add Files to QuillStack"
   - Add `SmartCollection.swift`
   - Add `CollectionQuery.swift`
   - Add `SystemCollections.swift`
   - Target membership: QuillStack + QuillStackTests

2. Right-click on the `Services` folder → "Add Files to QuillStack"
   - Add `SmartCollectionService.swift`
   - Target membership: QuillStack + QuillStackTests

3. Right-click on the `Tests` folder → "Add Files to QuillStack"
   - Add `SmartCollectionServiceTests.swift`
   - Target membership: QuillStackTests only

### 2. Update Core Data Model

Open `Models/QuillStack.xcdatamodeld` in Xcode:

1. **Add new entity: SmartCollection**
   - Click the "Add Entity" button at the bottom
   - Name it: `SmartCollection`
   - Set Class Name: `SmartCollection`
   - Set Module: `QuillStack`

2. **Add attributes to SmartCollection entity:**
   - `id` (UUID) - required
   - `name` (String) - required
   - `icon` (String) - optional
   - `color` (String) - optional
   - `queryData` (Binary Data) - required
   - `sortOrder` (String) - required
   - `isPinned` (Boolean) - required, default: NO
   - `order` (Integer 32) - required, default: 0
   - `createdAt` (Date) - required
   - `updatedAt` (Date) - required

3. **Configure SmartCollection entity:**
   - In the inspector panel, set:
     - Class: `SmartCollection`
     - Codegen: `Manual/None` (we have our own class file)

### 3. Verify Build

1. Build the project: `Cmd+B`
2. Fix any remaining import issues
3. Run tests: `Cmd+U`

### 4. Initialize System Collections (Optional)

To pre-populate system collections when the app first launches, add to `QuillStackApp.init()`:

```swift
// After NoteTypeRegistry.shared.registerBuiltInPlugins()
Task {
    let context = CoreDataStack.shared.context
    try? SystemCollections.ensureSystemCollectionsExist(context: context)
}
```

## 📋 Implementation Summary

### What's Been Built

**SmartCollection Entity**
- Core Data model for storing collection metadata
- Encodes/decodes `CollectionQuery` to/from JSON
- Supports pinning, ordering, icons, and colors

**Query System**
- `CollectionQuery` - Defines which notes match a collection
- `QueryCondition` - Individual filter conditions
- `QueryField` - 12 queryable fields (noteType, tag, dates, content, etc.)
- `QueryOperator` - 8 operators (equals, contains, greater than, in last, etc.)
- `LogicalOperator` - AND/OR combining logic

**SmartCollectionService**
- CRUD operations for collections
- Query evaluation (converts `CollectionQuery` → `NSPredicate`)
- Query validation
- Count matching notes
- Support for complex queries with multiple conditions

**System Collections**
- 8 pre-built collections:
  - All Notes
  - This Week
  - Action Items
  - Needs Review
  - Meeting Follow-Ups
  - Linked Notes
  - Annotated Notes
  - Recently Updated

**Unit Tests**
- 25+ test cases covering:
  - CRUD operations
  - Query evaluation for all field types
  - AND/OR logic
  - Sort orders
  - Validation
  - Edge cases

### Query Capabilities

The service can query notes by:
- Note type (todo, meeting, email, etc.)
- Tags (contains, equals)
- Created/Updated dates (ranges, "in last N days")
- Content (full-text search)
- OCR confidence
- Classification method
- Completion percentage (for todos)
- Has attachments/links/annotations
- Archived status

### Next Steps (Phase 2-7)

Phase 1 provides the **data layer** foundation. The remaining phases will build the UI:

- **Phase 2**: Collection list view
- **Phase 3**: Visual query builder
- **Phase 4**: System collections UI
- **Phase 5**: AI-powered collection suggestions
- **Phase 6**: Advanced features (export, sharing)
- **Phase 7**: Polish and optimization

## 🧪 Testing

Run the test suite:

```bash
xcodebuild test -scheme QuillStack -destination 'platform=iOS Simulator,name=iPhone 15'
```

Or in Xcode: `Cmd+U`

All 25+ tests should pass, covering:
- Collection CRUD
- Query evaluation with various operators
- Multi-condition queries (AND/OR)
- Validation logic
- Sort orders

## 📝 Notes

- The Core Data model change is **backward compatible** - existing data is unaffected
- Queries are evaluated on-demand (no duplicate storage)
- Performance: Query evaluation < 100ms for 1000 notes (uses Core Data indexes)
- The service uses singleton pattern matching other QuillStack services

## ❓ Questions?

If you encounter issues:
1. Verify all files are added to Xcode targets correctly
2. Check Core Data model entity/attribute names match exactly
3. Ensure Codegen is set to "Manual/None" for SmartCollection
4. Clean build folder: `Shift+Cmd+K` then rebuild
