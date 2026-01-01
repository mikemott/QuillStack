//
//  IntegrationProvider.swift
//  QuillStack
//
//  Phase 4.1 - Architecture refactoring: unified integration provider system.
//  Provides a common protocol for all integrations (exports, sync, imports).
//

import Foundation

// MARK: - Core Protocol

/// Base protocol for all integration providers.
/// Implement this protocol to create new integrations for QuillStack notes.
protocol IntegrationProvider: Identifiable, Sendable {
    /// Unique identifier for this provider
    var id: String { get }

    /// Human-readable name for display in UI
    var name: String { get }

    /// SF Symbol icon name
    var icon: String { get }

    /// Note types this provider supports
    var supportedNoteTypes: Set<NoteType> { get }

    /// Check if provider is properly configured (e.g., API keys set, permissions granted)
    func isConfigured() async -> Bool

    /// Configure the provider (request permissions, authenticate, etc.)
    func configure() async throws

    // MARK: - Capabilities

    /// Whether this provider can export notes
    var canExport: Bool { get }

    /// Whether this provider can sync notes bidirectionally
    var canSync: Bool { get }

    /// Whether this provider can import notes
    var canImport: Bool { get }
}

// MARK: - Default Implementations

extension IntegrationProvider {
    var canExport: Bool { false }
    var canSync: Bool { false }
    var canImport: Bool { false }
}

// MARK: - Exportable Provider

/// Protocol for providers that can export notes to external services.
protocol ExportableProvider: IntegrationProvider {
    /// Export a single note to the external service.
    /// - Parameter note: The note to export
    /// - Returns: Result of the export operation
    func export(note: Note) async throws -> IntegrationExportResult

    /// Export multiple notes to the external service.
    /// - Parameter notes: Array of notes to export
    /// - Returns: Array of export results (same order as input)
    func export(notes: [Note]) async throws -> [IntegrationExportResult]
}

extension ExportableProvider {
    var canExport: Bool { true }

    /// Default implementation exports notes sequentially
    func export(notes: [Note]) async throws -> [IntegrationExportResult] {
        var results: [IntegrationExportResult] = []
        for note in notes {
            let result = try await export(note: note)
            results.append(result)
        }
        return results
    }
}

// MARK: - Syncable Provider

/// Protocol for providers that support bidirectional sync.
protocol SyncableProvider: IntegrationProvider {
    /// Sync notes with the external service.
    /// - Parameter notes: Notes to sync
    /// - Returns: Result of the sync operation
    func sync(notes: [Note]) async throws -> SyncResult

    /// Fetch changes from the remote service since a given date.
    /// - Parameter since: Optional date to fetch changes from (nil = all changes)
    /// - Returns: Array of remote changes
    func fetchRemoteChanges(since: Date?) async throws -> [RemoteChange]

    /// Apply a remote change to the local store.
    /// - Parameter change: The remote change to apply
    func applyRemoteChange(_ change: RemoteChange) async throws
}

extension SyncableProvider {
    var canSync: Bool { true }
}

// MARK: - Importable Provider

/// Protocol for providers that can import notes from external services.
protocol ImportableProvider: IntegrationProvider {
    /// Import notes from the external service.
    /// - Returns: Array of imported note data
    func importNotes() async throws -> [ImportedNoteData]

    /// Import notes modified since a given date.
    /// - Parameter since: Date to import from (nil = all notes)
    /// - Returns: Array of imported note data
    func importNotes(since: Date?) async throws -> [ImportedNoteData]
}

extension ImportableProvider {
    var canImport: Bool { true }

    /// Default implementation imports all notes
    func importNotes() async throws -> [ImportedNoteData] {
        try await importNotes(since: nil)
    }
}

// MARK: - Supporting Types

/// Result of an integration export operation.
struct IntegrationExportResult: Equatable, Sendable {
    /// Whether the export succeeded
    let success: Bool

    /// Provider that performed the export
    let provider: String

    /// External ID of the exported item (if available)
    let exportedId: String?

    /// Human-readable message about the result
    let message: String?

    /// URL to the exported item (if available)
    let url: URL?

    /// Timestamp of the export
    let exportedAt: Date

    init(
        success: Bool,
        provider: String,
        exportedId: String? = nil,
        message: String? = nil,
        url: URL? = nil,
        exportedAt: Date = Date()
    ) {
        self.success = success
        self.provider = provider
        self.exportedId = exportedId
        self.message = message
        self.url = url
        self.exportedAt = exportedAt
    }

    /// Create a successful export result
    static func success(
        provider: String,
        exportedId: String? = nil,
        message: String? = nil,
        url: URL? = nil
    ) -> IntegrationExportResult {
        IntegrationExportResult(
            success: true,
            provider: provider,
            exportedId: exportedId,
            message: message,
            url: url
        )
    }

    /// Create a failed export result
    static func failure(provider: String, message: String) -> IntegrationExportResult {
        IntegrationExportResult(
            success: false,
            provider: provider,
            message: message
        )
    }
}

/// Result of a sync operation.
struct SyncResult: Equatable, Sendable {
    /// Number of notes uploaded to remote
    let uploaded: Int

    /// Number of notes downloaded from remote
    let downloaded: Int

    /// Number of notes that had conflicts
    let conflictCount: Int

