# QuillStack Feature Brainstorm

**Core Concept:** Bridging analog with digital - bringing order to notes, bits of paper, receipts, fliers, etc.

**Date:** 2025-01-27

---

## Current Feature Set

- Camera capture with OCR
- 12 note types (todo, email, meeting, contact, reminder, expense, shopping, recipe, event, idea, claudePrompt, general)
- LLM enhancement
- Handwriting learning
- Offline mode
- Photo library import
- Export integrations (GitHub, Notion)
- iCloud sync (planned)

---

## Feature Ideas

### 📋 **Organization & Discovery**

#### 1. **Smart Collections / Auto-Folders**
- **Concept:** Automatically group related notes into collections based on content, date, or context
- **Examples:**
  - "Receipts from January 2025" (all expense notes from same month)
  - "Meeting Notes - Project Alpha" (meetings mentioning same project)
  - "Shopping Lists - Groceries" (all grocery shopping lists)
- **Implementation:** Use LLM to detect project names, topics, or themes across notes
- **UI:** Collections appear as folders in note list, can be manually created/edited
- **Value:** Reduces clutter, makes finding related notes easier

#### 2. **Temporal Linking**
- **Concept:** Automatically link notes that reference the same event, person, or topic
- **Examples:**
  - Meeting note mentions "follow up with Sarah" → links to contact note for Sarah
  - Expense note for "lunch with John" → links to contact note for John
  - Todo "Review Q4 report" → links to meeting note where it was discussed
- **Implementation:** Named entity recognition, fuzzy matching of names/topics
- **UI:** "Related Notes" section in detail view, bidirectional links
- **Value:** Creates a knowledge graph of your analog notes

#### 3. **Smart Search with Context**
- **Concept:** Search that understands context, not just keywords
- **Examples:**
  - "receipts from coffee shops" → finds all expense notes mentioning coffee
  - "meetings with Sarah" → finds all meeting notes with Sarah as attendee
  - "ideas about mobile apps" → finds idea notes with mobile/app keywords
- **Implementation:** Semantic search using embeddings or LLM-based query understanding
- **UI:** Enhanced search bar with suggested queries
- **Value:** Find notes by meaning, not just exact text match

#### 4. **Note Templates / Quick Capture**
- **Concept:** Pre-defined templates for common note types
- **Examples:**
  - "Weekly Grocery List" template with common categories
  - "Meeting Notes" template with sections (Attendees, Agenda, Action Items)
  - "Expense Report" template with fields (Date, Amount, Category, Receipt)
- **Implementation:** Template system that pre-fills note structure, user can customize
- **UI:** Template picker before/after capture, or apply template to existing note
- **Value:** Faster capture, consistent structure for similar notes

---

### 🧾 **Receipt & Document Management**

#### 5. **Receipt OCR Enhancement**
- **Concept:** Specialized OCR and extraction for receipts
- **Features:**
  - Extract: merchant name, date, total amount, line items, tax, tip
  - Auto-categorize expenses (food, travel, office supplies, etc.)
  - Detect currency and convert if needed
  - Extract receipt numbers for warranty tracking
- **Implementation:** Vision framework for structured text detection, LLM for extraction
- **UI:** Receipt detail view with extracted fields, editable
- **Value:** Makes expense tracking automatic and accurate

#### 6. **Receipt Expiration Tracking**
- **Concept:** Track warranty periods, return windows, expiration dates from receipts
- **Features:**
  - Auto-detect return policy (30 days, 90 days, etc.)
  - Set reminders for warranty expiration
  - Track items with warranties (electronics, appliances)
- **Implementation:** Parse receipt text for dates, calculate expiration dates
- **UI:** "Warranties" view showing items with active warranties, expiration dates
- **Value:** Never miss a return window or warranty claim

#### 7. **Multi-Page Document Capture**
- **Concept:** Capture multi-page documents (receipts, contracts, multi-page notes)
- **Features:**
  - "Add Page" button to append additional photos to same note
  - Automatic page numbering
  - Stitch together for continuous reading
- **Implementation:** Note entity supports multiple images, page order tracking
- **UI:** Page indicator, swipe between pages, "Add Page" button
- **Value:** Handle real-world multi-page documents

#### 8. **Document Type Detection**
- **Concept:** Auto-detect document types beyond receipts
- **Types:**
  - Receipts (already handled)
  - Business cards (already handled)
  - Invoices
  - Contracts
  - Medical records
  - Insurance cards
  - ID cards
  - Event tickets
- **Implementation:** Visual pattern recognition + text analysis
- **UI:** Specialized detail views for each document type
- **Value:** Appropriate handling for each document type

