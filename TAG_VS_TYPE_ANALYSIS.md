# Tag-Based vs Type-Based Architecture Analysis

**Date:** 2025-01-27  
**Question:** Should types be ditched completely in favor of LLM-created tags that drive formatting and actions?

---

## Current Model: Type-Based

**Structure:**
- `Note.noteType: String` - Single value ("todo", "meeting", "contact", etc.)
- Type determines:
  - Which detail view to show (via `DetailViewFactory`)
  - What actions are available (create contact, create event, etc.)
  - Display formatting (badge color, icon)
- Type is **exclusive** - one type per note

**Example:**
```swift
note.noteType = "contact"
// → Shows ContactDetailView
// → Can create iOS contact
// → Badge shows contact icon/color
```

---

## Proposed Model: Tag-Based

**Structure:**
- No `noteType` field
- `Note.tagEntities: Set<Tag>` - Multiple tags
- Tags determine:
  - Which detail view to show (primary tag)
  - What actions are available (any relevant tag)
  - Display formatting (based on tags)
- Tags are **inclusive** - multiple tags per note

**Example:**
```swift
note.tags = ["contact", "work", "q4-project"]
// → Primary tag "contact" → Shows ContactDetailView
// → Tag "contact" → Can create iOS contact
// → Tags drive badge/icon/color
```

---

## Pros of Tag-Based Model

### 1. **More Flexible**
- A note can be both `tag:todo` and `tag:work`
- A note can be both `tag:meeting` and `tag:project-alpha`
- No artificial exclusivity

### 2. **More Natural**
- Users think in tags, not types
- "This is a work-related todo" → `["todo", "work"]`
- "This is a recipe I want to try" → `["recipe", "cooking"]`

### 3. **Better for Multi-Purpose Notes**
- Meeting notes with action items → `["meeting", "todo"]`
- Expense receipt for work → `["expense", "work", "tax-deductible"]`
- Recipe with modifications → `["recipe", "modified"]`

### 4. **LLM Can Suggest Multiple Tags**
- Current: LLM picks ONE type
- Tag-based: LLM suggests 3-5 relevant tags
- More nuanced classification

### 5. **Simpler Mental Model**
- No "what type is this?" decision
- Just "what tags apply?"
- Tags are additive, not exclusive

### 6. **Better Search/Filtering**
- Filter by `tag:work AND tag:todo`
- Filter by `tag:meeting OR tag:event`
- More powerful queries

---

## Cons of Tag-Based Model

### 1. **Primary Tag Problem**
- Which tag determines detail view?
- Need "primary tag" concept for routing
- Or: Multiple detail views? (complex)

### 2. **Exclusive Tags**
- Some tags might be mutually exclusive:
  - `tag:contact` vs `tag:event` (probably not both)
  - `tag:todo` vs `tag:general` (maybe?)
- Need rules for exclusivity

### 3. **Migration Complexity**
- Existing notes have `noteType` field
- Need to convert: `noteType="contact"` → `tag="contact"`
- Backward compatibility during transition

### 4. **Refactoring Required**
- All type-based logic → tag-based
- `DetailViewFactory` → tag-based routing
- `TextClassifier` → tag suggestion instead of type classification
- Many files to update

### 5. **Action Logic Complexity**
- Current: `if noteType == "contact" { createContact() }`
- Tag-based: `if note.hasTag("contact") { createContact() }`
- What if note has `["contact", "event"]`? Both actions?

---

## Hybrid Approach: Tags as Source of Truth, Type as Convenience

**Structure:**
- `Note.tagEntities: Set<Tag>` - Source of truth
- `Note.noteType: String` - Computed from primary tag (for convenience)
- Type is **derived**, not stored

**Example:**
```swift
// Tags are source of truth
note.tags = ["contact", "work"]

// Type is computed property
var noteType: String {
    primaryTag?.name ?? "general"
}

var primaryTag: Tag? {
    // Priority: contact > event > todo > meeting > general
    tagEntities.first { ["contact", "event", "todo", "meeting"].contains($0.name) }
        ?? tagEntities.first
        ?? nil
}
```

