# Privacy Policy for QuillStack

**Last Updated:** July 8, 2026

## Overview

QuillStack ("the App") is a fast image-capture tool for receipts, tickets, posters, and notes. This Privacy Policy explains what data the app handles, where it goes, and what stays on your device.

**Short version:** Everything you capture — images, recognized text, tags, and enrichment — is processed and stored entirely on your device. Your content never leaves your device unless you choose to sync it to your personal iCloud or export it to Obsidian. The only data the app sends off-device is pseudonymous crash diagnostics — tied to a random installation ID, never to you — which never include your images, text, or notes.

---

## What Stays on Your Device

Your captures and everything derived from them are created, processed, and stored locally:

- **Text recognition (OCR)** runs on-device using Apple's Vision framework. Captured images are **never uploaded** for text extraction.
- **Enrichment** — titles, suggested tags, and quick actions — is produced by a model running on your device. Nothing about enrichment leaves your phone.
- **SwiftData** (Apple's on-device database) stores captures, tags, and relationships.
- **Local file storage** holds original images and thumbnails.
- **UserDefaults** holds non-sensitive preferences (Obsidian vault bookmark, toggles). The app has no API keys to store — OCR and enrichment run entirely on-device.

We do not operate any server that stores — or ever receives — your notes or images.

---

## What Can Leave Your Device — and Only If You Choose

There are exactly three ways any data leaves your device. The first two are entirely your choice and move only the data you direct; the third is limited, pseudonymous diagnostics that never contain your content.

- **iCloud sync (optional, off unless you enable it):** your captures and tags sync across your Apple devices through **your own** iCloud account via CloudKit. Apple manages this end-to-end; we have no access to your iCloud data. Turn it off in iOS Settings → Apple ID → iCloud → QuillStack.
- **Obsidian export (optional, only when you configure a vault):** selected captures are written as local markdown files (with images attached, and optional recognized text) to a folder path you specify. Nothing is sent over the network.
- **Pseudonymous crash diagnostics (Sentry):** if the app crashes or errors, a diagnostic report is sent so we can fix the bug. It contains no images, no recognized text, and no notes — see below.

---

## Crash Diagnostics (Sentry)

- **What it does:** reports crashes, errors, and performance samples so we can fix bugs.
- **Data sent:** stack traces, device model, OS version, app version, breadcrumbs (in-app navigation events carrying only counts and fixed codes — page count, number of tags selected, recognized-character count, action type, and an OCR failure code), and non-sensitive diagnostic context. **Your captured images, recognized text, tag names, and notes are never sent. Screenshots are not attached.**
- **Identifier:** a random Sentry-generated installation ID that we cannot link to your Apple ID or name. Because reports carry this stable ID — and because you can ask us to delete reports tied to it — they are pseudonymous rather than strictly anonymous.
- **Their privacy policy:** https://sentry.io/privacy/
- **How to turn it off:** see "Your Rights" below.

---

## App Store Privacy Nutrition Label

The only data collected (i.e., transmitted off your device) is pseudonymous diagnostics. We declare it in App Store Connect as:

| Data Type | Collected? | Purpose | Linked to You? | Used to Track? |
|-----------|------------|---------|----------------|----------------|
| Crash Data | Yes, via Sentry | App Functionality (diagnostics) | No | No |
| Performance Data | Yes, via Sentry | App Functionality (diagnostics) | No | No |

**Not collected** — stays on your device (and, if you enable it, your iCloud): captured images and videos, recognized text (OCR), tags and notes (User Content), coarse location, contacts, identifiers, search and browsing history, purchase history, financial info, health & fitness, and sensitive info.

---

## Device Permissions

These permissions are used entirely on your device; granting them does not send data to us.

| Permission | Purpose | When Asked |
|------------|---------|------------|
| Camera | Capture photos of documents, receipts, and notes | First camera use |
| Location (While Using) | Optionally tag captures with location — stored on-device, never transmitted | When you enable location tagging in Settings |
| Contacts (Full Access) | Save contacts extracted from business cards | First "Save Contact" action |
| Calendars (Full Access) | Create calendar events from captured event details | First "Add to Calendar" action |
| Reminders (Full Access) | Create reminders from captured to-do lists | First "Add to Reminders" action |

You can revoke any permission at any time in iOS Settings → QuillStack.

---

## Data Security

- The SwiftData store uses iOS file protection (`NSFileProtectionCompleteUntilFirstUserAuthentication`, the system default).
- Crash diagnostics are sent to Sentry over HTTPS. Arbitrary loads are disabled (`NSAllowsArbitraryLoads = false`).
- We do not operate a server that ingests your notes or images.

---

## Children's Privacy

QuillStack is rated 4+ and does not knowingly collect information from children. The app contains no ads, no in-app purchases, no social features, and no age-gated content.

---

## Your Rights

Because QuillStack processes your data on your device and does not operate a server that stores it:

- **Access:** your data is on your device (and, optionally, your iCloud).
- **Deletion:** deleting the app removes local data. iCloud data can be removed via iOS Settings → Apple ID → iCloud → Manage Storage → QuillStack. To request deletion of any Sentry-side crash reports tied to your installation ID, email us.
- **Portability:** use the Obsidian export to write your notes to markdown files you own.
- **Opt-out of diagnostics:** Sentry honors your iOS system-level setting at *Settings → Privacy & Security → Analytics & Improvements → Share with App Developers*. Turning it off stops non-crash telemetry from being sent. To also block crash reports, revoke network access to the app via iOS Screen Time or a network profile.

---

## Changes to This Policy

Material changes will be reflected in this document and dated in the "Last Updated" line. If you continue to use the app after a change, you accept the updated policy.

---

## Contact

**Email:** mike@mottvt.com
**Issues:** https://github.com/mikemott/QuillStack/issues

---

*QuillStack is designed to keep your paper trail yours. If something in this policy is unclear, email us.*