---

### 📅 **Time & Location Context**

#### 9. **Location Tagging**
- **Concept:** Automatically tag notes with location where captured
- **Features:**
  - "Notes from [Location]" smart collection
  - Map view showing where notes were captured
  - Location-based reminders ("When I'm near Target, remind me about shopping list")
- **Implementation:** Core Location for capture location, reverse geocoding for place names
- **UI:** Location badge on notes, map view in app
- **Value:** Contextual organization, location-based workflows

#### 10. **Time-Based Smart Collections**
- **Concept:** Auto-organize notes by time patterns
- **Examples:**
  - "Morning Notes" (captured 6am-12pm)
  - "Weekend Receipts" (expenses from Saturday/Sunday)
  - "Monthly Summaries" (all notes from a month)
- **Implementation:** Date/time metadata already captured, add filtering/grouping
- **UI:** Time-based filters in note list
- **Value:** Find notes by when they were created

#### 11. **Recurring Note Detection**
- **Concept:** Detect and group recurring notes (weekly shopping lists, daily standups)
- **Features:**
  - "This looks like your weekly grocery list" prompt
  - Compare similar notes to show changes over time
  - Template extraction from recurring notes
- **Implementation:** Content similarity matching, date pattern detection
- **UI:** "Recurring Notes" section, diff view for similar notes
- **Value:** Track changes in recurring activities

---

### 🔗 **Integration & Workflow**

#### 12. **Calendar Integration**
- **Concept:** Sync event and reminder notes to iOS Calendar
- **Features:**
  - Event notes → Calendar events
  - Reminder notes → Calendar reminders
  - Meeting notes → Link to existing calendar event
- **Implementation:** EventKit framework for calendar access
- **UI:** "Add to Calendar" button in event/reminder detail views
- **Value:** Bridge analog notes with digital calendar

#### 13. **Contacts Integration**
- **Concept:** Sync contact notes to iOS Contacts app
- **Features:**
  - Business card capture → Create contact
  - Extract phone/email from any note → Quick add to contacts
  - Link notes to existing contacts
- **Implementation:** Contacts framework
- **UI:** "Add to Contacts" button, contact picker for linking
- **Value:** One less place to manage contact info

#### 14. **Email Integration**
- **Concept:** Send email notes directly from app
- **Features:**
  - Email note type → Compose email in Mail app
  - Extract recipient from note content
  - Attach receipt/note image to email
- **Implementation:** Mail framework, MFMailComposeViewController
- **UI:** "Send Email" button in email note detail view
- **Value:** Complete the email workflow without leaving app

#### 15. **Shortcuts / Automation**
- **Concept:** Siri Shortcuts and iOS Shortcuts app integration
- **Examples:**
  - "Hey Siri, add to shopping list" → captures photo, creates shopping note
  - "Add expense" shortcut → quick expense capture
  - "What did I write about [topic]?" → search notes via Siri
- **Implementation:** Intents framework, Shortcuts app integration
- **UI:** Shortcuts configuration in Settings
- **Value:** Voice-first workflows, automation

#### 16. **Share Sheet Integration**
- **Concept:** Accept content from other apps via share sheet
- **Features:**
  - Share image from Photos → Create note
  - Share text from Safari → Create note
  - Share PDF → Create note with PDF attachment
- **Implementation:** Share extension, document picker
- **UI:** QuillStack appears in share sheet
- **Value:** Capture from anywhere, not just camera

---

### 🎨 **Visual & UX Enhancements**

#### 17. **Note Thumbnails with Preview**
- **Concept:** Show note preview in list view
- **Features:**
  - Thumbnail of captured image
  - First few lines of OCR text
  - Quick actions (swipe to delete, mark complete for todos)
- **Implementation:** Image thumbnails, text preview
- **UI:** Enhanced list view with images
- **Value:** Visual recognition, faster scanning

#### 18. **Handwriting Style Preservation**
- **Concept:** Option to view notes in original handwriting style
- **Features:**
  - Toggle between OCR text and original image
  - Side-by-side view
  - Highlight OCR confidence (low confidence = show original)
- **Implementation:** Image display with text overlay option
- **UI:** Toggle button in detail view
- **Value:** Preserve analog feel, verify OCR accuracy

#### 19. **Note Sketches / Drawings**
- **Concept:** Support for handwritten sketches, diagrams, drawings
- **Features:**
  - Detect when note is primarily drawing vs text
  - Special "sketch" note type
  - Drawing tools for annotation
- **Implementation:** Image analysis to detect drawing vs text, drawing canvas
- **UI:** Sketch detail view with zoom/pan
- **Value:** Capture diagrams, mind maps, visual notes

