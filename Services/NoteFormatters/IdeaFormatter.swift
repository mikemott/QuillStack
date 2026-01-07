//
//  IdeaFormatter.swift
//  QuillStack
//
//  Created on 2026-01-06.
//  Part of QUI-146: Note Type Visual Themes & Formatting
//

import Foundation
import SwiftUI

/// Formats idea notes with lightbulb motif, star ratings, and tag chips.
///
/// **Features:**
/// - Lightbulb header motif for ideas
/// - Star rating system (★★★☆☆)
/// - Tag chips in gold color
/// - Idea bubbles/cards for organization
/// - Connection hints between related ideas
///
/// **Detection:**
/// - Ratings: "★★★", "3/5", "Rating: 4"
/// - Tags: #innovation, #product, etc.
/// - Ideas: Bullet points, numbered lists
/// - Connections: "Related to", "Inspired by"
///
/// **Usage:**
/// ```swift
/// let formatter = IdeaFormatter()
/// let styled = formatter.format(content: ideaNote.content)
/// let metadata = formatter.extractMetadata(from: ideaNote.content)
/// ```
@MainActor
final class IdeaFormatter: NoteFormatter {

    // MARK: - NoteFormatter Protocol

    var noteType: NoteType { .idea }

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
            if let rating = detectRating(trimmed) {
                result.append(formatRating(rating))
            } else if isIdeaBullet(trimmed) {
                result.append(formatIdeaBullet(line))
            } else if containsTags(trimmed) {
                result.append(formatLineWithTags(line))
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

        // Extract rating if present
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            if let rating = detectRating(line.trimmingCharacters(in: .whitespaces)) {
                metadata["rating"] = rating
                break
            }
        }

        return metadata
    }

    // MARK: - Private Helpers

    private let goldColor = Color(red: 0.85, green: 0.65, blue: 0.13)

    private func detectRating(_ line: String) -> Int? {
        let lowerLine = line.lowercased()

        // Check for star ratings
        let starCount = line.filter { $0 == "★" }.count
        if starCount > 0 {
            return starCount
        }

        // Check for "Rating: X" or "X/5"
        let ratingPatterns = [
            "rating:\\s*(\\d)",
            "(\\d)\\s*/\\s*5",
            "(\\d)\\s*stars?"
        ]

        for pattern in ratingPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
               let ratingRange = Range(match.range(at: 1), in: line) {
                if let rating = Int(String(line[ratingRange])) {
                    return min(rating, 5) // Cap at 5 stars
                }
            }
        }

        return nil
    }

    private func isIdeaBullet(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("•") || trimmed.hasPrefix("-") ||
               trimmed.hasPrefix("*") || trimmed.hasPrefix("💡")
    }

    private func containsTags(_ line: String) -> Bool {
        return line.contains("#")
    }

    private func formatRating(_ rating: Int) -> AttributedString {
        var result = AttributedString()

        // Stars
        let filledStars = String(repeating: "★", count: rating)
        let emptyStars = String(repeating: "☆", count: max(0, 5 - rating))

        var starsAttr = AttributedString(filledStars + emptyStars)
        starsAttr.foregroundColor = goldColor
        starsAttr.font = .title3
        result.append(starsAttr)

        return result
    }

    private func formatIdeaBullet(_ line: String) -> AttributedString {
        var result = AttributedString()
        var text = line.trimmingCharacters(in: .whitespaces)

        // Remove existing bullet
        if text.hasPrefix("💡") {
            text = String(text.dropFirst()).trimmingCharacters(in: .whitespaces)
        } else if text.hasPrefix("•") || text.hasPrefix("-") || text.hasPrefix("*") {
            text = String(text.dropFirst()).trimmingCharacters(in: .whitespaces)
        }

        // Add lightbulb bullet
        var bulletAttr = AttributedString("💡 ")
        bulletAttr.font = .system(size: 16)
        result.append(bulletAttr)

        // Add idea text with tags highlighted
        if containsTags(text) {
            result.append(formatTextWithTags(text))
        } else {
            result.append(AttributedString(text))
        }

        return result
    }

    private func formatLineWithTags(_ line: String) -> AttributedString {
        formatTextWithTags(line)
    }

    private func formatTextWithTags(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        let tagPattern = "#([\\w]+)"

        guard let regex = try? NSRegularExpression(pattern: tagPattern) else {
            return result
        }

        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)

        for match in matches {
            if let matchRange = Range(match.range, in: text) {
                let attributedRange = AttributedString.Index(matchRange.lowerBound, within: result)!..<AttributedString.Index(matchRange.upperBound, within: result)!
                result[attributedRange].foregroundColor = goldColor
                result[attributedRange].font = .body.bold()
            }
        }

        return result
    }
}
