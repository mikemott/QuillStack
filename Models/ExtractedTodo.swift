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
    /// Uses DateParsingService for robust date extraction via NSDataDetector
    var parsedDueDate: Date? {
        guard let dueDate = dueDate else { return nil }
        return DateParsingService.parse(dateString: dueDate)
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