#### 20. **Color-Coded Notes**
- **Concept:** Visual organization with colors
- **Features:**
  - Auto-assign colors by note type (or user choice)
  - Color tags for custom organization
  - Filter by color
- **Implementation:** Color property on Note entity
- **UI:** Color picker, color-coded list view
- **Value:** Quick visual organization

---

### 📊 **Analytics & Insights**

#### 21. **Spending Insights**
- **Concept:** Analyze expense notes for spending patterns
- **Features:**
  - Monthly spending summaries
  - Category breakdown (food, travel, etc.)
  - Trends over time
  - "You spent $X on coffee this month"
- **Implementation:** Aggregate expense notes, categorize, calculate totals
- **UI:** "Insights" tab with charts and summaries
- **Value:** Financial awareness from analog receipts

#### 22. **Productivity Insights**
- **Concept:** Analyze todo and meeting notes for productivity patterns
- **Features:**
  - Todo completion rate
  - Most productive times of day
  - Meeting frequency and duration estimates
  - "You completed 80% of todos this week"
- **Implementation:** Analyze todo completion, meeting patterns
- **UI:** Dashboard with metrics
- **Value:** Self-awareness, productivity optimization

#### 23. **Note Frequency Patterns**
- **Concept:** Show when and what you capture most
- **Features:**
  - "You capture most notes on Mondays"
  - "Most common note type: Shopping lists"
  - "You haven't captured a receipt in 2 weeks"
- **Implementation:** Aggregate note metadata
- **UI:** Insights view
- **Value:** Understand your own habits

---

### 🔍 **Advanced OCR & AI**

#### 24. **Multi-Language OCR**
- **Concept:** Support OCR for multiple languages
- **Features:**
  - Auto-detect language
  - Support for common languages (Spanish, French, Chinese, etc.)
  - Language-specific spell correction
- **Implementation:** Vision framework supports multiple languages
- **UI:** Language selector, auto-detection indicator
- **Value:** International users, multilingual notes

#### 25. **Table Extraction**
- **Concept:** Extract structured data from tables in notes
- **Features:**
  - Detect tables in handwritten notes
  - Extract rows and columns
  - Convert to structured format (CSV, markdown table)
- **Implementation:** Vision framework table detection, LLM for structure extraction
- **UI:** Table view in detail view, export as CSV
- **Value:** Capture structured data (budgets, schedules, etc.)

