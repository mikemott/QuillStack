//
//  NoteEvent.swift
//  QuillStack
//
//  Phase 4.2 - Architecture refactoring: event types for the event bus system.
//  Provides type-safe events for loose coupling between components.
//

import Foundation

// MARK: - Note Event

/// Events that can be published through the NoteEventBus.
/// Subscribe to these events to react to note lifecycle changes, processing, and integrations.
enum NoteEvent: Sendable {

    // MARK: - Lifecycle Events

    /// A new note was created
    case created(noteId: UUID, noteType: NoteType)

    /// A note was updated
    case updated(noteId: UUID, noteType: NoteType)

    /// A note was deleted
    case deleted(noteId: UUID)

    /// A note was archived
    case archived(noteId: UUID)

    /// A note was restored from archive
    case restored(noteId: UUID)

    // MARK: - Processing Events

    /// OCR processing completed for a note
    case ocrCompleted(noteId: UUID, result: OCREventResult)

    /// AI enhancement completed for a note
    case enhanced(noteId: UUID, result: EnhancementEventResult)

    /// Note was classified to a type
    case classified(noteId: UUID, noteType: NoteType, confidence: Float)

    // MARK: - Integration Events

    /// A note was exported to an external service
    case exported(noteId: UUID, provider: String, result: ExportEventResult)

    /// A note was synced with an external service
    case synced(noteId: UUID, provider: String, result: SyncEventResult)

    /// Import from external service started
    case importStarted(provider: String)

    /// Import from external service completed
    case importCompleted(provider: String, importedCount: Int)

    // MARK: - Error Events

    /// OCR processing failed
    case ocrFailed(noteId: UUID, error: String)

    /// AI enhancement failed
    case enhancementFailed(noteId: UUID, error: String)

    /// Export failed
    case exportFailed(noteId: UUID, provider: String, error: String)

    /// Sync failed
    case syncFailed(noteId: UUID, provider: String, error: String)

    /// Import failed
    case importFailed(provider: String, error: String)
}

// MARK: - Event Categories

/// Categories of events for filtered subscriptions.
enum NoteEventCategory: String, CaseIterable, Sendable {
    case lifecycle
    case processing
    case integration
    case error
}

extension NoteEvent {
    /// The category this event belongs to.
    var category: NoteEventCategory {
        switch self {
        case .created, .updated, .deleted, .archived, .restored:
            return .lifecycle
        case .ocrCompleted, .enhanced, .classified:
            return .processing
        case .exported, .synced, .importStarted, .importCompleted:
            return .integration
        case .ocrFailed, .enhancementFailed, .exportFailed, .syncFailed, .importFailed:
            return .error
        }
    }

    /// The note ID associated with this event (if applicable).
    var noteId: UUID? {
        switch self {
        case .created(let noteId, _),
             .updated(let noteId, _),
             .deleted(let noteId),
             .archived(let noteId),
             .restored(let noteId),
             .ocrCompleted(let noteId, _),
             .enhanced(let noteId, _),
             .classified(let noteId, _, _),
             .exported(let noteId, _, _),
             .synced(let noteId, _, _),
             .ocrFailed(let noteId, _),
             .enhancementFailed(let noteId, _),
             .exportFailed(let noteId, _, _),
             .syncFailed(let noteId, _, _):
            return noteId
        case .importStarted, .importCompleted, .importFailed:
            return nil
        }
    }

    /// Whether this event represents an error.
    var isError: Bool {
        category == .error
    }

    /// The provider name associated with this event (if applicable).
    var providerName: String? {
        switch self {
        case .exported(_, let provider, _),
             .synced(_, let provider, _),
             .importStarted(let provider),
             .importCompleted(let provider, _),
             .exportFailed(_, let provider, _),
             .syncFailed(_, let provider, _),
             .importFailed(let provider, _):
            return provider
        default:
            return nil
        }
    }
}

// MARK: - Event Result Types

