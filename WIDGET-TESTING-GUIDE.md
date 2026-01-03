# QuillStack Widget Testing Guide

## Widget Implementation Summary

QuillStack includes two widget types:

### Home Screen Widgets (`.systemSmall`, `.systemMedium`, `.systemLarge`)
- **Small (2x2)**: Voice capture button, camera capture button, daily note count
- **Medium (4x2)**: Capture buttons + 3 most recent notes with badges and timestamps
- **Large (4x4)**: Capture buttons + 6-8 recent notes + daily stats footer

### Lock Screen Widgets (iOS 16+)
- **Accessory Circular**: Voice capture or camera capture buttons
- **Accessory Rectangular**: Note count with today's stats
- **Accessory Inline**: Most recent note preview

## Testing Checklist

### ✅ Basic Functionality

#### Home Screen Widgets
- [ ] Add Small widget to home screen - displays correctly
- [ ] Add Medium widget to home screen - displays correctly
- [ ] Add Large widget to home screen - displays correctly
- [ ] Widget updates when new notes are created
- [ ] Widget updates on 15-minute refresh interval

#### Lock Screen Widgets
- [ ] Add Circular widget to lock screen - displays correctly
- [ ] Add Rectangular widget to lock screen - displays correctly
- [ ] Add Inline widget to lock screen - displays correctly
- [ ] Lock screen widgets update when notes change

### ✅ Deep Links

Test all deep link actions work correctly:

- [ ] Small widget: Tap voice button → opens voice capture
- [ ] Small widget: Tap camera button → opens camera
- [ ] Medium widget: Tap voice button → opens voice capture
- [ ] Medium widget: Tap camera button → opens camera
- [ ] Medium widget: Tap note → opens note detail view
- [ ] Large widget: Tap voice button → opens voice capture
- [ ] Large widget: Tap camera button → opens camera
- [ ] Large widget: Tap note → opens note detail view
- [ ] Lock screen circular: Tap → opens voice capture
- [ ] Lock screen rectangular: Tap → opens app
- [ ] Lock screen inline: Tap → opens app

### ✅ Empty States

- [ ] Delete all notes
- [ ] Small widget shows "No notes yet"
- [ ] Medium widget shows empty state message
- [ ] Large widget shows empty state with capture buttons
- [ ] Lock screen widgets handle empty state gracefully

### ✅ Performance Testing

#### Many Notes
- [ ] Create 100+ notes
- [ ] Widget loads without lag
- [ ] Timeline refresh completes in < 1 second
- [ ] Memory usage stays under 50MB

#### Edge Cases
- [ ] Notes with very long content (500+ chars) - truncates properly
- [ ] Notes with special characters and emojis - displays correctly
- [ ] Notes created in rapid succession - all appear in timeline

### ✅ Appearance & Theming

#### Light Mode
- [ ] Small widget: Background, text, icons visible
- [ ] Medium widget: Note badges have correct colors
- [ ] Large widget: Stats footer readable
- [ ] Lock screen widgets: Tinted correctly

#### Dark Mode
- [ ] Switch to dark mode system-wide
- [ ] Small widget adapts to dark mode
- [ ] Medium widget adapts to dark mode
- [ ] Large widget adapts to dark mode
- [ ] Lock screen widgets adapt to dark mode
- [ ] Text remains readable in all sizes

### ✅ Type Badge Colors

Verify all 12 note type badges display with correct colors in widgets:

- [ ] General: Gray badge
- [ ] Todo: Blue badge
- [ ] Meeting: Purple badge
- [ ] Email: Red badge
- [ ] Contact: Green badge
- [ ] Reminder: Orange badge
- [ ] Expense: Yellow badge
- [ ] Shopping: Pink badge
- [ ] Recipe: Brown badge
- [ ] Event: Indigo badge
- [ ] Idea: Teal badge
- [ ] Claude Prompt: Gradient badge

### ✅ Timeline Behavior

- [ ] Create a note → widget updates within 15 minutes
- [ ] Force refresh app → widget updates immediately (via WidgetCenter.reloadAllTimelines())
- [ ] Kill app → reopen → widget shows latest data
- [ ] Reboot device → widget reloads correctly

