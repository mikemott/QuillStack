# QuillStack Visual Structure

**Date:** 2025-01-27  
**Based on:** Refocus conversations about tag-based architecture, Action AND Knowledge model

---

## Core Principles

1. **Capture-first** - Camera is primary, everything else is secondary
2. **Tag-based, not type-based** - Tags drive everything (formatting, actions, organization)
3. **Everything in KB** - All notes searchable, no separate "log"
4. **Invisible intelligence** - App figures it out, user just captures
5. **Smart organization** - Auto-collections, related notes, tag-based filtering

---

## Main Navigation (Bottom Tab Bar)

### Tab 1: **Capture** (Primary - Camera Icon)
- **Purpose:** Main entry point, camera-first
- **Default view:** Camera ready to capture
- **Secondary actions:** Photo library import, recent captures
- **No "Type Guide"** - App just works

### Tab 2: **Notes** (KB - Document Icon)
- **Purpose:** Your knowledge base - everything searchable
- **Default view:** All notes, newest first
- **Organization:** Smart collections, tag filters, archive
- **No type badges** - Show primary tag badge instead

### Tab 3: **Search** (Magnifying Glass Icon)
- **Purpose:** Powerful search across all notes
- **Features:** Tag-based, semantic search, filters
- **Quick access:** Recent searches, saved filters

### Tab 4: **Settings** (Gear Icon)
- **Purpose:** App configuration, API keys, preferences
- **No "Type Guide"** - Move to Settings if needed

---

## Capture Flow

### Screen 1: Camera View
- **Full-screen camera** with capture button
- **Flash toggle** (top-left)
- **Gallery button** (top-right) - Photo library import
- **Minimal UI** - Focus on capture

### Screen 2: Processing View
- **Progress indicator** - "Processing your note..."
- **No type selection** - App figures it out
- **Background processing** - OCR, LLM, tag suggestion

### Screen 3: Section Preview (if multiple sections detected)
```
┌─────────────────────────────────────┐
│ I found 2 sections:                 │
│                                     │
│ 📝 Shopping List                    │
│ Tags: todo, shopping                │
│ - Milk, Eggs, Bread                 │
│                                     │
│ 📔 Meeting Notes                    │
│ Tags: meeting, work, q4            │
│ - Discussed Q4 budget with Sarah    │
│                                     │
│ [Split into 2 notes] [Keep as 1]   │
└─────────────────────────────────────┘
```

### Screen 4: Tag Review (optional)
- **Show suggested tags** - User can accept/reject/modify
- **Quick actions** - "Create contact?", "Add to calendar?"
- **Save** - Note goes to KB

---

## Notes View (Knowledge Base)

### Header
- **Search bar** - Quick search across all notes
- **Filter button** - Tag-based filters, date range, etc.

### Main Content: List View

**Note Card Design:**
```
┌─────────────────────────────────────┐
│ [todo] [shopping]  📅 Jan 27        │
│                                     │
│ Shopping List:                      │
│ - Milk                              │
│ - Eggs                              │
│ - Bread                             │
│                                     │
│ 12 words  •  95% confidence         │
└─────────────────────────────────────┘
```

**Key elements:**
- **Primary tag badge** (not type badge) - Color-coded
- **Additional tags** - Small chips below badge
- **Date** - When captured
- **Preview text** - First few lines
- **Metadata** - Word count, OCR confidence

### Smart Collections (Auto-Organized)

**Sections in Notes view:**
- **Recent** - Last 7 days
- **This Week** - Auto-grouped by week
- **By Tag** - Most used tags (contact, todo, meeting, etc.)
- **Related** - Notes linked together
- **Archive** - Archived notes (collapsed by default)

### Filtering

**Filter sheet:**
- **Tags** - Multi-select tag filter
- **Date range** - Last week, month, year, custom
- **Has actions** - Notes that created contacts/events
- **Has links** - Notes with cross-references
- **Archive** - Include archived notes

---

## Detail View (Tag-Driven)

### Header
- **Primary tag badge** - Large, color-coded
- **All tags** - Chips showing all tags
- **Edit tags** - Tap to add/remove tags
- **Share/Export** - Actions based on tags

### Content Area

**Tag-specific views:**
- **`tag:contact`** → ContactDetailView (create contact button)
- **`tag:event`** → EventDetailView (add to calendar button)
- **`tag:todo`** → TodoDetailView (extract todos)
- **`tag:meeting`** → MeetingDetailView (create meeting)
- **Default** → NoteDetailView (general note)

