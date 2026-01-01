//
//  ClaudePromptNoteTypePlugin.swift
//  QuillStack
//
//  Built-in plugin for Claude/AI prompt notes.
//

import SwiftUI

/// Plugin for Claude prompt/feature request notes.
/// Used for capturing AI prompts, feature requests, and issues.
struct ClaudePromptNoteTypePlugin: NoteTypePlugin {

    // MARK: - Identity

    let id = "builtin.claudePrompt"
    let type = NoteType.claudePrompt

    // MARK: - Triggers

    let triggers = ["#claude#", "#feature#", "#prompt#", "#request#", "#issue#"]

    // MARK: - Display

    let displayName = "Feature"
    let icon = "sparkles"
    let badgeColor = Color.badgePrompt
    let footerIcon = "arrow.up.circle"

    // MARK: - View Factory

    func makeDetailView(for note: Note) -> AnyView {
        AnyView(ClaudePromptDetailView(note: note))
    }
}
