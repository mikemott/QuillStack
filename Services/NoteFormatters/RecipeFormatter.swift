//
//  RecipeFormatter.swift
//  QuillStack
//
//  Created on 2026-01-06.
//  Part of QUI-146: Note Type Visual Themes & Formatting
//

import Foundation
import SwiftUI

/// Formats recipe content with ingredients, numbered steps, and cooking metadata.
///
/// **Features:**
/// - Ingredient list with checkboxes for shopping/prep mode
/// - Numbered cooking steps with large circular numbers
/// - Temperature and time highlighting (350°F, 12 min)
/// - Section separation (INGREDIENTS vs INSTRUCTIONS)
/// - Meta info extraction (servings, prep time, cook time)
///
/// **Section detection:**
/// - "INGREDIENTS" section → checkboxed ingredient list
/// - "INSTRUCTIONS" or "STEPS" section → numbered steps
/// - Temperature patterns: 350°F, 180°C, 12 min, 1 hour
///
/// **Usage:**
/// ```swift
/// let formatter = RecipeFormatter()
/// let styled = formatter.format(content: recipeNote.content)
/// let metadata = formatter.extractMetadata(from: recipeNote.content)
/// ```
@MainActor
final class RecipeFormatter: NoteFormatter {

    // MARK: - NoteFormatter Protocol

    var noteType: NoteType { .recipe }

    func format(content: String) -> AttributedString {
        let lines = content.components(separatedBy: .newlines)
        var result = AttributedString()
        var currentSection: SectionType = .header
        var stepNumber = 1

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            guard !trimmed.isEmpty else {
                result.append(AttributedString("\n"))
                continue
            }

            // Check for section transitions
            if let detectedSection = detectSection(trimmed) {
                currentSection = detectedSection
                result.append(formatSectionHeader(detectedSection))
                if index < lines.count - 1 {
                    result.append(AttributedString("\n"))
                }
                continue
            }

            // Format based on current section
            switch currentSection {
            case .header:
                result.append(formatHeaderLine(line))

            case .ingredients:
                result.append(formatIngredient(line))

            case .instructions:
                result.append(formatInstruction(line, stepNumber: stepNumber))
                stepNumber += 1
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

        // Extract prep time
        if let prepTime = extractTime(from: content, type: .prep) {
            metadata[FormatterMetadataKey.prepTime] = prepTime
        }

        // Extract servings
        if let servings = extractServings(from: content) {
            metadata[FormatterMetadataKey.servings] = servings
        }

        return metadata
    }

    // MARK: - Private Helpers

    private enum SectionType {
        case header
        case ingredients
        case instructions
    }

    private func detectSection(_ line: String) -> SectionType? {
        let upperLine = line.uppercased()

        if upperLine.contains("INGREDIENT") {
            return .ingredients
        } else if upperLine.contains("INSTRUCTION") || upperLine.contains("STEPS") || upperLine.contains("DIRECTIONS") {
            return .instructions
        }

        return nil
    }

    private func formatSectionHeader(_ section: SectionType) -> AttributedString {
        let indianRed = Color(red: 0.8, green: 0.36, blue: 0.36)

        let text: String
        let icon: String
        switch section {
        case .ingredients:
            text = "INGREDIENTS"
            icon = "🥘 "
        case .instructions:
            text = "INSTRUCTIONS"
            icon = "👨‍🍳 "
        case .header:
            return AttributedString()
        }

        var result = AttributedString()

        // Icon
        var iconAttr = AttributedString(icon)
        iconAttr.font = .system(size: 18)
        result.append(iconAttr)

        // Section title
        var titleAttr = AttributedString(text)
        titleAttr.font = .headline
        titleAttr.foregroundColor = indianRed
        result.append(titleAttr)

        return result
    }

    private func formatHeaderLine(_ line: String) -> AttributedString {
        // Format lines in the header (before sections) with temp/time highlighting
        formatTextWithTempAndTime(line)
    }

    private func formatIngredient(_ line: String) -> AttributedString {
        var result = AttributedString()

        // Add checkbox
        var checkboxAttr = AttributedString("☐ ")
        checkboxAttr.foregroundColor = .secondary
        checkboxAttr.font = .system(size: 18)
        result.append(checkboxAttr)

        // Format ingredient text with quantity highlighting
        result.append(formatIngredientText(line))

        return result
    }

    private func formatIngredientText(_ text: String) -> AttributedString {
        // Highlight quantities (numbers at start of ingredient)
        let quantityPattern = "^\\s*([\\d/½¼¾⅓⅔⅛⅜⅝⅞]+\\s*(?:cups?|tbsp|tsp|oz|lbs?|g|kg|ml|l)?)"

        if let regex = try? NSRegularExpression(pattern: quantityPattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let quantityRange = Range(match.range(at: 1), in: text) {

            let quantity = String(text[quantityRange])
            let remainder = String(text[quantityRange.upperBound...])

            var result = AttributedString()

            // Quantity in bold
            var quantityAttr = AttributedString(quantity)
            quantityAttr.font = .body.bold()
            result.append(quantityAttr)

            // Rest of ingredient
            result.append(AttributedString(remainder))

            return result
        }

        return AttributedString(text)
    }

    private func formatInstruction(_ line: String, stepNumber: Int) -> AttributedString {
        let indianRed = Color(red: 0.8, green: 0.36, blue: 0.36)
        var result = AttributedString()

        // Step number in circular badge
        var stepAttr = AttributedString("\(stepNumber). ")
        stepAttr.font = .system(size: 18, weight: .bold)
        stepAttr.foregroundColor = indianRed
        result.append(stepAttr)

        // Step text with temperature/time highlighting
        result.append(formatTextWithTempAndTime(line))

        return result
    }

    private func formatTextWithTempAndTime(_ text: String) -> AttributedString {
        var result = AttributedString()
        let indianRed = Color(red: 0.8, green: 0.36, blue: 0.36)

        // Pattern for temperatures and times
        let pattern = "\\b(\\d+)\\s*°?\\s*([FC])|\\b(\\d+)\\s*(min(?:utes?)?|hrs?|hours?)\\b"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return AttributedString(text)
        }

        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)

        var lastEnd = text.startIndex

        for match in matches {
            if let matchRange = Range(match.range, in: text) {
                // Add text before match
                if lastEnd < matchRange.lowerBound {
                    result.append(AttributedString(String(text[lastEnd..<matchRange.lowerBound])))
                }

                // Add highlighted temp/time
                let matchedText = String(text[matchRange])
                var highlightAttr = AttributedString(matchedText)
                highlightAttr.foregroundColor = indianRed
                highlightAttr.font = .body.bold()
                result.append(highlightAttr)

                lastEnd = matchRange.upperBound
            }
        }

        // Add remaining text
        if lastEnd < text.endIndex {
            result.append(AttributedString(String(text[lastEnd...])))
        }

        return result
    }