/// Result of OCR processing for event payload.
struct OCREventResult: Sendable, Equatable {
    /// The recognized text
    let text: String

    /// Average confidence score (0.0 to 1.0)
    let confidence: Float

    /// Number of words recognized
    let wordCount: Int

    init(text: String, confidence: Float, wordCount: Int) {
        self.text = text
        self.confidence = confidence
        self.wordCount = wordCount
    }
}

/// Result of AI enhancement for event payload.
struct EnhancementEventResult: Sendable, Equatable {
    /// The original text before enhancement
    let originalText: String

    /// The enhanced text
    let enhancedText: String

    /// Number of changes made
    let changeCount: Int

    /// Type of enhancement performed
    let enhancementType: EnhancementType

    init(
        originalText: String,
        enhancedText: String,
        changeCount: Int,
        enhancementType: EnhancementType = .ocrCorrection
    ) {
        self.originalText = originalText
        self.enhancedText = enhancedText
        self.changeCount = changeCount
        self.enhancementType = enhancementType
    }
}

/// Types of AI enhancement.
enum EnhancementType: String, Sendable, Equatable {
    case ocrCorrection
    case grammarFix
    case summarization
    case expansion
    case formatting
}

/// Result of export operation for event payload.
struct ExportEventResult: Sendable, Equatable {
    /// Whether the export succeeded
    let success: Bool

    /// External ID of the exported item
    let exportedId: String?

    /// URL to the exported item (if available)
    let url: URL?

    /// Human-readable message
    let message: String?

    init(
        success: Bool,
        exportedId: String? = nil,
        url: URL? = nil,
        message: String? = nil
    ) {
        self.success = success
        self.exportedId = exportedId
        self.url = url
        self.message = message
    }

    /// Create from an IntegrationExportResult
    init(from result: IntegrationExportResult) {
        self.success = result.success
        self.exportedId = result.exportedId
        self.url = result.url
        self.message = result.message
    }
}

/// Result of sync operation for event payload.
struct SyncEventResult: Sendable, Equatable {
    /// Number of items uploaded
    let uploaded: Int

    /// Number of items downloaded
    let downloaded: Int

    /// Number of conflicts encountered
    let conflictCount: Int

    /// Whether sync was clean (no conflicts/errors)
    let isClean: Bool

    init(
        uploaded: Int = 0,
        downloaded: Int = 0,
        conflictCount: Int = 0
    ) {
        self.uploaded = uploaded
        self.downloaded = downloaded
        self.conflictCount = conflictCount
        self.isClean = conflictCount == 0
    }

    /// Create from a SyncResult
    init(from result: SyncResult) {
        self.uploaded = result.uploaded
        self.downloaded = result.downloaded
        self.conflictCount = result.conflictCount
        self.isClean = result.isClean
    }
}

// MARK: - Event Metadata

/// Metadata attached to events for logging and debugging.
struct NoteEventMetadata: Sendable {
    /// Unique identifier for this event occurrence
    let eventId: UUID

    /// When the event occurred
    let timestamp: Date

    /// Source of the event (e.g., "CameraViewModel", "SyncService")
    let source: String

    /// Additional context as key-value pairs
    let context: [String: String]

    init(
        eventId: UUID = UUID(),
        timestamp: Date = Date(),
        source: String,
        context: [String: String] = [:]
    ) {
        self.eventId = eventId
        self.timestamp = timestamp
        self.source = source
        self.context = context
    }
}

// MARK: - Wrapped Event

/// An event with its metadata for the event bus.
struct WrappedNoteEvent: Sendable {
    let event: NoteEvent
    let metadata: NoteEventMetadata

    init(event: NoteEvent, source: String, context: [String: String] = [:]) {
        self.event = event
        self.metadata = NoteEventMetadata(source: source, context: context)
    }

    init(event: NoteEvent, metadata: NoteEventMetadata) {
        self.event = event
        self.metadata = metadata
    }
}
