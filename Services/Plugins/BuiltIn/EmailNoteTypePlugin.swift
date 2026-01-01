//
//  EmailNoteTypePlugin.swift
//  QuillStack
//
//  Built-in plugin for email draft notes.
//

import SwiftUI

/// Plugin for email draft notes.
/// Parses To/Subject/Body and provides "Open in Mail" action.
struct EmailNoteTypePlugin: NoteTypePlugin {

    // MARK: - Identity

    let id = "builtin.email"
    let type = NoteType.email

    // MARK: - Triggers

    let triggers = ["#email#", "#mail#"]

    // MARK: - Display

    let displayName = "Email"
    let icon = "envelope"
    let badgeColor = Color.badgeEmail
    let footerIcon = "paperplane"

    // MARK: - View Factory

    func makeDetailView(for note: Note) -> AnyView {
        AnyView(EmailDetailView(note: note))
    }
}
