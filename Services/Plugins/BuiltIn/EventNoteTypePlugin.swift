//
//  EventNoteTypePlugin.swift
//  QuillStack
//
//  Built-in plugin for calendar event notes.
//

import SwiftUI

/// Plugin for calendar event notes.
/// Integrates with iOS Calendar app.
struct EventNoteTypePlugin: NoteTypePlugin {

    // MARK: - Identity

    let id = "builtin.event"
    let type = NoteType.event

    // MARK: - Triggers

    let triggers = ["#event#", "#appointment#", "#schedule#", "#appt#"]

    // MARK: - Display

    let displayName = "Event"
    let icon = "calendar.badge.plus"
    let badgeColor = Color.badgeEvent
    let footerIcon = "clock"

    // MARK: - View Factory

    func makeDetailView(for note: Note) -> AnyView {
        AnyView(EventDetailView(note: note))
    }
}
