# QuillStack Refocus - Linear Issues Plan

## Projects to Create

### 1. **Phase 1: Messaging & Marketing**
- **Timeline**: Week 1 (Pre-Beta)
- **Goal**: Simplify external communication

### 2. **Phase 2: App Structure & Navigation**
- **Timeline**: Week 2 (Beta Polish)
- **Goal**: 4-tab navigation with tag-driven organization

### 3. **Phase 3: Background Intelligence**
- **Timeline**: Week 3 (Intelligence Layer)
- **Goal**: Automatic tagging, linking, extraction

### 4. **Phase 4: Tag Architecture Migration**
- **Timeline**: Week 4 + Post-Beta
- **Goal**: Complete migration from types to tags

### 5. **Phase 5: Enhanced Intelligence**
- **Timeline**: Ongoing (Future)
- **Goal**: Screenshot handling, semantic search, smart collections

---

## Issues to Archive (Not Aligned with New Direction)

- QUI-146: Note Type Visual Themes (moving away from types)
- QUI-145: iOS Integrations Suite (too broad, defer)
- QUI-144: Multi-Page Document Capture (defer)
- QUI-143: Note Templates & Quick Capture (defer)
- QUI-142: Receipt Intelligence Suite (defer)
- QUI-141: Context-Aware Suggestions Engine (defer)
- QUI-138: Project Hierarchy & Organization (defer)
- QUI-134: Add Quote note type (moving away from types)
- QUI-129: Improve LLM classification (evolving to tag-based)

---

## Phase 1: Messaging & Marketing Issues

### QUI-148: Update Website Hero Section
**Priority**: Urgent
**Effort**: Small (2-3 hours)
**Description**:
```
Simplify website hero to focus on "You capture, we figure it out" message.

Changes:
- Headline: "Transform Handwriting Into Action"
- Subhead: "Snap a photo. We'll figure out what to do with it."
- Show 3 visual transformations (not 12 types)
  • Business Card → Contact
  • Meeting Notes → Calendar Event
  • Todo List → Reminders
- Remove 5-chapter tour
- Remove technical jargon

Acceptance Criteria:
- [ ] Hero section loads in <2s
- [ ] All 3 examples have visuals
- [ ] No mention of "types" or "OCR"
- [ ] Privacy message: "We Don't Want Your Data"

Files:
- docs/index.html
```

### QUI-149: Rewrite TestFlight Welcome Email
**Priority**: Urgent
**Effort**: Small (1-2 hours)
**Description**:
```
Simplify onboarding email to emphasize automatic organization.

Key Changes:
- One concrete example (todo list → reminders)
- Add API key setup instructions
- Emphasize "no manual organizing"
- Address privacy proactively

Acceptance Criteria:
- [ ] Email < 300 words
- [ ] Includes API setup link
- [ ] One specific example walkthrough
- [ ] Privacy messaging clear

Files:
- testflight-welcome-worker/src/emailTemplate.ts
```

### QUI-150: Update App Store Description
**Priority**: High
**Effort**: Small (1 hour)
**Description**:
```
Rewrite App Store listing to focus on outcomes, not features.

Structure:
1. Value prop: "QuillStack reads handwritten notes and automatically figures out what to do with them"
2. How it works (3 steps)
3. Key features (4 items)
4. Privacy by design section
5. Perfect for (4 use cases)

Acceptance Criteria:
- [ ] First sentence explains value clearly
- [ ] No technical jargon
- [ ] Privacy messaging prominent
- [ ] < 4000 characters total

Files:
- AppStore/metadata.md
```

### QUI-151: Create Brand Voice Guidelines
**Priority**: Medium
**Effort**: Small (1-2 hours)
**Description**:
```
Document brand voice and messaging standards.

Include:
- Core message
- Do/Don't say lists
- Privacy messaging standards
- Tone examples (good/bad)

Acceptance Criteria:
- [ ] Examples for marketing vs technical contexts
- [ ] Privacy messaging templates
- [ ] Tone guidelines with examples

Files:
- docs/BRAND_VOICE.md
```

---

## Phase 2: App Structure & Navigation Issues

