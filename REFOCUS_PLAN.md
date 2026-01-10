# QuillStack Refocus Plan
**Date:** 2025-01-27  
**Goal:** Crystalize the vision and refocus on core value proposition

---

## Core Vision (Crystalized)

**QuillStack is your personal repository for valuable information that starts as impermanent, analog artifacts.**

### The Flow:
1. **Capture** → Any valuable information (handwritten notes, business cards, fliers, screenshots, etc.)
2. **Transform** → LLM automatically handles the annoying bits (OCR, categorization, tagging, linking)
3. **Organize** → Information becomes either:
   - **Actionable** (reminders, meetings, contacts, todos)
   - **Knowledge** (saved for later review, searchable, linked)

### Key Principle:
> "If someone hands me a business card, it gets scanned into the app and a contact is created. If I see a flier for an event it gets scanned and a calendar event is created."

**The app should feel like magic - you capture, it figures out what to do.**

---

## Current State Analysis

### ✅ What's Working Well

1. **Business Cards → Contacts** - Working (BusinessCardDetector + ContactParser)
2. **Event Fliers → Calendar Events** - Working (EventExtractor + CalendarService)
3. **OCR Pipeline** - Solid foundation (Vision framework, preprocessing, confidence tracking)
4. **Handwriting Learning** - Adaptive OCR corrections
5. **Multi-page Support** - Handles multi-page documents
6. **Cross-note Linking** - Infrastructure exists (NoteLink, NoteLinkService)

### ⚠️ What's Problematic

1. **Too Many Note Types (13 types)** - Creates decision fatigue
   - Current: general, todo, meeting, email, claudePrompt, reminder, contact, expense, shopping, recipe, event, journal, idea
   - Problem: User has to think "what type is this?" instead of just capturing
   - Reality: Most notes are just "valuable information" - type is metadata, not primary

2. **Classification is Too Prominent** - The app asks "what type?" too often
   - Manual type picker shown when confidence < threshold
   - User has to make decisions instead of app being smart
   - Should be invisible unless user wants to override

3. **Screenshot Handling is Unclear** - No special handling for:
   - Screenshots of highlighted text (quotes)
   - Screenshots of art/images
   - Screenshots of articles/URLs
   - These should be captured but treated differently than handwritten notes

4. **LLM Underutilized** - LLM classification exists but:
   - Not used for automatic tagging
   - Not used for automatic cross-linking
   - Not used for extracting structured data from general notes
   - Should be doing MORE, not less

5. **Tagging is Manual** - Tags exist but:
   - User has to manually add tags
   - No automatic tag suggestions
   - No automatic tag extraction from content
   - Should be automatic with LLM

6. **Cross-linking is Manual** - Infrastructure exists but:
   - No automatic linking based on content similarity
   - No automatic linking based on named entities (people, places, topics)
   - Should be automatic with LLM

7. **"Type Guide" Tab** - Suggests the app is about types, not about capturing valuable information
   - This tab teaches users about note types
   - But the vision is: "just capture, we'll figure it out"

---

## The Core Problem

**The app is organized around note types, but it should be organized around information capture and transformation.**

### Current Mental Model (Wrong):
```
User thinks: "I need to capture a todo, so I'll use the todo type"
App asks: "What type is this note?"
User has to know: "This is a meeting note, so I'll use meeting type"
```

### Desired Mental Model (Right):
```
User thinks: "This is valuable information, I'll capture it"
App thinks: "This looks like a business card → create contact"
App thinks: "This looks like an event → create calendar event"
App thinks: "This looks like a todo → extract todos"
App thinks: "This is just information → save to knowledge base"
User rarely thinks about types - app handles it
```

---

## Refocusing Strategy

### Phase 1: Simplify the Mental Model

#### 1.1 Reduce Note Types to Essentials
**Keep only types that have distinct actions:**
- ✅ **Contact** - Creates iOS contact (actionable)
- ✅ **Event** - Creates calendar event (actionable)
- ✅ **Todo** - Creates actionable todos (actionable)
- ✅ **Meeting** - Creates meeting with attendees (actionable)
- ✅ **General** - Everything else (knowledge base)

