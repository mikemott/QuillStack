//
//  ExpenseFormatter.swift
//  QuillStack
//
//  Created on 2026-01-06.
//  Part of QUI-146: Note Type Visual Themes & Formatting
//

import Foundation
import SwiftUI

/// Formats expense/receipt content with thermal receipt styling.
///
/// **Features:**
/// - Receipt paper aesthetic with centered layout
/// - Merchant header (name, address, date/time)
/// - Itemized list with right-aligned prices
/// - Calculations (subtotal, tax %, total) in bold
/// - Payment method and category
/// - Dashed dividers for thermal receipt feel
/// - Monospace numbers for authentic receipt look
///
/// **Detection:**
/// - Merchant name (first line or labeled)
/// - Line items with prices ($X.XX format)
/// - Subtotal, Tax, Total calculations
/// - Payment method (card type, last 4 digits)
/// - Date/time stamps
///
/// **Usage:**
/// ```swift
/// let formatter = ExpenseFormatter()
/// let styled = formatter.format(content: expenseNote.content)
/// let metadata = formatter.extractMetadata(from: expenseNote.content)
/// ```
@MainActor
final class ExpenseFormatter: NoteFormatter {

    // MARK: - NoteFormatter Protocol

    var noteType: NoteType { .expense }

    func format(content: String) -> AttributedString {
        let lines = content.components(separatedBy: .newlines)
        var result = AttributedString()
        var seenFirstLine = false

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            guard !trimmed.isEmpty else {
                result.append(AttributedString("\n"))
                continue
            }

            // Detect line type and format accordingly
            if !seenFirstLine && !isCalculationLine(trimmed) {
                // First line is likely merchant name
                result.append(formatMerchantName(trimmed))
                seenFirstLine = true
            } else if isDateTimeLine(trimmed) {
                result.append(formatDateTime(trimmed))
            } else if isCalculationLine(trimmed) {
                result.append(formatCalculationLine(trimmed))
            } else if let (item, price) = parseLineItem(trimmed) {
                result.append(formatLineItem(item: item, price: price))
            } else if isDividerLine(trimmed) {
                result.append(formatDivider())
            } else if isPaymentLine(trimmed) {
                result.append(formatPaymentLine(trimmed))
            } else {
                // Regular line (address, etc.)
                result.append(formatCenteredText(trimmed))
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

        // Extract total amount
        if let amount = extractTotal(from: content) {
            metadata[FormatterMetadataKey.amount] = amount
        }

        // Extract merchant name
        if let merchant = extractMerchant(from: content) {
            metadata[FormatterMetadataKey.merchant] = merchant
        }

        return metadata
    }

    // MARK: - Private Helpers

    private func formatMerchantName(_ name: String) -> AttributedString {
        var result = AttributedString(name)
        result.font = .title3.bold()
        result.foregroundColor = .primary
        return result
    }

    private func formatDateTime(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        result.font = .caption
        result.foregroundColor = .secondary
        return result
    }

    private func formatCenteredText(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        result.font = .caption
        result.foregroundColor = .secondary
        return result
    }

    private func formatLineItem(item: String, price: String) -> AttributedString {
        var result = AttributedString()

        // Item name
        var itemAttr = AttributedString(item)
        itemAttr.font = .body
        result.append(itemAttr)

        // Spacing (simplified - actual spacing would be handled by view layout)
        result.append(AttributedString(" "))

        // Price in monospace
        var priceAttr = AttributedString(price)
        priceAttr.font = .system(.body, design: .monospaced)
        priceAttr.foregroundColor = .primary
        result.append(priceAttr)

        return result
    }

    private func formatCalculationLine(_ line: String) -> AttributedString {
        // Parse calculation line (e.g., "Subtotal: $45.67")
        if let (label, amount) = parseCalculation(line) {
            var result = AttributedString()

            // Label
            var labelAttr = AttributedString(label)
            let isTotal = label.lowercased().contains("total") && !label.lowercased().contains("subtotal")
            labelAttr.font = isTotal ? .body.bold() : .body
            result.append(labelAttr)

            // Spacing
            result.append(AttributedString(" "))

            // Amount in monospace
            var amountAttr = AttributedString(amount)
            amountAttr.font = .system(isTotal ? .body : .body, design: .monospaced).bold()
            amountAttr.foregroundColor = isTotal ? .primary : .secondary
            result.append(amountAttr)

            return result
        }

        return AttributedString(line)
    }

    private func formatDivider() -> AttributedString {
        var result = AttributedString("- - - - - - - - - - - - - -")
        result.foregroundColor = .secondary
        result.font = .caption
        return result
    }

    private func formatPaymentLine(_ line: String) -> AttributedString {
        var result = AttributedString(line)
        result.font = .caption
        result.foregroundColor = .secondary
        return result
    }

    private func isDateTimeLine(_ line: String) -> Bool {
        let lowerLine = line.lowercased()
        // Look for date/time patterns
        return lowerLine.contains("/") && (lowerLine.contains(":") || lowerLine.contains("am") || lowerLine.contains("pm"))
    }

    private func isCalculationLine(_ line: String) -> Bool {
        let lowerLine = line.lowercased()
        return lowerLine.contains("subtotal") || lowerLine.contains("tax") ||
               lowerLine.contains("total") || lowerLine.contains("amount")
    }

    private func isDividerLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        // Check if line is mostly dashes or equals
        let dashCount = trimmed.filter { $0 == "-" || $0 == "=" || $0 == "_" }.count
        return dashCount > trimmed.count / 2
    }

