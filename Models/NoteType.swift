//
//  NoteType.swift
//  QuillStack
//
//  Architecture refactoring: extracted from TextClassifier.swift
//  Provides type-safe note classification.
//  Display properties are provided by NoteTypeConfigRegistry.
//

import SwiftUI

/// Type-safe enumeration of all supported note types.
/// Display properties (name, icon, color) are provided by NoteTypeConfigRegistry.
enum NoteType: String, CaseIterable, Codable, Sendable {
    case general = "general"
    case todo = "todo"
    case meeting = "meeting"
    case email = "email"
    case claudePrompt = "claudePrompt"
    case reminder = "reminder"
    case contact = "contact"
    case expense = "expense"
    case shopping = "shopping"
    case recipe = "recipe"
    case event = "event"
    case journal = "journal"
    case idea = "idea"

    // MARK: - Display Properties (via Config Registry)

    /// Human-readable name for display in UI
    /// Provided by the registered config for this type.
    @MainActor
    var displayName: String {
        NoteTypeConfigRegistry.shared.config(for: self)?.displayName ?? rawValue.capitalized
    }

    /// SF Symbol icon name for this note type
    /// Provided by the registered config for this type.
    @MainActor
    var icon: String {
        NoteTypeConfigRegistry.shared.config(for: self)?.icon ?? "doc.text"
    }

    /// Badge color for note type indicators
    /// Provided by the registered config for this type.
    @MainActor
    var badgeColor: Color {
        NoteTypeConfigRegistry.shared.config(for: self)?.badgeColor ?? .gray
    }

    /// Footer icon for card display (may differ from badge icon)
    /// Provided by the registered config for this type.
    @MainActor
    var footerIcon: String {
        NoteTypeConfigRegistry.shared.config(for: self)?.footerIcon ?? "text.alignleft"
    }

    // MARK: - Initialization

    /// Initialize from string, defaulting to .general if unrecognized
    init(from string: String) {
        self = NoteType(rawValue: string.lowercased()) ?? .general
    }
}

// MARK: - Note Extension

extension Note {
    /// Type-safe accessor for noteType string
    var type: NoteType {
        get { NoteType(from: noteType) }
        set { noteType = newValue.rawValue }
    }
}
