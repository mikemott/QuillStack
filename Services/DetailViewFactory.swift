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
    /// Falls back to plugin registry for backward compatibility, then to NoteDetailView.
    static func makeView(for note: Note) -> AnyView {
        // Try config-based routing first (delegates to closure)
        if let config = NoteTypeConfigRegistry.shared.config(for: note.type) {
            return config.makeView(note)
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
