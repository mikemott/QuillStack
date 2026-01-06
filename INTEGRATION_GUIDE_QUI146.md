# QUI-146 Integration Guide

Quick reference for integrating the new note formatting utilities into views.

## Quick Start

```swift
// In any view with a Note object
let processor = NoteContentProcessor()
let result = processor.process(note: myNote)

// Use the results:
Text(result.title)  // Smart title
Text(result.formattedContent)  // Styled content
if let progress = result.metadata["progress"] as? String {
    Text(progress)  // "3 of 5 completed"
}
```

## Convenience Extensions

```swift
// Even simpler with extensions:
Text(note.smartTitle)  // Smart-extracted title
Text(note.processedContent.formattedContent)  // Full processing
Text(note.cleanContent)  // Just OCR cleanup
```

## Example: Updating NoteListView

**Before:**
```swift
struct NoteCard: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading) {
            Text(note.content?.firstLines(1) ?? "Untitled")
                .font(.headline)
        }
    }
}
```

**After:**
```swift
struct NoteCard: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading) {
            Text(note.smartTitle)  // ✨ Smart title!
                .font(.headline)
        }
    }
}
```

## Example: Updating TodoDetailView

**Before:**
```swift
DetailHeader(
    title: note.content?.firstLines(1) ?? "Todo List",
    date: note.createdAt,
    noteType: "todo"
)

ScrollView {
    Text(note.content ?? "")  // Plain text
}
```

**After:**
```swift
let result = note.processedContent

DetailHeader(
    title: result.title,  // ✨ Smart title
    date: note.createdAt,
    noteType: "todo",
    completedCount: result.metadata[FormatterMetadataKey.completedCount] as? Int,
    totalCount: result.metadata[FormatterMetadataKey.totalCount] as? Int
)

ScrollView {
    Text(result.formattedContent)  // ✨ Styled with checkboxes, priorities, etc.
}
```

## Three Core Services

### 1. OCRNormalizer
Cleans up OCR artifacts before displaying.

```swift
let cleanedText = OCRNormalizer.cleanText(ocrOutput)
// "[ ] Buy milk" → "☐ Buy milk"
// "l Bullet item" → "• Bullet item"
```

### 2. TitleExtractor
Extracts smart titles based on note type.

```swift
let title = TitleExtractor.extractTitle(from: content, type: .todo)
// Skips checkbox lines, finds meaningful headers
// Falls back to: "Todo List - Jan 6"
```

### 3. NoteFormatter
Type-specific content formatting.

```swift
let formatter = FormatterRegistry.shared.formatter(for: .todo)
let styledContent = formatter.format(content: note.content)
let metadata = formatter.extractMetadata(from: note.content)
```

## Metadata Keys Reference

```swift
// Todo
FormatterMetadataKey.completedCount  // Int
FormatterMetadataKey.totalCount  // Int
FormatterMetadataKey.progress  // String: "3 of 5 completed"
FormatterMetadataKey.progressPercentage  // Double: 0.6

// More keys for other types (see NoteFormatter.swift)
```

## Creating New Formatters

See `TodoFormatter.swift` as a template:

```swift
@MainActor
final class MeetingFormatter: NoteFormatter {
    var noteType: NoteType { .meeting }

    func format(content: String) -> AttributedString {
        // Parse and style meeting content
        // Highlight participants, action items, etc.
    }

    func extractMetadata(from content: String) -> [String: Any] {
        // Extract participants, meeting date, etc.
    }
}
```

Then register in `FormatterRegistry.swift`:
```swift
case .meeting:
    formatter = MeetingFormatter()
```

## Next Steps

1. Update existing detail views to use smart titles
2. Apply formatters in detail views for styled content
3. Add progress visualizations using metadata
4. Implement remaining formatters (Meeting, Email, Recipe, etc.)
5. Test dark mode
6. Validate accessibility

## Files to Update

**High Priority:**
- `Views/Notes/TodoDetailView.swift` ✅ (proof of concept target)
- `Views/Notes/NoteListView.swift` (for smart titles in cards)
- `Views/Notes/MeetingDetailView.swift`

**Medium Priority:**
- `Views/Notes/EmailDetailView.swift`
- `Views/Notes/RecipeDetailView.swift`
- `Views/Notes/ContactDetailView.swift`

**Lower Priority:**
- Other detail views as formatters are implemented
