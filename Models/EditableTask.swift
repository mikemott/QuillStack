//
//  EditableTask.swift
//  QuillStack
//
//  Mutable task model for editing before saving to Reminders.
//

import Foundation

/// Represents a mutable todo task for editing in TodoReviewSheet
struct EditableTask: Identifiable, Equatable {
    let id: UUID
    var text: String
    var isCompleted: Bool
    var priority: String
    var dueDate: Date?
    var notes: String?

    init(id: UUID = UUID(), text: String, isCompleted: Bool, priority: String, dueDate: Date?, notes: String?) {
        self.id = id
        self.text = text
        self.isCompleted = isCompleted
        self.priority = priority
        self.dueDate = dueDate
        self.notes = notes
    }

    init(from extracted: ExtractedTodo) {
        self.id = extracted.id
        self.text = extracted.text
        self.isCompleted = extracted.isCompleted
        self.priority = extracted.priority
        self.dueDate = extracted.parsedDueDate
        self.notes = extracted.notes
    }
}
