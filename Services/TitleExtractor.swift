//
//  TitleExtractor.swift
//  QuillStack
//
//  Created on 2026-01-06.
//  Part of QUI-146: Note Type Visual Themes & Formatting
//

import Foundation

/// Extracts smart titles from note content based on note type.
///
/// Instead of blindly using the first line as a title (which often results in
/// "[ ] Buy milk" or "Hey Mike,"), this service applies type-specific logic to
/// extract meaningful titles.
///
/// **Type-specific strategies:**
/// - **Todo**: Skip checkbox lines, find meaningful header
/// - **Meeting**: Extract from "Meeting with X" or participant names
/// - **Email**: Extract from "Subject:" line or sender info
/// - **Recipe**: Look for title-like first line (capitalized, concise)
/// - **General/Idea/Journal**: First meaningful sentence under 50 chars
///
/// **Fallback**: If no good title found, returns: "[Type] - [Date]"
///
/// **Usage:**
/// ```swift
/// let title = TitleExtractor.extractTitle(from: noteContent, type: .todo)
/// ```
@MainActor
final class TitleExtractor {

    // MARK: - Configuration

    /// Maximum length for extracted titles
    private static let maxTitleLength = 50

    // MARK: - Public API

    /// Extracts a smart title from content based on note type.
    ///
    /// - Parameters:
    ///   - content: The full text content of the note
    ///   - type: The classified note type
    /// - Returns: A meaningful title, or fallback title if extraction fails
    static func extractTitle(from content: String, type: NoteType) -> String {
        // Clean and prepare lines
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else {
            return defaultTitle(for: type)
        }

        // Apply type-specific extraction logic
        let extractedTitle: String?
        switch type {
        case .todo:
            extractedTitle = extractTodoTitle(from: lines)
        case .meeting:
            extractedTitle = extractMeetingTitle(from: lines)
        case .email:
            extractedTitle = extractEmailTitle(from: lines)
        case .recipe:
            extractedTitle = extractRecipeTitle(from: lines)
        case .contact:
            extractedTitle = extractContactTitle(from: lines)
        case .event:
            extractedTitle = extractEventTitle(from: lines)
        case .shopping:
            extractedTitle = extractShoppingTitle(from: lines)
        case .expense:
            extractedTitle = extractExpenseTitle(from: lines)
        case .claudePrompt:
            extractedTitle = extractClaudePromptTitle(from: lines)
        case .general, .idea, .journal, .reminder:
            extractedTitle = extractGenericTitle(from: lines)
        }

        // Return extracted title or fallback
        if let title = extractedTitle, !title.isEmpty {
            return title.truncated(to: maxTitleLength, trailing: "...")
        }

        return defaultTitle(for: type)
    }

    // MARK: - Type-Specific Extractors

    /// Extract title from todo list by skipping checkbox lines
    private static func extractTodoTitle(from lines: [String]) -> String? {
        // Skip lines that start with checkboxes or bullets
        for line in lines {
            let hasCheckbox = line.hasPrefix("☐") || line.hasPrefix("☑") ||
                            line.hasPrefix("[ ]") || line.hasPrefix("[x]") ||
                            line.hasPrefix("[X]") || line.hasPrefix("[]")
            let hasBullet = line.hasPrefix("•") || line.hasPrefix("-") || line.hasPrefix("*")

            if !hasCheckbox && !hasBullet && line.count < maxTitleLength {
                return line
            }
        }

        // If all lines are checkboxes, try to extract from first checkbox text
        if let firstLine = lines.first {
            // Remove checkbox prefix and use remaining text
            let cleaned = firstLine
                .replacingOccurrences(of: "☐", with: "")
                .replacingOccurrences(of: "☑", with: "")
                .replacingOccurrences(of: "[ ]", with: "")
                .replacingOccurrences(of: "[x]", with: "")
                .replacingOccurrences(of: "[X]", with: "")
                .trimmingCharacters(in: .whitespaces)

            if !cleaned.isEmpty {
                return "Todo: \(cleaned)"
            }
        }

        return nil
    }

    /// Extract title from meeting notes by finding participant or meeting context
    private static func extractMeetingTitle(from lines: [String]) -> String? {
        // Look for "Meeting with X" pattern
        for line in lines {
            let lowercased = line.lowercased()
            if lowercased.contains("meeting with") {
                return line
            }
            if lowercased.hasPrefix("meeting:") || lowercased.hasPrefix("meeting -") {
                return String(line.dropFirst("meeting:".count).trimmingCharacters(in: .whitespaces))
            }
        }

        // Look for "Attendees:" or "Participants:" section
        for (index, line) in lines.enumerated() {
            let lowercased = line.lowercased()
            if lowercased.hasPrefix("attendees:") || lowercased.hasPrefix("participants:") {
                // Use next line as title if available
                if index + 1 < lines.count {
                    return "Meeting with \(lines[index + 1])"
                }
            }
        }

        // Fallback: use first line if it's short and looks like a title
        if let firstLine = lines.first, firstLine.count < maxTitleLength {
            return firstLine
        }

        return nil
    }

