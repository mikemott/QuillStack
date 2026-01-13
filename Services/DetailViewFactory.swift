//
//  DetailViewFactory.swift
//  QuillStack
//
//  Architecture refactoring: factory pattern for detail view routing.
//  Uses config-based routing via NoteTypeConfigRegistry.
//

import SwiftUI

/// Factory for creating type-specific detail views.
/// Uses NoteTypeConfigRegistry for config-based view routing.
@MainActor
struct DetailViewFactory {

    /// Creates the appropriate detail view for a note.
    /// Uses the config's detailViewType to route to the correct view.
    /// Falls back to plugin registry for backward compatibility, then to NoteDetailView.
    static func makeView(for note: Note) -> AnyView {
        // Try config-based routing first
        if let config = NoteTypeConfigRegistry.shared.config(for: note.type) {
            // Route based on detail view type
            switch config.detailViewType {
            case .general:
                return AnyView(NoteDetailView(note: note))
            case .todo:
                return AnyView(TodoDetailView(note: note))
            case .email:
                return AnyView(EmailDetailView(note: note))
            case .meeting:
                return AnyView(MeetingDetailView(note: note))
            case .reminder:
                return AnyView(ReminderDetailView(note: note))
            case .contact:
                return AnyView(ContactDetailView(note: note))
            case .event:
                return AnyView(EventDetailView(note: note))
            case .expense:
                return AnyView(ExpenseDetailView(note: note))
            case .shopping:
                return AnyView(ShoppingDetailView(note: note))
            case .recipe:
                return AnyView(RecipeDetailView(note: note))
            case .idea:
                return AnyView(IdeaDetailView(note: note))
            case .claudePrompt:
                return AnyView(ClaudePromptDetailView(note: note))
            }
        }

        // Fallback to plugin registry for backward compatibility
        if let view = NoteTypeRegistry.shared.makeDetailView(for: note) {
            return view
        }

        // Final fallback for unregistered types
        return AnyView(NoteDetailView(note: note))
    }

    /// Returns display info for a note type.
    /// Uses NoteTypeConfigRegistry for display information.
    static func displayInfo(for type: String) -> (name: String, icon: String, color: Color)? {
        NoteTypeConfigRegistry.shared.displayInfo(for: NoteType(from: type))
    }
}
