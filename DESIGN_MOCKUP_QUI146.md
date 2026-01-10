# QUI-146 Design Mockup - Practical Approach

## Design Philosophy
**Consistency First** - One cohesive design language with subtle per-type refinements
- Clean, readable formatting across all types
- Smart title extraction (not just first line)
- Subtle color accents per type (not dramatic theming)
- OCR cleanup for better readability

---

## 1. Better Title Extraction

### Current Problem
```
Todo List Title: "[ ] Buy groceries"  ❌
Meeting Title: "Met with John to discuss"  ❌
Email Title: "Hey Mike,"  ❌
```

### Proposed Solution
```swift
// Smart title extraction rules:

TODO:
- Skip checkbox lines entirely
- Look for header-like text (short, no checkbox)
- Fall back to: "Todo List - Jan 6"
Example: "[ ] Buy milk\n[ ] Call dentist\nGrocery Run" → "Grocery Run"

MEETING:
- Extract from "Meeting with X" or "X Meeting"
- Look for participant names
- Fall back to: "Meeting - Jan 6"
Example: "Meeting with Sarah\n- Discussed Q1 goals" → "Meeting with Sarah"

EMAIL:
- Extract from "Subject:" line
- Or "Re:" line
- Fall back to: "Email from [sender]" or "Email - Jan 6"
Example: "Subject: Project Update\nHey team," → "Project Update"

RECIPE:
- Look for title-like first line (capitalized, short)
- Or scan for "Recipe:" prefix
- Fall back to: "Recipe - Jan 6"

GENERAL/IDEA/JOURNAL:
- Use first meaningful sentence (< 50 chars)
- Skip bullets/checkboxes
- Fall back to: "[Type] - Jan 6"
```

---

## 2. OCR Text Cleanup

### Current Artifacts
```
[ ] Task one          → Checkbox artifact
() Another task       → Parentheses artifact
l Weird bullet        → OCR "l" as bullet
- Item                → Good (keep)
```

### Cleanup Rules
```swift
// Normalize common OCR mistakes:

"[ ]"  → "☐"  (unchecked box)
"[x]"  → "☑"  (checked box)
"[X]"  → "☑"  (checked box)
"( )"  → "○"  (hollow bullet)
"(x)"  → "●"  (filled bullet)

// Fix bullet artifacts:
"l "   → "• "  (OCR mistake: lowercase L as bullet)
"I "   → "• "  (OCR mistake: capital I as bullet)

// Preserve good formatting:
"- "   → "• "  (normalize to bullet)
"* "   → "• "  (normalize to bullet)
"• "   → "• "  (keep)
```

---

## 3. Consistent Visual Design

### Color System (Subtle Per-Type Accents)
All views share same layout/structure, just accent color changes:

```
┌─────────────────────────────────┐
│ [Icon] Smart Title              │ ← accent color
│ Jan 6, 2026                     │
├─────────────────────────────────┤
│                                 │
│ Clean, formatted content        │
│ with proper bullets:            │
│   • Task one                    │
│   • Task two                    │
│                                 │
│ No artifacts, good spacing      │
│                                 │
└─────────────────────────────────┘
  ↑ subtle accent underline

Accent colors (from existing badges):
- Todo: .badgeTodo (golden)
- Meeting: .badgeMeeting (teal)
- Email: .badgeEmail (plum)
- Recipe: .badgeRecipe (indian red)
- etc.
```

### Typography Consistency
```swift
// ONE typography system for all types:

Title: .system(.title2, weight: .bold)  // 22pt
Date: .system(.subheadline)             // 15pt
Body: .system(.body)                    // 17pt
Metadata: .system(.caption)             // 12pt

// Optional: Per-type font design hints
- Code: .monospaced design
- Recipe: .rounded design
- Journal: .serif design
- Rest: .default design
```

---

## 4. Smart Formatting Per Type

### Todo Lists
```
✓ Clean checkboxes (☐ ☑)
✓ Progress indicator: "3 of 5 completed"
✓ Strikethrough completed items
✓ Indent sub-tasks
```

### Meetings
```
✓ Extract participants if present
✓ Highlight action items (lines with "TODO:", "ACTION:")
✓ Preserve bullet hierarchy
```

### Recipes
```
✓ Detect "Ingredients:" and "Instructions:" sections
✓ Make ingredient lines checkable
✓ Format times (e.g., "30min", "2 hours")
```

### Emails
```
✓ Extract To/From/Subject if present
✓ Format quoted text (lines starting with >)
✓ Preserve formatting
```

### Other Types
```
✓ Clean bullets
✓ Preserve spacing
✓ Good line height
```

---

## 5. Implementation Scope

### Core Services (Simple)
```swift
// 1. OCRNormalizer.swift
static func cleanText(_ text: String) -> String {
    // Replace artifacts: [], (), etc.
    // Fix bullet mistakes: l → •
    // Normalize spacing
}

// 2. TitleExtractor.swift
static func extractTitle(content: String, type: NoteType) -> String {
    // Type-specific rules
    // Smart fallbacks
    // Max 50 chars
}

// 3. TextFormatter.swift
static func format(_ text: String, for type: NoteType) -> AttributedString {
    // Apply type-specific formatting
    // Checkboxes, bullets, etc.
}
```

### Visual Changes (Minimal)
```swift
// Update existing detail views:
// 1. Use smart title extraction
// 2. Clean text with OCRNormalizer
// 3. Apply subtle accent color
// 4. Format content with TextFormatter
```

---

## 6. Before/After Examples

### Todo List
**Before:**
```
Title: "[ ] Buy milk"
Content:
[ ] Buy milk
[ ] Call dentist
() Pick up dry cleaning
```

**After:**
```
Title: "Shopping & Errands"  ← smart extraction
Content:
☐ Buy milk
☐ Call dentist
☐ Pick up dry cleaning
Progress: 0 of 3 completed
```

### Meeting Notes
**Before:**
```
Title: "Met with John about Q1"
Content:
Met with John about Q1
l Discussed revenue targets
l Need to hire 2 engineers
```

**After:**
```
Title: "Meeting with John"  ← extracted participant
Content:
• Discussed revenue targets
• Need to hire 2 engineers
```

---

## Summary

### What Changes:
✓ Smart title extraction (not just first line)
✓ OCR cleanup ([], (), l → proper symbols)
✓ Subtle color accents per type
✓ Type-aware formatting (checkboxes, progress, etc.)

### What Stays Consistent:
✓ Same layout structure for all types
✓ Same typography system
✓ Same spacing and padding
✓ Same overall design language

### Complexity:
- 3 small utility services (~200 lines total)
- Minor updates to existing detail views
- No dramatic redesigns
- Easy to maintain

---

## Your Feedback Needed:

1. **Title extraction**: Good approach? Any types need special handling?
2. **OCR cleanup**: Are these the right artifacts to fix?
3. **Visual consistency**: Too subtle? Need more differentiation?
4. **Formatting rules**: Any type-specific needs I'm missing?

Let me know if this direction feels right, and I'll implement it!
