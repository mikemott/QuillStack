//
//  LockScreenWidgetViews.swift
//  QuillStackWidget
//
//  Created on 2026-01-02.
//

import SwiftUI
import WidgetKit

// MARK: - Accessory Circular Widgets

struct CircularVoiceCaptureWidget: View {
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()

            Image(systemName: "mic.fill")
                .font(.system(size: 24))
                .widgetAccentable()
        }
    }
}

struct CircularCameraCaptureWidget: View {
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()

            Image(systemName: "camera.fill")
                .font(.system(size: 24))
                .widgetAccentable()
        }
    }
}

// MARK: - Accessory Rectangular Widget

struct RectangularNoteCountWidget: View {
    let entry: NotesEntry

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "note.text")
                .font(.system(size: 20))
                .widgetAccentable()

            VStack(alignment: .leading, spacing: 2) {
                Text("\(entry.todayStats.totalNotes) notes today")
                    .font(.system(size: 14, weight: .semibold))
                    .widgetAccentable()

                if entry.todayStats.todoCount > 0 || entry.todayStats.meetingCount > 0 {
                    Text("\(entry.todayStats.todoCount) todos · \(entry.todayStats.meetingCount) meetings")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 4)
    }
}

struct RectangularRecentNoteWidget: View {
    let entry: NotesEntry

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: noteTypeIcon(entry.recentNotes.first?.noteType ?? "general"))
                .font(.system(size: 18))
                .widgetAccentable()

            VStack(alignment: .leading, spacing: 2) {
                if let note = entry.recentNotes.first {
                    Text(note.content)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(2)
                        .widgetAccentable()

                    Text(relativeTime(from: note.createdAt))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                } else {
                    Text("No notes yet")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private func noteTypeIcon(_ type: String) -> String {
        switch type {
        case "todo": return "checkmark.circle.fill"
        case "meeting": return "calendar"
        case "email": return "envelope.fill"
        case "idea": return "lightbulb.fill"
        case "contact": return "person.fill"
        case "reminder": return "bell.fill"
        case "expense": return "dollarsign.circle.fill"
        case "shopping": return "cart.fill"
        case "recipe": return "fork.knife"
        case "event": return "star.fill"
        default: return "note.text"
        }
    }

    private func relativeTime(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)

        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
}

// MARK: - Accessory Inline Widget

struct InlineRecentNoteWidget: View {
    let entry: NotesEntry

    var body: some View {
        if let note = entry.recentNotes.first {
            Text(note.content)
                .lineLimit(1)
        } else {
            Text("No recent notes")
        }
    }
}

// MARK: - Lock Screen Widget Entry View

struct LockScreenWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: NotesTimelineProvider.Entry

    var body: some View {
        switch family {
        case .accessoryCircular:
            // Default to voice capture for circular
            Link(destination: URL(string: "quillstack://capture/voice")!) {
                CircularVoiceCaptureWidget()
            }

        case .accessoryRectangular:
            Link(destination: URL(string: "quillstack://")!) {
                RectangularNoteCountWidget(entry: entry)
            }

        case .accessoryInline:
            Link(destination: URL(string: "quillstack://")!) {
                InlineRecentNoteWidget(entry: entry)
            }

        default:
            Text("Unsupported")
        }
    }
}

// MARK: - Lock Screen Widget Configuration

struct QuillStackLockScreenWidget: Widget {
    let kind: String = "QuillStackLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NotesTimelineProvider()) { entry in
            LockScreenWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("QuillStack")
        .description("Quick access to notes and capture")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Previews

#Preview("Circular Voice", as: .accessoryCircular) {
    QuillStackLockScreenWidget()
} timeline: {
    NotesEntry(
        date: .now,
        recentNotes: [],
        todayStats: DailyStats(totalNotes: 3, todoCount: 1, meetingCount: 1)
    )
}

#Preview("Rectangular Count", as: .accessoryRectangular) {
    QuillStackLockScreenWidget()
} timeline: {
    NotesEntry(
        date: .now,
        recentNotes: [],
        todayStats: DailyStats(totalNotes: 5, todoCount: 2, meetingCount: 1)
    )
}

#Preview("Inline Recent", as: .accessoryInline) {
    QuillStackLockScreenWidget()
} timeline: {
    NotesEntry(
        date: .now,
        recentNotes: [
            WidgetNote(
                id: UUID(),
                content: "Meeting with Sarah about Q1 planning",
                noteType: "meeting",
                createdAt: Date().addingTimeInterval(-120)
            )
        ],
        todayStats: DailyStats(totalNotes: 5, todoCount: 2, meetingCount: 1)
    )
}