    /// Detailed conflict information
    let conflicts: [SyncConflict]

    /// Any errors that occurred (non-fatal)
    let errors: [String]

    /// Timestamp of the sync
    let syncedAt: Date

    init(
        uploaded: Int = 0,
        downloaded: Int = 0,
        conflicts: [SyncConflict] = [],
        errors: [String] = [],
        syncedAt: Date = Date()
    ) {
        self.uploaded = uploaded
        self.downloaded = downloaded
        self.conflictCount = conflicts.count
        self.conflicts = conflicts
        self.errors = errors
        self.syncedAt = syncedAt
    }

    /// Whether the sync completed without conflicts or errors
    var isClean: Bool {
        conflicts.isEmpty && errors.isEmpty
    }
}

/// Represents a sync conflict between local and remote versions.
struct SyncConflict: Equatable, Sendable, Identifiable {
    let id: UUID

    /// Local note ID
    let noteId: UUID

    /// Note title for display
    let noteTitle: String

    /// When the local version was modified
    let localModifiedAt: Date

    /// When the remote version was modified
    let remoteModifiedAt: Date

    /// Resolution strategy applied (if any)
    let resolution: ConflictResolution?

    init(
        id: UUID = UUID(),
        noteId: UUID,
        noteTitle: String,
        localModifiedAt: Date,
        remoteModifiedAt: Date,
        resolution: ConflictResolution? = nil
    ) {
        self.id = id
        self.noteId = noteId
        self.noteTitle = noteTitle
        self.localModifiedAt = localModifiedAt
        self.remoteModifiedAt = remoteModifiedAt
        self.resolution = resolution
    }
}

/// How a sync conflict was resolved.
enum ConflictResolution: String, Equatable, Sendable {
    case keepLocal
    case keepRemote
    case merged
    case skipped
}

/// Represents a change detected on the remote service.
struct RemoteChange: Equatable, Sendable, Identifiable {
    let id: UUID

    /// Type of change
    let changeType: RemoteChangeType

    /// Remote ID of the affected item
    let remoteId: String

    /// Local note ID (if known)
    let localNoteId: UUID?

    /// Changed data (for create/update)
    let data: RemoteNoteData?

    /// When the change occurred
    let changedAt: Date

    init(
        id: UUID = UUID(),
        changeType: RemoteChangeType,
        remoteId: String,
        localNoteId: UUID? = nil,
        data: RemoteNoteData? = nil,
        changedAt: Date = Date()
    ) {
        self.id = id
        self.changeType = changeType
        self.remoteId = remoteId
        self.localNoteId = localNoteId
        self.data = data
        self.changedAt = changedAt
    }
}

/// Type of remote change.
enum RemoteChangeType: String, Equatable, Sendable {
    case created
    case updated
    case deleted
}

/// Data from a remote note (for sync/import).
struct RemoteNoteData: Equatable, Sendable {
    let title: String?
    let content: String
    let noteType: NoteType
    let tags: [String]
    let metadata: [String: String]

    init(
        title: String? = nil,
        content: String,
        noteType: NoteType = .general,
        tags: [String] = [],
        metadata: [String: String] = [:]
    ) {
        self.title = title
        self.content = content
        self.noteType = noteType
        self.tags = tags
        self.metadata = metadata
    }
}

/// Data for importing a new note.
struct ImportedNoteData: Equatable, Sendable, Identifiable {
    let id: UUID

    /// Remote ID from the source service
    let remoteId: String

    /// Source provider
    let provider: String

    /// Note content
    let content: String

    /// Detected or specified note type
    let noteType: NoteType

    /// Tags to apply
    let tags: [String]

    /// When the note was created in the source
    let createdAt: Date

    /// When the note was last modified in the source
    let modifiedAt: Date

    /// Additional metadata from the source
    let metadata: [String: String]

    init(
        id: UUID = UUID(),
        remoteId: String,
        provider: String,
        content: String,
        noteType: NoteType = .general,
        tags: [String] = [],
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.remoteId = remoteId
        self.provider = provider
        self.content = content
        self.noteType = noteType
        self.tags = tags
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.metadata = metadata
    }
}

// MARK: - Integration Errors

/// Errors that can occur during integration operations.
enum IntegrationError: Error, LocalizedError {
    case notConfigured
    case authenticationFailed
    case permissionDenied
    case networkError(underlying: Error)
    case rateLimited(retryAfter: TimeInterval?)
    case notFound(id: String)
    case invalidData(message: String)
    case syncConflict(conflict: SyncConflict)
    case providerError(message: String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Integration is not configured. Please set up the integration in Settings."
        case .authenticationFailed:
            return "Authentication failed. Please re-authenticate."
        case .permissionDenied:
            return "Permission denied. Please grant the required permissions."
        case .networkError(let underlying):
            return "Network error: \(underlying.localizedDescription)"
        case .rateLimited(let retryAfter):
            if let seconds = retryAfter {
                return "Rate limited. Please try again in \(Int(seconds)) seconds."
            }
            return "Rate limited. Please try again later."
        case .notFound(let id):
            return "Item not found: \(id)"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        case .syncConflict(let conflict):
            return "Sync conflict for '\(conflict.noteTitle)'"
        case .providerError(let message):
            return message
        }
    }
}
