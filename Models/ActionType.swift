//
//  ActionType.swift
//  QuillStack
//
//  Phase A.1 - Core Action Models
//  Defines available action types and their routing to integration providers.
//

import Foundation

/// All available action types that can be performed on notes.
/// Actions are routed to their respective IntegrationProvider based on `providerIdentifier`.
enum ActionType: String, Codable, CaseIterable, Sendable {
    // MARK: - LLM Actions (routed to LLMIntegrationProvider)
    case summarize
    case analyze
    case proofread
    case expand
    case translate
    case ask
    case research
    case generateQuestions
    case extractKeyPoints

    // MARK: - Integration Actions (routed to respective providers)
    case email          // → MailIntegrationProvider
    case addToCalendar  // → CalendarIntegration (existing)
    case setReminder    // → RemindersIntegration (existing)
    case createContact  // → ContactsIntegrationProvider

    // MARK: - Document-Specific (future)
    case extractExpense
    case buildSchedule
    case categorize

    // MARK: - Properties

    /// Whether this action requires user confirmation before execution
    var requiresConfirmation: Bool {
        switch self {
        case .email, .addToCalendar, .setReminder, .createContact:
            return true
        default:
            return false
        }
    }

    /// The IntegrationProvider identifier that handles this action
    var providerIdentifier: String {
        switch self {
        case .summarize, .analyze, .proofread, .expand, .translate,
             .ask, .research, .generateQuestions, .extractKeyPoints:
            return "llm"
        case .email:
            return "mail"
        case .addToCalendar:
            return "calendar"
        case .setReminder:
            return "reminders"
        case .createContact:
            return "contacts"
        case .extractExpense, .buildSchedule, .categorize:
            return "llm" // LLM-assisted extraction
        }
    }

    /// Human-readable name for display in UI
    var displayName: String {
        switch self {
        case .summarize: return "Summarize"
        case .analyze: return "Analyze"
        case .proofread: return "Proofread"
        case .expand: return "Expand"
        case .translate: return "Translate"
        case .ask: return "Ask Question"
        case .research: return "Research"
        case .generateQuestions: return "Generate Questions"
        case .extractKeyPoints: return "Extract Key Points"
        case .email: return "Send Email"
        case .addToCalendar: return "Add to Calendar"
        case .setReminder: return "Set Reminder"
        case .createContact: return "Create Contact"
        case .extractExpense: return "Extract Expense"
        case .buildSchedule: return "Build Schedule"
        case .categorize: return "Categorize"
        }
    }

    /// SF Symbol icon for this action type
    var icon: String {
        switch self {
        case .summarize: return "text.quote"
        case .analyze: return "magnifyingglass.circle"
        case .proofread: return "checkmark.circle"
        case .expand: return "arrow.up.left.and.arrow.down.right"
        case .translate: return "globe"
        case .ask: return "questionmark.bubble"
        case .research: return "books.vertical"
        case .generateQuestions: return "list.bullet.rectangle"
        case .extractKeyPoints: return "list.star"
        case .email: return "envelope"
        case .addToCalendar: return "calendar.badge.plus"
        case .setReminder: return "bell.badge"
        case .createContact: return "person.badge.plus"
        case .extractExpense: return "dollarsign.circle"
        case .buildSchedule: return "calendar.day.timeline.left"
        case .categorize: return "folder.badge.gearshape"
        }
    }
}
