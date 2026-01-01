//
//  NoteTypePlugin.swift
//  QuillStack
//
//  Phase 4.4 - Architecture refactoring: plugin protocol for extensible note types.
//  Enables adding new note types without modifying core code.
//

import Foundation
import SwiftUI

// MARK: - Core Plugin Protocol

/// Protocol for defining a note type plugin.
/// Implement this protocol to create new note types that integrate fully with QuillStack.
///
/// Note: Plugins are not Sendable since they are used exclusively from the MainActor
/// context (UI layer). The NoteTypeRegistry is @MainActor isolated.
@MainActor
protocol NoteTypePlugin: Identifiable {
    /// Unique identifier for this plugin
    var id: String { get }

    /// The note type this plugin handles
    var type: NoteType { get }

    /// Hashtag triggers that activate this note type (e.g., ["#todo#", "#task#"])
    var triggers: [String] { get }

    /// Human-readable display name
    var displayName: String { get }

    /// SF Symbol icon name
    var icon: String { get }

    /// Badge color for this note type
    var badgeColor: Color { get }

    /// Footer icon for note cards
    var footerIcon: String { get }

    // MARK: - View Factory

    /// Create the detail view for a note of this type.
    /// - Parameter note: The note to display
    /// - Returns: A view wrapped in AnyView
    func makeDetailView(for note: Note) -> AnyView

    // MARK: - Optional Capabilities

    /// Custom parser for this note type (optional)
    var parser: (any NoteContentParser)? { get }

    /// Custom export formatter for this note type (optional)
    var exportFormatter: (any NoteExportFormatter)? { get }

    /// Integration providers specific to this note type (optional)
    var integrationProviders: [any IntegrationProvider] { get }

    // MARK: - Lifecycle Hooks

    /// Called when a note of this type is created
    func onNoteCreated(_ note: Note) async

    /// Called when a note of this type is updated
    func onNoteUpdated(_ note: Note) async

    /// Called when a note of this type is deleted
    func onNoteDeleted(_ noteId: UUID) async
}

// MARK: - Default Implementations

extension NoteTypePlugin {
    var parser: (any NoteContentParser)? { nil }
    var exportFormatter: (any NoteExportFormatter)? { nil }
    var integrationProviders: [any IntegrationProvider] { [] }

    func onNoteCreated(_ note: Note) async {}
    func onNoteUpdated(_ note: Note) async {}
    func onNoteDeleted(_ noteId: UUID) async {}
}

// MARK: - Content Parser Protocol

/// Protocol for parsing note content into structured data.
protocol NoteContentParser: Sendable {
    /// The type of parsed content this parser produces
    associatedtype ParsedContent: Sendable

    /// Parse the content of a note.
    /// - Parameter content: The raw note content
    /// - Returns: Parsed content structure
    func parse(_ content: String) -> ParsedContent

    /// Validate that content matches this parser's expected format.
    /// - Parameter content: The content to validate
    /// - Returns: True if content is valid for this parser
    func canParse(_ content: String) -> Bool
}

extension NoteContentParser {
    func canParse(_ content: String) -> Bool { true }
}

// MARK: - Export Formatter Protocol

/// Protocol for formatting notes for export to external services.
protocol NoteExportFormatter: Sendable {
    /// Format a note for a specific export destination.
    /// - Parameters:
    ///   - note: The note to format
    ///   - destination: The export destination type
    /// - Returns: Formatted content string
    func format(_ note: Note, for destination: ExportDestinationType) -> String

    /// Supported export destinations for this formatter.
    var supportedDestinations: Set<ExportDestinationType> { get }
}

extension NoteExportFormatter {
    var supportedDestinations: Set<ExportDestinationType> {
        Set(ExportDestinationType.allCases)
    }
}

// MARK: - Parsed Content Types

/// Generic parsed content that any parser can return.
struct GenericParsedContent: Sendable, Equatable {
    /// Title extracted from content
    let title: String?

    /// Main body text
    let body: String

    /// Key-value metadata
    let metadata: [String: String]

    /// Tags found in content
    let tags: [String]

    init(
        title: String? = nil,
        body: String = "",
        metadata: [String: String] = [:],
        tags: [String] = []
    ) {
        self.title = title
        self.body = body
        self.metadata = metadata
        self.tags = tags
    }
}

/// Parsed content for todo-type notes.
struct TodoParsedContent: Sendable, Equatable {
    /// List of todo items
    let items: [TodoParsedItem]

    /// Any text that wasn't a todo item
    let additionalNotes: String?
}

struct TodoParsedItem: Sendable, Equatable, Identifiable {
    let id: UUID
    let text: String
    let isCompleted: Bool
    let priority: String
    let dueDate: Date?

    init(
        id: UUID = UUID(),
        text: String,
        isCompleted: Bool = false,
        priority: String = "normal",
        dueDate: Date? = nil
    ) {
        self.id = id
        self.text = text
        self.isCompleted = isCompleted
        self.priority = priority
        self.dueDate = dueDate
    }
}

/// Parsed content for email-type notes.
struct EmailParsedContent: Sendable, Equatable {
    let to: String?
    let cc: String?
    let subject: String?
    let body: String

    init(
        to: String? = nil,
        cc: String? = nil,
        subject: String? = nil,
        body: String = ""
    ) {
        self.to = to
        self.cc = cc
        self.subject = subject
        self.body = body
    }
}

/// Parsed content for meeting-type notes.
struct MeetingParsedContent: Sendable, Equatable {
    let title: String?
    let attendees: [String]
    let date: Date?
    let duration: Int? // minutes
    let agenda: String?
    let notes: String?
    let actionItems: [String]

    init(
        title: String? = nil,
        attendees: [String] = [],
        date: Date? = nil,
        duration: Int? = nil,
        agenda: String? = nil,
        notes: String? = nil,
        actionItems: [String] = []
    ) {
        self.title = title
        self.attendees = attendees
        self.date = date
        self.duration = duration
        self.agenda = agenda
        self.notes = notes
        self.actionItems = actionItems
    }
}

// MARK: - Plugin Metadata

/// Metadata about a plugin for display and management.
struct PluginMetadata: Sendable, Identifiable {
    let id: String
    let name: String
    let version: String
    let author: String
    let description: String
    let isBuiltIn: Bool

    init(
        id: String,
        name: String,
        version: String = "1.0.0",
        author: String = "QuillStack",
        description: String = "",
        isBuiltIn: Bool = true
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.author = author
        self.description = description
        self.isBuiltIn = isBuiltIn
    }
}

// MARK: - Plugin Capability Flags

/// Capabilities that a plugin may support.
struct PluginCapabilities: OptionSet, Sendable {
    let rawValue: Int

    /// Plugin provides custom parsing
    static let parsing = PluginCapabilities(rawValue: 1 << 0)

    /// Plugin provides custom export formatting
    static let exporting = PluginCapabilities(rawValue: 1 << 1)

    /// Plugin provides integration providers
    static let integrations = PluginCapabilities(rawValue: 1 << 2)

    /// Plugin handles lifecycle events
    static let lifecycle = PluginCapabilities(rawValue: 1 << 3)

    /// All capabilities
    static let all: PluginCapabilities = [.parsing, .exporting, .integrations, .lifecycle]
}

extension NoteTypePlugin {
    /// Determine capabilities based on optional protocol implementations.
    var capabilities: PluginCapabilities {
        var caps = PluginCapabilities()

        if parser != nil {
            caps.insert(.parsing)
        }
        if exportFormatter != nil {
            caps.insert(.exporting)
        }
        if !integrationProviders.isEmpty {
            caps.insert(.integrations)
        }

        return caps
    }
}
