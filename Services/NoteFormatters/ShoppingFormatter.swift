//
//  ShoppingFormatter.swift
//  QuillStack
//
//  Created on 2026-01-06.
//  Part of QUI-146: Note Type Visual Themes & Formatting
//

import Foundation
import SwiftUI

/// Formats shopping lists with category grouping and quantity detection.
///
/// **Features:**
/// - Category grouping with emoji headers (🥛 Dairy, 🥬 Produce, etc.)
/// - Orange checkboxes matching shopping badge color
/// - Quantity parsing and highlighting (×4, "2 bags", etc.)
/// - Progress tracking (items checked vs total)
///
/// **Category detection:**
/// - Dairy: milk, cheese, yogurt, butter, etc.
/// - Produce: vegetables, fruits
/// - Bakery: bread, rolls, bagels
/// - Meat: chicken, beef, pork, fish
/// - Pantry: canned goods, spices, pasta, rice
/// - Frozen: ice cream, frozen vegetables
/// - Beverages: soda, juice, water
///
/// **Usage:**
/// ```swift
/// let formatter = ShoppingFormatter()
/// let styled = formatter.format(content: shoppingNote.content)
/// let metadata = formatter.extractMetadata(from: shoppingNote.content)
/// ```
@MainActor
final class ShoppingFormatter: NoteFormatter {

    // MARK: - NoteFormatter Protocol

    var noteType: NoteType { .shopping }

    func format(content: String) -> AttributedString {
        let lines = content.components(separatedBy: .newlines)
        var result = AttributedString()
        var lastCategory: Category?

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            guard !trimmed.isEmpty else {
                result.append(AttributedString("\n"))
                continue
            }

            // Check for explicit category header
            if let category = detectExplicitCategory(trimmed) {
                result.append(formatCategoryHeader(category))
                lastCategory = category
                if index < lines.count - 1 {
                    result.append(AttributedString("\n"))
                }
                continue
            }

            // Auto-categorize items if not in a category section
            if lastCategory == nil {
                let detectedCategory = detectItemCategory(trimmed)
                if detectedCategory != lastCategory {
                    result.append(formatCategoryHeader(detectedCategory))
                    result.append(AttributedString("\n"))
                    lastCategory = detectedCategory
                }
            }

            // Format as shopping item
            result.append(formatShoppingItem(line))

            // Add newline between lines
            if index < lines.count - 1 {
                result.append(AttributedString("\n"))
            }
        }

