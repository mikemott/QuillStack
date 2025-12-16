//
//  MeetingParser.swift
//  QuillStack
//
//  Created on 2025-12-10.
//

import Foundation
import CoreData

class MeetingParser {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    /// Detects and parses meeting information from text
    func parseMeeting(from text: String, note: Note? = nil) -> Meeting? {
        // Look for meeting indicators
        let indicators = [
            "meeting",
            "call with",
            "agenda",
            "attendees:",
            "discussion:",
            "action items",
            "minutes"
        ]

        let lowercased = text.lowercased()
        let hasMeetingIndicator = indicators.contains { lowercased.contains($0) }

        guard hasMeetingIndicator else { return nil }

        let meeting = Meeting(context: context)
        meeting.title = extractTitle(from: text)
        meeting.meetingDate = extractDate(from: text)
        meeting.attendees = extractAttendees(from: text).joined(separator: ", ")
        meeting.agenda = extractAgenda(from: text)
        meeting.actionItems = extractActionItems(from: text).joined(separator: "\n")
        meeting.note = note

        return meeting
    }

    private func extractTitle(from text: String) -> String {
        // First line is often the title
        let lines = text.components(separatedBy: .newlines)
        let firstLine = lines.first?.trimmingCharacters(in: .whitespaces) ?? "Untitled Meeting"

        // Remove common prefixes
        let cleanedTitle = firstLine
            .replacingOccurrences(of: "Meeting:", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "Minutes:", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespaces)

        return cleanedTitle.isEmpty ? "Untitled Meeting" : cleanedTitle
    }

    private func extractDate(from text: String) -> Date? {
        // Look for date/time patterns
        let datePatterns = [
            "\\d{1,2}/\\d{1,2}/\\d{2,4}",          // 12/25/24
            "\\w+\\s+\\d{1,2},?\\s+\\d{4}"         // December 25, 2024
        ]

        for pattern in datePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(text.startIndex..., in: text)
                if let match = regex.firstMatch(in: text, range: range) {
                    let dateRange = Range(match.range, in: text)
                    if let dateRange = dateRange {
                        let dateString = String(text[dateRange])
                        return parseDateString(dateString)
                    }
                }
            }
        }

        return nil
    }

    private func extractAttendees(from text: String) -> [String] {
        var attendees: [String] = []

        if let range = text.range(of: "attendees:", options: [.caseInsensitive]) {
            let afterAttendees = text[range.upperBound...]
            let lines = afterAttendees.components(separatedBy: .newlines)

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty { break }

                // Look for names (starting with letter or containing @)
                if trimmed.contains("@") || trimmed.first?.isLetter == true {
                    // Remove bullet points or dashes
                    let cleaned = trimmed
                        .replacingOccurrences(of: "^[-*•]\\s*", with: "", options: .regularExpression)
                    attendees.append(cleaned)
                }
            }
        }

        return attendees
    }

    private func extractAgenda(from text: String) -> String {
        if let range = text.range(of: "agenda:", options: [.caseInsensitive]) {
            let afterAgenda = text[range.upperBound...]

            // Get text until next section or end
            if let nextSectionRange = afterAgenda.range(of: "attendees:|action items:|discussion:", options: [.caseInsensitive, .regularExpression]) {
                return String(afterAgenda[..<nextSectionRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                return afterAgenda.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return ""
    }

    private func extractActionItems(from text: String) -> [String] {
        let parser = TodoParser(context: context)
        let todos = parser.parseTodos(from: text)
        return todos.map { $0.text }
    }

    private func parseDateString(_ string: String) -> Date? {
        let formatter = DateFormatter()

        // Try MM/dd/yyyy format
        formatter.dateFormat = "MM/dd/yyyy"
        if let date = formatter.date(from: string) {
            return date
        }

        // Try MM/dd/yy format
        formatter.dateFormat = "MM/dd/yy"
        if let date = formatter.date(from: string) {
            return date
        }

        // Try full text format
        formatter.dateFormat = "MMMM dd, yyyy"
        if let date = formatter.date(from: string) {
            return date
        }

        return nil
    }
}
