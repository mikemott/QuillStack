//
//  ExpenseNoteTypePlugin.swift
//  QuillStack
//
//  Built-in plugin for expense/receipt notes.
//

import SwiftUI

/// Plugin for expense/receipt notes.
struct ExpenseNoteTypePlugin: NoteTypePlugin {

    // MARK: - Identity

    let id = "builtin.expense"
    let type = NoteType.expense

    // MARK: - Triggers

    let triggers = ["#expense#", "#receipt#", "#spent#", "#paid#"]

    // MARK: - Display

    let displayName = "Expense"
    let icon = "dollarsign.circle"
    let badgeColor = Color.badgeExpense
    let footerIcon = "creditcard"

    // MARK: - View Factory

    func makeDetailView(for note: Note) -> AnyView {
        AnyView(ExpenseDetailView(note: note))
    }
}