#### 26. **Math & Formula Recognition**
- **Concept:** Recognize and preserve mathematical notation
- **Features:**
  - Detect equations and formulas
  - Preserve as image (don't try to OCR)
  - Optional: Convert to LaTeX
- **Implementation:** Image analysis to detect math notation
- **UI:** Math notation preserved as image, LaTeX export option
- **Value:** Capture technical notes, equations

#### 27. **Signature Detection**
- **Concept:** Detect and extract signatures from documents
- **Features:**
  - Identify signature areas
  - Extract signature image
  - Link to document for verification
- **Implementation:** Vision framework for signature detection
- **UI:** Highlight signature areas, extract button
- **Value:** Document verification, contract management

---

### 🗂️ **Physical Organization Bridge**

#### 28. **Physical Location Tracking**
- **Concept:** Track where physical documents are stored
- **Features:**
  - "This receipt is in the blue folder in my desk"
  - Link digital note to physical location
  - "Where did I put that?" search
- **Implementation:** Custom location field, search
- **UI:** Location field in note detail, location-based search
- **Value:** Bridge digital and physical organization

#### 29. **Document Scanning Workflow**
- **Concept:** Optimized workflow for scanning documents in bulk
- **Features:**
  - "Scan Mode" for rapid document capture
  - Auto-advance to next capture
  - Batch processing
  - "Scan 10 receipts" mode
- **Implementation:** Camera session optimization, batch capture
- **UI:** Scan mode toggle, progress indicator
- **Value:** Efficient bulk digitization

#### 30. **Duplicate Detection**
- **Concept:** Detect if you've already captured a document
- **Features:**
  - "You may have already captured this receipt"
  - Compare images for similarity
  - Merge duplicates
- **Implementation:** Image similarity comparison, hash-based detection
- **UI:** Duplicate warning, merge option
- **Value:** Avoid duplicate entries

---

### 🎯 **Specialized Use Cases**

#### 31. **Recipe Enhancement**
- **Concept:** Enhanced recipe note type
- **Features:**
  - Extract ingredients list
  - Extract cooking instructions
  - Convert measurements (cups to ml, etc.)
  - Link to similar recipes
  - Shopping list generation from recipe
- **Implementation:** LLM extraction, measurement conversion library
- **UI:** Recipe detail view with structured sections
- **Value:** Better recipe management

#### 32. **Event Planning**
- **Concept:** Enhanced event note type for planning
- **Features:**
  - Extract event details (date, time, location, attendees)
  - Create todo list from event note
  - Link related notes (venue receipt, guest list, etc.)
  - Countdown timer to event
- **Implementation:** Enhanced event parsing, todo generation
- **UI:** Event planning dashboard
- **Value:** Complete event management from analog notes

#### 33. **Meeting Action Items**
- **Concept:** Enhanced meeting note type
- **Features:**
  - Auto-extract action items
  - Assign action items to attendees
  - Create todos from action items
  - Meeting summary generation
- **Implementation:** LLM extraction, todo creation
- **UI:** Action items section, attendee assignment
- **Value:** Better meeting follow-through

#### 34. **Shopping List Intelligence**
- **Concept:** Enhanced shopping list note type
- **Features:**
  - Categorize items (produce, dairy, etc.)
  - Suggest stores based on items
  - Price tracking (if receipts linked)
  - "You usually buy these items together" suggestions
- **Implementation:** Item categorization, pattern detection
- **UI:** Organized shopping list by category
- **Value:** Smarter shopping

---

### 🔐 **Privacy & Security**

#### 35. **Secure Notes / Locked Notes**
- **Concept:** Password-protect sensitive notes
- **Features:**
  - Lock individual notes with Face ID / Touch ID
  - Secure folder for sensitive documents
  - Auto-lock after viewing
- **Implementation:** Keychain for encryption, biometric authentication
- **UI:** Lock icon, authentication prompt
- **Value:** Privacy for sensitive information

#### 36. **Note Expiration / Auto-Delete**
- **Concept:** Set notes to auto-delete after a period
- **Features:**
  - "Delete this receipt after 1 year"
  - "Delete this todo after completion"
  - Expiration reminders
- **Implementation:** Expiration date field, background cleanup
- **UI:** Expiration setting in note detail
- **Value:** Automatic cleanup, privacy

---

### 🌐 **Collaboration**

#### 37. **Shared Collections**
- **Concept:** Share collections of notes with others
- **Features:**
  - "Share this shopping list with my partner"
  - "Share meeting notes with team"
  - Read-only or editable sharing
- **Implementation:** CloudKit sharing, or export/share links
- **UI:** Share button, sharing settings
- **Value:** Collaborative organization

#### 38. **Family Receipt Sharing**
- **Concept:** Share expense notes with family members
- **Features:**
  - Shared expense tracking
  - Split expenses
  - Family budget insights
- **Implementation:** CloudKit sharing, expense aggregation
- **UI:** Family sharing settings, shared expense view
- **Value:** Household financial coordination

---

## Prioritization Framework

### High Impact, Low Effort (Quick Wins)
- Note Thumbnails with Preview (#17)
- Share Sheet Integration (#16)
- Color-Coded Notes (#20)
- Handwriting Style Preservation (#18)

### High Impact, High Effort (Major Features)
- Smart Collections / Auto-Folders (#1)
- Receipt OCR Enhancement (#5)
- Calendar Integration (#12)
- Spending Insights (#21)

### Medium Impact, Medium Effort
- Location Tagging (#9)
- Multi-Page Document Capture (#7)
- Shortcuts / Automation (#15)
- Note Templates (#4)

### Nice to Have (Future)
- Math & Formula Recognition (#26)
- Table Extraction (#25)
- Physical Location Tracking (#28)
- Secure Notes (#35)

---

## Implementation Notes

- Many features can leverage existing infrastructure:
  - LLM service for extraction and classification
  - Core Data for persistence
  - Vision framework for advanced OCR
  - NoteTypePlugin system for extensibility

- Consider user privacy:
  - Location data should be opt-in
  - Biometric authentication for sensitive features
  - Clear data retention policies

- Maintain core simplicity:
  - Don't overwhelm users with features
  - Keep the analog-to-digital bridge clear
  - Focus on workflows users already have

---

## Questions to Consider

1. **What's the most common use case?** (Receipts? Meeting notes? Shopping lists?)
2. **What's the biggest pain point?** (Finding old notes? Organizing? Extracting data?)
3. **What would make users capture more notes?** (Faster capture? Better organization? More integrations?)
4. **What would make users use QuillStack daily?** (Habits? Reminders? Insights?)

---

*This document is a living brainstorm. Features should be validated with user research and prioritized based on impact and effort.*