### QUI-152: Implement 4-Tab Bottom Navigation
**Priority**: Urgent
**Effort**: Medium (4-6 hours)
**Description**:
```
Replace current navigation with 4-tab bottom bar.

Tabs:
1. Capture (camera icon) - primary
2. Notes (document icon) - KB view
3. Search (magnifying glass) - semantic search
4. Settings (gear icon) - configuration

Implementation:
- Remove Type Guide tab
- Camera as default tab on launch
- Full-screen camera interface
- Preserve state across tab switches

Acceptance Criteria:
- [ ] 4 tabs visible and functional
- [ ] Capture tab opens camera immediately
- [ ] Tab bar follows iOS design guidelines
- [ ] State preserved when switching tabs

Files:
- App/ContentView.swift
- Create Views/Capture/CaptureTab.swift
- Create Views/Notes/NotesTab.swift
- Create Views/Search/SearchTab.swift
- Update Views/Settings/SettingsView.swift
- Delete Views/TypeGuide/ folder
```

### QUI-153: Create Tag-Based Note Cards
**Priority**: High
**Effort**: Medium (4-5 hours)
**Description**:
```
Design and implement note cards with tag-based visual system.

Features:
- Primary tag badge (large, colored)
- Secondary tags (small chips)
- Preview text (first 2-3 lines)
- Metadata (date, word count, related count)
- Enhanced indicator (✨)
- Processing state indicator (⏳)

Tag Colors:
- contact: Blue
- event: Purple
- todo: Orange
- meeting: Teal
- recipe: Red
- general: Forest green

Acceptance Criteria:
- [ ] Primary tag prominently displayed
- [ ] Secondary tags as chips
- [ ] Color-coded borders based on primary tag
- [ ] Processing states visible
- [ ] Tappable to open detail view

Files:
- Create Views/Components/NoteCard.swift
- Create Views/Components/TagBadge.swift
- Update Models/Tag+Extensions.swift
```

### QUI-154: Implement Smart Collections View
**Priority**: High
**Effort**: Large (6-8 hours)
**Description**:
```
Create auto-organized collections in Notes tab.

Collections:
- Recent (last 7 days) - always shown
- People (auto-detected mentions)
- Tags (grouped by tag)
- Related (linked notes)
- Archive (collapsed by default)

Features:
- Collapsible sections
- Note counts per collection
- Tap to expand/view notes
- Auto-generate based on usage

Acceptance Criteria:
- [ ] All collections auto-populate
- [ ] Expand/collapse animations
- [ ] Note counts accurate
- [ ] Empty collections hidden
- [ ] Archive collapsed by default

Files:
- Create Models/SmartCollection.swift
- Create Views/Notes/SmartCollectionSection.swift
- Update Views/Notes/NotesTab.swift
```

### QUI-155: API Key Onboarding Flow
**Priority**: Urgent
**Effort**: Medium (5-6 hours)
**Description**:
```
Create first-run experience for API key setup.

Flow:
1. Welcome screen (brief intro)
2. API key setup screen
   - "Why do I need this?" expandable
   - [I have a key] / [Get a key] / [Skip for now]
3. API key validation
4. Success → Start capturing

Features:
- Keychain storage for API key
- Test connection before proceeding
- Limited feature banner if skipped
- Link to Anthropic console

Acceptance Criteria:
- [ ] First launch detection works
- [ ] API key stored in Keychain
- [ ] Validation tests actual API call
- [ ] Can skip and use OCR only
- [ ] Limited feature banner shows when no key

Files:
- Create Views/Onboarding/WelcomeView.swift
- Create Views/Onboarding/APIKeySetupView.swift
- Create Services/APIKeyManager.swift
- Update App/ContentView.swift (first launch check)
```

### QUI-156: Remove Type-Based UI Elements
**Priority**: High
**Effort**: Medium (4-5 hours)
**Description**:
```
Systematically remove all type-based language and UI.

Changes:
- Replace "Type:" with "Tags:"
- Replace "Change type" with "Edit tags"
- Remove type picker sheet
- Remove type badges (use tag badges)
- Remove type filter dropdown
- Update all user-facing strings

Search and replace:
- "note type" → "tags"
- "What type is this?" → "How should this be organized?"
- "OCR" → "Reading..." / "Processing..."
- "Classification" → "Detection"
- "Enhancement" → "Refine"

Acceptance Criteria:
- [ ] Zero mentions of "type" in UI
- [ ] All jargon replaced
- [ ] Type picker sheet deleted
- [ ] Settings updated

Files:
- Search all Views/ files
- Views/Components/NoteTypePickerSheet.swift → Delete or rename to TagEditorSheet.swift
- Update all alert messages
```

