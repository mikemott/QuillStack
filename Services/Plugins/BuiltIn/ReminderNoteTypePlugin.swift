//
//  ReminderNoteTypePlugin.swift
//  QuillStack
//
//  Built-in plugin for reminder notes.
//

import SwiftUI

/// Plugin for reminder notes.
/// Integrates with iOS Reminders app.
struct ReminderNoteTypePlugin: NoteTypePlugin {

    // MARK: - Identity

    let id = "builtin.reminder"
    let type = NoteType.reminder

    // MARK: - Triggers

    let triggers = ["#reminder#", "#remind#", "#remindme#"]

    // MARK: - Display

    let displayName = "Reminder"
    let icon = "bell"
    let badgeColor = Color.badgeReminder
    let footerIcon = "clock"

    // MARK: - View Factory

    func makeDetailView(for note: Note) -> AnyView {
        AnyView(ReminderDetailView(note: note))
    }
}
