//
//  TodoParser.swift
//  QuillStack
//
//  Created on 2025-12-10.
//

import Foundation
import CoreData

class TodoParser {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    /// Parses todo items from text content
    func parseTodos(from text: String, note: Note? = nil) -> [TodoItem] {
        var todos: [TodoItem] = []
        let lines = text.components(separatedBy: .newlines)

        for line in lines {
            if let todo = parseTodoLine(line, note: note) {
                todos.append(todo)
            }
        }

        return todos
    }

    private func parseTodoLine(_ line: String, note: Note?) -> TodoItem? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Skip empty lines
        guard !trimmed.isEmpty else { return nil }

        // Patterns to detect todos
        let patterns = [
            "^[\\[\\(][ xX]?[\\]\\)]\\s*(.+)$",  // [ ] or [x] checkbox
            "^[-*•]\\s*(.+)$",                     // bullet points
            "^\\d+\\.\\s*(.+)$",                   // numbered lists
            "^TODO:?\\s*(.+)$",                    // explicit TODO
            "^\\s*-\\s*(.+)$"                      // dash bullets
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(trimmed.startIndex..., in: trimmed)
                if let match = regex.firstMatch(in: trimmed, range: range) {
                    let taskRange = Range(match.range(at: 1), in: trimmed)
                    if let taskRange = taskRange {
                        let taskText = String(trimmed[taskRange])
                        let isCompleted = trimmed.contains("[x]") || trimmed.contains("[X]")

                        let todo = TodoItem(context: context)
                        todo.text = taskText
                        todo.isCompleted = isCompleted
                        todo.priority = detectPriority(in: taskText).rawValue
                        todo.dueDate = detectDueDate(in: taskText)
                        todo.status = isCompleted ? "done" : "todo"
                        todo.note = note

                        return todo
                    }
                }
            }
        }

        return nil
    }

    private func detectPriority(in text: String) -> TodoPriority {
        if text.contains("!!!") || text.lowercased().contains("urgent") {
            return .high
        } else if text.contains("!!") || text.lowercased().contains("important") {
            return .medium
        }
        return .normal
    }

    private func detectDueDate(in text: String) -> Date? {
        // Look for date patterns
        let datePatterns = [
            "due\\s+(\\d{1,2}/\\d{1,2})",          // due 12/25
            "by\\s+(\\w+\\s+\\d{1,2})",            // by Dec 25
            "(\\d{1,2}/\\d{1,2}/\\d{2,4})"         // 12/25/24
        ]

        for pattern in datePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(text.startIndex..., in: text)
                if let match = regex.firstMatch(in: text, range: range) {
                    let dateRange = Range(match.range(at: 1), in: text)
                    if let dateRange = dateRange {
                        let dateString = String(text[dateRange])
                        return parseDateString(dateString)
                    }
                }
            }
        }

        return nil
    }

    private func parseDateString(_ string: String) -> Date? {
        let formatter = DateFormatter()

        // Try MM/dd/yy format
        formatter.dateFormat = "MM/dd/yy"
        if let date = formatter.date(from: string) {
            return date
        }

        // Try MM/dd/yyyy format
        formatter.dateFormat = "MM/dd/yyyy"
        if let date = formatter.date(from: string) {
            return date
        }

        // Try MM/dd format (current year)
        formatter.dateFormat = "MM/dd"
        if let date = formatter.date(from: string) {
            return date
        }

        return nil
    }
}