### ✅ App Updates & Migrations

- [ ] Simulate app update (bump version number)
- [ ] Widget continues to function
- [ ] Core Data migration preserves widget data access
- [ ] No crashes after update

### ✅ Device Testing

Test on multiple device sizes:

- [ ] iPhone SE (small screen)
- [ ] iPhone 14/15 Pro (standard)
- [ ] iPhone 14/15 Pro Max (large)
- [ ] iPad (if widgets supported)

### ✅ Widget Gallery & Configuration

- [ ] Open widget picker
- [ ] QuillStack appears in gallery
- [ ] Widget preview images display
- [ ] Configuration display name: "QuillStack"
- [ ] Description: "Quick capture and view your recent notes"
- [ ] Lock screen description: "Quick access to notes and capture"

## Known Issues & Limitations

### Widget Limitations (iOS WidgetKit)
- Widgets cannot directly record audio or capture photos (by design)
- Widgets update on system-determined schedule + manual refresh
- Maximum 50MB memory per widget
- Complex animations not supported

### Current Implementation Notes
- Timeline refresh: 15 minutes (can be customized)
- Note limit in Medium widget: 3 notes
- Note limit in Large widget: 6-8 notes
- Content truncation: 2 lines max for note preview

## Performance Benchmarks

Target performance metrics:

- **Widget load time**: < 500ms
- **Timeline fetch from Core Data**: < 100ms
- **Memory usage**: < 30MB per widget
- **Timeline entry count**: 5 entries (now + 4 future)

## Troubleshooting

### Widget Not Updating
1. Check WidgetCenter.shared.reloadAllTimelines() is called after note creation
2. Verify App Groups entitlement is configured
3. Check Core Data shared container path
4. Force remove and re-add widget

### Widget Shows Old Data
1. Kill widget extension process: Settings > Developer > Clear Trusted Computers
2. Reboot device
3. Check NotificationCenter post is triggering reload

### Deep Links Not Working
1. Verify URL scheme in Info.plist: `quillstack://`
2. Check DeepLinkManager is handling URL
3. Test URL in Safari: `quillstack://capture/voice`

## Testing Commands

```bash
# Reload all widgets programmatically
# Add to QuillStackApp.swift or NoteViewModel after note creation:
WidgetCenter.shared.reloadAllTimelines()

# Check widget memory usage in Instruments:
# Product > Profile > Allocations
# Filter by "QuillStackWidget"

# Simulate widget refresh in Xcode
# Run widget scheme, then use Debug > Simulate Location
```

## Sign-Off Checklist

Before marking widgets as complete:

- [ ] All widget sizes build and run
- [ ] All deep links tested and working
- [ ] Empty states tested
- [ ] Dark mode tested
- [ ] Performance acceptable (< 500ms load)
- [ ] Memory usage acceptable (< 30MB)
- [ ] Tested on physical device
- [ ] TestFlight notes updated
- [ ] No crashes in last 10 test sessions

## TestFlight Release Notes

```
🎉 New in this release: Home Screen & Lock Screen Widgets!

• Add QuillStack widgets to your home screen for quick access
• Three sizes: Small (quick capture), Medium (recent notes), Large (full dashboard)
• Lock screen widgets for iOS 16+ (circular, rectangular, inline)
• Tap notes in widgets to open them instantly
• Voice and camera capture buttons right from your home screen

Widgets update automatically as you create new notes!
```

## Next Steps for Production

1. **Test on physical devices** - Widgets behave differently on real hardware
2. **Profile memory usage** - Use Instruments to verify < 30MB
3. **Test with real user data** - Create 50+ notes and test performance
4. **A/B test widget designs** - Gather feedback on spacing/colors
5. **Monitor crash reports** - Check Sentry for widget-specific crashes
6. **Update screenshots** - Capture widget previews for App Store

---

**Testing Date**: _________
**Tested By**: _________
**Device**: _________
**iOS Version**: _________
**Build Number**: _________
