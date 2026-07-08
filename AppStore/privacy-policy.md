# Privacy Policy for QuillStack

**Last Updated:** July 8, 2026

## Overview

QuillStack ("the App") is a fast image-capture tool for receipts, tickets, posters, and notes. This Privacy Policy explains what data the app handles, where it goes, and what stays on your device.

**Short version:** Your captures live on your device and (optionally) in your personal iCloud. Two third-party services process limited data on your behalf: Datalab (for OCR) and Sentry (for crash and performance reports).

---

## What Stays on Your Device

All of your captures, tags, extracted text, enrichment results, and settings are stored locally on your device using:

- **SwiftData** (Apple's on-device database) for captures, tags, and relationships
- **Local file storage** for original images and thumbnails
- **UserDefaults** for non-sensitive preferences (Obsidian vault path, toggles)
- **iOS Keychain** for any API keys you enter

We do not operate any server that stores your notes or images.

---

## iCloud Sync (Optional)

If you are signed in to iCloud on your device and iCloud Drive is enabled, QuillStack syncs your captures and tags across your Apple devices via **CloudKit** in your personal iCloud account. Apple manages this sync end-to-end; we have no access to your iCloud data.

You can turn iCloud sync off in iOS Settings → Apple ID → iCloud → QuillStack.

---

## Third-Party Services

### Datalab OCR (required for text extraction)

- **What it does:** Extracts text from captured images using the Chandra OCR model.
- **Data sent:** The image you capture, transmitted over HTTPS to `datalab.to`.
- **Retention:** Governed by Datalab's terms. QuillStack does not instruct Datalab to retain images beyond processing.
- **Their privacy policy:** https://datalab.to/privacy
- **How to avoid it:** Do not capture content you don't want processed off-device. A future release may allow disabling OCR entirely.

### Sentry (crash and performance monitoring)

- **What it does:** Reports crashes, errors, and performance samples so we can fix bugs.
- **Data sent:** Stack traces, device model, OS version, app version, breadcrumbs (in-app navigation events), and non-sensitive diagnostic context. **Screenshots are not attached.** Captured images and OCR text are not sent.
- **Identifier:** A random Sentry-generated installation ID that we cannot link to your Apple ID or name.
- **Their privacy policy:** https://sentry.io/privacy/

### Obsidian (optional local export)

- **What it does:** Writes markdown files to a folder path you specify.
- **Data sent:** None over the network. Files are written locally on your device.

---

## App Store Privacy Nutrition Label

We declare the following data types in App Store Connect:

| Data Type | Collected? | Purpose | Linked to You? | Used to Track? |
|-----------|------------|---------|----------------|----------------|
| Photos or Videos (captured images) | Yes, sent to Datalab | App Functionality (OCR) | No | No |
| Crash Data | Yes, via Sentry | App Functionality (diagnostics) | No | No |
| Performance Data | Yes, via Sentry | App Functionality (diagnostics) | No | No |
| Coarse Location | Yes, on-device only | App Functionality (tagging captures) | No | No |
| Contact Info, Identifiers, Search History, Browsing History, User Content (notes, tags), Purchase History, Financial Info, Health & Fitness, Sensitive Info, Contacts, Diagnostics not listed above | Not collected | — | — | — |

---

## Device Permissions

| Permission | Purpose | When Asked |
|------------|---------|------------|
| Camera | Capture photos of documents, receipts, and notes | First camera use |
| Location (While Using) | Optionally tag captures with location | When you enable location tagging in Settings |
| Contacts (Full Access) | Save contacts extracted from business cards | First "Save Contact" action |
| Calendars (Full Access) | Create calendar events from captured event details | First "Add to Calendar" action |
| Reminders (Full Access) | Create reminders from captured to-do lists | First "Add to Reminders" action |

You can revoke any permission at any time in iOS Settings → QuillStack.

---

## Data Security

- API keys entered in the app are stored in the iOS Keychain with hardware-backed encryption.
- The SwiftData store uses iOS file protection.
- All third-party requests use HTTPS. Arbitrary loads are disabled (`NSAllowsArbitraryLoads = false`).
- We do not operate a server that ingests your notes or images.

---

## Children's Privacy

QuillStack is rated 4+ and does not knowingly collect information from children. The app contains no ads, no in-app purchases, no social features, and no age-gated content.

---

## Changes to This Policy

Material changes will be reflected in this document and dated in the "Last Updated" line. If you continue to use the app after a change, you accept the updated policy.

---

## Contact

**Email:** mike@mottvt.com
**Issues:** https://github.com/mikemott/QuillStack/issues

---

## Your Rights

Because QuillStack does not operate a server that stores your data:

- **Access:** Your data is on your device (and, optionally, your iCloud).
- **Deletion:** Deleting the app removes local data. iCloud data can be removed via iOS Settings → Apple ID → iCloud → Manage Storage → QuillStack. To request deletion of any Sentry-side crash reports tied to your installation ID, email us.
- **Portability:** Use the Obsidian export to write your notes to markdown files you own.
- **Opt-out of diagnostics:** Sentry honors your iOS system-level setting at *Settings → Privacy & Security → Analytics & Improvements → Share with App Developers*. Turning it off stops non-crash telemetry from being sent. To also block crash reports, revoke network access to the app via iOS Screen Time or a network profile.

---

*QuillStack is designed to keep your paper trail yours. If something in this policy is unclear, email us.*