        return result
    }

    func extractMetadata(from content: String) -> [String: Any] {
        let lines = content.components(separatedBy: .newlines)
        var totalItems = 0
        var checkedItems = 0

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if isShoppingItem(trimmed) {
                totalItems += 1
                if isItemChecked(trimmed) {
                    checkedItems += 1
                }
            }
        }

        let progressPercentage = totalItems > 0 ? Double(checkedItems) / Double(totalItems) : 0.0

        return [
            FormatterMetadataKey.totalCount: totalItems,
            FormatterMetadataKey.completedCount: checkedItems,
            FormatterMetadataKey.progress: "\(checkedItems) of \(totalItems) items",
            FormatterMetadataKey.progressPercentage: progressPercentage
        ]
    }

    // MARK: - Private Helpers

    private enum Category {
        case dairy
        case produce
        case bakery
        case meat
        case pantry
        case frozen
        case beverages
        case other

        var displayName: String {
            switch self {
            case .dairy: return "Dairy"
            case .produce: return "Produce"
            case .bakery: return "Bakery"
            case .meat: return "Meat & Seafood"
            case .pantry: return "Pantry"
            case .frozen: return "Frozen"
            case .beverages: return "Beverages"
            case .other: return "Other"
            }
        }

        var emoji: String {
            switch self {
            case .dairy: return "🥛"
            case .produce: return "🥬"
            case .bakery: return "🍞"
            case .meat: return "🥩"
            case .pantry: return "🥫"
            case .frozen: return "🧊"
            case .beverages: return "🥤"
            case .other: return "🛒"
            }
        }
    }

    private func detectExplicitCategory(_ line: String) -> Category? {
        let lowerLine = line.lowercased()

        if lowerLine.contains("dairy") {
            return .dairy
        } else if lowerLine.contains("produce") || lowerLine.contains("fruits") || lowerLine.contains("vegetables") {
            return .produce
        } else if lowerLine.contains("bakery") || lowerLine.contains("bread") {
            return .bakery
        } else if lowerLine.contains("meat") || lowerLine.contains("seafood") || lowerLine.contains("deli") {
            return .meat
        } else if lowerLine.contains("pantry") {
            return .pantry
        } else if lowerLine.contains("frozen") {
            return .frozen
        } else if lowerLine.contains("beverages") || lowerLine.contains("drinks") {
            return .beverages
        }

        return nil
    }

    private func detectItemCategory(_ item: String) -> Category {
        let lowerItem = item.lowercased()

        // Dairy
        let dairyKeywords = ["milk", "cheese", "yogurt", "butter", "cream", "eggs"]
        if dairyKeywords.contains(where: { lowerItem.contains($0) }) {
            return .dairy
        }

        // Produce
        let produceKeywords = ["apple", "banana", "orange", "lettuce", "tomato", "carrot", "onion", "potato", "pepper", "broccoli", "spinach", "celery"]
        if produceKeywords.contains(where: { lowerItem.contains($0) }) {
            return .produce
        }

        // Bakery
        let bakeryKeywords = ["bread", "rolls", "bagel", "muffin", "croissant", "bun"]
        if bakeryKeywords.contains(where: { lowerItem.contains($0) }) {
            return .bakery
        }

        // Meat
        let meatKeywords = ["chicken", "beef", "pork", "turkey", "fish", "salmon", "steak", "bacon", "sausage"]
        if meatKeywords.contains(where: { lowerItem.contains($0) }) {
            return .meat
        }

        // Frozen
        let frozenKeywords = ["ice cream", "frozen", "popsicle"]
        if frozenKeywords.contains(where: { lowerItem.contains($0) }) {
            return .frozen
        }

        // Beverages
        let beverageKeywords = ["soda", "juice", "water", "coffee", "tea", "beer", "wine"]
        if beverageKeywords.contains(where: { lowerItem.contains($0) }) {
            return .beverages
        }

        // Default to pantry for everything else
        return .pantry
    }

    private func formatCategoryHeader(_ category: Category) -> AttributedString {
        let orange = Color.orange

        var result = AttributedString()

        // Category emoji
        var emojiAttr = AttributedString(category.emoji + " ")
        emojiAttr.font = .system(size: 18)
        result.append(emojiAttr)

        // Category name
        var nameAttr = AttributedString(category.displayName)
        nameAttr.font = .headline
        nameAttr.foregroundColor = orange
        result.append(nameAttr)

        return result
    }

    private func isShoppingItem(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        // Check if it starts with checkbox or bullet
        return trimmed.hasPrefix("☐") || trimmed.hasPrefix("☑") ||
               trimmed.hasPrefix("[ ]") || trimmed.hasPrefix("[x]") ||
               trimmed.hasPrefix("[X]") || trimmed.hasPrefix("•") ||
               trimmed.hasPrefix("-") || trimmed.hasPrefix("*")
    }

    private func isItemChecked(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("☑") || trimmed.hasPrefix("[x]") || trimmed.hasPrefix("[X]")
    }

    private func formatShoppingItem(_ line: String) -> AttributedString {
        var result = AttributedString()
        var text = line.trimmingCharacters(in: .whitespaces)
        let isChecked = isItemChecked(text)

        // Remove checkbox/bullet
        if text.hasPrefix("☐") || text.hasPrefix("☑") {
            text = String(text.dropFirst()).trimmingCharacters(in: .whitespaces)
        } else if text.hasPrefix("[ ]") || text.hasPrefix("[x]") || text.hasPrefix("[X]") {
            text = String(text.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        } else if text.hasPrefix("•") || text.hasPrefix("-") || text.hasPrefix("*") {
            text = String(text.dropFirst()).trimmingCharacters(in: .whitespaces)
        }

        // Add checkbox with orange color
        let checkbox = isChecked ? "☑ " : "☐ "
        var checkboxAttr = AttributedString(checkbox)
        checkboxAttr.foregroundColor = isChecked ? .orange : .secondary
        checkboxAttr.font = .system(size: 18)
        result.append(checkboxAttr)

        // Format item text with quantity detection
        if isChecked {
            var textAttr = FormattingUtilities.strikethrough(text, color: .secondary)
            result.append(textAttr)
        } else {
            result.append(formatItemWithQuantity(text))
        }

        return result
    }

    private func formatItemWithQuantity(_ text: String) -> AttributedString {
        // Pattern for quantities: ×4, x4, 2 bags, 3 lbs, etc.
        let quantityPattern = "^([×x]?\\d+(?:\\.\\d+)?\\s*(?:bags?|boxes?|lbs?|oz|g|kg|bottles?|cans?)?)"

        if let regex = try? NSRegularExpression(pattern: quantityPattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let quantityRange = Range(match.range(at: 1), in: text) {

            let quantity = String(text[quantityRange])
            let remainder = String(text[quantityRange.upperBound...]).trimmingCharacters(in: .whitespaces)

            var result = AttributedString()

            // Quantity in bold orange
            var quantityAttr = AttributedString(quantity)
            quantityAttr.font = .body.bold()
            quantityAttr.foregroundColor = .orange
            result.append(quantityAttr)

            // Add space if needed
            if !remainder.isEmpty {
                result.append(AttributedString(" "))
            }

            // Rest of item
            result.append(AttributedString(remainder))

            return result
        }

        return AttributedString(text)
    }
}
