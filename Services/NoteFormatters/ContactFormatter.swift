//
//  ContactFormatter.swift
//  QuillStack
//
//  Created on 2026-01-06.
//  Part of QUI-146: Note Type Visual Themes & Formatting
//

import Foundation
import SwiftUI

/// Formats contact/business card information with structured field display.
///
/// **Features:**
/// - Name extraction and prominent display
/// - Icon prefixes for different field types (🏢 📱 ✉️ 🔗 📍)
/// - Tappable field detection (phone, email, URLs)
/// - Title/role extraction
/// - Company information
///
/// **Field detection:**
/// - Phone: Patterns like (555) 123-4567, +1-555-123-4567
/// - Email: standard@email.com format
/// - URL: https://... or www...
/// - Address: Multi-line addresses
///
/// **Usage:**
/// ```swift
/// let formatter = ContactFormatter()
/// let styled = formatter.format(content: contactNote.content)
/// let metadata = formatter.extractMetadata(from: contactNote.content)
/// ```
@MainActor
final class ContactFormatter: NoteFormatter {

    // MARK: - NoteFormatter Protocol

    var noteType: NoteType { .contact }

    func format(content: String) -> AttributedString {
        let lines = content.components(separatedBy: .newlines)
        var result = AttributedString()
        var isFirstNonEmptyLine = true

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            guard !trimmed.isEmpty else {
                result.append(AttributedString("\n"))
                continue
            }

            // First non-empty line is likely the name - make it prominent
            if isFirstNonEmptyLine {
                result.append(formatName(trimmed))
                isFirstNonEmptyLine = false
            } else if let fieldType = detectFieldType(trimmed) {
                result.append(formatField(fieldType, text: trimmed))
            } else {
                // Regular text line
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

        // Extract phone
        if let phone = extractPhone(from: content) {
            metadata[FormatterMetadataKey.phone] = phone
        }

        // Extract email
        if let email = extractEmail(from: content) {
            metadata[FormatterMetadataKey.email] = email
        }

        // Extract company
        if let company = extractCompany(from: content) {
            metadata[FormatterMetadataKey.company] = company
        }

        return metadata
    }

    // MARK: - Private Helpers

    private enum FieldType {
        case phone
        case email
        case website
        case address
        case company
        case title

        var icon: String {
            switch self {
            case .phone: return "📱"
            case .email: return "✉️"
            case .website: return "🔗"
            case .address: return "📍"
            case .company: return "🏢"
            case .title: return "💼"
            }
        }

        var color: Color {
            // Steel blue accent for contact fields
            Color(red: 0.27, green: 0.51, blue: 0.71)
        }
    }

    private func formatName(_ name: String) -> AttributedString {
        var result = AttributedString(name)
        result.font = .title2.bold()
        result.foregroundColor = .primary
        return result
    }

    private func detectFieldType(_ line: String) -> FieldType? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let lowerLine = trimmed.lowercased()

        // Email detection
        if lowerLine.contains("@") && lowerLine.contains(".") {
            return .email
        }

        // Phone detection
        let phonePattern = "[(\\d\\s\\-+().]{7,}"
        if let regex = try? NSRegularExpression(pattern: phonePattern),
           regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil {
            return .phone
        }

        // Website detection
        if lowerLine.hasPrefix("http") || lowerLine.hasPrefix("www.") || lowerLine.contains(".com") || lowerLine.contains(".org") {
            return .website
        }

        // Company indicators
        if lowerLine.contains("company:") || lowerLine.contains("organization:") || lowerLine.contains("corp") || lowerLine.contains("inc.") || lowerLine.contains("llc") {
            return .company
        }

        // Title indicators
        if lowerLine.contains("title:") || lowerLine.contains("position:") || lowerLine.contains("role:") {
            return .title
        }

        // Address indicators (street, ave, rd, city/state patterns)
        if lowerLine.contains("street") || lowerLine.contains(" st") || lowerLine.contains(" ave") ||
           lowerLine.contains(" road") || lowerLine.contains(" rd") || lowerLine.contains(" blvd") {
            return .address
        }

        return nil
    }

    private func formatField(_ fieldType: FieldType, text: String) -> AttributedString {
        var result = AttributedString()

        // Icon
        var iconAttr = AttributedString(fieldType.icon + " ")
        iconAttr.font = .system(size: 16)
        result.append(iconAttr)

        // Field text
        let cleanedText = cleanFieldText(text, fieldType: fieldType)
        var textAttr = AttributedString(cleanedText)

        // Make tappable fields stand out
        if fieldType == .phone || fieldType == .email || fieldType == .website {
            textAttr.foregroundColor = fieldType.color
            textAttr.underlineStyle = .single
        }

        result.append(textAttr)

        return result
    }

    private func cleanFieldText(_ text: String, fieldType: FieldType) -> String {
        var cleaned = text

        // Remove label prefixes like "Phone:", "Email:", etc.
        let prefixes = ["phone:", "email:", "website:", "web:", "url:", "address:", "company:", "title:", "position:", "role:"]
        for prefix in prefixes {
            if cleaned.lowercased().hasPrefix(prefix) {
                cleaned = String(cleaned.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            }
        }

        return cleaned
    }

    private func extractPhone(from content: String) -> String? {
        // Pattern for phone numbers
        let phonePattern = "(?:phone:?\\s*)?([+\\d\\s()\\-]{10,})"

        if let regex = try? NSRegularExpression(pattern: phonePattern, options: [.caseInsensitive]) {
            let range = NSRange(content.startIndex..., in: content)
            if let match = regex.firstMatch(in: content, range: range) {
                let phoneRange = Range(match.range(at: 1), in: content)
                if let phoneRange = phoneRange {
                    let phone = String(content[phoneRange]).trimmingCharacters(in: .whitespaces)
                    // Validate it has enough digits
                    let digitCount = phone.filter { $0.isNumber }.count
                    if digitCount >= 10 {
                        return phone
                    }
                }
            }
        }

        return nil
    }

    private func extractEmail(from content: String) -> String? {
        // Pattern for email addresses
        let emailPattern = "([\\w._%+-]+@[\\w.-]+\\.[A-Za-z]{2,})"

        if let regex = try? NSRegularExpression(pattern: emailPattern) {
            let range = NSRange(content.startIndex..., in: content)
            if let match = regex.firstMatch(in: content, range: range) {
                let emailRange = Range(match.range(at: 1), in: content)
                if let emailRange = emailRange {
                    return String(content[emailRange])
                }
            }
        }

        return nil
    }

    private func extractCompany(from content: String) -> String? {
        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let lowerLine = trimmed.lowercased()

            // Look for explicit company labels
            if lowerLine.hasPrefix("company:") || lowerLine.hasPrefix("organization:") {
                return cleanFieldText(trimmed, fieldType: .company)
            }

            // Look for company indicators (Inc., Corp, LLC, etc.)
            if lowerLine.contains("inc.") || lowerLine.contains("corp") || lowerLine.contains("llc") ||
               lowerLine.contains("limited") || lowerLine.contains("co.") {
                return trimmed
            }
        }

        return nil
    }
}
