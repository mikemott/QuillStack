//
//  FormatterRegistry.swift
//  QuillStack
//
//  Created on 2026-01-06.
//  Part of QUI-146: Note Type Visual Themes & Formatting
//

import Foundation

/// Central registry for note type formatters.
///
/// Provides easy access to the appropriate formatter for each note type.
/// Currently implements TodoFormatter, with more formatters to be added
/// as part of the QUI-146 implementation.
///
/// **Usage:**
/// ```swift
/// let formatter = FormatterRegistry.shared.formatter(for: .todo)
/// let formattedContent = formatter.format(content: note.content)
/// ```
@MainActor
final class FormatterRegistry {

    // MARK: - Singleton

    static let shared = FormatterRegistry()

    private init() {}

    // MARK: - Formatter Cache

    /// Cached formatter instances (formatters are stateless, so we can reuse them)
    private var formatters: [NoteType: NoteFormatter] = [:]

    // MARK: - Public API

    /// Returns the appropriate formatter for a given note type.
    ///
    /// - Parameter type: The note type to get a formatter for
    /// - Returns: A formatter instance for the specified type
    func formatter(for type: NoteType) -> NoteFormatter {
        // Return cached formatter if available
        if let cached = formatters[type] {
            return cached
        }

        // Create new formatter
        let formatter: NoteFormatter
        switch type {
        case .todo:
            formatter = TodoFormatter()

        // TODO: Implement remaining formatters as part of QUI-146
        // case .meeting:
        //     formatter = MeetingFormatter()
        // case .email:
        //     formatter = EmailFormatter()
        // case .recipe:
        //     formatter = RecipeFormatter()
        // case .contact:
        //     formatter = ContactFormatter()
        // case .event:
        //     formatter = EventFormatter()
        // case .shopping:
        //     formatter = ShoppingFormatter()
        // case .expense:
        //     formatter = ExpenseFormatter()
        // case .claudePrompt:
        //     formatter = ClaudePromptFormatter()

        default:
            // Default formatter for types without specific formatting
            formatter = DefaultFormatter(noteType: type)
        }

        // Cache and return
        formatters[type] = formatter
        return formatter
    }

    /// Clears the formatter cache (useful for testing)
    func clearCache() {
        formatters.removeAll()
    }
}

// MARK: - Default Formatter

/// Default formatter for note types that don't have specific formatting needs.
///
/// Simply returns the content as-is with basic AttributedString styling.
@MainActor
private final class DefaultFormatter: NoteFormatter {
    let noteType: NoteType

    init(noteType: NoteType) {
        self.noteType = noteType
    }

    func format(content: String) -> AttributedString {
        FormattingUtilities.attributedString(content)
    }

    func extractMetadata(from content: String) -> [String: Any] {
        [:]
    }
}
