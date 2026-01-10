# Architecture Decision: Action vs Knowledge & The "Log" Question

**Date:** 2025-01-27  
**Context:** Refocusing discussion with Claude about Action/Knowledge split

---

## The Core Question

**Is the Action/Knowledge binary the right mental model, or is it more nuanced?**

### The Original Proposal (Action/Knowledge Split)

**Type A: Actionable**
- Business card → Create contact in iOS Contacts
- Event flier → Create calendar event  
- Todo list → Create reminders
- Meeting notes → Create meeting with attendees

**Type B: Knowledge**
- Recipe you want to save
- Quote you found interesting
- Article screenshot
- Journal entry
- Random idea

**Key difference:** Actionable items "leave" QuillStack and go somewhere else. Knowledge stays in QuillStack.

---

## User's Key Insights

### 1. **Meetings Are Context-Dependent** ⭐ CRITICAL

> "Sometimes I'm drafting an agenda and I'll include attendees and want to create a meeting based on that information but other times I'm taking meeting notes and want them stored in the knowledge base."

**Same note type, different temporal contexts:**
- **Pre-meeting agenda** (future-focused) → Create calendar event (actionable)
- **Post-meeting notes** (retrospective) → Save to KB for reference (knowledge)

**This breaks the binary.** A meeting note can be BOTH actionable AND knowledge, depending on when it's captured.

### 2. **Actionable Items Shouldn't Fully "Leave"**

> "I'm not sure that the actionable stuff should fully 'leave' quillstack, maybe there could be a log separate from the KB where the notes are preserved until deleted or archived."

**User suggests:**
- Business card → Creates contact, but also preserved in "log"
- Event flier → Creates calendar event, but also preserved in "log"
- Not deleted, just archived/separated from main KB

**Question:** Is this "log" actually useful, or just conceptual tidiness?

### 3. **Recipes = Pure Knowledge** ✅

> "I disagree about recipes, I think they can just be added to the KB with proper tags."

User agrees: Recipes don't need special "action" - just good tagging.

### 4. **Shopping = Styled Todo** ✅

> "I think Cursor is right about shopping too, it really could just be formatted like a todo but maybe the styling should be different."

User agrees: Shopping is functionally a todo list, just needs different visual treatment.

---

## Analysis: The "Log" Concept

### What the User Is Describing

The "log" seems to be:
- A record of actions taken
- Preserved notes that have been "actioned"
- Separate from the main knowledge base
- Eventually archived/deleted

### The Critical Question

> "When you capture a business card and create a contact, do you ever need to go back and reference that original note/photo? Or once it's in Contacts, is it dead to you?"

**This determines if we need a three-state system or can simplify.**

---

## My Recommendation: **Two States, Not Three**

### The Simplification

**Instead of:**
- Active KB
- Action Log  
- Archived

**Use:**
- **Active** (main view - everything searchable)
- **Archived** (already exists via `isArchived`)

### Why This Works

1. **The "log" is just archived notes that have been actioned**
   - Business card creates contact → Note stays in Active KB
   - User can search for it, reference it, link to it
   - When user is done with it → Archive it
   - Archived notes are still searchable, just filtered out of main view

2. **No need for separate "log" view**
   - If user wants to see "all business cards I've captured" → Search by type:contact
   - If user wants to see "all events I've created" → Search by type:event
   - If user wants to see "all actioned items" → Filter by tags:["actioned"] or search for notes with extractedDataJSON

3. **Archive already exists**
   - `Note.isArchived` field exists
   - Archive functionality exists in `NoteViewModel`
   - Search can filter by archived status
   - Just need to make archiving easier/more automatic

### The Real Insight: **Intent, Not Type**

The meeting example reveals the real issue: **It's not about type, it's about intent/temporal context.**

**Pre-meeting agenda:**
- Intent: "I want to schedule this meeting"
- Action: Create calendar event
- Also: Save note to KB (for reference)

**Post-meeting notes:**
- Intent: "I want to remember what was discussed"
- Action: None (or extract todos)
- Also: Save note to KB (for reference)

**Same note type, different intents.**

---

## Proposed Solution: **Intent-Based Actions, Not Type-Based**

### Instead of Organizing by Type, Organize by Intent

**When user captures a note, LLM determines:**
1. **What is this?** (classification - meeting, contact, event, etc.)
2. **What should happen?** (intent detection - schedule, save, extract, etc.)

### For Meetings Specifically

**LLM analyzes temporal context:**
- **Future dates mentioned** → "This looks like a meeting agenda. Create calendar event?"
- **Past dates mentioned** → "This looks like meeting notes. Save to knowledge base?"
- **No dates** → "This looks like meeting notes. Save to knowledge base?"

