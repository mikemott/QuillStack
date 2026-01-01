//
//  NoteType.swift
//  QuillStack
//
//  Architecture refactoring: extracted from TextClassifier.swift
//  Provides type-safe note classification.
//  Display properties now delegate to NoteTypeRegistry plugins.
//

import SwiftUI

/// Type-safe enumeration of all supported note types.
/// Display properties (name, icon, color) are provided by registered plugins.
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
    case idea = "idea"

    // MARK: - Display Properties (via Registry)

    /// Human-readable name for display in UI
    /// Provided by the registered plugin for this type.
    @MainActor
    var displayName: String {
        NoteTypeRegistry.shared.displayInfo(for: self)?.name ?? rawValue.capitalized
    }

    /// SF Symbol icon name for this note type
    /// Provided by the registered plugin for this type.
    @MainActor
    var icon: String {
        NoteTypeRegistry.shared.displayInfo(for: self)?.icon ?? "doc.text"
    }

    /// Badge color for note type indicators
    /// Provided by the registered plugin for this type.
    @MainActor
    var badgeColor: Color {
        NoteTypeRegistry.shared.displayInfo(for: self)?.color ?? .gray
    }

    /// Footer icon for card display (may differ from badge icon)
    /// Provided by the registered plugin for this type.
    @MainActor
    var footerIcon: String {
        NoteTypeRegistry.shared.footerIcon(for: self) ?? "text.alignleft"
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
