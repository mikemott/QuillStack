//
//  DetailViewFactory.swift
//  QuillStack
//
//  Architecture refactoring: factory pattern for detail view routing.
//  Delegates to NoteTypeRegistry for plugin-based view creation.
//

import SwiftUI

/// Factory for creating type-specific detail views.
/// Delegates to NoteTypeRegistry which holds the registered plugins.
@MainActor
struct DetailViewFactory {

    /// Creates the appropriate detail view for a note.
    /// Uses the plugin's makeDetailView method via NoteTypeRegistry.
    /// Falls back to NoteDetailView for unregistered types.
    static func makeView(for note: Note) -> AnyView {
        // Delegate to the registry, which holds all the plugins
        if let view = NoteTypeRegistry.shared.makeDetailView(for: note) {
            return view
        }

        // Fallback for unregistered types (should rarely happen)
        return AnyView(NoteDetailView(note: note))
    }

    /// Returns true if a custom view is registered for the type.
    static func hasCustomView(for type: NoteType) -> Bool {
        NoteTypeRegistry.shared.hasPlugin(for: type)
    }

    /// Returns all registered note types.
    static var registeredTypes: [NoteType] {
        NoteTypeRegistry.shared.availableTypes
    }
}
