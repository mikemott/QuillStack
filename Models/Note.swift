//
//  Note.swift
//  QuillStack
//
//  Created on 2025-12-10.
//

import Foundation
import CoreData

/// Processing state for notes captured offline
public enum NoteProcessingState: String, CaseIterable {
    case ocrOnly           // Captured offline, no LLM enhancement
    case pendingEnhancement // Queued for processing
    case processing        // Currently enhancing
    case enhanced          // Fully processed
    case failed            // Processing error
}

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
    @NSManaged public var classificationConfidence: Double // 0.0 to 1.0
    @NSManaged public var classificationMethod: String? // "explicit", "llm", "heuristic", etc.
    @NSManaged public var extractedDataJSON: String? // JSON-encoded extracted data (Contact, Event, Todo)
    @NSManaged public var llmClassificationCache: String? // Cached LLM classification result
    @NSManaged public var originalClassificationType: String? // Original type before manual correction
    @NSManaged public var annotationData: Data? // PKDrawing serialized data
    @NSManaged public var hasAnnotations: Bool // Quick check if note has annotations
    @NSManaged public var sourceNoteID: UUID? // Original note this was split from
    @NSManaged public var processingStateRaw: String // NoteProcessingState raw value

    // Relationships
    @NSManaged public var todoItems: NSSet?
    @NSManaged public var meeting: Meeting?
    @NSManaged public var pages: NSSet? // Multi-page document support
    @NSManaged public var outgoingLinks: NSSet? // Links from this note to others
    @NSManaged public var incomingLinks: NSSet? // Links from other notes to this one

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
        classificationConfidence = 0.0
        classificationMethod = nil
        extractedDataJSON = nil
        llmClassificationCache = nil
        originalClassificationType = nil
        hasAnnotations = false
        processingStateRaw = NoteProcessingState.enhanced.rawValue // Default to enhanced
    }

    /// Type-safe access to processing state
    var processingState: NoteProcessingState {
        get {
            NoteProcessingState(rawValue: processingStateRaw) ?? .enhanced
        }
        set {
            processingStateRaw = newValue.rawValue
        }
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

// MARK: - Note Links Relationship

extension Note {
    @objc(addOutgoingLinksObject:)
    @NSManaged public func addToOutgoingLinks(_ value: NoteLink)

    @objc(removeOutgoingLinksObject:)
    @NSManaged public func removeFromOutgoingLinks(_ value: NoteLink)

    @objc(addOutgoingLinks:)
    @NSManaged public func addToOutgoingLinks(_ values: NSSet)

    @objc(removeOutgoingLinks:)
    @NSManaged public func removeFromOutgoingLinks(_ values: NSSet)

    @objc(addIncomingLinksObject:)
    @NSManaged public func addToIncomingLinks(_ value: NoteLink)

    @objc(removeIncomingLinksObject:)
    @NSManaged public func removeFromIncomingLinks(_ value: NoteLink)

    @objc(addIncomingLinks:)
    @NSManaged public func addToIncomingLinks(_ values: NSSet)

    @objc(removeIncomingLinks:)
    @NSManaged public func removeFromIncomingLinks(_ values: NSSet)

    /// Get all notes that this note links to (forward links)
    var forwardLinks: [Note] {
        guard let links = outgoingLinks as? Set<NoteLink> else { return [] }
        return links.map { $0.targetNote }
    }

    /// Get all notes that link to this note (backlinks)
    var backlinks: [Note] {
        guard let links = incomingLinks as? Set<NoteLink> else { return [] }
        return links.map { $0.sourceNote }
    }

    /// Get all linked notes (both incoming and outgoing)
    var allLinkedNotes: [Note] {
        let forward = forwardLinks
        let back = backlinks
        // Remove duplicates and return
        var seen = Set<UUID>()
        var result: [Note] = []
        for note in forward + back {
            if !seen.contains(note.id) {
                seen.insert(note.id)
                result.append(note)
            }
        }
        return result
    }

    /// Get count of all links (incoming + outgoing)
    var linkCount: Int {
        let outgoing = (outgoingLinks as? Set<NoteLink>)?.count ?? 0
        let incoming = (incomingLinks as? Set<NoteLink>)?.count ?? 0
        return outgoing + incoming
    }

    /// Get all outgoing links as typed array
    var typedOutgoingLinks: [NoteLink] {
        guard let links = outgoingLinks as? Set<NoteLink> else { return [] }
        return Array(links).sorted { $0.createdAt > $1.createdAt }
    }

    /// Get all incoming links as typed array
    var typedIncomingLinks: [NoteLink] {
        guard let links = incomingLinks as? Set<NoteLink> else { return [] }
        return Array(links).sorted { $0.createdAt > $1.createdAt }
    }
}

// MARK: - Classification Extensions

extension Note {
    /// Get the classification method used for this note
    var classificationMethodEnum: ClassificationMethod? {
        get {
            guard let methodString = classificationMethod else { return nil }
            return ClassificationMethod(rawValue: methodString)
        }
        set {
            classificationMethod = newValue?.rawValue
        }
    }
    
    /// Get the classification result for this note
    var classification: NoteClassification {
        NoteClassification(
            type: type,
            confidence: classificationConfidence,
            method: classificationMethodEnum ?? .default,
            reasoning: nil
        )
    }
    
    /// Set the classification result for this note
    func setClassification(_ classification: NoteClassification) {
        type = classification.type
        classificationConfidence = classification.confidence
        classificationMethodEnum = classification.method
        updatedAt = Date()
    }
}
