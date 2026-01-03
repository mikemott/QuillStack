//
//  WidgetNote.swift
//  QuillStackWidget
//
//  Created on 2026-01-02.
//

import Foundation
import SwiftUI

/// Lightweight note model for widgets (no Core Data dependency)
struct WidgetNote: Identifiable, Hashable {
    let id: UUID
    let content: String
    let noteType: String
    let createdAt: Date

    var displayContent: String {
        // Get first line or first 50 characters
        let firstLine = content.components(separatedBy: .newlines).first ?? content
        return String(firstLine.prefix(50))
    }

    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }

    var badgeColor: Color {
        switch noteType {
        case "todo": return .blue
        case "meeting": return .green
        case "email": return .orange
        case "reminder": return .purple
        case "contact": return .pink
        case "expense": return .red
        case "shopping": return .teal
        case "recipe": return .brown
        case "event": return .indigo
        case "idea": return .yellow
        case "claudePrompt": return .cyan
        default: return .gray
        }
    }

    var iconName: String {
        switch noteType {
        case "todo": return "checkmark.circle"
        case "meeting": return "person.2"
        case "email": return "envelope"
        case "reminder": return "bell"
        case "contact": return "person.crop.circle"
        case "expense": return "dollarsign.circle"
        case "shopping": return "cart"
        case "recipe": return "fork.knife"
        case "event": return "calendar"
        case "idea": return "lightbulb"
        case "claudePrompt": return "sparkles"
        default: return "doc.text"
        }
    }
}

/// Daily statistics for widgets
struct DailyStats {
    let totalNotes: Int
    let todoCount: Int
    let meetingCount: Int

    var isEmpty: Bool {
        totalNotes == 0
    }
}
