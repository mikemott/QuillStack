//
//  EmailFormatter.swift
//  QuillStack
//
//  Created on 2026-01-06.
//  Part of QUI-146: Note Type Visual Themes & Formatting
//

import Foundation
import SwiftUI

/// Formats email content with header fields, quoted text, and signature detection.
///
/// **Features:**
/// - Header fields (To, From, Subject) in plum-accented box
/// - Quoted text (> or |) with indented plum left border styling
/// - Signature detection with dashed separator
/// - Tappable email addresses with underline
/// - Subject line extraction for smart title
///
/// **Detection:**
/// - Header lines: "To:", "From:", "Subject:", "Date:", "Cc:", "Bcc:"
/// - Quoted text: Lines starting with > or |
/// - Signatures: Common patterns like "Sent from", "Best regards", signature blocks
/// - Email addresses: standard email format
///
/// **Usage:**
/// ```swift
/// let formatter = EmailFormatter()
/// let styled = formatter.format(content: emailNote.content)
/// let metadata = formatter.extractMetadata(from: emailNote.content)
/// ```
@MainActor
final class EmailFormatter: NoteFormatter {

    // MARK: - NoteFormatter Protocol

    var noteType: NoteType { .email }

    func format(content: String) -> AttributedString {
        let lines = content.components(separatedBy: .newlines)
        var result = AttributedString()
        var inHeaderSection = true
        var inSignature = false

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Empty lines might signal end of header section
            if trimmed.isEmpty {
                result.append(AttributedString("\n"))
                if inHeaderSection && hasSeenHeaderFields(in: lines[0...index]) {
                    inHeaderSection = false
                }
                continue
            }

            // Check for signature start
            if detectSignatureStart(trimmed) {
                inSignature = true
                result.append(formatSignatureDivider())
                result.append(AttributedString("\n"))
                continue
            }

            // Format based on context
            if inSignature {
                result.append(formatSignatureLine(line))
            } else if inHeaderSection && isHeaderField(trimmed) {
                result.append(formatHeaderField(trimmed))
            } else if isQuotedText(trimmed) {
                result.append(formatQuotedText(line))
            } else {
                // Regular body text with email detection
                result.append(formatBodyText(line))
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

        // Extract subject
        if let subject = extractSubject(from: content) {
            metadata[FormatterMetadataKey.subject] = subject
        }

        // Extract sender
        if let sender = extractSender(from: content) {
            metadata[FormatterMetadataKey.sender] = sender
        }

        // Extract recipients
        if let recipients = extractRecipients(from: content) {
            metadata[FormatterMetadataKey.recipients] = recipients
        }

        return metadata
    }

    // MARK: - Private Helpers

    private let plumColor = Color(red: 0.56, green: 0.27, blue: 0.52)

    private let headerFieldLabels = ["to:", "from:", "subject:", "date:", "cc:", "bcc:", "reply-to:"]

    private func isHeaderField(_ line: String) -> Bool {
        let lowerLine = line.lowercased()
        return headerFieldLabels.contains(where: { lowerLine.hasPrefix($0) })
    }

    private func hasSeenHeaderFields(in lines: ArraySlice<String>) -> Bool {
        return lines.contains(where: { isHeaderField($0.trimmingCharacters(in: .whitespaces)) })
    }

    private func formatHeaderField(_ line: String) -> AttributedString {
        var result = AttributedString()

        // Find the colon separator
        if let colonIndex = line.firstIndex(of: ":") {
            let label = String(line[..<colonIndex])
            let value = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)

            // Format label in plum
            var labelAttr = AttributedString(label + ":")
            labelAttr.font = .body.bold()
            labelAttr.foregroundColor = plumColor
            result.append(labelAttr)

            result.append(AttributedString(" "))

            // Format value (with email detection)
            if containsEmail(value) {
                result.append(formatTextWithEmails(value))
            } else {
                result.append(AttributedString(value))
            }
        } else {
            result.append(AttributedString(line))
        }

        return result
    }

    private func isQuotedText(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix(">") || trimmed.hasPrefix("|")
    }