### QUI-157: Update Capture Flow with Background Processing
**Priority**: High
**Effort**: Medium (5-6 hours)
**Description**:
```
Implement two-phase processing: immediate OCR, background enhancement.

Phase 1 (Immediate):
- OCR extraction (2 sec)
- Save to KB with ocrOnly state
- User can continue capturing

Phase 2 (Background):
- LLM tag suggestion
- Structured data extraction
- Related notes linking
- Mark as enhanced

UI States:
- Processing (⏳): "Processing..."
- Enhanced (✨): Background complete
- Failed (⚠️): Processing error

Acceptance Criteria:
- [ ] OCR completes in <3s
- [ ] Note saved immediately
- [ ] Background processing queue works
- [ ] UI shows processing states
- [ ] Multiple captures don't block

Files:
- Update ViewModels/CameraViewModel.swift
- Create Services/BackgroundProcessor.swift
- Update Views/Components/NoteCard.swift (status indicators)
```

### QUI-158: Offline Mode Support
**Priority**: Medium
**Effort**: Medium (4-5 hours)
**Description**:
```
Enable graceful degradation when offline.

Features:
- OCR works offline
- Notes saved with pendingEnhancement state
- Queue for processing when online
- Visual indicator for offline notes
- Auto-process when connection restored

States:
- ocrOnly: Captured offline, no LLM processing
- pendingEnhancement: Queued for processing
- processing: Currently being enhanced
- enhanced: Fully processed
- failed: Processing error

Acceptance Criteria:
- [ ] Can capture offline
- [ ] Offline notes show "Offline" badge
- [ ] Auto-processes when back online
- [ ] Network monitor tracks connection
- [ ] Queue persists across app restarts

Files:
- Update Models/Note.swift (add processingState field)
- Create Services/NetworkMonitor.swift
- Create Services/ProcessingQueue.swift
- Update ViewModels/CameraViewModel.swift
```

---

## Phase 3: Background Intelligence Issues

### QUI-159: LLM Tag Suggestion Service
**Priority**: Urgent
**Effort**: Medium (5-6 hours)
**Description**:
```
Implement automatic tag suggestion with vocabulary consistency.

Features:
- Analyze note content with LLM
- Suggest 2-5 tags per note
- Prefer existing tags (consistency)
- Primary tag + context/content tags

Tag Types:
- Primary (1): contact, event, todo, meeting, note
- Context (1-2): work, personal, urgent
- Content (1-2): specific topics/people

Consistency:
- Feed existing tags to LLM
- Strongly prefer existing spellings
- Only create new tags if needed

Acceptance Criteria:
- [ ] Tags suggested automatically after OCR
- [ ] Uses existing tag vocabulary
- [ ] Suggests 2-5 tags per note
- [ ] Primary tag identified correctly
- [ ] < 2s response time

Files:
- Create Services/TagService.swift
- Update ViewModels/CameraViewModel.swift
- Update Services/LLMService.swift (add suggestTags method)
```

### QUI-160: Section Detection with Auto-Split
**Priority**: High
**Effort**: Large (6-8 hours)
**Description**:
```
Detect multiple sections on one page and offer to split.

Strategy:
- Conservative (only split if confidence > 0.85)
- Check for explicit markers first (#type# tags)
- LLM semantic detection as fallback
- Preview before splitting

Flow:
1. OCR completes
2. LLM analyzes for sections
3. If multiple sections found with high confidence:
   - Show preview sheet
   - User chooses: Split or Keep together
4. If split: Create separate notes, link to original image

Acceptance Criteria:
- [ ] Clear sections auto-detected
- [ ] Preview shows before splitting
- [ ] Each section gets appropriate tags
- [ ] All notes link to original image
- [ ] False positive rate < 5%

Files:
- Create Services/SectionDetector.swift
- Create Views/Capture/SectionPreviewSheet.swift
- Update ViewModels/CameraViewModel.swift
```

