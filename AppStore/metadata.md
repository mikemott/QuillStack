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

**ON-DEVICE TEXT RECOGNITION**
Every capture is read with Apple's on-device Vision framework, so you can search your entire timeline by content — not just by date. Find "that Delta ticket from March" in one query. Your images are never uploaded for text recognition.

**ON-DEVICE ENRICHMENT**
A model running on your device reads each capture and pulls out the parts you actually need: a title, suggested tags, and quick actions like "add to reminders," "save contact," or "add to calendar." Nothing about enrichment leaves your device.

**TAG-BASED, NOT FOLDER-BASED**
Ten curated tags — Receipt, Event, Work, Contact, Food, To-Do, Project, Ticket, Reference, Quote — cover the shape of everyday paper. Add your own sparingly. No nested folders to reorganize every six months.

**QUICK ACTIONS**
Turn a business card into a saved contact, an event flyer into a calendar entry, a to-do list into Reminders items. The actions surface only when the capture actually contains the right information.

**OBSIDIAN EXPORT**
Point QuillStack at your Obsidian vault path. Captures export as markdown with images attached and optional recognized text, ready to link from your daily note. Your archive stays portable — plain files, plain folders.

**ICLOUD SYNC**
Sign in to iCloud and your captures and tags sync across your iPhone and iPad automatically via CloudKit. Reinstall the app, sign in, and your timeline comes back.

**YOUR DATA STAYS ON YOUR DEVICE**
Captured images, recognized text, enrichment output, and tags are processed and stored on your device (and, optionally, in your own iCloud). Your content never leaves your device unless you choose to sync via iCloud or export to Obsidian. The only data the app sends off-device is anonymous crash diagnostics via Sentry — never your images, text, or notes. Full detail: quillstack.io/privacy.html.

**BUILT FOR IOS 26**
Native SwiftUI, SwiftData persistence, minimum iOS 26.

**FEATURES**
✓ Document-scanner capture with auto-crop
✓ Multi-page stacks
✓ On-device text recognition (Apple Vision) for full-text search
✓ On-device enrichment: titles, tags, quick actions
✓ 10 curated default tags plus your own
✓ Location tagging (optional, on-device only)
✓ Save Contact, Add to Calendar, Add to Reminders quick actions
✓ Obsidian markdown export with attachments
✓ iCloud sync via CloudKit
✓ Dark, minimal UI

Fast capture for real life. Download QuillStack.

---

## Promotional Text (170 character limit — can be updated without review)

Snap the receipts, tickets, and notes piling up in real life. QuillStack captures, tags, and searches them on-device — then exports to Obsidian when you want them for keeps.

---

## Keywords (100 character limit, comma-separated)

receipt scanner,notes,capture,tag,obsidian,ocr,document,camera,archive,paper

---

## What's New (Version 2.0.0)

QuillStack is a fast image-capture app for the paper trail of real life.

• One-tap document scanner with auto-crop and multi-page stacks
• On-device text recognition (Apple Vision) for full-text search across your timeline
• On-device enrichment suggests titles, tags, and quick actions
• Ten curated default tags — no folders to reorganize
• Save Contact, Add to Calendar, Add to Reminders quick actions
• Obsidian markdown export with attachments
• iCloud sync via CloudKit
• Optional location tagging (on-device only)
• Dark, minimal UI — monochrome chrome, colorful tags

Note: the app's marketing version is 2.0.0 to reflect a full rewrite from an earlier codebase; this is the first release on this App Store record.

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

The only data transmitted off the device is anonymous diagnostics.

| Data Type | Purpose | Source |
|-----------|---------|--------|
| Crash Data | App Functionality | Sent to Sentry |
| Performance Data | App Functionality | Sent to Sentry |

### Data NOT Collected

Photos or Videos (captured images), User Content (recognized text, tags, notes), Coarse Location (on-device only, never transmitted), Contact Info, Health & Fitness, Financial Info, Contacts, Search History, Browsing History, Identifiers, Purchase History, Usage Data, Sensitive Info, Other Data.

> Text recognition and enrichment run entirely on-device, so captured images and recognized text are never transmitted and are not "collected" under Apple's definition.

### Third-Party SDKs Disclosed

- **Sentry** — https://sentry.io/privacy/

---

## Reviewer Notes (for App Review submission)

Use App Store Connect → App Information → Review Notes.

> QuillStack captures images (receipts, tickets, notes). Text recognition runs entirely on-device using Apple's Vision framework, and an on-device model suggests tags and quick actions — no image or recognized text is uploaded to any server. No account is required; sign-in is optional via iCloud. There are no in-app purchases. Sentry is used only for anonymous crash and performance reporting — no screenshots or capture content is attached.
>
> Test flow: Launch → tap capture → scan any document (a receipt is a good test) → hold to save → view the timeline → tap a capture → see enrichment (title, tags, quick actions). Obsidian export requires a vault path in Settings; iCloud sync requires the reviewer's iCloud account to be signed in on the test device.

---

## Version + Build Checklist Before Upload

- [ ] `project.yml` → `MARKETING_VERSION` is `2.0.0` (matches "What's New")
- [ ] `project.yml` → `CURRENT_PROJECT_VERSION` bumped from the last uploaded build
- [ ] `Secrets.xcconfig` populated on the archiving machine (`SENTRY_DSN`) — no OCR API key is needed; text recognition is on-device
- [ ] `xcodegen generate` run after any `project.yml` change
- [ ] Archive built with Release config, tested on a real device once (not just simulator)
- [ ] Screenshots regenerated per `AppStore/screenshots.md`
