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
    
    // MARK: - LLM-Powered Extraction
    
    /// Extract todos from text using LLM for better accuracy
    /// Falls back to heuristic parsing if LLM fails
    func extractWithLLM(_ content: String) async throws -> [ExtractedTodo] {
        let prompt = """
        Extract all todo items from this text. Return valid JSON only, no other text.
        
        Format:
        {
            "todos": [
                {
                    "text": "Task description",
                    "completed": false,
                    "priority": "normal",
                    "dueDate": "2024-12-25" or "tomorrow" or null,
                    "notes": "Additional context if any"
                }
            ]
        }
        
        Rules:
        - Extract ALL tasks, even if not explicitly marked
        - Set completed=true if task has checkmark [x] or is marked done
        - Priority: "high" (urgent/critical), "medium" (important), "normal" (default)
        - Extract dates in natural language ("tomorrow", "next week") or ISO format
        - If no todos found, return empty array
        
        Text:
        \(content)
        """
        
        let settings = await SettingsManager.shared
        guard let apiKey = await settings.claudeAPIKey, !apiKey.isEmpty else {
            throw TodoExtractionError.noAPIKey
        }
        
        let response = try await LLMService.shared.performAPIRequest(
            prompt: prompt,
            maxTokens: 500
        )
        
        // Parse JSON response
        guard let jsonData = response.data(using: .utf8) else {
            throw TodoExtractionError.invalidResponse
        }
        
        // Try to extract JSON from markdown code blocks if present
        let cleanedResponse = cleanJSONResponse(response)
        guard let cleanedData = cleanedResponse.data(using: .utf8) else {
            throw TodoExtractionError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        let extractionResult = try decoder.decode(TodoExtractionJSON.self, from: cleanedData)
        
        // Convert to ExtractedTodo
        return extractionResult.todos.map { jsonTodo in
            ExtractedTodo(
                text: jsonTodo.text,
                isCompleted: jsonTodo.completed ?? false,
                priority: jsonTodo.priority ?? "normal",
                dueDate: jsonTodo.dueDate,
                notes: jsonTodo.notes
            )
        }
    }
    
    /// Hybrid approach: Try LLM first, fall back to heuristics
    ///
    /// **Error Handling:**
    /// - Recoverable errors (invalidResponse, parsingFailed): Falls back to heuristics
    /// - Critical errors (noAPIKey, network issues): Re-thrown to notify caller
    func extractHybrid(_ content: String) async throws -> [ExtractedTodo] {
        // Try LLM first
        do {
            let llmTodos = try await extractWithLLM(content)
            if !llmTodos.isEmpty {
                return llmTodos
            }
            // LLM succeeded but didn't extract any todos, fall through to heuristics
        } catch let error as TodoExtractionError
            where error == .invalidResponse || error == .parsingFailed {
            // Recoverable errors: fall back to heuristic parser
            // Log for debugging but don't surface to user
            print("LLM extraction failed, falling back to heuristic parser. Error: \(error.localizedDescription ?? "Unknown")")
        } catch {
            // Critical errors (noAPIKey, network issues): re-throw to notify caller
            throw error
        }

        // Fall back to existing heuristic parser
        let todoItems = parseTodos(from: content)
        return todoItems.map { item in
            let dateString: String?
            if let dueDate = item.dueDate {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime]
                dateString = formatter.string(from: dueDate)
            } else {
                dateString = nil
            }

            return ExtractedTodo(
                text: item.text,
                isCompleted: item.isCompleted,
                priority: item.priority,
                dueDate: dateString,
                notes: nil
            )
        }
    }
    
    /// Clean JSON response by removing markdown code blocks
    private func cleanJSONResponse(_ response: String) -> String {
        var cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove markdown code blocks
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }
        
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Errors

    enum TodoExtractionError: LocalizedError, Equatable {
        case noAPIKey
        case invalidResponse
        case parsingFailed

        var errorDescription: String? {
            switch self {
            case .noAPIKey:
                return "No API key configured for LLM extraction"
            case .invalidResponse:
                return "Invalid response from LLM"
            case .parsingFailed:
                return "Failed to parse todo extraction result"
            }
        }
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
        // Use shared DateParsingService for robust date parsing
        return DateParsingService.parse(dateString: string)
    }
}