### QUI-161: Automatic Cross-Linking
**Priority**: Medium
**Effort**: Large (6-8 hours)
**Description**:
```
Find and create links between related notes automatically.

Relationship Types:
- mentions_same_person
- same_topic
- temporal_relationship (follow-up)
- semantic_similarity

Process:
- Background task after note saved
- LLM analyzes content + existing notes
- Creates NoteLink entities (confidence > 0.75)
- UI shows "Related Notes" section

Display:
- Related notes section in detail view
- Note count badge on note cards
- Tap to view related notes
- Bidirectional links

Acceptance Criteria:
- [ ] Links created automatically
- [ ] Confidence threshold > 0.75
- [ ] Bidirectional links work
- [ ] Related notes section displays
- [ ] Performance acceptable (<5s)

Files:
- Create Services/CrossLinkingService.swift
- Create Views/Components/RelatedNotesSection.swift
- Update all detail views
- Update Models/NoteLink.swift
```

### QUI-162: Structured Data Extraction
**Priority**: High
**Effort**: Medium (5-6 hours)
**Description**:
```
Extract structured data from notes to JSON.

Extraction by Tag:
- contact: {name, phone, email, company}
- event: {title, date, time, location}
- todo: {items[], dueDate}
- meeting: {attendees[], date, agenda[]}
- recipe: {ingredients[], steps[], servings}
- expense: {amount, category, date}

Storage:
- extractedDataJSON field in Note model
- Immediate extraction after OCR
- Used for UI rendering, search, export

Benefits:
- Rich UI formatting
- Structured search
- Better export formats

Acceptance Criteria:
- [ ] JSON extracted for all primary tags
- [ ] Data used in detail views
- [ ] Searchable structured fields
- [ ] Export includes structured data

Files:
- Create Services/DataExtractor.swift
- Update all extractor services (ContactParser, etc.)
- Update detail views to use structured data
```

### QUI-163: Tag Review & Editor UI
**Priority**: Medium
**Effort**: Medium (4-5 hours)
**Description**:
```
Optional tag review sheet after capture + tag editor in detail view.

Features:
- Show suggested tags with usage counts
- Indicate existing vs new tags
- Add/remove tags via UI
- Tag suggestions based on content
- Quick accept/edit flow

Tag Suggestions:
- Show if tag already exists
- Display usage count (e.g., "Used in 12 notes")
- Highlight new tags
- Tap to add/remove

Acceptance Criteria:
- [ ] Review sheet shown after capture (optional setting)
- [ ] Tag editor accessible from detail view
- [ ] Existing tags highlighted
- [ ] Can add custom tags
- [ ] Changes saved immediately

Files:
- Create Views/Capture/TagReviewSheet.swift
- Create Views/Components/TagEditorSheet.swift
- Create Views/Components/TagChip.swift
- Update detail views (add "Edit Tags" button)
```

---

## Phase 4: Tag Architecture Migration Issues

### QUI-164: Add Tag Entity to Core Data
**Priority**: Urgent
**Effort**: Medium (4-5 hours)
**Description**:
```
Add Tag entity and relationship to Note.

Schema:
- Tag entity:
  - name: String
  - color: String?
  - createdAt: Date
  - notes: Relationship (to-many)

- Note entity:
  - tags: Relationship (to-many)
  - Keep noteType field (for now, dual mode)

Migration:
- Create new Core Data model version
- Add Tag entity
- Add tags relationship to Note
- Keep existing noteType field

Acceptance Criteria:
- [ ] Tag entity created
- [ ] Relationship to Note works
- [ ] Migration runs without data loss
- [ ] Existing notes unaffected

Files:
- Models/QuillStack.xcdatamodeld
- Create Models/Tag+CoreDataClass.swift
- Create Models/Tag+Extensions.swift
```

### QUI-165: Implement Dual-Mode Routing
**Priority**: High
**Effort**: Medium (3-4 hours)
**Description**:
```
Route by primary tag OR noteType (fallback).

Logic:
1. Try primary tag first (if tags exist)
2. Fall back to noteType (for old notes)
3. Default to NoteDetailView

Priority Tags:
- contact > event > todo > meeting > note

Implementation:
- Check primaryTag?.name first
- If no tags, use noteType
- Ensure both systems work simultaneously

Acceptance Criteria:
- [ ] New notes route by primary tag
- [ ] Old notes route by noteType
- [ ] No routing errors
- [ ] Smooth transition period

Files:
- Update Models/Note+Extensions.swift (makeDetailView)
- Update all detail view routing logic
```

