//
//  ClaudePromptFormatter.swift
//  QuillStack
//
//  Created on 2026-01-06.
//  Part of QUI-146: Note Type Visual Themes & Formatting
//

import Foundation
import SwiftUI

/// Formats Claude prompt content with variable highlighting and structure.
///
/// **Features:**
/// - Prompt/Response section separation
/// - Variable highlighting ({{VARIABLE}})
/// - Token count display
/// - Code block formatting
/// - Purple accent throughout
///
/// **Detection:**
/// - Variables: {{VAR_NAME}}, {variable}
/// - Sections: "Prompt:", "Response:", "System:"
/// - Code blocks: ```code```
/// - Instructions: Numbered steps, bullet points
///
/// **Usage:**
/// ```swift
/// let formatter = ClaudePromptFormatter()
/// let styled = formatter.format(content: promptNote.content)
/// let metadata = formatter.extractMetadata(from: promptNote.content)
/// ```
@MainActor
final class ClaudePromptFormatter: NoteFormatter {

    // MARK: - NoteFormatter Protocol

    var noteType: NoteType { .claudePrompt }

    func format(content: String) -> AttributedString {
        let lines = content.components(separatedBy: .newlines)
        var result = AttributedString()
        var inCodeBlock = false

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Check for code block markers
            if trimmed.hasPrefix("```") {
                inCodeBlock.toggle()
                result.append(formatCodeBlockMarker())
                if index < lines.count - 1 {
                    result.append(AttributedString("\n"))
                }
                continue
            }

            guard !trimmed.isEmpty else {
                result.append(AttributedString("\n"))
                continue
            }

            // Format based on context
            if inCodeBlock {
                result.append(formatCodeLine(line))
            } else if isSectionHeader(trimmed) {
                result.append(formatSectionHeader(trimmed))
            } else if containsVariables(trimmed) {
                result.append(formatLineWithVariables(line))
            } else {
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

        // Count variables
        let variablePattern = "\\{\\{[A-Z_]+\\}\\}"
        if let regex = try? NSRegularExpression(pattern: variablePattern) {
            let range = NSRange(content.startIndex..., in: content)
            let matches = regex.matches(in: content, range: range)
            metadata["variableCount"] = matches.count
        }

        // Estimate token count (rough approximation)
        let words = content.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let estimatedTokens = Int(Double(words.count) * 1.3) // Rough approximation
        metadata["estimatedTokens"] = estimatedTokens

        return metadata
    }

    // MARK: - Private Helpers

    private let purpleColor = Color(red: 0.58, green: 0.40, blue: 0.74)

    private func isSectionHeader(_ line: String) -> Bool {
        let lowerLine = line.lowercased()

        let sectionHeaders = [
            "prompt:", "response:", "system:", "user:", "assistant:",
            "instructions:", "context:", "examples:", "output:"
        ]

        for header in sectionHeaders {
            if lowerLine.hasPrefix(header) {
                return true
            }
        }

        return false
    }

    private func containsVariables(_ line: String) -> Bool {
        // Check for {{VAR}} or {var} patterns
        return line.range(of: "\\{\\{[^}]+\\}\\}|\\{[^}]+\\}", options: .regularExpression) != nil
    }

    private func formatSectionHeader(_ text: String) -> AttributedString {
        var result = AttributedString()

        // Section marker
        var markerAttr = AttributedString("▸ ")
        markerAttr.foregroundColor = purpleColor
        markerAttr.font = .system(size: 16, weight: .bold)
        result.append(markerAttr)

        // Section title
        var titleAttr = AttributedString(text)
        titleAttr.font = .headline
        titleAttr.foregroundColor = purpleColor
        result.append(titleAttr)

        return result
    }

    private func formatCodeBlockMarker() -> AttributedString {
        var result = AttributedString("```")
        result.foregroundColor = .secondary
        result.font = .system(.caption, design: .monospaced)
        return result
    }

    private func formatCodeLine(_ line: String) -> AttributedString {
        var result = AttributedString(line)
        result.font = .system(.body, design: .monospaced)
        result.foregroundColor = .primary
        return result
    }

    private func formatLineWithVariables(_ line: String) -> AttributedString {
        var result = AttributedString()

        // Pattern for variables: {{VAR}} or {var}
        let variablePattern = "(\\{\\{[^}]+\\}\\}|\\{[^}]+\\})"

        guard let regex = try? NSRegularExpression(pattern: variablePattern) else {
            return AttributedString(line)
        }

        let range = NSRange(line.startIndex..., in: line)
        let matches = regex.matches(in: line, range: range)

        var lastEnd = line.startIndex

        for match in matches {
            if let matchRange = Range(match.range, in: line) {
                // Add text before variable
                if lastEnd < matchRange.lowerBound {
                    result.append(AttributedString(String(line[lastEnd..<matchRange.lowerBound])))
                }

                // Add highlighted variable
                let variable = String(line[matchRange])
                var varAttr = AttributedString(variable)
                varAttr.foregroundColor = purpleColor
                varAttr.font = .body.bold()
                varAttr.backgroundColor = Color.purple.opacity(0.1)
                result.append(varAttr)

                lastEnd = matchRange.upperBound
            }
        }

        // Add remaining text
        if lastEnd < line.endIndex {
            result.append(AttributedString(String(line[lastEnd...])))
        }

        return result
    }
}
