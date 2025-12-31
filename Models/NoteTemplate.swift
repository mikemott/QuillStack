//
//  NoteTemplate.swift
//  QuillStack
//
//  Created on 2025-12-30.
//

import SwiftUI

/// Predefined templates for structured note capture
enum NoteTemplate: String, CaseIterable, Identifiable {
    case freeform
    case meetingNotes
    case dailyTodo
    case emailDraft

    var id: String { rawValue }

    var name: String {
        switch self {
        case .freeform: return "Freeform"
        case .meetingNotes: return "Meeting Notes"
        case .dailyTodo: return "Daily Todo"
        case .emailDraft: return "Email Draft"
        }
    }

    var icon: String {
        switch self {
        case .freeform: return "pencil.line"
        case .meetingNotes: return "person.3.fill"
        case .dailyTodo: return "checklist"
        case .emailDraft: return "envelope.fill"
        }
    }

    var description: String {
        switch self {
        case .freeform: return "Write anything you like"
        case .meetingNotes: return "Attendees, agenda, action items"
        case .dailyTodo: return "Prioritized task list"
        case .emailDraft: return "To, subject, and body"
        }
    }

    var color: Color {
        switch self {
        case .freeform: return .badgeGeneral
        case .meetingNotes: return .badgeMeeting
        case .dailyTodo: return .badgeTodo
        case .emailDraft: return .badgeEmail
        }
    }

    /// The hashtag that will be auto-applied to ensure correct type classification
    var triggerHashtag: String? {
        switch self {
        case .freeform: return nil
        case .meetingNotes: return "#meeting#"
        case .dailyTodo: return "#todo#"
        case .emailDraft: return "#email#"
        }
    }

    /// Guide sections to display in the camera overlay
    var guideSections: [TemplateSection] {
        switch self {
        case .freeform:
            return []

        case .meetingNotes:
            return [
                TemplateSection(label: "Attendees:", placeholder: "List meeting participants"),
                TemplateSection(label: "Agenda:", placeholder: "Meeting topics"),
                TemplateSection(label: "Action Items:", placeholder: "Tasks and owners")
            ]

        case .dailyTodo:
            return [
                TemplateSection(label: "Priority:", placeholder: "Must-do items"),
                TemplateSection(label: "If Time:", placeholder: "Nice-to-have tasks"),
                TemplateSection(label: "Notes:", placeholder: "Additional context")
            ]

        case .emailDraft:
            return [
                TemplateSection(label: "To:", placeholder: "Recipient"),
                TemplateSection(label: "Subject:", placeholder: "Email subject"),
                TemplateSection(label: "Body:", placeholder: "Your message")
            ]
        }
    }

    /// Instruction text shown below the camera preview
    var instructionText: String {
        switch self {
        case .freeform:
            return "Point camera at your handwritten notes\nWe'll convert them to text instantly"
        case .meetingNotes:
            return "Write attendees at top, then agenda,\nand action items at the bottom"
        case .dailyTodo:
            return "List priority tasks first,\nthen 'if time' items below"
        case .emailDraft:
            return "Start with To: and Subject:\nthen write your message"
        }
    }
}

/// A section within a template guide
struct TemplateSection: Identifiable {
    let id = UUID()
    let label: String
    let placeholder: String
}