**Benefits:**
- Tags are flexible and additive
- Type is convenient for routing/display
- Backward compatible (type still exists)
- Can migrate gradually

**Drawbacks:**
- Still have type concept (might confuse users)
- Need to maintain primary tag logic
- Two concepts (tags + type) instead of one

---

## Recommendation: **Pure Tag-Based with Primary Tag**

### Architecture

**1. Remove `noteType` field entirely**
- Tags are the only classification mechanism
- No type enum, no type field

**2. Primary Tag for Routing**
```swift
extension Note {
    /// Primary tag determines detail view and main action
    var primaryTag: Tag? {
        // Priority order: contact > event > todo > meeting > general
        let priorityTags = ["contact", "event", "todo", "meeting"]
        return tagEntities.first { priorityTags.contains($0.name) }
            ?? tagEntities.first
    }
    
    /// Computed type for backward compatibility (if needed)
    var computedType: String {
        primaryTag?.name ?? "general"
    }
}
```

**3. Tag-Based Routing**
```swift
func makeDetailView(for note: Note) -> AnyView {
    guard let primaryTag = note.primaryTag else {
        return AnyView(NoteDetailView(note: note))
    }
    
    switch primaryTag.name {
    case "contact": return AnyView(ContactDetailView(note: note))
    case "event": return AnyView(EventDetailView(note: note))
    case "todo": return AnyView(TodoDetailView(note: note))
    case "meeting": return AnyView(MeetingDetailView(note: note))
    default: return AnyView(NoteDetailView(note: note))
    }
}
```

**4. Tag-Based Actions**
```swift
func processNote(_ note: Note) {
    // Multiple actions can happen based on tags
    if note.hasTag("contact") {
        createContact(from: note)
    }
    if note.hasTag("event") {
        createCalendarEvent(from: note)
    }
    if note.hasTag("todo") {
        extractTodos(from: note)
    }
    // All can happen simultaneously
}
```

**5. LLM Tag Suggestion**
```swift
func suggestTags(for content: String) async -> [String] {
    // LLM suggests multiple tags, not just one type
    // "This looks like a work-related todo with action items"
    // → ["todo", "work", "action-items"]
}
```

---

## Migration Strategy

### Phase 1: Add Tag Support (Keep Types)
1. LLM suggests tags in addition to type
2. Store tags alongside type
3. Use tags for search/filtering
4. Type still determines detail view

### Phase 2: Dual Mode
1. Compute primary tag from tags
2. Use primary tag for routing if available
3. Fall back to type if no primary tag
4. Gradually migrate notes to tags

### Phase 3: Remove Types
1. All notes have tags
2. Remove `noteType` field
3. Use tags exclusively
4. Type is computed property (if needed for compatibility)

---

## Example: Shopping List + Journal Entry

**Current (Type-Based):**
- Entire page → `type=general` (or whatever classifier thinks)
- Can't be both shopping list AND journal entry

**Tag-Based:**
- Section 1: `tags=["todo", "shopping"]` → TodoDetailView (shopping-styled)
- Section 2: `tags=["general", "journal"]` → NoteDetailView
- Both sections can have multiple tags
- More flexible and accurate

---

## Critical Question: Multi-Section Pages with Tags

> "If we have multiple tags in the same source image, how do we split the content into different notes? Ex: a shopping list is on the same page as some meeting notes or a journal entry."

### The Problem

**Same page, different sections:**
```
Page content:
"Shopping List:
- Milk
- Eggs

Meeting Notes:
Discussed Q4 budget with Sarah..."

Current issue: How to split and assign tags?
```

### Solution: LLM Semantic Section Detection + Tag Assignment

**The flow:**

1. **OCR** → Full text from page

