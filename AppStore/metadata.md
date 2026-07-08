# QuillStack — App Store Metadata

## App Name
**QuillStack** (10 characters — max 30)

## Subtitle
**Fast capture for real life** (26 characters — max 30)

---

## Description (4000 character limit)

The receipts, tickets, and business cards piling up in your camera roll finally have a home. QuillStack is a fast image-capture app for the paper trail of real life — snap it now, sort it later.

**ONE-TAP CAPTURE**
Open the app, hit the shutter, done. The document scanner auto-crops and corrects perspective. Multi-page captures stack into a single item. No form to fill in before you can put your phone away.

**TEXT EXTRACTION**
Every capture is run through cloud OCR (Datalab Chandra) so you can search your entire timeline by content — not just by date. Find "that Delta ticket from March" in one query.

**ON-DEVICE ENRICHMENT**
An on-device model reads each capture and pulls out the parts you actually need: a title, suggested tags, and quick actions like "add to reminders," "save contact," or "add to calendar." Nothing about enrichment leaves your device.

**TAG-BASED, NOT FOLDER-BASED**
Ten curated tags — Receipt, Event, Work, Contact, Food, To-Do, Project, Ticket, Reference, Quote — cover the shape of everyday paper. Add your own sparingly. No nested folders to reorganize every six months.

**QUICK ACTIONS**
Turn a receipt into a saved expense, a business card into a contact, an event flyer into a calendar entry, a to-do list into Reminders items. The actions surface only when the capture actually contains the right information.

**OBSIDIAN EXPORT**
Point QuillStack at your Obsidian vault path. Captures export as markdown with images attached and optional OCR text, ready to link from your daily note. Your archive stays portable — plain files, plain folders.

**ICLOUD SYNC**
Sign in to iCloud and your captures and tags sync across your iPhone and iPad automatically via CloudKit. Reinstall the app, sign in, and your timeline comes back.

**WHAT STAYS ON YOUR DEVICE**
Captured images, extracted text, enrichment output, tags, and Obsidian export live locally (and, optionally, in your iCloud). Two services handle limited data on your behalf: Datalab performs OCR on submitted images, and Sentry receives anonymous crash reports so bugs get fixed. Full detail: quillstack.io/privacy.

**BUILT FOR IOS 26**
Native SwiftUI, SwiftData persistence, minimum iOS 26.

**FEATURES**
✓ Document-scanner capture with auto-crop
✓ Multi-page stacks
✓ Cloud OCR (Datalab Chandra) for full-text search
✓ On-device enrichment: titles, tags, quick actions
✓ 10 curated default tags plus your own
✓ Location tagging (optional)
✓ Save Contact, Add to Calendar, Add to Reminders quick actions
✓ Obsidian markdown export with attachments
✓ iCloud sync via CloudKit
✓ Dark editorial UI

Fast capture for real life. Download QuillStack.

---

## Promotional Text (170 character limit — can be updated without review)

Snap the receipts, tickets, and notes piling up in real life. QuillStack captures, tags, and searches them — then exports to Obsidian when you want them for keeps.

---

## Keywords (100 character limit, comma-separated)

receipt scanner,notes,capture,tag,obsidian,ocr,document,camera,archive,paper

---

## What's New (Version 1.0.0 — first release on this App Store record)

Hello. QuillStack is a fast image-capture app for the paper trail of real life.

• One-tap document scanner with auto-crop and multi-page stacks
• Cloud OCR (Datalab Chandra) for full-text search across your timeline
• On-device enrichment suggests titles, tags, and quick actions
• Ten curated default tags — no folders to reorganize
• Save Contact, Add to Calendar, Add to Reminders quick actions
• Obsidian markdown export with attachments
• iCloud sync via CloudKit
• Optional location tagging
• Dark editorial UI, monochrome chrome, colorful data

Note: internal build version is 2.x — the "2" reflects the rewrite from an earlier codebase, not a public update.

---

## Support URL
https://github.com/mikemott/QuillStack/issues

## Marketing URL
https://quillstack.io

## Privacy Policy URL
https://quillstack.io/privacy.html

---

## App Store Categories

**Primary Category:** Productivity
**Secondary Category:** Utilities

---

## Age Rating Questionnaire

- Made for Kids: No
- Cartoon or Fantasy Violence: None
- Realistic Violence: None
- Sexual Content or Nudity: None
- Profanity or Crude Humor: None
- Alcohol, Tobacco, or Drug Use: None
- Mature/Suggestive Themes: None
- Simulated Gambling: None
- Horror/Fear Themes: None
- Medical/Treatment Information: None
- Unrestricted Web Access: No
- Gambling and Contests: None

**Expected Rating:** 4+ (All Ages)

---

## App Privacy — App Store Connect Nutrition Label

Declare the following in App Store Connect. These MUST match `AppStore/privacy-policy.md`.

### Data Collected — Linked to User: NO — Used for Tracking: NO

| Data Type | Purpose | Source |
|-----------|---------|--------|
| Photos or Videos (captured images) | App Functionality | Sent to Datalab for OCR |
| Crash Data | App Functionality | Sent to Sentry |
| Performance Data | App Functionality | Sent to Sentry |
| Coarse Location | App Functionality | On-device only, never transmitted |

### Data NOT Collected

Contact Info · Health & Fitness · Financial Info · Contacts · User Content (notes, tags, OCR text — stays on device or in the user's iCloud) · Search History · Browsing History · Identifiers · Purchase History · Usage Data · Sensitive Info · Other Data.

### Third-Party SDKs Disclosed

- **Datalab OCR** — https://datalab.to/privacy
- **Sentry** — https://sentry.io/privacy/

---

## Reviewer Notes (for App Review submission)

Use App Store Connect → App Information → Review Notes.

> QuillStack captures images (receipts, tickets, notes) and processes them via Datalab OCR (cloud) for text extraction and an on-device model for tag/action suggestions. No account required; sign-in optional via iCloud. No in-app purchases. Sentry is used only for anonymous crash reporting — no screenshots or capture content is attached. The `DATALAB_API_KEY` in the build is a per-app service key, not user-provided.
>
> Test flow: Launch → tap capture → scan any document (a receipt is a good test) → hold to save → view the timeline → tap a capture → see enrichment (title, tags, quick actions). Obsidian export requires a vault path in Settings; iCloud sync requires the reviewer's iCloud account to be signed in on the test device.

---

## Version + Build Checklist Before Upload

- [ ] `project.yml` → `MARKETING_VERSION` matches "What's New" version (currently `2.0.0`)
- [ ] `project.yml` → `CURRENT_PROJECT_VERSION` bumped from the last uploaded build
- [ ] `Secrets.xcconfig` populated on the archiving machine (`SENTRY_DSN`, `DATALAB_API_KEY`)
- [ ] `xcodegen generate` run after any `project.yml` change
- [ ] Archive built with Release config, tested on a real device once (not just simulator)
- [ ] Screenshots regenerated per `AppStore/screenshots.md` (still a v1 doc — rewrite pending)