**User can override:** "Actually, create event" or "Actually, just save"

### For Business Cards

**Current flow (works well):**
- Detect business card → Extract contact → Create iOS contact → **Also save note to KB**

**No "log" needed** - the note is in the KB, tagged as "contact", with extracted data in JSON.

### For Events

**Current flow (works well):**
- Detect event → Extract event data → Create calendar event → **Also save note to KB**

**No "log" needed** - the note is in the KB, tagged as "event", with extracted data in JSON.

---

## Concrete Implementation

### 1. **Keep Archive, Don't Create "Log"**

- Use existing `isArchived` field
- When user is "done" with a note → Archive it
- Archived notes still searchable, just filtered from main view
- No need for separate "log" view

### 2. **Add "Action Status" Metadata (Optional)**

If we want to track what's been "actioned":

```swift
// Add to Note entity (optional)
@NSManaged public var actionStatus: String? // "pending", "completed", "none"
@NSManaged public var actionedAt: Date? // When action was taken
```

**But this might be over-engineering.** Better to use tags:
- Tag as `["contact-created"]` when contact is created
- Tag as `["event-created"]` when event is created
- Search for `tag:contact-created` to see all business cards

### 3. **Intent Detection for Meetings**

**Add to LLM classification prompt:**
```
Is this a meeting agenda (future-focused, needs scheduling) or meeting notes (retrospective, reference only)?

If agenda: Suggest creating calendar event
If notes: Suggest saving to knowledge base
```

**User sees:** "This looks like a meeting agenda. Create calendar event?" [Yes] [No, just save]

### 4. **Visual Differentiation Without Separate Types**

**Shopping vs Todo:**
- Both are `type:todo`
- Shopping has tag `["shopping"]`
- UI can style differently based on tags
- No need for separate `type:shopping`

**Example:**
```swift
// In TodoDetailView
if note.hasTagEntity(named: "shopping") {
    // Show shopping-specific UI (categories, checkboxes, etc.)
} else {
    // Show regular todo UI
}
```

---

## Answer to the Critical Question

> "When you capture a business card and create a contact, do you ever need to go back and reference that original note/photo?"

**My hypothesis:** Sometimes yes, but not often.

**Evidence:**
- User wants notes "preserved until deleted or archived"
- But also says "I'm struggling to think of other situations where that is true"

**This suggests:**
- The "log" is more about **not losing data** than **actively using it**
- Archive serves this purpose - notes are preserved, just filtered
- No need for separate "log" view

---

## Final Recommendation

### ✅ Keep It Simple: Two States

1. **Active** (main KB - everything searchable)
2. **Archived** (filtered from main view, still searchable)

### ✅ Use Intent Detection, Not Just Type

- LLM determines intent (schedule, save, extract)
- User can override
- Same type can have different intents

### ✅ Use Tags for Differentiation

- Shopping = `type:todo` + `tag:shopping`
- Recipe = `type:general` + `tag:recipe`
- Contact-created = `type:contact` + `tag:contact-created`

### ❌ Don't Create "Log" View

- Archive serves this purpose
- Search/filtering is more powerful
- Less UI complexity

### ✅ Make Archiving Easier

- Add "Archive" button to note detail view
- Add "Archive all actioned" bulk action
- Auto-archive after X days (optional setting)

---

## Meeting Example: How It Works

### Pre-Meeting Agenda

1. User captures: "#meeting# Q4 Planning with Sarah, Jan 15, 2pm"
2. LLM detects: Future date → "This looks like a meeting agenda"
3. App suggests: "Create calendar event?"
4. User: [Yes]
5. App: Creates calendar event + Saves note to KB with `tag:["meeting", "agenda"]`
6. Note stays in Active KB, searchable, linkable

### Post-Meeting Notes

1. User captures: "#meeting# Discussed Q4 budget. Sarah will follow up on expenses."
2. LLM detects: No future date, past tense → "This looks like meeting notes"
3. App: Saves note to KB with `tag:["meeting", "notes"]`
4. App: Optionally extracts todos ("Sarah will follow up")
5. Note stays in Active KB, searchable, linkable

**Both are `type:meeting`, both stay in KB, differentiated by tags and intent.**

---

## Expense Receipt Example: Multiple Simultaneous Intents

### The Flow

1. **User captures:** Receipt from coffee shop
2. **LLM extracts structured data:**
   ```json
   {
     "amount": 4.50,
     "date": "2025-01-27",
     "merchant": "Blue Bottle Coffee",
     "category": "food",
     "lineItems": ["Latte: $4.50"],
     "tax": 0.36,
     "tip": 0.00
   }
   ```
