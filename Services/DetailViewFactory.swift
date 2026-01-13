//
//  DetailViewFactory.swift
//  QuillStack
//
//  Architecture refactoring: factory pattern for detail view routing.
//  Delegates to config closures for view creation (Open/Closed Principle).
//

import SwiftUI

/// Factory for creating type-specific detail views.
/// Delegates view creation to NoteTypeConfig closures, eliminating the need
/// for a switch statement and enabling extensibility without modification.
@MainActor
struct DetailViewFactory {

    /// Creates the appropriate detail view for a note.
    /// Delegates to the config's makeView closure for view creation.
    static func makeView(for note: Note) -> AnyView {
        // Use config-based routing (delegates to closure)
        if let config = NoteTypeConfigRegistry.shared.config(for: note.type) {
            return config.makeView(note)
        }

        // Fallback for unregistered types
        return AnyView(NoteDetailView(note: note))
    }

    /// Returns display info for a note type.
    /// Uses NoteTypeConfigRegistry for display information.
    static func displayInfo(for type: String) -> (name: String, icon: String, color: Color)? {
        NoteTypeConfigRegistry.shared.displayInfo(for: NoteType(from: type))
    }
}
