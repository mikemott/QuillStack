//
//  IdeaNoteTypePlugin.swift
//  QuillStack
//
//  Built-in plugin for idea/brainstorm notes.
//

import SwiftUI

/// Plugin for idea notes.
struct IdeaNoteTypePlugin: NoteTypePlugin {

    // MARK: - Identity

    let id = "builtin.idea"
    let type = NoteType.idea

    // MARK: - Triggers

    let triggers = ["#idea#", "#thought#", "#note-to-self#", "#notetoself#"]

    // MARK: - Display

    let displayName = "Idea"
    let icon = "lightbulb"
    let badgeColor = Color.badgeIdea
    let footerIcon = "brain"

    // MARK: - View Factory

    func makeDetailView(for note: Note) -> AnyView {
        AnyView(IdeaDetailView(note: note))
    }
}
