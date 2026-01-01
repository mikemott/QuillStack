//
//  GeneralNoteTypePlugin.swift
//  QuillStack
//
//  Built-in plugin for general/default note type.
//  Serves as the template for all other note type plugins.
//

import SwiftUI

/// Plugin for general notes (the default note type).
/// General notes have no triggers - they're the fallback when no other type matches.
struct GeneralNoteTypePlugin: NoteTypePlugin {

    // MARK: - Identity

    let id = "builtin.general"
    let type = NoteType.general

    // MARK: - Triggers

    /// General notes have no triggers - they're the default type
    let triggers: [String] = []

    // MARK: - Display

    let displayName = "Note"
    let icon = "doc.text"
    let badgeColor = Color.badgeGeneral
    let footerIcon = "text.alignleft"

    // MARK: - View Factory

    func makeDetailView(for note: Note) -> AnyView {
        AnyView(NoteDetailView(note: note))
    }
}