3. **App saves to KB:**
   - Note stays in Active KB
   - Structured data in `extractedDataJSON`
   - Tags: `["expense", "receipt", "food", "coffee"]`
   - Image preserved
4. **App can also:**
   - Export to expense tracking system (future)
   - Generate tax reports (future)
   - Track spending by category (future)
5. **User can:**
   - Search "coffee receipts" → Finds it
   - Search "expenses from January" → Finds it
   - Link to meeting note "coffee with Sarah"
   - Reference original receipt image

**The note serves BOTH purposes:**
- ✅ **Actionable:** Structured data extracted for tracking
- ✅ **Knowledge:** Saved to KB for reference

**This is the model: Action AND Knowledge, not OR.**

---

## Challenge: Multiple Simultaneous Intents ⭐ NEW

### The Expense Receipt Example

> "When you capture an expense receipt, is it 'track this for taxes' or 'just remember what I spent'? - I think sometimes it's both of these things."

**This is a critical insight that breaks the binary model further.**

**An expense receipt can have MULTIPLE simultaneous intents:**
1. **"Track this for taxes"** → Extract structured data (amount, date, merchant, category) for expense tracking
2. **"Just remember what I spent"** → Save note/image to KB for reference

**This is different from meetings (temporal context). This is about multiple simultaneous intents.**

### The Real Model: **Action AND Knowledge, Not OR**

The app should handle BOTH actions simultaneously:
- Extract structured expense data → Store in `extractedDataJSON` for tracking/export
- Save note/image to KB → Tagged, searchable, linkable
- Tag appropriately → `["expense", "receipt", "tax-deductible"]` or `["expense", "receipt", "personal"]`

**Example Flow:**
1. User captures receipt
2. LLM extracts: amount, date, merchant, category, line items
3. App: Saves structured data to `extractedDataJSON`
4. App: Saves note to KB with tags `["expense", "receipt", category]`
5. App: Optionally exports to expense tracking system (future feature)
6. Note stays in KB, searchable, with structured data available

**The note serves BOTH purposes simultaneously.**

### Implications for Architecture

**The model isn't "Action OR Knowledge" - it's "Action AND Knowledge" for many things.**

**Every note:**
- Goes to KB (searchable repository) ✅
- Can have structured data extracted (for actions) ✅
- Can have external actions created (contacts, events, todos) ✅
- Can be tagged for organization ✅
- Can be linked to other notes ✅

**The "action" is metadata, not a separate state.**

### Updated Model: **Structured Data + KB, Not Action/Knowledge Split**

**Instead of thinking:**
- Actionable → Leaves QuillStack
- Knowledge → Stays in QuillStack

**Think:**
- Everything stays in QuillStack (KB)
- Some notes have structured data extracted (for actions)
- Some notes create external actions (contacts, events, todos)
- All notes are searchable, linkable, taggable

**The "action" is what happens WITH the note, not what happens TO it.**

---

## Summary

**The Action/Knowledge split is too binary. The real model is: Action AND Knowledge simultaneously.**

**Better model:**
- Everything goes to KB (searchable repository) ✅
- Actionable items ALSO create external actions (contacts, events, todos) ✅
- Structured data extraction happens for all relevant notes (expenses, meetings, etc.) ✅
- Archive when done (not a separate "log") ✅
- Use intent detection for context-dependent behavior (meetings) ✅
- Use tags for differentiation (shopping, recipes, etc.) ✅
- Support multiple simultaneous intents (expense = track + remember) ✅

**The app should feel like:** "I'll figure out what this is and what to do with it. You just capture it."

**Key insight:** The "action" is metadata and external integrations, not a separate state. Everything stays in the KB.

---

## Multi-Section Notes: Shopping List + Journal Entry on Same Page

### The Question

> "What if there are multiple note types on the same scanned page? Say a shopping list and a more general style journal entry. What's the flow then?"

### Current Implementation

The app **already supports multi-section notes** via `splitIntoSections()`:

1. **OCR processes entire page** → Gets full text
2. **`splitIntoSections()` detects hashtags** → Splits by `#todo#`, `#meeting#`, etc.
3. **Each section saved as separate note** → Different types, same image (first section only)
4. **Image attached to first section only** → Avoids duplication

**Example:**
```
Page content:
"#todo# Buy milk, eggs, bread
#meeting# Q4 Planning with Sarah"

Result:
- Note 1: type=todo, content="Buy milk, eggs, bread", has image
- Note 2: type=meeting, content="Q4 Planning with Sarah", no image
```

### The Problem: No Hashtags

**Current limitation:** If there are NO hashtags, the entire page is classified as one type.