### QUI-166: Migrate Existing Notes to Tags
**Priority**: High
**Effort**: Medium (4-5 hours)
**Description**:
```
One-time migration: Convert all noteType values to tags.

Process:
- For each note without tags:
  - Convert noteType → primary tag
  - Suggest additional tags via LLM
  - Save tags to note

Batch Processing:
- Process in batches of 10
- Show progress UI
- Can run in background
- Recoverable if interrupted

Acceptance Criteria:
- [ ] All notes have at least one tag
- [ ] NoteType → tag conversion accurate
- [ ] Additional tags suggested
- [ ] Progress tracked
- [ ] No data loss

Files:
- Create Migrations/TypeToTagMigration.swift
- Create Views/Settings/MigrationProgressView.swift
- Add migration trigger in Settings
```

### QUI-167: Multiple Actions Based on Tags
**Priority**: Medium
**Effort**: Medium (3-4 hours)
**Description**:
```
Show all applicable actions based on ALL tags (not just primary).

Logic:
- Check all tags, not just primary
- Show multiple action buttons if applicable
- Primary action gets visual emphasis
- Track which actions performed

Actions by Tag:
- contact → "Create Contact"
- event → "Add to Calendar"
- todo → "Export Todos"
- meeting → "Create Meeting"

UI:
- Horizontal scrollable action bar
- Primary action: Bold, colored background
- Secondary actions: Muted, outline style
- Checkmark if action performed

Acceptance Criteria:
- [ ] Multiple actions can appear
- [ ] Primary action emphasized
- [ ] Performed actions show checkmark
- [ ] State persisted

Files:
- Create Views/Components/ActionButtonRow.swift
- Update all detail views
- Add performedActions field to Note model
```

### QUI-168: Tag Management Settings
**Priority**: Low
**Effort**: Medium (4-5 hours)
**Description**:
```
Settings page for managing tags.

Features:
- View all tags
- See usage counts per tag
- Edit tag colors/names
- Merge similar tags
- Auto-suggest settings

Tag Merge Tool:
- Find similar tags (e.g., "work", "professional")
- Preview merge
- Merge all notes from old tag → new tag
- Delete old tag

Acceptance Criteria:
- [ ] All tags listed with counts
- [ ] Can edit tag properties
- [ ] Merge tool works correctly
- [ ] Auto-suggest toggle functional

Files:
- Create Views/Settings/TagManagementView.swift
- Create Views/Settings/TagMergeView.swift
- Update Services/TagService.swift
```

### QUI-169: Remove NoteType from Schema
**Priority**: Low (Post-Beta)
**Effort**: Small (2-3 hours)
**Description**:
```
Final step: Remove noteType field entirely.

Prerequisites:
- All notes have tags
- Routing uses primary tag only
- No code references noteType

Process:
1. Verify all notes have tags
2. Create new Core Data model version
3. Remove noteType attribute
4. Create mapping model
5. Test migration thoroughly

Acceptance Criteria:
- [ ] All notes migrated to tags
- [ ] NoteType field removed from schema
- [ ] No crashes or data loss
- [ ] App functions identically

Files:
- Models/QuillStack.xcdatamodeld
- Remove noteType references in code
- Models/NoteType.swift (keep as reference enum only)
```

---

## Phase 5: Enhanced Intelligence Issues

### QUI-170: Screenshot Detection & Intelligence
**Priority**: Low
**Effort**: Large (8-10 hours)
**Description**:
```
Detect screenshots and handle differently from handwritten notes.

Detection Heuristics:
- Perfect rectangles (UI elements)
- High text contrast
- Digital font characteristics
- Pixel-perfect edges

Screenshot Types:
- article (extract URL)
- quote (highlighted text)
- visual (art/image)
- ui (app screenshot)

Handling:
- article → Extract URL, add article tag
- quote → Extract highlighted text
- visual → Minimal text, visual tag
- ui → Reference tag

Acceptance Criteria:
- [ ] Screenshots detected accurately (>90%)
- [ ] Each type handled appropriately
- [ ] URLs extracted when present
- [ ] Tags assigned automatically

Files:
- Create Services/ScreenshotDetector.swift
- Update ViewModels/CameraViewModel.swift
- Update Services/TagService.swift
```

