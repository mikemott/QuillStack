# QuillStack — Screenshot Requirements

## Required Screenshot Sizes

You need screenshots for these device sizes:

### iPhone (Required)
| Device | Resolution | Display Size |
|--------|------------|--------------|
| iPhone 16 Pro Max | 1320 x 2868 | 6.9" |
| iPhone 16 Pro Max (or 15 Pro Max, 14 Pro Max) | 1290 x 2796 | 6.7" |
| iPhone 8 Plus | 1242 x 2208 | 5.5" |

### iPad (Required if app supports iPad)
| Device | Resolution |
|--------|------------|
| iPad Pro 13" | 2064 x 2752 |
| iPad Pro 12.9" | 2048 x 2732 |

**Tip:** Take 6.7" iPhone screenshots, then scale for other sizes. App Store Connect can auto-generate some sizes.

---

## Recommended Screenshots (6-10 per device)

The app is dark and minimal — monochrome chrome, with color coming only from the tag chips. Keep the captured images authentic (receipts, tickets, flyers) but free of real personal info.

### Screenshot 1: Hero / Timeline
**Caption:** "The paper trail of real life, captured"
- Show the main timeline with 3–4 capture cards (a receipt, an event flyer, a business card, a note)
- Each card shows its image, extracted title, timestamp, and colored tag chips
- The QUILLSTACK header is visible at the top

### Screenshot 2: One-tap capture
**Caption:** "Snap it now, sort it later"
- Show the document scanner with a receipt in frame, auto-crop edges detected
- The capture button (light circle) prominent at the bottom

### Screenshot 3: Capture detail + enrichment
**Caption:** "A title, tags, and actions — on your device"
- Show a capture detail view: the image up top, an auto-generated title, and suggested tags
- Emphasize that recognition and enrichment happen on-device

### Screenshot 4: Tag filter bar
**Caption:** "Tags, not folders"
- Show the tag filter bar with the colorful default chips (Receipt, Event, Work, Food, To-Do, …)
- One tag selected, the timeline filtered to matching captures

### Screenshot 5: Quick actions
**Caption:** "Turn a card into a contact, a flyer into an event"
- Show a business-card capture surfacing "Save Contact," or an event flyer surfacing "Add to Calendar"
- Emphasize the action appears only when the capture contains the right info

### Screenshot 6: Search
**Caption:** "Search by what it says, not just the date"
- Show search results for a query like "delta" surfacing a ticket capture
- Full-text search across recognized text, titles, and tags

### Screenshot 7: Obsidian export (Optional)
**Caption:** "Export to Obsidian — plain files, yours to keep"
- Show Settings with the Obsidian vault path set, or an export confirmation
- Emphasize markdown + attached images, written locally

### Screenshot 8: Multi-page stack (Optional)
**Caption:** "Multi-page captures, stacked into one"
- Show a multi-page capture with a page indicator

---

## Screenshot Tips

1. **Use real-looking content** — sample captures that look authentic but contain no personal info (fake names, redacted numbers).
2. **Clean status bar** — take screenshots at 9:41 AM with full battery (Apple's preferred time).
3. **Consistent style** — same dark background and similar content density across all shots.
4. **Show key features** — each screenshot highlights a different capability.
5. **Captions** — add text overlays that explain the feature (Figma or Canva). Keep type minimal and monochrome to match the app.

---

## Taking Screenshots

### On Simulator:
```bash
# Run in simulator, then:
# Cmd + S to save screenshot, or:
xcrun simctl io booted screenshot screenshot.png
```

### On Device:
- Side button + Volume up (Face ID devices)

> Camera capture requires a physical device — take Screenshot 2 (and any capture-flow shots) on device.

---

## App Preview Video (Optional but Recommended)

- 15–30 seconds
- Show the capture → recognize → tag → find flow, all on-device
- Same resolutions as screenshots
- No audio required, but can add music/captions

---

## Sample Capture Content for Screenshots

Aim for the everyday paper the app is built for. Keep it realistic but anonymized:

- **Receipt** — a coffee-shop or hardware-store receipt (redact the last card digits). Tag: Receipt.
- **Event flyer** — a concert or farmers-market poster with a date and venue. Tag: Event.
- **Business card** — a made-up name, title, and email. Tag: Contact.
- **Ticket** — a boarding pass or event ticket with a made-up confirmation code. Tag: Ticket.
- **To-do list** — a handwritten list of a few tasks. Tag: To-Do.
- **Quote / note** — a short handwritten note or quote. Tag: Quote.
