//
//  ShoppingNoteTypePlugin.swift
//  QuillStack
//
//  Built-in plugin for shopping/grocery list notes.
//

import SwiftUI

/// Plugin for shopping list notes.
struct ShoppingNoteTypePlugin: NoteTypePlugin {

    // MARK: - Identity

    let id = "builtin.shopping"
    let type = NoteType.shopping

    // MARK: - Triggers

    let triggers = ["#shopping#", "#shop#", "#grocery#", "#groceries#", "#list#"]

    // MARK: - Display

    let displayName = "Shopping"
    let icon = "cart"
    let badgeColor = Color.badgeShopping
    let footerIcon = "bag"

    // MARK: - View Factory

    func makeDetailView(for note: Note) -> AnyView {
        AnyView(ShoppingDetailView(note: note))
    }
}
