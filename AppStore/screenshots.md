# QuillStack - Screenshot Requirements

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

### Screenshot 1: Hero/Note List
**Caption:** "Your handwritten notes, digitized"
- Show the main NoteListView with the QuillStack logo header
- Display 3-4 sample notes with different types (Todo, Meeting, Email, Prompt)
- Show the confidence bar on note cards

### Screenshot 2: Camera Capture
**Caption:** "Point, capture, convert"
- Show the camera view with a handwritten note in frame
- Flash toggle and capture button visible
- Perhaps show template overlay options

### Screenshot 3: OCR Confidence
**Caption:** "Smart confidence highlighting"
- Show a note detail view with some words underlined (low confidence)
- Maybe show the word alternatives popup
- Emphasize the accuracy feedback

### Screenshot 4: Todo List
**Caption:** "Checkable tasks from handwriting"
- Show TodoDetailView with several tasks
- Mix of completed and pending items
- Show progress indicator

### Screenshot 5: AI Enhancement
**Caption:** "AI-powered text cleanup"
- Show before/after of enhanced text
- Or show the Enhance button in action
- Claude integration visible

### Screenshot 6: Export Options
**Caption:** "Export anywhere"
- Show the export sheet with destinations
- GitHub, Obsidian, Notion, Apple Notes icons
- Emphasize flexibility

### Screenshot 7: Meeting Notes (Optional)
**Caption:** "Meeting notes with structure"
- Show MeetingDetailView
- Attendees, agenda, action items
- Calendar integration button

### Screenshot 8: Search (Optional)
**Caption:** "Find any note instantly"
- Show search view with results
- Filter options visible
- Full-text search in action

---

## Screenshot Tips

1. **Use real content** - Create sample notes that look authentic but don't contain personal info

2. **Clean status bar** - Take screenshots at 9:41 AM with full battery (Apple's preferred time)

3. **Consistent style** - Same background color, similar content density across all shots

4. **Show key features** - Each screenshot should highlight a different capability

5. **Captions** - Add text overlays that explain the feature (use a tool like Figma or Canva)

---

## Taking Screenshots

### On Simulator:
```bash
# Run in simulator, then:
# Cmd + S to save screenshot
xcrun simctl io booted screenshot screenshot.png
```

### On Device:
- Side button + Volume up (Face ID devices)
- Side button + Home button (Touch ID devices)

### From Xcode:
1. Run app on device/simulator
2. Debug → View Debugging → Take Screenshot

---

## App Preview Video (Optional but Recommended)

- 15-30 seconds
- Show the capture → OCR → organize flow
- Same resolutions as screenshots
- No audio required, but can add music/captions

---

## Sample Note Content for Screenshots

### Todo Note:
```
#todo#
Project Tasks
- Review design mockups
- Update documentation
- Fix login bug
- Send weekly report
```

### Meeting Note:
```
#meeting#
Sprint Planning
Attendees: Sarah, Mike, Alex
Date: Monday 2pm

Agenda:
- Review backlog
- Assign stories
- Set sprint goals
```

### Email Note:
```
#email#
To: team@company.com
Subject: Project Update

Hi team,
Quick update on the project status...
```

### Claude Prompt Note:
```
#claude#
Add dark mode toggle to settings
- Should persist preference
- Use system default option
- Animate transition
```
