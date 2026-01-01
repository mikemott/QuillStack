//
//  TodoNoteTypePlugin.swift
//  QuillStack
//
//  Built-in plugin for todo/task list notes.
//

import SwiftUI

/// Plugin for todo/task list notes.
/// Handles checkable task lists with progress tracking.
struct TodoNoteTypePlugin: NoteTypePlugin {

    // MARK: - Identity

    let id = "builtin.todo"
    let type = NoteType.todo

    // MARK: - Triggers

    let triggers = ["#todo#", "#to-do#", "#tasks#", "#task#"]

    // MARK: - Display

    let displayName = "To-Do"
    let icon = "checkmark.square"
    let badgeColor = Color.badgeTodo
    let footerIcon = "checkmark.square"

    // MARK: - View Factory

    func makeDetailView(for note: Note) -> AnyView {
        AnyView(TodoDetailView(note: note))
    }
}