**User's scenario:**
```
Page content (no hashtags):
"Shopping List:
- Milk
- Eggs
- Bread

Today I had a great meeting with Sarah about Q4 planning..."

Current behavior: Entire page → type=general (or whatever classifier thinks)
Desired: Split into shopping list + journal entry
```

### Solution: LLM-Based Section Detection

**Enhance `splitIntoSections()` to use LLM when no hashtags detected:**

1. **If hashtags found** → Use current tag-based splitting ✅
2. **If no hashtags** → Use LLM to detect semantic sections:
   ```
   "Analyze this text and identify distinct sections that should be separate notes.
   Return JSON with sections: [{type, content, startIndex, endIndex}]
   
   Example: Shopping list + journal entry should be split."
   ```

3. **LLM returns sections** → Each saved as separate note
4. **User can review/merge** → "I found 2 sections. Split into separate notes?" [Yes] [No, keep together]

### Enhanced Flow for Multi-Section Notes

**Step 1: OCR** → Full text from page

**Step 2: Section Detection**
- Check for hashtags first (fast, explicit)
- If no hashtags → LLM semantic detection (slower, intelligent)

**Step 3: Section Preview**
- Show user: "I found 2 sections: Shopping List + Journal Entry"
- Options:
  - [Split into 2 notes] (default)
  - [Keep as 1 note] (user override)
  - [Edit sections] (user can adjust boundaries)

**Step 4: Save**
- Each section → Separate note
- First section gets original image
- Other sections link to first (via NoteLink) OR reference same image

### Image Handling for Multi-Section Notes

**Option A: First Section Only (Current)**
- First section: Has full image
- Other sections: No image, but link to first section
- **Pros:** Simple, no duplication
- **Cons:** Other sections can't see their part of image

**Option B: Crop Image Per Section**
- Detect section boundaries in image
- Crop image for each section
- Each section has its portion of image
- **Pros:** Each section has relevant image
- **Cons:** Complex, requires image analysis

**Option C: All Sections Share Same Image**
- All sections reference same original image
- Each section highlights its region (optional)
- **Pros:** Simple, preserves context
- **Cons:** Image not section-specific

**Recommendation: Option C (with Option B as future enhancement)**
- All sections share same image
- Add visual indicator showing which section is which (highlight region)
- Future: Smart cropping based on text position

### Implementation Plan

**Phase 1: LLM Section Detection (High Priority)**

1. **Enhance `splitIntoSections()`:**
   ```swift
   func splitIntoSections(content: String) async -> [NoteSection] {
       // 1. Check for hashtags (fast path)
       let tagSections = detectTagSections(content)
       if !tagSections.isEmpty {
           return tagSections
       }
       
       // 2. LLM semantic detection (slow path)
       return await detectSemanticSections(content)
   }
   ```

2. **Add LLM prompt:**
   ```
   "Analyze this text and identify distinct sections that should be separate notes.
   A section is a coherent piece of content with a clear purpose.
   
   Examples:
   - Shopping list + journal entry → 2 sections
   - Meeting notes with action items → 1 section (but extract todos)
   - Recipe + notes about modifications → 2 sections
   
   Return JSON: [{type: "todo|general|meeting|...", content: "...", reasoning: "..."}]
   ```

3. **Add section preview UI:**
   - Show detected sections before saving
   - User can merge/split/adjust

**Phase 2: Image Region Highlighting (Medium Priority)**

1. **Detect text regions in image** (Vision framework)
2. **Map sections to image regions**
3. **Show highlighted regions in section preview**

**Phase 3: Smart Image Cropping (Future)**

1. **Crop image per section** based on text position
2. **Each section has its portion of image**

### Example Flow: Shopping List + Journal Entry

**User captures page with:**
```
Shopping List:
- Milk
- Eggs
- Bread

Today I had a great meeting with Sarah about Q4 planning. We discussed the budget and timeline.
```

**App flow:**
1. OCR → Full text extracted
2. No hashtags detected → LLM semantic detection
3. LLM detects:
   - Section 1: "Shopping List: ..." → type=todo, tag=shopping
   - Section 2: "Today I had..." → type=general, tag=journal
4. Preview shown:
   ```
   "I found 2 sections:
   
   📝 Shopping List (Todo)
   - Milk, Eggs, Bread
   
   📔 Journal Entry (General)
   - Meeting notes about Q4 planning
   
   [Split into 2 notes] [Keep as 1 note]"
   ```
5. User: [Split into 2 notes]
6. App saves:
   - Note 1: type=todo, content="Shopping List: ...", tags=["shopping"], has image
   - Note 2: type=general, content="Today I had...", tags=["journal"], links to Note 1's image

**Both notes searchable, linkable, with shared image context.**
