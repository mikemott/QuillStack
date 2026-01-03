# Sentry Issue #7161938631 - Fix Summary

**Issue:** DB on Main Thread  
**Status:** ✅ **Fixed**  
**Date:** 2026-01-03

---

## Problem

Sentry detected Core Data operations happening on the main thread when users swipe to delete notes:

- **Location**: `_UISwipeActionDynamicButtonView._buttonDidTouchUpInInside`
- **Operation**: Deleting a note via swipe action
- **Warning**: "DB on Main Thread" - Core Data delete/save on main thread
- **Impact**: Can cause UI freezing, especially on slower devices

---

## Root Cause

In `NoteViewModel.swift`, all delete and archive operations were:
1. Running on `@MainActor` (main thread)
2. Calling `context.delete(note)` directly on main thread
3. Calling `saveViewContext()` synchronously on main thread

This violates Core Data best practices - database operations should happen on background threads.

---

## Solution

Moved all Core Data delete/archive operations to background contexts:

### Changes Made

1. **`deleteNote(_:)`** - Now uses background context
2. **`deleteNotes(_:)`** - Now uses background context  
3. **`deleteNotes(at:)`** - Now uses background context
4. **`archiveNote(_:)`** - Now uses background context
5. **`archiveNotes(_:)`** - Now uses background context

### Implementation Pattern

```swift
// Before (main thread - BAD)
context.delete(note)
try CoreDataStack.shared.saveViewContext()

// After (background thread - GOOD)
let backgroundContext = CoreDataStack.shared.newBackgroundContext()
backgroundContext.perform {
    let noteToDelete = try backgroundContext.existingObject(with: note.objectID) as? Note
    if let noteToDelete = noteToDelete {
        backgroundContext.delete(noteToDelete)
        try CoreDataStack.shared.save(context: backgroundContext)
    }
}
```

### Key Features

- ✅ **Optimistic updates**: UI updates immediately (removes from list)
- ✅ **Background operations**: Core Data work happens off main thread
- ✅ **Automatic merging**: Changes merge to main context via `automaticallyMergesChangesFromParent`
- ✅ **Error handling**: Restores notes if delete fails
- ✅ **Thread-safe**: Uses `objectID` to safely reference across contexts

---

## Testing

To verify the fix:

1. **Test swipe to delete**:
   - Swipe left on a note
   - Tap delete
   - Note should disappear immediately
   - No "DB on Main Thread" warning in Sentry

2. **Test bulk delete**:
   - Enter edit mode
   - Select multiple notes
   - Delete
   - All should disappear immediately

3. **Test archive**:
   - Swipe right to archive
   - Note should disappear from list
   - No main thread warnings

4. **Monitor Sentry**:
   - Check for new "DB on Main Thread" warnings
   - Should see zero occurrences after fix

---

## Files Modified

- `ViewModels/NoteViewModel.swift` - All delete/archive methods updated

---

## Performance Impact

- ✅ **Before**: Database operations blocked main thread (UI could freeze)
- ✅ **After**: Database operations on background thread (UI stays responsive)
- ✅ **User experience**: Swipe actions feel instant, no lag

---

## Related Best Practices

This fix follows Core Data best practices:
- Heavy operations on background contexts
- Main context for UI binding only
- Use `objectID` for cross-context references
- Leverage automatic change merging

---

## Next Steps

1. **Test the fix** - Swipe to delete a note and verify no warnings
2. **Monitor Sentry** - Check that issue #7161938631 doesn't recur
3. **Deploy** - Once verified, this can be included in next release

---

**Status**: Ready for testing ✅

