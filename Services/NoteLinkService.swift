//
//  NoteLinkService.swift
//  QuillStack
//
//  Created on 2026-01-06.
//  QUI-136: Cross-Note Linking & Knowledge Graph
//

import Foundation
import CoreData
import os.log

/// Errors that can occur during note linking operations
enum NoteLinkError: Error, LocalizedError {
    case selfLink
    case duplicateLink
    case cycleDetected
    case noteNotFound
    case invalidLink

    var errorDescription: String? {
        switch self {
        case .selfLink:
            return "A note cannot link to itself"
        case .duplicateLink:
            return "This link already exists"
        case .cycleDetected:
            return "This link would create a cycle in parent-child relationships"
        case .noteNotFound:
            return "One or both notes could not be found"
        case .invalidLink:
            return "The link is invalid or malformed"
        }
    }
}

/// Service for managing relationships between notes
final class NoteLinkService: @unchecked Sendable {
    static let shared = NoteLinkService()

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "QuillStack",
        category: "NoteLinks"
    )

    private init() {}

    // MARK: - Link Creation

    /// Creates a link from one note to another
    /// - Parameters:
    ///   - source: The note to link from
    ///   - target: The note to link to
    ///   - type: The type of relationship
    ///   - label: Optional custom label for the link
    ///   - context: The managed object context to use
    /// - Returns: The created link
    /// - Throws: NoteLinkError if validation fails
    func createLink(
        from source: Note,
        to target: Note,
        type: LinkType = .reference,
        label: String? = nil,
        in context: NSManagedObjectContext
    ) throws -> NoteLink {
        // Validate the link
        try validateLink(from: source, to: target, type: type, in: context)

        // Check for duplicate
        if linkExists(from: source, to: target, type: type, in: context) {
            throw NoteLinkError.duplicateLink
        }

        // Create the link
        let link = NoteLink.create(in: context, from: source, to: target, type: type, label: label)

        Self.logger.info("Created \(type.rawValue) link from note \(source.id) to \(target.id)")

        return link
    }

    /// Creates multiple links at once
    /// - Parameters:
    ///   - source: The note to link from
    ///   - targets: Array of target notes
    ///   - type: The type of relationship
    ///   - context: The managed object context to use
    /// - Returns: Array of created links
    func createLinks(
        from source: Note,
        to targets: [Note],
        type: LinkType = .reference,
        in context: NSManagedObjectContext
    ) throws -> [NoteLink] {
        var createdLinks: [NoteLink] = []

        for target in targets {
            do {
                let link = try createLink(from: source, to: target, type: type, in: context)
                createdLinks.append(link)
            } catch NoteLinkError.duplicateLink {
                // Skip duplicates - this is expected behavior for idempotent operations
                Self.logger.debug("Skipped duplicate \(type.rawValue) link from note \(source.id) to \(target.id)")
                continue
            } catch {
                // Re-throw other errors
                throw error
            }
        }

        return createdLinks
    }

    // MARK: - Link Deletion

    /// Deletes a specific link
    /// - Parameters:
    ///   - link: The link to delete
    ///   - context: The managed object context to use
    func deleteLink(_ link: NoteLink, in context: NSManagedObjectContext) {
        Self.logger.info("Deleting link \(link.id)")
        context.delete(link)
    }

    /// Deletes all links between two notes
    /// - Parameters:
    ///   - source: The source note
    ///   - target: The target note
    ///   - context: The managed object context to use
    func deleteAllLinks(from source: Note, to target: Note, in context: NSManagedObjectContext) {
        let links = getLinks(from: source, to: target, in: context)
        links.forEach { context.delete($0) }
        Self.logger.info("Deleted \(links.count) links from \(source.id) to \(target.id)")
    }

    /// Deletes all links for a note (both incoming and outgoing)
    /// - Parameters:
    ///   - note: The note whose links to delete
    ///   - context: The managed object context to use
    func deleteAllLinks(for note: Note, in context: NSManagedObjectContext) {
        let outgoing = note.typedOutgoingLinks
        let incoming = note.typedIncomingLinks

        outgoing.forEach { context.delete($0) }
        incoming.forEach { context.delete($0) }

        Self.logger.info("Deleted \(outgoing.count + incoming.count) links for note \(note.id)")
    }

    // MARK: - Link Queries

    /// Get all links from a note
    /// - Parameters:
    ///   - note: The source note
    ///   - context: The managed object context to use
    /// - Returns: Array of outgoing links
    func getLinks(from note: Note, in context: NSManagedObjectContext) -> [NoteLink] {
        return note.typedOutgoingLinks
    }

    /// Get all links to a note (backlinks)
    /// - Parameters:
    ///   - note: The target note
    ///   - context: The managed object context to use
    /// - Returns: Array of incoming links
    func getBacklinks(for note: Note, in context: NSManagedObjectContext) -> [NoteLink] {
        return note.typedIncomingLinks
    }

    /// Get all links between two specific notes
    /// - Parameters:
    ///   - source: The source note
    ///   - target: The target note
    ///   - context: The managed object context to use
    /// - Returns: Array of links from source to target
    func getLinks(from source: Note, to target: Note, in context: NSManagedObjectContext) -> [NoteLink] {
        return source.typedOutgoingLinks.filter { $0.targetNote.id == target.id }
    }

    /// Get all notes linked from a note
    /// - Parameters:
    ///   - note: The source note
    ///   - context: The managed object context to use
    /// - Returns: Array of linked notes
    func getLinkedNotes(from note: Note, in context: NSManagedObjectContext) -> [Note] {
        return note.forwardLinks
    }

    /// Get all notes that link to a note
    /// - Parameters:
    ///   - note: The target note
    ///   - context: The managed object context to use
    /// - Returns: Array of notes that link to this note
    func getBacklinkNotes(for note: Note, in context: NSManagedObjectContext) -> [Note] {
        return note.backlinks
    }

    // MARK: - Validation

    /// Validates that a link can be created
    /// - Parameters:
    ///   - source: The source note
    ///   - target: The target note
    ///   - type: The link type
    ///   - context: The managed object context
    /// - Throws: NoteLinkError if validation fails
    func validateLink(
        from source: Note,
        to target: Note,
        type: LinkType,
        in context: NSManagedObjectContext
    ) throws {
        // Prevent self-links
        if source.id == target.id {
            throw NoteLinkError.selfLink
        }

        // For parent/child relationships, check for cycles
        if type == .parent || type == .child {
            if wouldCreateCycle(from: source, to: target, type: type, in: context) {
                throw NoteLinkError.cycleDetected
            }
        }
    }

    /// Checks if a link already exists
    /// - Parameters:
    ///   - source: The source note
    ///   - target: The target note
    ///   - type: The link type
    ///   - context: The managed object context
    /// - Returns: True if the link exists
    func linkExists(
        from source: Note,
        to target: Note,
        type: LinkType,
        in context: NSManagedObjectContext
    ) -> Bool {
        let existingLinks = getLinks(from: source, to: target, in: context)
        return existingLinks.contains { $0.type == type }
    }

    // MARK: - Cycle Detection

    /// Checks if creating a link would create a cycle in parent-child relationships
    /// - Parameters:
    ///   - source: The source note
    ///   - target: The target note
    ///   - type: The link type
    ///   - context: The managed object context
    /// - Returns: True if a cycle would be created
    private func wouldCreateCycle(
        from source: Note,
        to target: Note,
        type: LinkType,
        in context: NSManagedObjectContext
    ) -> Bool {
        // Only check for parent/child relationships
        guard type == .parent || type == .child else { return false }

        // If we're creating a parent link from A to B, check if B is already
        // an ancestor of A (which would create a cycle)
        if type == .parent {
            return isAncestor(target, of: source, in: context)
        }

        // If we're creating a child link from A to B, check if B is already
        // a descendant of A (which would create a cycle)
        if type == .child {
            return isDescendant(target, of: source, in: context)
        }

        return false
    }

    /// Check if a note is an ancestor of another note
    private func isAncestor(_ potentialAncestor: Note, of note: Note, in context: NSManagedObjectContext) -> Bool {
        var visited = Set<UUID>()
        var current = note

        while true {
            visited.insert(current.id)

            // Get parent links
            let parentLinks = current.typedOutgoingLinks.filter { $0.type == .parent }

            guard let parentLink = parentLinks.first else {
                // No more parents
                return false
            }

            let parent = parentLink.targetNote

            if parent.id == potentialAncestor.id {
                return true
            }

            if visited.contains(parent.id) {
                // Cycle detected in existing data
                return false
            }

            current = parent
        }
    }

    /// Check if a note is a descendant of another note
    private func isDescendant(_ potentialDescendant: Note, of note: Note, in context: NSManagedObjectContext) -> Bool {
        var visited = Set<UUID>()
        var toVisit: [Note] = [note]

        while !toVisit.isEmpty {
            let current = toVisit.removeFirst()

            if visited.contains(current.id) {
                continue
            }

            visited.insert(current.id)

            // Get child links
            let childLinks = current.typedOutgoingLinks.filter { $0.type == .child }

            for link in childLinks {
                let child = link.targetNote

                if child.id == potentialDescendant.id {
                    return true
                }

                if !visited.contains(child.id) {
                    toVisit.append(child)
                }
            }
        }

        return false
    }

    // MARK: - Statistics

    /// Get link statistics for a note
    /// - Parameters:
    ///   - note: The note to analyze
    ///   - context: The managed object context
    /// - Returns: Dictionary of link type counts
    func getLinkStatistics(for note: Note, in context: NSManagedObjectContext) -> [LinkType: Int] {
        var stats: [LinkType: Int] = [:]

        let allLinks = note.typedOutgoingLinks + note.typedIncomingLinks

        for link in allLinks {
            stats[link.type, default: 0] += 1
        }

        return stats
    }
}
