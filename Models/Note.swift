//
//  Note.swift
//  QuillStack
//
//  Created on 2025-12-10.
//

import Foundation
import CoreData

@objc(Note)
public class Note: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var content: String
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    @NSManaged public var noteType: String // "general", "todo", "meeting"
    @NSManaged public var thumbnail: Data?
    @NSManaged public var originalImageData: Data?
    @NSManaged public var tags: String? // Comma-separated tags
    @NSManaged public var ocrConfidence: Float
    @NSManaged public var ocrResultData: Data? // Encoded OCRResult for confidence display
    @NSManaged public var isArchived: Bool

    // Relationships
    @NSManaged public var todoItems: NSSet?
    @NSManaged public var meeting: Meeting?

    /// Decoded OCR result for confidence highlighting
    /// Note: Access from main actor context for UI display
    @MainActor var ocrResult: OCRResult? {
        get {
            guard let data = ocrResultData else { return nil }
            return try? JSONDecoder().decode(OCRResult.self, from: data)
        }
        set {
            ocrResultData = try? JSONEncoder().encode(newValue)
        }
    }

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date()
        updatedAt = Date()
        noteType = "general"
        ocrConfidence = 0.0
        isArchived = false
    }
}

// MARK: - Convenience Initializer
extension Note {
    static func create(
        in context: NSManagedObjectContext,
        content: String,
        noteType: String = "general",
        originalImage: Data? = nil
    ) -> Note {
        let note = Note(context: context)
        note.content = content
        note.noteType = noteType
        note.originalImageData = originalImage
        return note
    }
}

// MARK: - Todo Items Relationship
extension Note {
    @objc(addTodoItemsObject:)
    @NSManaged public func addToTodoItems(_ value: TodoItem)

    @objc(removeTodoItemsObject:)
    @NSManaged public func removeFromTodoItems(_ value: TodoItem)

    @objc(addTodoItems:)
    @NSManaged public func addToTodoItems(_ values: NSSet)

    @objc(removeTodoItems:)
    @NSManaged public func removeFromTodoItems(_ values: NSSet)
}
