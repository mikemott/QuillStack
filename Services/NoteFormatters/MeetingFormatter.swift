//
//  MeetingFormatter.swift
//  QuillStack
//
//  Created on 2026-01-06.
//  Part of QUI-146: Note Type Visual Themes & Formatting
//

import Foundation
import SwiftUI

/// Formats meeting notes with participant detection, section headers, and action items.
///
/// **Features:**
/// - Participant detection and extraction
/// - Section headers (DISCUSSION, ACTION ITEMS, etc.) with teal styling
/// - @mention highlighting in teal
/// - Action item detection and formatting
/// - Next meeting date extraction
///
/// **Section detection:**
/// - Lines with "DISCUSSION:", "ACTION ITEMS:", "NOTES:", etc. get header styling
/// - Action items section gets special bordered treatment
/// - @mentions get highlighted throughout
///
/// **Usage:**
/// ```swift
/// let formatter = MeetingFormatter()
/// let styled = formatter.format(content: meetingNote.content)
/// let metadata = formatter.extractMetadata(from: meetingNote.content)
/// let participants = metadata[FormatterMetadataKey.participants] as? [String]
/// ```
@MainActor
final class MeetingFormatter: NoteFormatter {

    // MARK: - NoteFormatter Protocol

    var noteType: NoteType { .meeting }