### QUI-171: Dynamic Smart Collections
**Priority**: Low
**Effort**: Medium (5-6 hours)
**Description**:
```
Auto-generate smart collections based on usage patterns.

Collections to Generate:
- By person (mentions detected)
- By project (recurring topics)
- By time period (this week, last month)
- By tag combinations
- By action status (pending actions)

Features:
- Update collections daily
- Show/hide based on relevance
- Customize collection display order
- Pin favorite collections

Acceptance Criteria:
- [ ] Collections auto-generate
- [ ] People detected from mentions
- [ ] Projects detected from topics
- [ ] Collections update automatically

Files:
- Update Models/SmartCollection.swift
- Update Views/Notes/SmartCollectionSection.swift
- Create Services/CollectionGenerator.swift
```

### QUI-172: Semantic Search Implementation
**Priority**: Low
**Effort**: Large (8-10 hours)
**Description**:
```
LLM-powered semantic search beyond keyword matching.

Features:
- Understand query intent
- Find synonyms/related concepts
- Handle OCR variations
- Temporal context ("last week's meeting")

Search Modes:
- Quick filters (by tag, date, has actions)
- Natural language queries
- Semantic similarity

Examples:
- "budget" finds "expenses", "costs", "spending"
- "Sarah" finds OCR errors ("Sarag", "Sara")
- "last week's meeting" understands time + type

Acceptance Criteria:
- [ ] Semantic search more accurate than keyword
- [ ] Handles OCR variations
- [ ] Understands temporal context
- [ ] Response time < 3s

Files:
- Update Views/Search/SearchTab.swift
- Create Services/SemanticSearchService.swift
- Update Services/LLMService.swift
```

### QUI-173: LLM Cost Monitoring & Optimization
**Priority**: Medium
**Effort**: Medium (4-5 hours)
**Description**:
```
Track API usage and implement cost optimizations.

Monitoring:
- Track daily token usage
- Estimate costs
- Alert at thresholds ($0.15, $0.30/day)
- Display in Settings → API Usage

Optimizations:
- Batch processing (5 notes per LLM call)
- Configurable delay (immediate, 30s, 1m, 5m)
- Optional features (auto-linking toggle)
- Cache LLM responses

Settings:
- Enable/disable background processing
- Batch delay configuration
- Feature toggles
- Usage statistics

Acceptance Criteria:
- [ ] Token usage tracked accurately
- [ ] Cost estimates displayed
- [ ] Alerts shown at thresholds
- [ ] Batch processing reduces calls by 80%

Files:
- Create Services/UsageTracker.swift
- Update Services/BackgroundProcessor.swift (batching)
- Create Views/Settings/APIUsageView.swift
- Create Views/Settings/ProcessingSettingsView.swift
```

---

## Testing & Infrastructure Issues

### QUI-174: Core Services Unit Tests
**Priority**: High
**Effort**: Large (8-10 hours)
**Description**:
```
Comprehensive unit tests for critical services.

Test Coverage:
- OCRService: Basic handwriting, confidence scores
- TagService: Tag suggestion, vocabulary consistency
- SectionDetector: Obvious splits, ambiguous content
- CrossLinkingService: Relationship detection
- DataExtractor: Structured data extraction

Mock LLM:
- Create MockLLMService for deterministic testing
- Mock responses for common scenarios
- Fast tests (no actual API calls)

Acceptance Criteria:
- [ ] >80% code coverage for services
- [ ] All critical paths tested
- [ ] Tests run in <30s
- [ ] No flaky tests

Files:
- Tests/Services/OCRServiceTests.swift
- Tests/Services/TagServiceTests.swift
- Tests/Services/SectionDetectorTests.swift
- Tests/Services/CrossLinkingServiceTests.swift
- Tests/Mocks/MockLLMService.swift
```

