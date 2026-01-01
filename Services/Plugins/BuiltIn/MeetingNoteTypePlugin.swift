//
//  MeetingNoteTypePlugin.swift
//  QuillStack
//
//  Built-in plugin for meeting notes.
//

import SwiftUI

/// Plugin for meeting notes.
/// Supports attendees, agenda, and action items.
struct MeetingNoteTypePlugin: NoteTypePlugin {

    // MARK: - Identity

    let id = "builtin.meeting"
    let type = NoteType.meeting

    // MARK: - Triggers

    let triggers = ["#meeting#", "#notes#", "#minutes#"]

    // MARK: - Display

    let displayName = "Meeting"
    let icon = "calendar"
    let badgeColor = Color.badgeMeeting
    let footerIcon = "person.2"

    // MARK: - View Factory

    func makeDetailView(for note: Note) -> AnyView {
        AnyView(MeetingDetailView(note: note))
    }
}
