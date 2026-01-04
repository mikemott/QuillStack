//
//  ExtractedTodo.swift
//  QuillStack
//
//  Phase 2.2 - Todo Extraction
//  Represents a todo item extracted from text using LLM.
//

import Foundation

/// Represents a todo item extracted from text content
struct ExtractedTodo: Codable, Identifiable, Sendable, Equatable {
    let id: UUID
    let text: String
    let isCompleted: Bool
    let priority: String // "high", "medium", "normal"
    let dueDate: String? // ISO 8601 date string or natural language
    let notes: String? // Additional context or notes
    
    init(
        id: UUID = UUID(),
        text: String,
        isCompleted: Bool = false,
        priority: String = "normal",
        dueDate: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.text = text
        self.isCompleted = isCompleted
        self.priority = priority
        self.dueDate = dueDate
        self.notes = notes
    }
    
    /// Parse dueDate string into a Date object
    /// Handles ISO 8601, natural language ("tomorrow", "next week"), and common formats
    var parsedDueDate: Date? {
        guard let dueDate = dueDate else { return nil }
        
        // Try ISO 8601 first
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: dueDate) {
            return date
        }
        
        // Try without fractional seconds
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: dueDate) {
            return date
        }
        
        // Try common date formats
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        let formats = [
            "yyyy-MM-dd",
            "MM/dd/yyyy",
            "MM/dd/yy",
            "MMMM dd, yyyy",
            "MMM dd, yyyy"
        ]
        
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: dueDate) {
                return date
            }
        }
        
        // Try natural language parsing (basic)
        let lowercased = dueDate.lowercased()
        let calendar = Calendar.current
        let now = Date()
        
        if lowercased.contains("tomorrow") {
            return calendar.date(byAdding: .day, value: 1, to: now)
        } else if lowercased.contains("next week") {
            return calendar.date(byAdding: .weekOfYear, value: 1, to: now)
        } else if lowercased.contains("next month") {
            return calendar.date(byAdding: .month, value: 1, to: now)
        } else if lowercased.contains("today") {
            return now
        }
        
        return nil
    }
    
    /// Convert to TodoItem priority enum
    var todoPriority: TodoPriority {
        switch priority.lowercased() {
        case "high", "urgent", "critical":
            return .high
        case "medium", "important":
            return .medium
        default:
            return .normal
        }
    }
}

/// JSON response structure from LLM for todo extraction
struct TodoExtractionJSON: Codable {
    let todos: [ExtractedTodoJSON]
}

struct ExtractedTodoJSON: Codable {
    let text: String
    let completed: Bool?
    let priority: String?
    let dueDate: String?
    let notes: String?
}