    /// Extract title from email by finding Subject line
    private static func extractEmailTitle(from lines: [String]) -> String? {
        // Look for "Subject:" line (case-insensitive)
        for line in lines {
            if line.lowercased().hasPrefix("subject:") {
                let title = String(line.dropFirst("subject:".count))
                    .trimmingCharacters(in: .whitespaces)
                return title.isEmpty ? nil : title
            }
            if line.lowercased().hasPrefix("re:") {
                return line
            }
        }

        // Look for "From:" or "To:" to extract sender/recipient
        for line in lines {
            if line.lowercased().hasPrefix("from:") {
                let sender = String(line.dropFirst("from:".count))
                    .trimmingCharacters(in: .whitespaces)
                return sender.isEmpty ? nil : "Email from \(sender)"
            }
        }

        return nil
    }

    /// Extract title from recipe by using first line if it looks like a title
    private static func extractRecipeTitle(from lines: [String]) -> String? {
        guard let firstLine = lines.first else { return nil }

        // Recipe titles are usually capitalized and short
        let isCapitalized = firstLine.first?.isUppercase == true
        let isShort = firstLine.count < maxTitleLength
        let isNotIngredient = !firstLine.lowercased().contains("cup") &&
                              !firstLine.lowercased().contains("tbsp") &&
                              !firstLine.lowercased().contains("tsp")

        if isCapitalized && isShort && isNotIngredient {
            return firstLine
        }

        // Look for "Recipe:" prefix
        for line in lines {
            if line.lowercased().hasPrefix("recipe:") {
                return String(line.dropFirst("recipe:".count))
                    .trimmingCharacters(in: .whitespaces)
            }
        }

        return nil
    }

    /// Extract title from contact/business card by finding name
    private static func extractContactTitle(from lines: [String]) -> String? {
        // Name is usually the first line on a business card
        if let firstLine = lines.first,
           firstLine.count < maxTitleLength,
           !firstLine.contains("@"),  // Not an email
           !firstLine.contains("www"),  // Not a URL
           !firstLine.contains("http") {  // Not a URL
            return firstLine
        }

        return nil
    }

    /// Extract title from event by finding event name or date
    private static func extractEventTitle(from lines: [String]) -> String? {
        // Look for "Event:" prefix
        for line in lines {
            if line.lowercased().hasPrefix("event:") {
                return String(line.dropFirst("event:".count))
                    .trimmingCharacters(in: .whitespaces)
            }
        }

        // Use first non-date line as title
        if let firstLine = lines.first,
           !firstLine.contains("/"),  // Not a date
           !firstLine.lowercased().contains("date:") {
            return firstLine
        }

        return nil
    }

    /// Extract title from shopping list
    private static func extractShoppingTitle(from lines: [String]) -> String? {
        // Look for store name or list name
        if let firstLine = lines.first,
           !firstLine.hasPrefix("☐"),
           !firstLine.hasPrefix("☑"),
           !firstLine.hasPrefix("•") {
            return firstLine
        }

        return nil
    }

    /// Extract title from expense/receipt
    private static func extractExpenseTitle(from lines: [String]) -> String? {
        // Look for merchant name (usually first line)
        if let firstLine = lines.first,
           firstLine.count < maxTitleLength {
            return firstLine
        }

        // Look for amount if merchant not found
        for line in lines {
            if line.contains("$") || line.lowercased().contains("total") {
                return "Receipt - \(line)"
            }
        }

        return nil
    }

    /// Extract title from Claude prompt
    private static func extractClaudePromptTitle(from lines: [String]) -> String? {
        // Use first line as title if it's a clear prompt
        if let firstLine = lines.first, firstLine.count < maxTitleLength {
            return firstLine
        }

        return nil
    }

    /// Extract generic title from first meaningful line
    private static func extractGenericTitle(from lines: [String]) -> String? {
        // Skip bullets/checkboxes and use first meaningful sentence
        for line in lines {
            let hasCheckbox = line.hasPrefix("☐") || line.hasPrefix("☑")
            let hasBullet = line.hasPrefix("•") || line.hasPrefix("-")

            if !hasCheckbox && !hasBullet && line.count < maxTitleLength {
                return line
            }
        }

        return lines.first
    }

    // MARK: - Fallback

    /// Returns default title with type and date
    private static func defaultTitle(for type: NoteType) -> String {
        "\(type.displayName) - \(Date().shortFormat)"
    }
}