2. **LLM Semantic Section Detection:**
   ```
   "Analyze this text and identify distinct sections.
   For each section, suggest appropriate tags.
   
   Return JSON:
   [
     {
       "content": "Shopping List: ...",
       "tags": ["todo", "shopping"],
       "startIndex": 0,
       "endIndex": 50,
       "reasoning": "Shopping list with items"
     },
     {
       "content": "Meeting Notes: ...",
       "tags": ["meeting", "work", "q4"],
       "startIndex": 52,
       "endIndex": 150,
       "reasoning": "Meeting notes about Q4 budget"
     }
   ]
   ```

3. **Section Preview:**
   ```
   "I found 2 sections:
   
   📝 Shopping List
   Tags: todo, shopping
   - Milk, Eggs
   
   📔 Meeting Notes
   Tags: meeting, work, q4
   - Discussed Q4 budget with Sarah
   
   [Split into 2 notes] [Keep as 1 note]"
   ```

4. **Save:**
   - Note 1: `content="Shopping List: ..."`, `tags=["todo", "shopping"]`, has image
   - Note 2: `content="Meeting Notes: ..."`, `tags=["meeting", "work", "q4"]`, links to Note 1's image

### Implementation

**Enhanced `splitIntoSections()` with tag assignment:**

```swift
struct NoteSection {
    let content: String
    let tags: [String]  // NEW: Tags for this section
    let startIndex: String.Index
    let endIndex: String.Index
    let reasoning: String?  // Why these tags?
}

func splitIntoSections(content: String) async -> [NoteSection] {
    // 1. Check for hashtags first (fast path)
    let tagSections = detectTagSections(content)
    if !tagSections.isEmpty {
        return tagSections.map { section in
            // Convert type to tags
            NoteSection(
                content: section.content,
                tags: [section.noteType.rawValue],  // Type becomes primary tag
                startIndex: section.tagRange.lowerBound,
                endIndex: section.tagRange.upperBound
            )
        }
    }
    
    // 2. LLM semantic detection with tag assignment
    return await detectSemanticSectionsWithTags(content)
}

func detectSemanticSectionsWithTags(_ content: String) async -> [NoteSection] {
    let prompt = """
    Analyze this text and identify distinct sections that should be separate notes.
    For each section, suggest 3-5 relevant tags.
    
    A section is a coherent piece of content with a clear purpose.
    
    Examples:
    - Shopping list → tags: ["todo", "shopping"]
    - Meeting notes → tags: ["meeting", "work"]
    - Journal entry → tags: ["journal", "personal"]
    - Recipe → tags: ["recipe", "cooking"]
    
    Return JSON array:
    [
      {
        "content": "section text",
        "tags": ["tag1", "tag2"],
        "startIndex": 0,
        "endIndex": 50,
        "reasoning": "why these tags"
      }
    ]
    
    Text:
    \(content)
    """
    
    let response = try await LLMService.shared.performAPIRequest(prompt: prompt)
    // Parse JSON and return sections
}
```

### Tag Assignment Logic

**For each detected section, LLM suggests tags based on:**
1. **Content analysis** - What is this? (todo, meeting, recipe, etc.)
2. **Context clues** - Work-related? Personal? Urgent?
3. **Named entities** - People, places, projects mentioned

**Example:**
```
Section: "Shopping List: Milk, Eggs, Bread"
LLM suggests: ["todo", "shopping", "groceries"]

Section: "Meeting with Sarah about Q4 budget"
LLM suggests: ["meeting", "work", "q4", "sarah"]
```

### Image Handling

**All sections share same source image:**
- First section: Has full image
- Other sections: Link to first section's image (via `NoteLink` or shared reference)
- Future: Highlight which region belongs to which section

### User Control

**User can:**
1. **Accept split** → Creates separate notes with suggested tags
2. **Reject split** → Keeps as one note, all tags combined
3. **Edit sections** → Adjust boundaries, add/remove tags
4. **Merge sections** → Combine sections into one note

### Example Flow: Shopping List + Meeting Notes