    private func formatQuotedText(_ line: String) -> AttributedString {
        var result = AttributedString()

        // Quote marker
        var markerAttr = AttributedString("▐ ")
        markerAttr.foregroundColor = plumColor
        markerAttr.font = .system(size: 16, weight: .bold)
        result.append(markerAttr)

        // Remove > or | prefix from line
        var text = line.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix(">") || text.hasPrefix("|") {
            text = String(text.dropFirst()).trimmingCharacters(in: .whitespaces)
        }

        // Quoted text in secondary color
        var textAttr = AttributedString(text)
        textAttr.foregroundColor = .secondary
        textAttr.font = .callout
        result.append(textAttr)

        return result
    }

    private func detectSignatureStart(_ line: String) -> Bool {
        let lowerLine = line.lowercased()

        // Common signature indicators
        let signaturePatterns = [
            "best regards",
            "sincerely",
            "thanks",
            "cheers",
            "sent from",
            "get outlook for",
            "signature",
            "--"  // Common email signature separator
        ]

        return signaturePatterns.contains(where: { lowerLine.contains($0) })
    }

    private func formatSignatureDivider() -> AttributedString {
        var result = AttributedString("- - - - - -")
        result.foregroundColor = .secondary
        result.font = .caption
        return result
    }

    private func formatSignatureLine(_ line: String) -> AttributedString {
        var result = AttributedString(line)
        result.font = .caption
        result.foregroundColor = .secondary
        return result
    }

    private func formatBodyText(_ line: String) -> AttributedString {
        // Check for emails in the text
        if containsEmail(line) {
            return formatTextWithEmails(line)
        }

        return AttributedString(line)
    }

    private func containsEmail(_ text: String) -> Bool {
        let emailPattern = "[\\w._%+-]+@[\\w.-]+\\.[A-Za-z]{2,}"
        if let regex = try? NSRegularExpression(pattern: emailPattern) {
            let range = NSRange(text.startIndex..., in: text)
            return regex.firstMatch(in: text, range: range) != nil
        }
        return false
    }

    private func formatTextWithEmails(_ text: String) -> AttributedString {
        var result = AttributedString()
        let emailPattern = "([\\w._%+-]+@[\\w.-]+\\.[A-Za-z]{2,})"

        guard let regex = try? NSRegularExpression(pattern: emailPattern) else {
            return AttributedString(text)
        }

        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)

        var lastEnd = text.startIndex

        for match in matches {
            if let matchRange = Range(match.range, in: text) {
                // Add text before email
                if lastEnd < matchRange.lowerBound {
                    result.append(AttributedString(String(text[lastEnd..<matchRange.lowerBound])))
                }

                // Add email with styling
                let email = String(text[matchRange])
                var emailAttr = AttributedString(email)
                emailAttr.foregroundColor = plumColor
                emailAttr.underlineStyle = .single
                result.append(emailAttr)

                lastEnd = matchRange.upperBound
            }
        }

        // Add remaining text
        if lastEnd < text.endIndex {
            result.append(AttributedString(String(text[lastEnd...])))
        }

        return result
    }

    private func extractSubject(from content: String) -> String? {
        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let lowerLine = trimmed.lowercased()

            if lowerLine.hasPrefix("subject:") {
                let subject = String(trimmed.dropFirst("subject:".count)).trimmingCharacters(in: .whitespaces)
                return subject.isEmpty ? nil : subject
            }
        }

        return nil
    }

    private func extractSender(from content: String) -> String? {
        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let lowerLine = trimmed.lowercased()

            if lowerLine.hasPrefix("from:") {
                let sender = String(trimmed.dropFirst("from:".count)).trimmingCharacters(in: .whitespaces)
                return sender.isEmpty ? nil : sender
            }
        }

        return nil
    }

    private func extractRecipients(from content: String) -> [String]? {
        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let lowerLine = trimmed.lowercased()

            if lowerLine.hasPrefix("to:") {
                let recipients = String(trimmed.dropFirst("to:".count)).trimmingCharacters(in: .whitespaces)
                // Split by comma or semicolon
                let recipientList = recipients.components(separatedBy: CharacterSet(charactersIn: ",;"))
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }

                return recipientList.isEmpty ? nil : recipientList
            }
        }

        return nil
    }
}
