//
//  NoteFormatter.swift
//  QuillStack
//
//  Created on 2026-01-06.
//  Part of QUI-146: Note Type Visual Themes & Formatting
//

import Foundation
import SwiftUI

/// Protocol for type-specific note content formatting.
///
/// Each note type can have its own formatter that parses content and applies
/// visual styling appropriate to that type. Formatters handle:
/// - Content parsing (checkboxes, sections, metadata)
/// - AttributedString styling (colors, fonts, emphasis)
/// - Metadata extraction (progress, participants, due dates, etc.)
///
/// **Example:**
/// ```swift
/// let formatter = TodoFormatter()
/// let formattedContent = formatter.format(content: note.content)
/// let metadata = formatter.extractMetadata(from: note.content)
/// print("Progress: \(metadata["progress"] as? String ?? "N/A")")
/// ```
protocol NoteFormatter {
    /// The note type this formatter handles
    var noteType: NoteType { get }

    /// Formats raw content into a styled AttributedString
    ///
    /// - Parameter content: Raw note content (after OCR cleanup)
    /// - Returns: Formatted content with type-specific styling
    func format(content: String) -> AttributedString

    /// Extracts metadata from content for display in headers/footers
    ///
    /// - Parameter content: Raw note content
    /// - Returns: Dictionary of metadata values (progress, participants, etc.)
    func extractMetadata(from content: String) -> [String: Any]
}

// MARK: - Default Implementations

extension NoteFormatter {
    /// Default metadata extraction returns empty dictionary
    func extractMetadata(from content: String) -> [String: Any] {
        [:]
    }
}

// MARK: - Formatter Metadata Keys

/// Standard metadata keys used across formatters
enum FormatterMetadataKey {
    /// Todo: completion progress (e.g., "3 of 5")
    static let progress = "progress"

    /// Todo: percentage complete (e.g., 0.6 for 60%)
    static let progressPercentage = "progressPercentage"

    /// Todo: count of completed tasks
    static let completedCount = "completedCount"

    /// Todo: total count of tasks
    static let totalCount = "totalCount"

    /// Meeting: array of participant names
    static let participants = "participants"

    /// Meeting: date/time of meeting
    static let meetingDate = "meetingDate"

    /// Email: sender name
    static let sender = "sender"

    /// Email: recipient names
    static let recipients = "recipients"

    /// Email: subject line
    static let subject = "subject"

    /// Recipe: preparation time
    static let prepTime = "prepTime"

    /// Recipe: number of servings
    static let servings = "servings"

    /// Contact: phone number
    static let phone = "phone"

    /// Contact: email address
    static let email = "email"

    /// Contact: company name
    static let company = "company"

    /// Event: event date
    static let eventDate = "eventDate"

    /// Event: location
    static let location = "location"

    /// Expense: total amount
    static let amount = "amount"

    /// Expense: merchant name
    static let merchant = "merchant"
}

// MARK: - Shared Formatting Utilities

/// Shared utilities for all formatters
enum FormattingUtilities {
    /// Creates an AttributedString with specified attributes
    static func attributedString(
        _ text: String,
        font: Font = .body,
        color: Color = .primary
    ) -> AttributedString {
        var attributed = AttributedString(text)
        attributed.font = font
        attributed.foregroundColor = color
        return attributed
    }

    /// Applies strikethrough to completed items
    static func strikethrough(_ text: String, color: Color = .secondary) -> AttributedString {
        var attributed = AttributedString(text)
        attributed.strikethroughStyle = .single
        attributed.foregroundColor = color
        return attributed
    }

    /// Applies bold emphasis
    static func bold(_ text: String, color: Color = .primary) -> AttributedString {
        var attributed = AttributedString(text)
        attributed.font = .body.bold()
        attributed.foregroundColor = color
        return attributed
    }

    /// Applies monospace font (for code, prices, etc.)
    static func monospace(_ text: String, color: Color = .primary) -> AttributedString {
        var attributed = AttributedString(text)
        attributed.font = .system(.body, design: .monospaced)
        attributed.foregroundColor = color
        return attributed
    }
}
