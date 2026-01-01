//
//  ContactNoteTypePlugin.swift
//  QuillStack
//
//  Built-in plugin for contact/business card notes.
//

import SwiftUI

/// Plugin for contact notes.
/// Integrates with iOS Contacts app.
struct ContactNoteTypePlugin: NoteTypePlugin {

    // MARK: - Identity

    let id = "builtin.contact"
    let type = NoteType.contact

    // MARK: - Triggers

    let triggers = ["#contact#", "#person#", "#phone#"]

    // MARK: - Display

    let displayName = "Contact"
    let icon = "person.crop.circle"
    let badgeColor = Color.badgeContact
    let footerIcon = "person"

    // MARK: - View Factory

    func makeDetailView(for note: Note) -> AnyView {
        AnyView(ContactDetailView(note: note))
    }
}
