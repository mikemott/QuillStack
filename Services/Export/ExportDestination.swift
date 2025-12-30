//
//  ExportDestination.swift
//  QuillStack
//
//  Created on 2025-12-18.
//

import Foundation
import UIKit

// MARK: - Export Destination Type

enum ExportDestinationType: String, CaseIterable, Identifiable {
    case appleNotes = "apple_notes"
    case obsidian = "obsidian"
    case notion = "notion"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .appleNotes: return "Apple Notes"
        case .obsidian: return "Obsidian"
        case .notion: return "Notion"
        }
    }

    var icon: String {
        switch self {
        case .appleNotes: return "note.text"
        case .obsidian: return "doc.text.fill"
        case .notion: return "book.closed.fill"
        }
    }

    var description: String {
        switch self {
        case .appleNotes: return "Native iOS notes app"
        case .obsidian: return "Local markdown vault"
        case .notion: return "Cloud workspace"
        }
    }
}

// MARK: - Export Destination Protocol

protocol ExportDestination {
    var type: ExportDestinationType { get }

    /// Check if destination is properly configured
    func isConfigured() -> Bool

    /// Get list of missing configuration items
    func getMissingConfiguration() -> [String]

    /// Export a note to this destination
    func export(request: ExportRequest) async throws -> ExportResult
}

// MARK: - Export Request

struct ExportRequest {
    let note: Note
    let content: FormattedExportContent
    let targetPath: String?
    let options: ExportOptions

    init(note: Note, content: FormattedExportContent, targetPath: String? = nil, options: ExportOptions = ExportOptions()) {
        self.note = note
        self.content = content
        self.targetPath = targetPath
        self.options = options
    }
}

// MARK: - Export Options

struct ExportOptions: Sendable {
    var includeOriginalImage: Bool = false
    var includeMetadata: Bool = true
    var openAfterExport: Bool = false

    nonisolated init(includeOriginalImage: Bool = false, includeMetadata: Bool = true, openAfterExport: Bool = false) {
        self.includeOriginalImage = includeOriginalImage
        self.includeMetadata = includeMetadata
        self.openAfterExport = openAfterExport
    }
}

// MARK: - Export Result

struct ExportResult {
    let success: Bool
    let destination: ExportDestinationType
    let exportedPath: String?
    let message: String?
    let openURL: URL?

    static func success(destination: ExportDestinationType, path: String? = nil, message: String? = nil, openURL: URL? = nil) -> ExportResult {
        ExportResult(success: true, destination: destination, exportedPath: path, message: message, openURL: openURL)
    }

    static func failure(destination: ExportDestinationType, message: String) -> ExportResult {
        ExportResult(success: false, destination: destination, exportedPath: nil, message: message, openURL: nil)
    }
}

// MARK: - Formatted Export Content

struct FormattedExportContent {
    let title: String
    let plainBody: String
    let markdownBody: String
    let attributedBody: NSAttributedString
    let metadata: ExportMetadata
    let attachments: [ExportAttachment]

    init(
        title: String,
        plainBody: String,
        markdownBody: String? = nil,
        attributedBody: NSAttributedString? = nil,
        metadata: ExportMetadata,
        attachments: [ExportAttachment] = []
    ) {
        self.title = title
        self.plainBody = plainBody
        self.markdownBody = markdownBody ?? plainBody
        self.attributedBody = attributedBody ?? NSAttributedString(string: plainBody)
        self.metadata = metadata
        self.attachments = attachments
    }
}

// MARK: - Export Metadata

struct ExportMetadata {
    let noteType: String
    let createdAt: Date
    let updatedAt: Date
    let tags: [String]
    let ocrConfidence: Float?
    let source: String = "QuillStack"

    init(from note: Note, tags: [String] = []) {
        self.noteType = note.noteType
        self.createdAt = note.createdAt
        self.updatedAt = note.updatedAt
        self.tags = tags
        self.ocrConfidence = note.ocrConfidence > 0 ? note.ocrConfidence : nil
    }
}

// MARK: - Export Attachment

struct ExportAttachment {
    let data: Data
    let filename: String
    let mimeType: String

    static func image(_ data: Data, filename: String = "original.jpg") -> ExportAttachment {
        ExportAttachment(data: data, filename: filename, mimeType: "image/jpeg")
    }
}

// MARK: - Export Error

enum ExportError: LocalizedError {
    case destinationNotConfigured(ExportDestinationType)
    case vaultPathInvalid(String)
    case vaultNotAccessible
    case fileWriteFailed(String)
    case notionAPIKeyMissing
    case notionAPIError(String)
    case notionDatabaseNotFound
    case networkError(String)
    case formatError(String)
    case cancelled
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .destinationNotConfigured(let dest):
            return "\(dest.name) is not configured. Please set it up in Settings."
        case .vaultPathInvalid(let path):
            return "Invalid Obsidian vault path: \(path)"
        case .vaultNotAccessible:
            return "Cannot access Obsidian vault. Check the path and permissions."
        case .fileWriteFailed(let reason):
            return "Failed to write file: \(reason)"
        case .notionAPIKeyMissing:
            return "Notion API key is missing. Add it in Settings > Export."
        case .notionAPIError(let message):
            return "Notion API error: \(message)"
        case .notionDatabaseNotFound:
            return "Notion database not found. Check your configuration."
        case .networkError(let message):
            return "Network error: \(message)"
        case .formatError(let message):
            return "Format error: \(message)"
        case .cancelled:
            return "Export was cancelled."
        case .unknown(let message):
            return "Export failed: \(message)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .destinationNotConfigured:
            return "Go to Settings > Export to configure your destination."
        case .vaultPathInvalid, .vaultNotAccessible:
            return "Check your Obsidian vault path in Settings > Export > Obsidian."
        case .notionAPIKeyMissing, .notionDatabaseNotFound:
            return "Configure Notion in Settings > Export > Notion."
        case .networkError:
            return "Check your internet connection and try again."
        default:
            return nil
        }
    }
}
