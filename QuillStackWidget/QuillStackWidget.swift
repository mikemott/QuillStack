//
//  QuillStackWidget.swift
//  QuillStackWidget
//
//  Created on 2026-01-02.
//

import WidgetKit
import SwiftUI

struct QuillStackWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: NotesTimelineProvider.Entry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

struct QuillStackWidget: Widget {
    let kind: String = "QuillStackWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NotesTimelineProvider()) { entry in
            QuillStackWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [Color(hex: "F5F1E8"), Color(hex: "E8DCC8")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
        }
        .configurationDisplayName("QuillStack")
        .description("Quick capture and view your recent notes")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview(as: .systemSmall) {
    QuillStackWidget()
} timeline: {
    NotesEntry(
        date: .now,
        recentNotes: [
            WidgetNote(
                id: UUID(),
                content: "Meeting with Sarah about Q1 planning",
                noteType: "meeting",
                createdAt: Date().addingTimeInterval(-120)
            ),
            WidgetNote(
                id: UUID(),
                content: "Buy groceries: milk, eggs, bread",
                noteType: "todo",
                createdAt: Date().addingTimeInterval(-900)
            )
        ],
        todayStats: DailyStats(totalNotes: 5, todoCount: 2, meetingCount: 1)
    )
}

#Preview(as: .systemMedium) {
    QuillStackWidget()
} timeline: {
    NotesEntry(
        date: .now,
        recentNotes: [
            WidgetNote(
                id: UUID(),
                content: "Meeting with Sarah about Q1 planning",
                noteType: "meeting",
                createdAt: Date().addingTimeInterval(-120)
            ),
            WidgetNote(
                id: UUID(),
                content: "Buy groceries: milk, eggs, bread",
                noteType: "todo",
                createdAt: Date().addingTimeInterval(-900)
            ),
            WidgetNote(
                id: UUID(),
                content: "App idea: fitness tracker with AI coaching",
                noteType: "idea",
                createdAt: Date().addingTimeInterval(-3600)
            )
        ],
        todayStats: DailyStats(totalNotes: 5, todoCount: 2, meetingCount: 1)
    )
}

#Preview(as: .systemLarge) {
    QuillStackWidget()
} timeline: {
    NotesEntry(
        date: .now,
        recentNotes: [
            WidgetNote(
                id: UUID(),
                content: "Meeting with Sarah about Q1 planning and budget review",
                noteType: "meeting",
                createdAt: Date().addingTimeInterval(-120)
            ),
            WidgetNote(
                id: UUID(),
                content: "Buy groceries: milk, eggs, bread, cheese, tomatoes",
                noteType: "todo",
                createdAt: Date().addingTimeInterval(-900)
            ),
            WidgetNote(
                id: UUID(),
                content: "App idea: fitness tracker with AI coaching and meal planning",
                noteType: "idea",
                createdAt: Date().addingTimeInterval(-3600)
            ),
            WidgetNote(
                id: UUID(),
                content: "Email draft to client about project timeline",
                noteType: "email",
                createdAt: Date().addingTimeInterval(-7200)
            ),
            WidgetNote(
                id: UUID(),
                content: "Fix authentication bug in the login flow",
                noteType: "todo",
                createdAt: Date().addingTimeInterval(-86400)
            )
        ],
        todayStats: DailyStats(totalNotes: 5, todoCount: 2, meetingCount: 1)
    )
}
