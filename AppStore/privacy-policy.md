# Privacy Policy for QuillStack

**Last Updated:** December 31, 2024

## Overview

QuillStack ("the App") is committed to protecting your privacy. This Privacy Policy explains how we handle information when you use our iOS application.

**The short version:** QuillStack does not collect, store, or transmit your personal data to our servers. All your notes and data remain on your device or in your personal iCloud account.

---

## Information We Do NOT Collect

QuillStack does not collect:
- Personal identification information
- Usage analytics or telemetry
- Location data
- Device identifiers
- Crash reports sent to us
- Any content from your notes

---

## Data Storage

### Local Storage
All notes, images, and settings are stored locally on your device using:
- Core Data for structured note content
- Local file storage for captured images
- UserDefaults and Keychain for settings and API keys

### iCloud Sync (Optional)
If you enable iCloud sync on your device, your QuillStack data may sync across your Apple devices through your personal iCloud account. This sync is handled entirely by Apple's CloudKit framework, and we have no access to your iCloud data.

---

## Third-Party Services

QuillStack allows you to optionally connect to third-party services. When you choose to use these integrations, your data is sent directly from your device to these services:

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
- **Your control:** You specify the local vault path

---

## Device Permissions

QuillStack requests the following permissions:

| Permission | Purpose | When Asked |
|------------|---------|------------|
| Camera | Capture photos of handwritten notes | First camera use |
| Photo Library | Import existing photos of notes | First import attempt |
| Calendar | Create events from meeting notes | First calendar export |
| Reminders | Export todo items to Reminders app | First reminder export |

You can revoke any permission at any time through iOS Settings.

---

## Data Security

- API keys are stored in the iOS Keychain with hardware encryption
- Core Data store uses iOS file protection (complete protection when locked)
- No data is transmitted to our servers
- All third-party API calls use HTTPS encryption

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
