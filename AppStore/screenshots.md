# QuillStack — Screenshot Guide (v2)

## Required Sizes

App Store Connect will render your submission on every device, but you must upload for at least the largest supported iPhone size. Everything else can be auto-scaled.

### iPhone (required)
| Device | Points | Pixels @ 3x |
|--------|--------|-------------|
| iPhone 17 Pro Max (6.9") | 440 × 956 | 1320 × 2868 |
| iPhone 16 Pro Max (6.7") | 430 × 932 | 1290 × 2796 |
| iPhone 8 Plus / older (5.5") | 414 × 736 | 1242 × 2208 (only if you support the size) |

### iPad (required only if you list iPad support)
QuillStack is iPhone-first with portrait-only orientation on iPhone (Info.plist:62). If you don't ship iPad support, remove iPad from App Store Connect — don't submit stretched iPhone shots.

Recommendation: **submit 6.9" only** and let Apple scale. Fewer shots to keep in sync when the UI shifts.

---

## Shot List (target: 6 shots)

Each shot has an on-device screen to capture, plus an optional caption overlay you add in Figma/Canva. Captions are your primary sales copy — a user scans them before reading anything.

### 1. Timeline — Card Pager
**Screen:** `ContentView` (default state, cards visible)
**Caption:** *Fast capture for real life*
**Setup:**
- 4–6 captures in the timeline
- Mixed tags: at least one Receipt, one Event, one Contact
- Search bar hidden, layout toggle set to card pager (not drawer)
- Show the header "QUILLSTACK" glow prominently

### 2. Capture Flow — Tag Picker
**Screen:** `CaptureFlowView` in `showTagPicker = true` state
**Caption:** *Snap it. Tag it. Done.*
**Setup:**
- A crisp document scan visible behind the sheet (a receipt reads best)
- 2–3 tags pre-selected so the "N tagged" affordance is visible
- Focus a colorful tag (Receipt, Event) so the color story pops against the monochrome UI

### 3. Detail View — Enrichment
**Screen:** `CaptureDetailView` with enrichment populated
**Caption:** *Titles, tags, and actions — automatic*
**Setup:**
- A receipt capture with `extractedTitle`, tags, and a Receipt quick-action visible
- OCR text expanded or hinted at
- Location line if it fits

### 4. Timeline — Drawer Mode
**Screen:** `ContentView` with `isDrawerMode = true`
**Caption:** *A grid when you want it, cards when you don't*
**Setup:**
- Same captures as shot #1 but grouped by date (headers visible)
- 2+ date sections so the date header shows real content
- Long-press one card if you want to highlight actions

### 5. Quick Action — Contact / Calendar / Receipt / Reminder
**Screen:** Pick one action sheet — `ContactActionView`, `EventActionView`, `ReceiptPreviewSheet`, or `TodoActionView`
**Caption:** *Turn a business card into a contact. Instantly.*
**Setup:**
- Capture visible behind the sheet
- Sheet expanded with parsed fields (name, phone, org for Contact)
- The primary action button ("Save Contact") in the highlight color

### 6. Settings — Obsidian Export
**Screen:** `SettingsView` scrolled to the Obsidian section
**Caption:** *Export to Obsidian when you want it for keeps*
**Setup:**
- Vault path field filled with a plausible path (e.g. `/Vaults/Personal`)
- "Include OCR Text" toggle on
- iCloud Backup section visible below (bonus: shows the sync story)

---

## Empty State (optional 7th shot, only for App Store 6.9" if you have room)

**Screen:** `ContentView` with no captures — the "Point your phone at something. Something happens." state
**Caption:** *Start with the very first snap*

This shot is a strong opener if you have space. Users unfamiliar with the app understand what to do immediately.

---

## Content Guidance

**Realism beats polish.** Screenshot fakery gets flagged in review — every screen must be reachable in the actual app. Use real receipts you'd be comfortable showing (redact totals if you like, but don't fabricate).

**Match the dark editorial UI.** The app is dark by design (`preferredColorScheme(.dark)` in `ContentView`). Don't try to shoot in a light appearance — it doesn't exist in the app.

**Use color from tags, nothing else.** The single most on-brand thing you can show is a monochrome timeline with 3 or 4 saturated tag chips. That's the whole design story of v2 in one image.

**Time on the status bar.** Apple's guidance is 9:41 AM, full signal, full battery. Use `xcrun simctl status_bar` to fake it on the Simulator:

```bash
xcrun simctl status_bar booted override \
  --time "9:41" --dataNetwork wifi \
  --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 \
  --batteryState charged --batteryLevel 100
```

Reset with `xcrun simctl status_bar booted clear`.

---

## Capturing Screens

### Simulator (fastest)
```bash
xcrun simctl io booted screenshot ~/Desktop/quillstack-01-timeline.png
```
Simulator screenshots come out at the correct pixel density for the device you booted — no post-processing needed.

### On device (real content)
- Side button + Volume up (Face ID)
- AirDrop to your Mac, do not iCloud-share (metadata leak)

### From Xcode (for design mocks)
Debug → View Debugging → Take Screenshot renders at the current window size.

---

## App Preview Video (optional, strongly recommended)

15–30 seconds, no audio required. Suggested flow:

1. Timeline scrolls (2s)
2. Tap capture button, doc scanner appears (3s)
3. Snap → tag picker → confirm (5s)
4. Return to timeline, new card animates in (3s)
5. Tap card → detail view with enrichment (4s)
6. Quick action sheet slides up (3s)
7. Hold on the finished detail view with caption "Fast capture for real life." (5s)

Record on-device via QuickTime → New Movie Recording → source = iPhone. Trim in QuickTime, export at native resolution.

---

## Localization

If you localize the App Store listing in the future, you must re-upload screenshots per locale — captions overlaid in Figma need the translated string baked in. On first submission, English only is fine.
