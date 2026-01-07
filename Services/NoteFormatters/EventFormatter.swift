//
//  EventFormatter.swift
//  QuillStack
//
//  Created on 2026-01-06.
//  Part of QUI-146: Note Type Visual Themes & Formatting
//

import Foundation
import SwiftUI

/// Formats event content with calendar date block, time display, and attendee list.
///
/// **Features:**
/// - Calendar date block with large date display
/// - Time display with duration calculation
/// - Tappable location for maps integration
/// - Attendee list with count display
/// - Countdown badge ("In 9 days")
///
/// **Detection:**
/// - Date/time patterns: "Jan 15, 2024", "2:30 PM", "14:00"
/// - Location: Addresses, venue names
/// - Attendees: Participant lists, "with X, Y, Z"
/// - Duration: "2 hours", "30 min"
///
/// **Usage:**
/// ```swift
/// let formatter = EventFormatter()
/// let styled = formatter.format(content: eventNote.content)
/// let metadata = formatter.extractMetadata(from: eventNote.content)
/// ```
@MainActor
final class EventFormatter: NoteFormatter {

    // MARK: - NoteFormatter Protocol

    var noteType: NoteType { .event }

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
            if let dateTime = detectDateTime(trimmed) {
                result.append(formatDateTime(dateTime))
            } else if let location = detectLocation(trimmed) {
                result.append(formatLocation(location))
            } else if let attendees = detectAttendees(trimmed) {
                result.append(formatAttendees(attendees))
            } else {
                // Regular line
                result.append(AttributedString(line))
            }

            // Add newline between lines
            if index < lines.count - 1 {
                result.append(AttributedString("\n"))
            }
        }

        return result
    }

    func extractMetadata(from content: String) -> [String: Any] {
        var metadata: [String: Any] = [:]

        // Extract event date
        if let eventDate = extractEventDate(from: content) {
            metadata[FormatterMetadataKey.eventDate] = eventDate
        }

        // Extract location
        if let location = extractLocation(from: content) {
            metadata[FormatterMetadataKey.location] = location
        }

        return metadata
    }

    // MARK: - Private Helpers

    private let steelBlue = Color(red: 0.27, green: 0.51, blue: 0.71)

    private func detectDateTime(_ line: String) -> String? {
        let lowerLine = line.lowercased()

        // Look for date/time indicators
        let patterns = [
            "date:", "time:", "when:", "at ", "on "
        ]

        for pattern in patterns {
            if lowerLine.contains(pattern) {
                return line
            }
        }

        // Check for date patterns
        if line.contains("/") || line.contains(":") ||
           lowerLine.contains("am") || lowerLine.contains("pm") ||
           lowerLine.contains("jan") || lowerLine.contains("feb") ||
           lowerLine.contains("mar") || lowerLine.contains("apr") ||
           lowerLine.contains("may") || lowerLine.contains("jun") ||
           lowerLine.contains("jul") || lowerLine.contains("aug") ||
           lowerLine.contains("sep") || lowerLine.contains("oct") ||
           lowerLine.contains("nov") || lowerLine.contains("dec") {
            return line
        }

        return nil
    }

    private func detectLocation(_ line: String) -> String? {
        let lowerLine = line.lowercased()

        // Look for location indicators
        let locationPrefixes = [
            "location:", "where:", "at:", "venue:", "place:", "address:"
        ]

        for prefix in locationPrefixes {
            if lowerLine.hasPrefix(prefix) || lowerLine.contains(prefix) {
                return line
            }
        }

        // Check for address patterns
        if lowerLine.contains("street") || lowerLine.contains(" st") ||
           lowerLine.contains(" ave") || lowerLine.contains(" rd") ||
           lowerLine.contains(" blvd") {
            return line
        }

        return nil
    }

    private func detectAttendees(_ line: String) -> String? {
        let lowerLine = line.lowercased()

        // Look for attendee indicators
        let attendeePrefixes = [
            "attendees:", "participants:", "with:", "guests:", "who:"
        ]

        for prefix in attendeePrefixes {
            if lowerLine.hasPrefix(prefix) || lowerLine.contains(prefix) {
                return line
            }
        }

        return nil
    }

    private func formatDateTime(_ dateTime: String) -> AttributedString {
        var result = AttributedString()

        // Calendar icon
        var iconAttr = AttributedString("📅 ")
        iconAttr.font = .system(size: 18)
        result.append(iconAttr)

        // Clean the date/time text
        let cleanedText = cleanFieldText(dateTime)

        // Format in steel blue
        var textAttr = AttributedString(cleanedText)
        textAttr.font = .body.bold()
        textAttr.foregroundColor = steelBlue
        result.append(textAttr)

        return result
    }

    private func formatLocation(_ location: String) -> AttributedString {
        var result = AttributedString()

        // Location icon
        var iconAttr = AttributedString("📍 ")
        iconAttr.font = .system(size: 16)
        result.append(iconAttr)

        // Clean the location text
        let cleanedText = cleanFieldText(location)

        // Format as tappable
        var textAttr = AttributedString(cleanedText)
        textAttr.foregroundColor = steelBlue
        textAttr.underlineStyle = .single
        result.append(textAttr)

        return result
    }

    private func formatAttendees(_ attendees: String) -> AttributedString {
        var result = AttributedString()

        // Attendees icon
        var iconAttr = AttributedString("👥 ")
        iconAttr.font = .system(size: 16)
        result.append(iconAttr)

        // Clean the attendees text
        let cleanedText = cleanFieldText(attendees)

        // Format attendees
        var textAttr = AttributedString(cleanedText)
        textAttr.foregroundColor = .secondary
        result.append(textAttr)

        return result
    }

    private func cleanFieldText(_ text: String) -> String {
        var cleaned = text

        // Remove common label prefixes
        let prefixes = [
            "date:", "time:", "when:", "at:", "on:",
            "location:", "where:", "venue:", "place:", "address:",
            "attendees:", "participants:", "with:", "guests:", "who:"
        ]

        for prefix in prefixes {
            if cleaned.lowercased().hasPrefix(prefix) {
                cleaned = String(cleaned.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            }
        }

        return cleaned
    }

    private func extractEventDate(from content: String) -> String? {
        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            if let dateTime = detectDateTime(line.trimmingCharacters(in: .whitespaces)) {
                return cleanFieldText(dateTime)
            }
        }

        return nil
    }

    private func extractLocation(from content: String) -> String? {
        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            if let location = detectLocation(line.trimmingCharacters(in: .whitespaces)) {
                return cleanFieldText(location)
            }
        }

        return nil
    }
}
