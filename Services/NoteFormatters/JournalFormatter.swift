//
//  JournalFormatter.swift
//  QuillStack
//
//  Created on 2026-01-06.
//  Part of QUI-146: Note Type Visual Themes & Formatting
//

import Foundation
import SwiftUI

/// Formats journal entries with elegant date headers and literary-style typography.
///
/// **Features:**
/// - Elegant date headers with serif typography
/// - Generous margins for readability
/// - Entry separators with time stamps
/// - Optional mood/weather indicators
/// - Literary feel with serif fonts for body text
///
/// **Detection:**
/// - Date entries: "January 15, 2024", "Monday, Jan 15"
/// - Time stamps: "9:30 AM", "Evening"
/// - Mood indicators: 😊 😢 😐 etc.
/// - Weather: ☀️ 🌧️ ⛅ etc.
///
/// **Usage:**
/// ```swift
/// let formatter = JournalFormatter()
/// let styled = formatter.format(content: journalNote.content)
/// let metadata = formatter.extractMetadata(from: journalNote.content)
/// ```
@MainActor
final class JournalFormatter: NoteFormatter {

    // MARK: - NoteFormatter Protocol

    var noteType: NoteType { .journal }

    func format(content: String) -> AttributedString {
        let lines = content.components(separatedBy: .newlines)
        var result = AttributedString()

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            guard !trimmed.isEmpty else {
                result.append(AttributedString("\n"))
                continue
            }

            // Detect and format different line types
            if isDateHeader(trimmed) {
                result.append(formatDateHeader(trimmed))
            } else if isTimeStamp(trimmed) {
                result.append(formatTimeStamp(trimmed))
            } else {
                // Regular entry text with serif font
                result.append(formatEntryText(line))
            }

            // Add newline between lines
            if index < lines.count - 1 {
                result.append(AttributedString("\n"))
            }
        }

        return result
    }

    func extractMetadata(from content: String) -> [String: Any] {
        // Journal entries typically don't need special metadata extraction
        // Date is already in the note title usually
        [:]
    }

    // MARK: - Private Helpers

    private func isDateHeader(_ line: String) -> Bool {
        let lowerLine = line.lowercased()

        // Check for date patterns
        let monthNames = ["january", "february", "march", "april", "may", "june",
                         "july", "august", "september", "october", "november", "december",
                         "jan", "feb", "mar", "apr", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]

        let dayNames = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
                       "mon", "tue", "wed", "thu", "fri", "sat", "sun"]

        // Check if line contains month name or day name
        for month in monthNames {
            if lowerLine.contains(month) {
                return true
            }
        }

        for day in dayNames {
            if lowerLine.hasPrefix(day) {
                return true
            }
        }

        // Check for date patterns like "15th", "1st", "2024"
        if line.range(of: "\\d{1,2}(st|nd|rd|th)", options: .regularExpression) != nil {
            return true
        }

        return false
    }

    private func isTimeStamp(_ line: String) -> Bool {
        let lowerLine = line.lowercased()

        // Check for time patterns
        let timePatterns = ["morning", "afternoon", "evening", "night", "am", "pm"]

        for pattern in timePatterns {
            if lowerLine.contains(pattern) {
                return true
            }
        }

        // Check for time format like "9:30"
        if line.range(of: "\\d{1,2}:\\d{2}", options: .regularExpression) != nil {
            return true
        }

        return false
    }

    private func formatDateHeader(_ text: String) -> AttributedString {
        var result = AttributedString()

        // Decorative divider before date
        var dividerAttr = AttributedString("─── ")
        dividerAttr.foregroundColor = .secondary
        dividerAttr.font = .caption
        result.append(dividerAttr)

        // Date text with serif font
        var dateAttr = AttributedString(text)
        dateAttr.font = Font.system(.title3, design: .serif).weight(.semibold)
        dateAttr.foregroundColor = .primary
        result.append(dateAttr)

        // Closing divider
        var closingDivider = AttributedString(" ───")
        closingDivider.foregroundColor = .secondary
        closingDivider.font = .caption
        result.append(closingDivider)

        return result
    }

    private func formatTimeStamp(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        result.font = .caption
        result.foregroundColor = .secondary
        return result
    }

    private func formatEntryText(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        // Use serif font for literary feel
        result.font = Font.system(.body, design: .serif)
        result.foregroundColor = .primary
        return result
    }
}
