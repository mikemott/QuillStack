//
//  TodoFormatter.swift
//  QuillStack
//
//  Created on 2026-01-06.
//  Part of QUI-146: Note Type Visual Themes & Formatting
//

import Foundation
import SwiftUI

/// Formats todo list content with checkboxes, progress tracking, and priority styling.
///
/// **Features:**
/// - Checkbox styling: ☐ for incomplete, ☑ for completed
/// - Strikethrough for completed tasks
/// - Priority detection (🔥 for high priority)
/// - Due date extraction and formatting
/// - Progress calculation
///
/// **Priority detection:**
/// - "!!!" or "urgent" → high priority (red accent, 🔥 icon)
/// - "!!" or "important" → medium priority
/// - Normal tasks → standard styling
///
/// **Usage:**
/// ```swift
/// let formatter = TodoFormatter()
/// let styled = formatter.format(content: todoNote.content)
/// let metadata = formatter.extractMetadata(from: todoNote.content)
/// ```
@MainActor
final class TodoFormatter: NoteFormatter {

    // MARK: - NoteFormatter Protocol

    var noteType: NoteType { .todo }

    func format(content: String) -> AttributedString {
        let lines = content.components(separatedBy: .newlines)
        var result = AttributedString()

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            guard !trimmed.isEmpty else {
                // Preserve empty lines for spacing
                result.append(AttributedString("\n"))
                continue
            }

            // Parse todo line
            if let todoLine = parseTodoLine(trimmed) {
                result.append(formatTodoLine(todoLine))
            } else {
                // Non-todo line (headers, notes, etc.)
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
        let lines = content.components(separatedBy: .newlines)
        var completedCount = 0
        var totalCount = 0

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let todoLine = parseTodoLine(trimmed) {
                totalCount += 1
                if todoLine.isCompleted {
                    completedCount += 1
                }
            }
        }

        let progressPercentage = totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0.0

        return [
            FormatterMetadataKey.completedCount: completedCount,
            FormatterMetadataKey.totalCount: totalCount,
            FormatterMetadataKey.progress: "\(completedCount) of \(totalCount) completed",
            FormatterMetadataKey.progressPercentage: progressPercentage
        ]
    }

    // MARK: - Private Helpers

    private struct TodoLine {
        let isCompleted: Bool
        let text: String
        let priority: Priority
        let dueDate: String?

        enum Priority {
            case high
            case medium
            case normal

            var icon: String? {
                switch self {
                case .high: return "🔥"
                case .medium: return "⚡️"
                case .normal: return nil
                }
            }

            var color: Color {
                switch self {
                case .high: return .red
                case .medium: return .orange
                case .normal: return .primary
                }
            }
        }
    }

    private func parseTodoLine(_ line: String) -> TodoLine? {
        // Check if line starts with checkbox
        var text = line
        var isCompleted = false

        // Unchecked: ☐ [ ]
        if text.hasPrefix("☐") {
            isCompleted = false
            text = String(text.dropFirst()).trimmingCharacters(in: .whitespaces)
        } else if text.hasPrefix("☑") {
            isCompleted = true
            text = String(text.dropFirst()).trimmingCharacters(in: .whitespaces)
        } else if text.hasPrefix("[ ]") {
            isCompleted = false
            text = String(text.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        } else if text.hasPrefix("[x]") || text.hasPrefix("[X]") {
            isCompleted = true
            text = String(text.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        } else if text.hasPrefix("•") || text.hasPrefix("-") || text.hasPrefix("*") {
            // Treat bullet points as todos
            isCompleted = false
            text = String(text.dropFirst()).trimmingCharacters(in: .whitespaces)
        } else {
            // Not a todo line
            return nil
        }

        // Detect priority
        let priority = detectPriority(in: text)

        // Detect due date
        let dueDate = detectDueDate(in: text)

        return TodoLine(
            isCompleted: isCompleted,
            text: text,
            priority: priority,
            dueDate: dueDate
        )
    }

    private func formatTodoLine(_ todo: TodoLine) -> AttributedString {
        var result = AttributedString()

        // Checkbox
        let checkbox = todo.isCompleted ? "☑ " : "☐ "
        var checkboxAttr = AttributedString(checkbox)
        checkboxAttr.foregroundColor = todo.isCompleted ? .forestMedium : .secondary
        checkboxAttr.font = .system(size: 20)
        result.append(checkboxAttr)

        // Priority icon
        if let icon = todo.priority.icon {
            var iconAttr = AttributedString(icon + " ")
            iconAttr.font = .system(size: 16)
            result.append(iconAttr)
        }

        // Task text
        var textAttr: AttributedString
        if todo.isCompleted {
            textAttr = FormattingUtilities.strikethrough(todo.text, color: .secondary)
        } else {
            textAttr = AttributedString(todo.text)
            textAttr.foregroundColor = todo.priority.color
        }
        result.append(textAttr)

        // Due date (if present)
        if let dueDate = todo.dueDate {
            var dueDateAttr = AttributedString(" 📅 \(dueDate)")
            dueDateAttr.foregroundColor = .secondary
            dueDateAttr.font = .caption
            result.append(dueDateAttr)
        }

        return result
    }

    private func detectPriority(in text: String) -> TodoLine.Priority {
        let lowercased = text.lowercased()

        if text.contains("!!!") || lowercased.contains("urgent") || lowercased.contains("critical") {
            return .high
        } else if text.contains("!!") || lowercased.contains("important") {
            return .medium
        }

        return .normal
    }

    private func detectDueDate(in text: String) -> String? {
        // Look for common date patterns
        let patterns = [
            "due\\s+(\\d{1,2}/\\d{1,2})",          // due 12/25
            "by\\s+(\\w+\\s+\\d{1,2})",            // by Dec 25
            "(\\d{1,2}/\\d{1,2}/\\d{2,4})",        // 12/25/24
            "due\\s+(today|tomorrow|\\w+day)",     // due tomorrow, due monday
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(text.startIndex..., in: text)
                if let match = regex.firstMatch(in: text, range: range) {
                    let dateRange = Range(match.range(at: 1), in: text)
                    if let dateRange = dateRange {
                        return String(text[dateRange])
                    }
                }
            }
        }

        return nil
    }
}