    private func isPaymentLine(_ line: String) -> Bool {
        let lowerLine = line.lowercased()
        return lowerLine.contains("card") || lowerLine.contains("cash") ||
               lowerLine.contains("visa") || lowerLine.contains("mastercard") ||
               lowerLine.contains("amex") || lowerLine.contains("payment")
    }

    private func parseLineItem(_ line: String) -> (item: String, price: String)? {
        // Pattern: item name followed by price ($X.XX or X.XX)
        let pricePattern = "(.+?)\\s+(\\$?\\d+\\.\\d{2})\\s*$"

        if let regex = try? NSRegularExpression(pattern: pricePattern),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {

            let itemRange = Range(match.range(at: 1), in: line)
            let priceRange = Range(match.range(at: 2), in: line)

            if let itemRange = itemRange, let priceRange = priceRange {
                let item = String(line[itemRange]).trimmingCharacters(in: .whitespaces)
                var price = String(line[priceRange])

                // Ensure price has $ prefix
                if !price.hasPrefix("$") {
                    price = "$" + price
                }

                return (item, price)
            }
        }

        return nil
    }

    private func parseCalculation(_ line: String) -> (label: String, amount: String)? {
        // Pattern: "Label: $X.XX" or "Label $X.XX"
        let calcPattern = "(.+?)[:.]?\\s+(\\$?\\d+\\.\\d{2})"

        if let regex = try? NSRegularExpression(pattern: calcPattern),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {

            let labelRange = Range(match.range(at: 1), in: line)
            let amountRange = Range(match.range(at: 2), in: line)

            if let labelRange = labelRange, let amountRange = amountRange {
                var label = String(line[labelRange]).trimmingCharacters(in: .whitespaces)
                var amount = String(line[amountRange])

                // Add colon to label if not present
                if !label.hasSuffix(":") {
                    label += ":"
                }

                // Ensure amount has $ prefix
                if !amount.hasPrefix("$") {
                    amount = "$" + amount
                }

                return (label, amount)
            }
        }

        return nil
    }

    private func extractTotal(from content: String) -> String? {
        let totalPattern = "total[:\\s]+\\$?(\\d+\\.\\d{2})"

        if let regex = try? NSRegularExpression(pattern: totalPattern, options: [.caseInsensitive]) {
            let range = NSRange(content.startIndex..., in: content)
            if let match = regex.firstMatch(in: content, range: range) {
                let amountRange = Range(match.range(at: 1), in: content)
                if let amountRange = amountRange {
                    return "$" + String(content[amountRange])
                }
            }
        }

        return nil
    }

    private func extractMerchant(from content: String) -> String? {
        // First non-empty line is likely the merchant
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && !isDateTimeLine(trimmed) && !isCalculationLine(trimmed) {
                return trimmed
            }
        }

        return nil
    }
}
