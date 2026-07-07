# Privacy Policy for QuillStack

**Last Updated:** December 31, 2024

## Overview

QuillStack ("the App") is committed to protecting your privacy. This Privacy Policy explains how we handle information when you use our iOS application.

**The short version:** QuillStack does not collect, store, or transmit your captured notes, images, OCR text, tags, contacts, events, receipts, or reminders to QuillStack servers. Your capture content remains on your device or in your personal iCloud account. If crash reporting is enabled in the App Store build, limited diagnostic telemetry may be sent to Sentry to help identify crashes and performance problems.

---

## Information We Do NOT Collect

QuillStack does not collect:
- Personal identification information
- Advertising identifiers
- Location data for advertising or tracking
- Any content from your notes

QuillStack may collect limited diagnostic information:
- Crash reports
- Performance and app hang diagnostics
- Basic device and operating system information needed to diagnose crashes
- Non-content app breadcrumbs such as capture count, OCR status, selected tag names, and action type

Diagnostic telemetry is used only to improve app stability and performance. It is not used for advertising or cross-app tracking.

---

## Data Storage

### Local Storage
All notes, images, and settings are stored locally on your device using:
- SwiftData for structured note content
- Local file storage for captured images
- UserDefaults for settings

### iCloud Sync (Optional)
If you enable iCloud sync on your device, your QuillStack data may sync across your Apple devices through your personal iCloud account. This sync is handled entirely by Apple's CloudKit framework, and we have no access to your iCloud data.

---

## Third-Party Services

QuillStack uses the following third-party services:

### Sentry
- **Purpose:** Crash reporting, performance monitoring, failed-request diagnostics, and app hang diagnostics
- **Data sent:** Technical diagnostics such as crash stack traces, app version, device/OS information, performance traces, and non-content breadcrumbs
- **Data not intentionally sent:** Captured images, OCR text, contact details, receipt contents, and note content
- **Their privacy policy:** https://sentry.io/privacy/

QuillStack also allows you to optionally connect to third-party services. When you choose to use these integrations, your data is sent directly from your device to these services:

### Claude API (Anthropic)
- **Purpose:** AI-powered text enhancement and prompt refinement
- **Data sent:** Note text content you choose to enhance
- **Your control:** You provide your own API key; we never see it
- **Their privacy policy:** https://www.anthropic.com/privacy

### GitHub API
- **Purpose:** Creating issues from Claude prompt notes
- **Data sent:** Note content when you export to GitHub
- **Your control:** You authenticate with your own GitHub account
- **Their privacy policy:** https://docs.github.com/en/site-policy/privacy-policies

### Notion API
- **Purpose:** Exporting notes to Notion
- **Data sent:** Note content when you choose to export
- **Your control:** You provide your own integration token
- **Their privacy policy:** https://www.notion.so/privacy

### Obsidian
- **Purpose:** Exporting notes to Obsidian vault
- **Data sent:** None transmitted over network; files saved locally
- **Your control:** You choose the vault folder through the iOS document picker

---

## Device Permissions

QuillStack requests the following permissions:

| Permission | Purpose | When Asked |
|------------|---------|------------|
| Camera | Capture photos of handwritten notes | First camera use |
| Calendar | Create events from meeting notes | First calendar export |
| Reminders | Export todo items to Reminders app | First reminder export |

You can revoke any permission at any time through iOS Settings.

---

## Data Security

- QuillStack does not currently store third-party API keys
- SwiftData and local app storage are protected by iOS app sandboxing and device security
- No data is transmitted to our servers
- Diagnostic telemetry and third-party service requests use HTTPS encryption

---

## Children's Privacy

QuillStack does not knowingly collect information from children under 13. The app does not contain ads, in-app purchases, or social features that would require age-gated content.

---

## Changes to This Policy

We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy in the app and updating the "Last Updated" date.

---

## Contact Us

If you have questions about this Privacy Policy, please contact us at:

**Email:** [your-email@example.com]
**GitHub:** https://github.com/[your-username]/quillstack/issues

---

## Your Rights

Depending on your jurisdiction, you may have rights regarding your personal data. Since QuillStack does not collect personal data, these rights are automatically satisfied:

- **Right to Access:** All your data is already on your device
- **Right to Deletion:** Delete the app to remove all local data
- **Right to Portability:** Export your notes using the built-in export features
- **Right to Opt-Out:** No data collection means nothing to opt out of

---

*This privacy policy is provided for informational purposes. QuillStack is designed with privacy as a core principle—your notes are yours alone.*
