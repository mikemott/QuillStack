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
            let afterAttendees = String(text[range.upperBound...])

            // Get text until next section header
            let sectionPattern = "(?i)(agenda:|action items:|discussion:|notes:|location:|date:|time:)"
            var attendeeText = afterAttendees
            if let sectionRange = afterAttendees.range(of: sectionPattern, options: .regularExpression) {
                attendeeText = String(afterAttendees[..<sectionRange.lowerBound])
            }

            // Clean up the text
            attendeeText = attendeeText
                .replacingOccurrences(of: "^[-*•]\\s*", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\n[-*•]\\s*", with: "\n", options: .regularExpression)

            // Strategy 1: Check for comma or "and" separated names on same line
            if attendeeText.contains(",") || attendeeText.lowercased().contains(" and ") {
                // Split by comma or "and"
                let separators = CharacterSet(charactersIn: ",")
                var parts = attendeeText.components(separatedBy: separators)
                    .flatMap { $0.components(separatedBy: " and ") }
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }

                for part in parts {
                    if isLikelyName(part) {
                        attendees.append(cleanName(part))
                    }
                }
            }

            // Strategy 2: If no comma-separated names found, try to group words into full names
            if attendees.isEmpty {
                let lines = attendeeText.components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }

                var pendingName: [String] = []

                for line in lines {
                    let words = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

                    for word in words {
                        let cleaned = word.trimmingCharacters(in: .punctuationCharacters)

                        // Check if this looks like a capitalized name word
                        if isCapitalizedWord(cleaned) {
                            pendingName.append(cleaned)

                            // If we have 2+ words, check if this completes a name
                            // (FirstName LastName pattern)
                            if pendingName.count >= 2 {
                                let fullName = pendingName.joined(separator: " ")
                                attendees.append(cleanName(fullName))
                                pendingName = []
                            }
                        } else if !pendingName.isEmpty {
                            // Non-capitalized word breaks the name sequence
                            // Save what we have if it looks like a name
                            if pendingName.count == 1 && isLikelySingleName(pendingName[0]) {
                                attendees.append(cleanName(pendingName[0]))
                            } else if pendingName.count >= 2 {
                                attendees.append(cleanName(pendingName.joined(separator: " ")))
                            }
                            pendingName = []
                        }
                    }
                }

                // Don't forget any remaining pending name
                if !pendingName.isEmpty {
                    attendees.append(cleanName(pendingName.joined(separator: " ")))
                }
            }
        }

        // Remove duplicates while preserving order
        var seen = Set<String>()
        return attendees.filter { name in
            let lowercased = name.lowercased()
            if seen.contains(lowercased) { return false }
            seen.insert(lowercased)
            return true
        }
    }

    /// Checks if a word is capitalized (likely a proper noun/name)
    private func isCapitalizedWord(_ word: String) -> Bool {
        guard let first = word.first else { return false }
        return first.isUppercase && word.count >= 2
    }

    /// Checks if text looks like a name (contains letters, reasonable length)
    private func isLikelyName(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard trimmed.first?.isLetter == true else { return false }
        // Names are typically 2-40 characters
        return trimmed.count >= 2 && trimmed.count <= 40
    }

    /// Checks if a single word is likely a standalone first name
    private func isLikelySingleName(_ word: String) -> Bool {
        // Single names should be capitalized and reasonable length
        guard let first = word.first else { return false }
        return first.isUppercase && word.count >= 2 && word.count <= 20
    }

    /// Cleans up a name string
    private func cleanName(_ name: String) -> String {
        return name
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
        // Use shared DateParsingService for robust date parsing
        return DateParsingService.parse(dateString: string)
    }
}