    private enum TimeType {
        case prep
        case cook
        case total
    }

    private func extractTime(from content: String, type: TimeType) -> String? {
        let label: String
        switch type {
        case .prep: label = "prep"
        case .cook: label = "cook"
        case .total: label = "total"
        }

        let patterns = [
            "\(label)\\s+time[:\\s]+(\\d+\\s*(?:min(?:utes?)?|hrs?|hours?))",
            "\(label)[:\\s]+(\\d+\\s*(?:min(?:utes?)?|hrs?|hours?))"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(content.startIndex..., in: content)
                if let match = regex.firstMatch(in: content, range: range) {
                    let timeRange = Range(match.range(at: 1), in: content)
                    if let timeRange = timeRange {
                        return String(content[timeRange])
                    }
                }
            }
        }

        return nil
    }

    private func extractServings(from content: String) -> String? {
        let patterns = [
            "servings?[:\\s]+(\\d+(?:-\\d+)?)",
            "serves?[:\\s]+(\\d+(?:-\\d+)?)",
            "yields?[:\\s]+(\\d+(?:-\\d+)?)"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(content.startIndex..., in: content)
                if let match = regex.firstMatch(in: content, range: range) {
                    let servingRange = Range(match.range(at: 1), in: content)
                    if let servingRange = servingRange {
                        return String(content[servingRange])
                    }
                }
            }
        }

        return nil
    }
}