**All views show:**
- **Original image** - Full-screen image viewer
- **OCR text** - Editable content
- **Extracted data** - Structured data (if available)
- **Related notes** - Auto-linked notes
- **Actions** - Based on tags (create contact, add to calendar, etc.)

### Bottom Bar

**Actions based on tags:**
- **`tag:contact`** → "Create Contact" button
- **`tag:event`** → "Add to Calendar" button
- **`tag:todo`** → "Extract Todos" button
- **Always:** Edit, Archive, Delete, Share

---

## Search View

### Search Bar
- **Instant search** - As you type
- **Tag autocomplete** - "tag:contact", "tag:work"
- **Semantic search** - "meetings with Sarah"

### Results

**Grouped by:**
- **Best match** - Most relevant
- **By tag** - Grouped by primary tag
- **By date** - Recent first

**Result card:**
- Shows matching text highlighted
- Primary tag badge
- Related tags
- Quick preview

### Filters

**Quick filters:**
- **Tags** - Filter by specific tags
- **Date** - Last week, month, year
- **Has actions** - Created contacts/events
- **Has links** - Cross-referenced notes

---

## Smart Collections (Auto-Organized)

### In Notes View

**Auto-generated sections:**
- **Recent** - Last 7 days
- **This Week** - Grouped by week
- **By Person** - "Notes mentioning Sarah"
- **By Project** - "Notes about Q4"
- **By Tag** - Most used tags
- **Related** - Notes linked together

**Collection card:**
```
┌─────────────────────────────────────┐
│ 📁 Notes mentioning Sarah            │
│ 5 notes • Last updated: Jan 27      │
│                                     │
│ [View Collection →]                 │
└─────────────────────────────────────┘
```

---

## Archive View

### Access
- **In Notes view** - Swipe down to reveal archive
- **Or** - Filter toggle "Include archived"

### Design
- **Collapsed by default** - Archive is secondary
- **Grouped by date** - "Archived this month"
- **Restore action** - Swipe to restore

---

## Visual Design Language

### Colors

**Tag-based color system:**
- **Primary tag** - Determines badge color
- **Color palette:**
  - `contact` → Blue
  - `event` → Purple
  - `todo` → Orange
  - `meeting` → Green
  - `general` → Gray

### Typography

**Hierarchy:**
- **Headlines** - Serif, bold (note titles)
- **Body** - Serif, regular (note content)
- **Metadata** - Sans-serif, small (tags, dates)

### Icons

**Tag-based icons:**
- **Primary tag** - Determines icon
- **SF Symbols** - Consistent iconography
- **No type-specific icons** - Tags drive icons

---

## Key Differences from Current Design

### ❌ Remove
- **Type Guide tab** - App should just work
- **Type badges** - Replace with tag badges
- **Type picker** - No manual type selection
- **Type-based routing** - Use primary tag instead

### ✅ Add
- **Tag badges** - Primary tag + additional tags
- **Section preview** - Multi-section detection
- **Tag review** - Accept/reject suggested tags
- **Smart collections** - Auto-organized sections
- **Related notes** - Auto-linked notes section
- **Tag-based actions** - Actions based on tags

---

## User Flow Examples

### Flow 1: Capture Business Card

1. **Capture tab** → Camera
2. **Take photo** → Business card
3. **Processing** → OCR + LLM
4. **Tag suggestion** → `["contact", "work"]`
5. **Preview** → "Create contact?" [Yes]
6. **Saves** → Note in KB with `tags=["contact", "work"]`
7. **Creates** → iOS contact
8. **Done** → Back to camera

### Flow 2: Capture Shopping List + Journal Entry

1. **Capture tab** → Camera
2. **Take photo** → Page with shopping list + journal
3. **Processing** → OCR + LLM section detection
4. **Section preview** → "I found 2 sections..."
5. **User** → [Split into 2 notes]
6. **Saves** → 
   - Note 1: `tags=["todo", "shopping"]`
   - Note 2: `tags=["general", "journal"]`
7. **Done** → Back to camera

### Flow 3: Search for Notes

1. **Search tab** → Search bar
2. **Type** → "meetings with Sarah"
3. **Results** → Semantic search results
4. **Filter** → Add `tag:work` filter
5. **View note** → Tap result
6. **Detail view** → Shows note with related notes

---

## Summary

**Visual structure reflects:**
- **Capture-first** - Camera is primary tab
- **Tag-based** - Tags drive formatting and actions
- **KB-centric** - Everything searchable, no separate log
- **Invisible intelligence** - App figures it out
- **Smart organization** - Auto-collections, related notes

**The app feels like:** "Just capture, I'll figure it out and organize it for you."