**Remove or merge:**
- ❌ **Email** - Merge into General (or extract email addresses automatically)
- ❌ **Reminder** - Merge into Todo (todos can have dates)
- ❌ **Expense** - Merge into General (extract expense data automatically)
- ❌ **Shopping** - Merge into Todo (it's a todo list)
- ❌ **Recipe** - Merge into General (it's knowledge)
- ❌ **Journal** - Merge into General (it's knowledge)
- ❌ **Idea** - Merge into General (it's knowledge)
- ❌ **ClaudePrompt** - Merge into General (or make it a special export action)

**Result: 5 types instead of 13** - Much simpler mental model

#### 1.2 Make Classification Invisible
- **Default behavior:** Auto-classify with high confidence threshold (0.90)
- **Never show type picker** unless:
  - User explicitly wants to change type (long-press or edit mode)
  - Classification confidence is very low (< 0.50) AND content is ambiguous
- **Trust the LLM** - If LLM says it's a meeting with 0.85 confidence, trust it
- **User can override** - But make it a power-user feature, not default

#### 1.3 Remove "Type Guide" Tab
- Replace with "Capture" tab (camera-first)
- Or merge into Settings as "How it works"
- The app shouldn't teach types - it should just work

### Phase 2: Enhance LLM Automation

#### 2.1 Automatic Tagging
**After OCR, LLM should:**
- Extract key topics/concepts from content
- Suggest 3-5 relevant tags automatically
- User can accept/reject/modify
- Tags stored in Tag entities (already exists)

**Example:**
```
Note: "Meeting with Sarah about Q4 budget. Need to review expenses."
LLM suggests tags: ["work", "budget", "q4", "sarah"]
```

#### 2.2 Automatic Cross-Linking
**After saving, LLM should:**
- Find other notes mentioning same people, places, topics
- Automatically create NoteLinks
- Show "Related Notes" section in detail view

**Example:**
```
New note: "Follow up with Sarah about budget"
LLM finds: Previous note "Meeting with Sarah about Q4 budget"
LLM creates: Link with type "related" and label "Sarah - Budget Discussion"
```

#### 2.3 Automatic Structured Data Extraction
**For General notes, LLM should extract:**
- People mentioned (names)
- Dates mentioned
- URLs mentioned
- Email addresses
- Phone numbers
- Key facts/claims

**Store in `extractedDataJSON`** (already exists) for later use

#### 2.4 Screenshot Intelligence
**Detect screenshot vs handwritten:**
- Screenshots: Usually have UI elements, perfect text, rectangular
- Handwritten: Usually has handwriting, imperfect text, organic shapes

**For screenshots, LLM should:**
- Detect if it's a quote (highlighted text)
- Detect if it's an article/URL (extract URL if visible)
- Detect if it's art/image (no text, just visual)
- Tag appropriately: `["screenshot", "quote"]` or `["screenshot", "article"]`

**Special handling:**
- Quotes: Extract text, preserve original image, tag as quote
- Articles: Extract URL if visible, create link to article
- Art: Just save as image, tag as art/visual

### Phase 3: Improve Knowledge Base Experience

#### 3.1 Better Search
- Semantic search (not just keyword)
- Search by tags
- Search by linked notes
- Search by extracted entities (people, dates, topics)

#### 3.2 Better Organization
- Smart Collections (already planned in FEATURE_BRAINSTORM.md)
- Auto-group by topic, date, person
- Show related notes automatically

#### 3.3 Better Discovery
- "Notes mentioning Sarah" collection
- "Notes from last week" collection
- "Notes about budget" collection
- All automatic, no manual organization needed

---

## Concrete Implementation Plan

### Step 1: Simplify Note Types (High Priority)

**Files to modify:**
- `Models/NoteType.swift` - Remove unused types
- `Services/TextClassifier.swift` - Update classification logic
- `Services/Plugins/` - Remove plugin files for deleted types
- `Views/Notes/` - Update routing logic

**Changes:**
1. Remove: email, reminder, expense, shopping, recipe, journal, idea, claudePrompt
2. Keep: general, todo, meeting, contact, event
3. Update classification to map removed types to "general"
4. Migration: Convert existing notes of removed types to "general"

**Estimated effort:** 4-6 hours

### Step 2: Make Classification Invisible (High Priority)

**Files to modify:**
- `ViewModels/CameraViewModel.swift` - Remove type picker logic
- `Services/TextClassifier.swift` - Increase default confidence threshold
- `Views/Capture/` - Remove type selection UI

**Changes:**
1. Set default confidence threshold to 0.90 (very high)
2. Only show type picker if confidence < 0.50 AND ambiguous
3. Add "Change Type" button in note detail view (power-user feature)
4. Trust LLM classifications more

**Estimated effort:** 2-3 hours

### Step 3: Automatic Tagging with LLM (Medium Priority)

**New file:**
- `Services/AutoTaggingService.swift`

**Files to modify:**
- `ViewModels/CameraViewModel.swift` - Call auto-tagging after OCR
- `Views/Notes/NoteDetailView.swift` - Show suggested tags

**Implementation:**
```swift
func suggestTags(for content: String) async -> [String] {
    // LLM prompt: "Extract 3-5 key topics/tags from this note"
    // Return array of tag names
}
```

**Estimated effort:** 4-6 hours

### Step 4: Automatic Cross-Linking (Medium Priority)

**New file:**
- `Services/AutoLinkingService.swift`

**Files to modify:**
- `ViewModels/CameraViewModel.swift` - Call auto-linking after save
- `Views/Notes/NoteDetailView.swift` - Show related notes

**Implementation:**
```swift
func findRelatedNotes(for note: Note, in context: NSManagedObjectContext) async -> [Note] {
    // LLM: "Find notes mentioning same people, places, topics"
    // Create NoteLinks automatically
}
```

**Estimated effort:** 6-8 hours

### Step 5: Screenshot Detection & Handling (Medium Priority)

**New file:**
- `Services/ScreenshotDetector.swift`

**Files to modify:**
- `ViewModels/CameraViewModel.swift` - Detect screenshots
- `Services/TextClassifier.swift` - Special handling for screenshots

**Implementation:**
- Detect screenshot (UI elements, perfect text, rectangular)
- Classify screenshot type (quote, article, art)
- Extract structured data (URL, quote text)

**Estimated effort:** 4-6 hours

### Step 6: Remove Type Guide Tab (Low Priority)

**Files to modify:**
- `App/ContentView.swift` - Remove TypeGuideView tab
- Move type guide to Settings as "How it works"

**Estimated effort:** 1 hour

---

## Success Metrics

### Before Refocus:
- ❌ User has to think about note types
- ❌ Manual tagging required
- ❌ Manual linking required
- ❌ 13 note types to choose from
- ❌ Type Guide tab teaches complexity

### After Refocus:
- ✅ User just captures, app figures it out
- ✅ Automatic tagging with LLM
- ✅ Automatic linking with LLM
- ✅ 5 note types (only actionable ones)
- ✅ No type guide needed - app just works

---

## Migration Strategy

### For Existing Users:
1. **Type Migration:** Convert removed types to "general"
   - email → general
   - reminder → todo (if has date) or general
   - expense → general (extract expense data to JSON)
   - shopping → todo (if has list items) or general
   - recipe → general
   - journal → general
   - idea → general
   - claudePrompt → general

2. **Data Preservation:** All content preserved, just type changes
3. **Gradual Enhancement:** Run auto-tagging and auto-linking on existing notes in background

---

## Questions to Answer

1. **Should we keep "reminder" as separate from "todo"?**
   - If todos can have dates, probably not needed
   - But reminders might be time-sensitive without being todos
   - **Recommendation:** Merge into todo, todos can have dates

2. **Should we keep "expense" for receipt tracking?**
   - Receipts are important use case
   - But they're just documents with structured data
   - **Recommendation:** Keep as "general" but extract expense data automatically

3. **What about "claudePrompt" → GitHub export?**
   - This is a workflow, not a type
   - **Recommendation:** Make it an export action available on any note
   - User can export any note to GitHub, not just "claude prompt" type

4. **Should screenshots be a separate type?**
   - Probably not - they're just a different capture method
   - **Recommendation:** Tag as "screenshot" and handle intelligently

---

## Next Steps

1. **Review this plan** - Does this align with your vision?
2. **Prioritize** - Which steps should we do first?
3. **Start with Step 1** - Simplify note types (biggest impact, clears mental model)
4. **Then Step 2** - Make classification invisible
5. **Then Steps 3-5** - Add LLM automation

---

## Key Insight

**The app should feel like a smart assistant that handles the annoying bits, not a form-filling app that asks you to categorize everything.**

You said: "I want the app to be my personal repository of valuable information."

The app should say: "I'll figure out what this is and what to do with it. You just capture it."