**User captures page:**
```
"Shopping List:
- Milk
- Eggs
- Bread

Meeting Notes:
Discussed Q4 budget with Sarah. She'll follow up on expenses."
```

**App flow:**
1. OCR → Full text
2. No hashtags → LLM semantic detection
3. LLM detects:
   - Section 1: "Shopping List: ..." → `tags=["todo", "shopping"]`
   - Section 2: "Meeting Notes: ..." → `tags=["meeting", "work", "q4", "sarah"]`
4. Preview shown:
   ```
   "I found 2 sections:
   
   📝 Shopping List
   Tags: todo, shopping
   
   📔 Meeting Notes  
   Tags: meeting, work, q4, sarah
   
   [Split into 2 notes] [Keep as 1 note]"
   ```
5. User: [Split into 2 notes]
6. App saves:
   - Note 1: `content="Shopping List: ..."`, `tags=["todo", "shopping"]`, has image
   - Note 2: `content="Meeting Notes: ..."`, `tags=["meeting", "work", "q4", "sarah"]`, links to Note 1's image

**Result:** Each section is a separate note with appropriate tags, all sharing the source image.

### Key Insight

**Tags are assigned per section, not per page.**

- One page can have multiple sections
- Each section gets its own tags
- Each section becomes its own note
- All notes share the source image

**The LLM does both:**
1. **Section detection** - Where to split
2. **Tag assignment** - What tags for each section

This solves the multi-section problem elegantly.

---

## Example: Meeting with Action Items

**Current (Type-Based):**
- `type=meeting` → MeetingDetailView
- Action items extracted but note is "meeting" type

**Tag-Based:**
- `tags=["meeting", "todo", "work"]` → MeetingDetailView (primary tag)
- Can also show todo items (secondary tag)
- More accurate representation

---

## Example: Expense Receipt

**Current (Type-Based):**
- `type=expense` → ExpenseDetailView
- Can't also be `type=work` or `type=tax-deductible`

**Tag-Based:**
- `tags=["expense", "work", "tax-deductible", "receipt"]` → ExpenseDetailView
- All tags apply simultaneously
- Better categorization

---

## Answer: **Yes, Ditch Types in Favor of Tags**

### Why?

1. **More Flexible** - Notes can have multiple classifications
2. **More Natural** - Users think in tags, not types
3. **Better LLM Integration** - LLM suggests multiple tags, not just one type
4. **Simpler Mental Model** - Tags are additive, not exclusive
5. **Better for Multi-Purpose Notes** - Meeting + todo, expense + work, etc.

### Implementation

1. **Remove `noteType` field** - Tags are source of truth
2. **Primary tag for routing** - Determines detail view
3. **Multiple tags for actions** - All relevant actions can happen
4. **LLM suggests tags** - Not just one type, but multiple relevant tags
5. **Gradual migration** - Convert existing notes to tags

### The Flow

**User captures note:**
1. OCR → Full text
2. LLM suggests tags: `["todo", "work", "urgent"]`
3. App: Primary tag "todo" → TodoDetailView
4. App: All tags apply → Can extract todos, tag as work, mark urgent
5. Note saved with tags, no type field

**Result:** More flexible, more accurate, more natural.

---

## Open Questions

1. **Primary Tag Priority** - What order? `contact > event > todo > meeting > general`?
2. **Exclusive Tags** - Should `contact` and `event` be mutually exclusive?
3. **Migration** - How to convert existing notes? Automatic or manual?
4. **Backward Compatibility** - Keep computed `noteType` property for compatibility?
5. **UI** - How to show multiple tags in list view? Badge for primary tag only?

---

## Recommendation

**Yes, eliminate types in favor of tags.** But implement gradually:

1. **Phase 1:** Add tag suggestion alongside type (dual mode)
2. **Phase 2:** Use primary tag for routing, fall back to type
3. **Phase 3:** Remove type field, use tags exclusively

**The tag-based model is more flexible, natural, and powerful.**
