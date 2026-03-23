# Quick Actions: Tag-Triggered Structured Extraction

## Overview

When a user tags a capture with an actionable tag (#Contact, #Event, #Receipt), the OCR prompt dynamically includes extraction instructions for that type. The extracted structured data is cached in `enrichmentJSON` and surfaced via floating action icons on the card and detail view images.

## Capture Flow (Revised)

```
Scanner finishes
  → Save capture + images to SwiftData
  → Half-sheet tag picker appears over image preview
  → User selects 1+ tags (required, no skip)
  → Taps DONE
  → OCR fires with tag-aware prompt
  → Dismiss to timeline
```

The tag toast on the timeline is removed. Tagging now happens inside the capture flow, before OCR.

## Tag → Action Mapping

| Tag | Action | Icon (SF Symbol) | System Framework |
|-----|--------|-------------------|-----------------|
| Contact | Add to Contacts | `person.crop.circle.badge.plus` | CNContactViewController |
| Event | Create Calendar Event | `calendar.badge.plus` | EKEventEditViewController |
| Receipt | Export structured receipt | `doc.text` | ObsidianExporter (extended) |

## Dynamic OCR Prompt

The base prompt (text + title + aiTags) is always included. Tag-specific extraction blocks are appended based on which actionable tags the user selected:

### Contact extraction (when #Contact tag present)
```
4. "contact": Extract contact information as a JSON object with fields:
   name, phone, email, company, address, title (job title), url.
   Only include fields that are clearly visible.
```

### Event extraction (when #Event tag present)
```
4. "event": Extract event information as a JSON object with fields:
   title, date (ISO 8601), time, endTime, location, description.
   Only include fields that are clearly visible.
```

### Receipt extraction (when #Receipt tag present)
```
4. "receipt": Extract receipt information as a JSON object with fields:
   vendor, total, date (ISO 8601), currency,
   items (array of {name, quantity, price}).
   Only include fields that are clearly visible.
```

## Data Model

Extracted action data is stored in the existing `enrichmentJSON` blob. The `Enrichment` struct gets new optional fields:

```swift
struct Enrichment: Codable, Sendable {
    // existing
    var title: String
    var summary: String
    var text: String
    var tags: [String]
    var aiTags: [String]
    var actions: [Action]  // legacy, can deprecate

    // new — populated by tag-specific extraction
    var contact: ContactExtraction?
    var event: EventExtraction?
    var receipt: ReceiptExtraction?
}

struct ContactExtraction: Codable, Sendable {
    var name: String?
    var phone: String?
    var email: String?
    var company: String?
    var address: String?
    var jobTitle: String?
    var url: String?
}

struct EventExtraction: Codable, Sendable {
    var title: String?
    var date: String?       // ISO 8601
    var time: String?
    var endTime: String?
    var location: String?
    var description: String?
}

struct ReceiptExtraction: Codable, Sendable {
    var vendor: String?
    var total: String?
    var date: String?       // ISO 8601
    var currency: String?
    var items: [ReceiptItem]?
}

struct ReceiptItem: Codable, Sendable {
    var name: String?
    var quantity: Int?
    var price: String?
}
```

All new fields use `decodeIfPresent` for backward compatibility with existing enrichmentJSON.

## Floating Action Icon

- Appears on both **CaptureCard** (timeline) and **CaptureDetailView** (detail)
- Positioned over the image area (bottom-left, matching the existing share button style on top-right)
- Only visible when:
  1. OCR is complete (`!capture.isProcessingOCR`)
  2. An actionable tag is present (#Contact, #Event, #Receipt)
  3. Corresponding extraction data exists in enrichmentJSON
- **Tag-specific SF Symbol icons**, stacked vertically when multiple actions available
- Glass style matching existing utility buttons (`QSSurface.base.opacity(0.70)` + `.ultraThinMaterial`)

## Action Flow (per type)

### Contact
1. Tap contact icon
2. Build `CNMutableContact` from `ContactExtraction` fields
3. Present `CNContactViewController(forNewContact:)` pre-filled
4. User reviews/edits, taps Done to save

### Event
1. Tap calendar icon
2. Build `EKEvent` from `EventExtraction` fields
3. Present `EKEventEditViewController` pre-filled
4. User reviews/edits calendar, alerts, taps Add

### Receipt
1. Tap receipt icon
2. Present a confirmation sheet showing extracted vendor, total, date, line items
3. User taps "Export to Obsidian" (or other configured export)
4. ObsidianExporter formats receipt data into structured markdown

## Files to Create/Modify

### New files
- `QuillStack/Models/ContactExtraction.swift`
- `QuillStack/Models/EventExtraction.swift`
- `QuillStack/Models/ReceiptExtraction.swift`
- `QuillStack/Views/Components/ActionIcon.swift` — floating icon component
- `QuillStack/Views/Actions/ContactActionView.swift` — CNContactViewController wrapper
- `QuillStack/Views/Actions/EventActionView.swift` — EKEventEditViewController wrapper
- `QuillStack/Views/Actions/ReceiptPreviewSheet.swift` — receipt confirmation sheet

### Modified files
- `QuillStack/Models/Enrichment.swift` — add optional contact/event/receipt fields
- `QuillStack/Services/RemoteOCRService.swift` — dynamic prompt builder accepting tags
- `QuillStack/Services/CaptureProcessor.swift` — pass tags to OCR prompt
- `QuillStack/Services/OCRQueueService.swift` — pass tags to OCR prompt (for queue re-processing)
- `QuillStack/Views/Capture/CaptureFlowView.swift` — two-phase: scanner → tag picker sheet → OCR
- `QuillStack/Views/Components/CaptureCard.swift` — add floating action icon over image
- `QuillStack/Views/Detail/CaptureDetailView.swift` — add floating action icon over image
- `QuillStack/App/ContentView.swift` — remove tag toast (replaced by capture flow picker)
- `QuillStack/Info.plist` — add NSContactsUsageDescription, NSCalendarsUsageDescription

### Remove
- `QuillStack/Views/Components/TagToast.swift` — replaced by in-flow tag picker

## Build Sequence

1. **Data model** — extraction structs + Enrichment updates
2. **Dynamic prompt** — RemoteOCRService builds prompt based on tags
3. **Capture flow** — scanner → tag picker sheet → OCR with tags
4. **Remove tag toast** from ContentView
5. **Action icons** — floating component on card + detail view
6. **Contact action** — CNContactViewController integration
7. **Event action** — EKEventEditViewController integration
8. **Receipt action** — preview sheet + Obsidian export

## Resolved Questions

- **Tag picker in capture flow**: Simpler, purpose-built picker optimized for quick selection — not the full TagPickerView. Just a flow layout of tag chips, no "Quick Tags" / "All Tags" sections, no create-new-tag.
- **Receipt export**: Appends structured receipt data to the Obsidian daily note (same as existing export path).
