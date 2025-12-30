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
    @NSManaged public var summary: String? // Cached AI-generated summary
    @NSManaged public var summaryGeneratedAt: Date? // When summary was generated

    // Relationships
    @NSManaged public var todoItems: NSSet?
    @NSManaged public var meeting: Meeting?
    @NSManaged public var pages: NSSet? // Multi-page document support

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

// MARK: - Pages Relationship
extension Note {
    @objc(addPagesObject:)
    @NSManaged public func addToPages(_ value: NotePage)

    @objc(removePagesObject:)
    @NSManaged public func removeFromPages(_ value: NotePage)

    @objc(addPages:)
    @NSManaged public func addToPages(_ values: NSSet)

    @objc(removePages:)
    @NSManaged public func removeFromPages(_ values: NSSet)

    /// Get pages sorted by page number
    var sortedPages: [NotePage] {
        guard let pagesSet = pages as? Set<NotePage> else { return [] }
        return pagesSet.sorted { $0.pageNumber < $1.pageNumber }
    }

    /// Check if this is a multi-page note
    var isMultiPage: Bool {
        guard let pagesSet = pages else { return false }
        return pagesSet.count > 1
    }

    /// Get page count
    var pageCount: Int {
        (pages as? Set<NotePage>)?.count ?? (originalImageData != nil ? 1 : 0)
    }

    /// Combine OCR text from all pages
    var combinedPageText: String {
        sortedPages
            .compactMap { $0.ocrText }
            .joined(separator: "\n\n--- Page Break ---\n\n")
    }
}