### QUI-175: Integration Tests for Capture Flow
**Priority**: Medium
**Effort**: Medium (5-6 hours)
**Description**:
```
End-to-end tests for complete capture flow.

Test Scenarios:
- Basic capture → OCR → tags → save
- Multi-section detection → split
- Offline capture → queue → process online
- Business card → extract contact → create
- Meeting note → extract event → calendar

Test Data:
- Sample handwriting images
- Known OCR outputs
- Expected tag suggestions

Acceptance Criteria:
- [ ] All scenarios covered
- [ ] Tests use mock LLM
- [ ] Tests run in <60s
- [ ] No external dependencies

Files:
- Tests/Integration/CaptureFlowTests.swift
- Tests/Integration/OfflineModeTests.swift
- Tests/TestData/ (sample images)
```

### QUI-176: Manual Testing Checklist & Beta Guide
**Priority**: High
**Effort**: Small (2-3 hours)
**Description**:
```
Create comprehensive testing checklist for beta testers.

Sections:
- Onboarding flow
- Capture variations
- Offline mode
- Tagging accuracy
- Section detection
- Actions (contact, event, todo)
- Navigation
- Edge cases

Format:
- Markdown checklist
- Clear pass/fail criteria
- Screenshots for reference
- Bug reporting instructions

Acceptance Criteria:
- [ ] All features covered
- [ ] Clear instructions
- [ ] Pass/fail criteria defined
- [ ] Bug report template included

Files:
- Create Tests/BETA_TESTING_CHECKLIST.md
- Create docs/BETA_TESTER_GUIDE.md
```

### QUI-177: Accuracy Metrics & Logging
**Priority**: Medium
**Effort**: Medium (4-5 hours)
**Description**:
```
Track accuracy metrics for tag assignment and section detection.

Metrics to Track:
- Tag suggestion accuracy (user overrides)
- Section detection precision (false positives)
- Primary tag correctness (user changes)
- OCR confidence correlation

Analytics Events:
- tag_override (suggested vs final)
- section_split_override (auto vs manual)
- type_correction (detected vs corrected)
- action_taken (which actions used)

Privacy:
- No content logged
- Only metadata and counts
- Local storage only (no external analytics)

Acceptance Criteria:
- [ ] All key metrics tracked
- [ ] No PII logged
- [ ] Dashboard view in Settings (dev only)
- [ ] Export to CSV for analysis

Files:
- Create Services/AccuracyTracker.swift
- Create Views/Settings/MetricsDashboardView.swift (dev only)
```

---

## Priority Order for Implementation

### Week 1 (Must Do Before Beta)
1. QUI-148: Update Website Hero Section
2. QUI-149: Rewrite TestFlight Welcome Email
3. QUI-155: API Key Onboarding Flow
4. QUI-150: Update App Store Description

### Week 2 (Core UX)
5. QUI-152: Implement 4-Tab Navigation
6. QUI-164: Add Tag Entity to Core Data
7. QUI-153: Create Tag-Based Note Cards
8. QUI-156: Remove Type-Based UI Elements
9. QUI-157: Update Capture Flow with Background Processing

### Week 3 (Intelligence)
10. QUI-159: LLM Tag Suggestion Service
11. QUI-162: Structured Data Extraction
12. QUI-160: Section Detection with Auto-Split
13. QUI-158: Offline Mode Support
14. QUI-161: Automatic Cross-Linking

### Week 4 (Polish & Beta)
15. QUI-154: Implement Smart Collections View
16. QUI-165: Implement Dual-Mode Routing
17. QUI-167: Multiple Actions Based on Tags
18. QUI-163: Tag Review & Editor UI
19. QUI-176: Manual Testing Checklist & Beta Guide

### Post-Beta (Migration)
20. QUI-166: Migrate Existing Notes to Tags
21. QUI-168: Tag Management Settings
22. QUI-169: Remove NoteType from Schema
23. QUI-174: Core Services Unit Tests
24. QUI-175: Integration Tests for Capture Flow

### Ongoing (Enhanced Features)
25. QUI-173: LLM Cost Monitoring & Optimization
26. QUI-171: Dynamic Smart Collections
27. QUI-170: Screenshot Detection & Intelligence
28. QUI-172: Semantic Search Implementation
29. QUI-177: Accuracy Metrics & Logging

---

## Labels to Use

- `frontend`: UI/SwiftUI work
- `backend`: Services/business logic
- `data`: Core Data/persistence
- `design`: Visual design work
- `infrastructure`: Build/test/deploy
- `documentation`: Docs and guides
- `urgent`: Must-do for beta
- `enhancement`: Nice-to-have features
- `refactor`: Architecture improvements