    func format(content: String) -> AttributedString {
        let lines = content.components(separatedBy: .newlines)
        var result = AttributedString()
        var inActionSection = false

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            guard !trimmed.isEmpty else {
                result.append(AttributedString("\n"))
                continue
            }

            // Check for section headers
            if let sectionType = detectSection(trimmed) {
                inActionSection = (sectionType == .actionItems)
                result.append(formatSectionHeader(sectionType, text: trimmed))
            } else if inActionSection {
                // Format as action item
                result.append(formatActionItem(line))
            } else {
                // Regular line with @mention detection
                result.append(formatLineWithMentions(line))
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

        // Extract participants
        let participants = extractParticipants(from: content)
        if !participants.isEmpty {
            metadata[FormatterMetadataKey.participants] = participants
        }

        // Extract meeting date if mentioned
        if let meetingDate = extractMeetingDate(from: content) {
            metadata[FormatterMetadataKey.meetingDate] = meetingDate
        }

        return metadata
    }

    // MARK: - Private Helpers

    private enum SectionType {
        case discussion
        case actionItems
        case notes
        case attendees
        case agenda
        case nextMeeting

        var displayName: String {
            switch self {
            case .discussion: return "DISCUSSION"
            case .actionItems: return "ACTION ITEMS"
            case .notes: return "NOTES"
            case .attendees: return "ATTENDEES"
            case .agenda: return "AGENDA"
            case .nextMeeting: return "NEXT MEETING"
            }
        }

        var color: Color {
            // Teal accent for all section types
            Color(red: 0.2, green: 0.7, blue: 0.7)
        }
    }

    private func detectSection(_ line: String) -> SectionType? {
        let upperLine = line.uppercased()

        if upperLine.contains("DISCUSSION") || upperLine.contains("DISCUSSED") {
            return .discussion
        } else if upperLine.contains("ACTION ITEM") || upperLine.contains("TODO") || upperLine.contains("FOLLOW UP") {
            return .actionItems
        } else if upperLine.hasPrefix("NOTES:") || upperLine.hasPrefix("NOTE:") {
            return .notes
        } else if upperLine.contains("ATTENDEE") || upperLine.contains("PARTICIPANT") || upperLine.contains("PRESENT:") {
            return .attendees
        } else if upperLine.contains("AGENDA") {
            return .agenda
        } else if upperLine.contains("NEXT MEETING") {
            return .nextMeeting
        }

        return nil
    }

    private func formatSectionHeader(_ section: SectionType, text: String) -> AttributedString {
        var result = AttributedString()

        // Section icon
        let icon: String
        switch section {
        case .discussion: icon = "💬 "
        case .actionItems: icon = "✅ "
        case .notes: icon = "📝 "
        case .attendees: icon = "👥 "
        case .agenda: icon = "📋 "
        case .nextMeeting: icon = "📅 "
        }

        var iconAttr = AttributedString(icon)
        iconAttr.font = .system(size: 16)
        result.append(iconAttr)

        // Section title
        var titleAttr = AttributedString(section.displayName)
        titleAttr.font = .headline
        titleAttr.foregroundColor = section.color
        result.append(titleAttr)

        return result
    }

    private func formatActionItem(_ line: String) -> AttributedString {
        var result = AttributedString()

        // Add action bullet point
        var bulletAttr = AttributedString("▸ ")
        bulletAttr.foregroundColor = Color(red: 0.2, green: 0.7, blue: 0.7) // Teal
        bulletAttr.font = .system(size: 16, weight: .bold)
        result.append(bulletAttr)

        // Format rest of line with mention detection
        result.append(formatLineWithMentions(line.trimmingCharacters(in: .whitespaces)))

        return result
    }

    private func formatLineWithMentions(_ line: String) -> AttributedString {
        var result = AttributedString()
        let tealColor = Color(red: 0.2, green: 0.7, blue: 0.7)

        // Split by @ to find mentions
        let parts = line.components(separatedBy: "@")

        for (index, part) in parts.enumerated() {
            if index == 0 {
                // First part (before any @)
                result.append(AttributedString(part))
            } else {
                // After @, extract the name (word characters until space)
                let namePattern = "^([\\w]+)"
                if let regex = try? NSRegularExpression(pattern: namePattern),
                   let match = regex.firstMatch(in: part, range: NSRange(part.startIndex..., in: part)) {
                    let nameRange = Range(match.range(at: 1), in: part)
                    if let nameRange = nameRange {
                        let name = String(part[nameRange])
                        let remainder = String(part[nameRange.upperBound...])

                        // Format @mention
                        var mentionAttr = AttributedString("@\(name)")
                        mentionAttr.foregroundColor = tealColor
                        mentionAttr.font = .body.bold()
                        result.append(mentionAttr)

                        // Add remainder
                        result.append(AttributedString(remainder))
                    } else {
                        result.append(AttributedString("@\(part)"))
                    }
                } else {
                    result.append(AttributedString("@\(part)"))
                }
            }
        }

        return result
    }

    private func extractParticipants(from content: String) -> [String] {
        var participants: Set<String> = []

        // Look for @mentions
        let mentionPattern = "@([\\w]+)"
        if let regex = try? NSRegularExpression(pattern: mentionPattern) {
            let range = NSRange(content.startIndex..., in: content)
            let matches = regex.matches(in: content, range: range)

            for match in matches {
                if let nameRange = Range(match.range(at: 1), in: content) {
                    let name = String(content[nameRange])
                    participants.insert(name)
                }
            }
        }

        // Look for attendees/participants section
        let lines = content.components(separatedBy: .newlines)
        var inAttendeesSection = false

        for line in lines {
            let upperLine = line.uppercased()

            if upperLine.contains("ATTENDEE") || upperLine.contains("PARTICIPANT") || upperLine.contains("PRESENT:") {
                inAttendeesSection = true
                continue
            }

            // Exit attendees section on next header
            if inAttendeesSection && detectSection(line) != nil {
                inAttendeesSection = false
            }

            if inAttendeesSection {
                // Extract names from attendee list
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    // Remove bullets, dashes, etc.
                    let name = trimmed
                        .replacingOccurrences(of: "^[•\\-*]\\s*", with: "", options: .regularExpression)
                        .trimmingCharacters(in: .whitespaces)

                    if !name.isEmpty {
                        participants.insert(name)
                    }
                }
            }
        }

        return Array(participants).sorted()
    }

    private func extractMeetingDate(from content: String) -> String? {
        let patterns = [
            "next meeting[:\\s]+([\\w\\s,]+\\d{1,2}(?:,\\s*\\d{4})?)",  // "Next meeting: Dec 15, 2024"
            "meeting date[:\\s]+([\\w\\s,]+\\d{1,2})",                  // "Meeting date: Dec 15"
            "(\\d{1,2}/\\d{1,2}/\\d{2,4})\\s+\\d{1,2}:\\d{2}",         // "12/15/24 2:30"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(content.startIndex..., in: content)
                if let match = regex.firstMatch(in: content, range: range) {
                    let dateRange = Range(match.range(at: 1), in: content)
                    if let dateRange = dateRange {
                        return String(content[dateRange]).trimmingCharacters(in: .whitespaces)
                    }
                }
            }
        }

        return nil
    }
}
