//
//  TodoItem.swift
//  QuillStack
//
//  Created on 2025-12-10.
//

import Foundation
import CoreData

@objc(TodoItem)
public class TodoItem: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var text: String
    @NSManaged public var isCompleted: Bool
    @NSManaged public var priority: String // "high", "medium", "normal"
    @NSManaged public var dueDate: Date?
    @NSManaged public var createdAt: Date
    @NSManaged public var status: String // "todo", "inProgress", "done"
    @NSManaged public var sortOrder: Int16

    // Relationship
    @NSManaged public var note: Note?

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date()
        isCompleted = false
        priority = "normal"
        status = "todo"
        sortOrder = 0
    }
}

// MARK: - Priority Enum
enum TodoPriority: String, Codable, CaseIterable {
    case high = "high"
    case medium = "medium"
    case normal = "normal"

    var displayName: String {
        switch self {
        case .high: return "High"
        case .medium: return "Medium"
        case .normal: return "Normal"
        }
    }
}

// MARK: - Status Enum
enum TodoStatus: String, Codable, CaseIterable {
    case todo = "todo"
    case inProgress = "inProgress"
    case done = "done"

    var displayName: String {
        switch self {
        case .todo: return "To Do"
        case .inProgress: return "In Progress"
        case .done: return "Done"
        }
    }
}

// MARK: - Convenience Initializer
extension TodoItem {
    static func create(
        in context: NSManagedObjectContext,
        text: String,
        priority: TodoPriority = .normal,
        dueDate: Date? = nil,
        note: Note? = nil
    ) -> TodoItem {
        let item = TodoItem(context: context)
        item.text = text
        item.priority = priority.rawValue
        item.dueDate = dueDate
        item.note = note
        return item
    }
}
