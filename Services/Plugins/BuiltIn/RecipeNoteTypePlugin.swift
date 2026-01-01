//
//  RecipeNoteTypePlugin.swift
//  QuillStack
//
//  Built-in plugin for recipe notes.
//

import SwiftUI

/// Plugin for recipe notes.
struct RecipeNoteTypePlugin: NoteTypePlugin {

    // MARK: - Identity

    let id = "builtin.recipe"
    let type = NoteType.recipe

    // MARK: - Triggers

    let triggers = ["#recipe#", "#cook#", "#bake#"]

    // MARK: - Display

    let displayName = "Recipe"
    let icon = "fork.knife"
    let badgeColor = Color.badgeRecipe
    let footerIcon = "list.bullet"

    // MARK: - View Factory

    func makeDetailView(for note: Note) -> AnyView {
        AnyView(RecipeDetailView(note: note))
    }
}
