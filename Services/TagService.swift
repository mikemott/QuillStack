//
//  TagService.swift
//  QuillStack
//
//  QUI-157: Service for managing tags and providing vocabulary for LLM suggestions
//

import Foundation
import CoreData
import SwiftUI

/// Service for managing tags and tag suggestions
@MainActor
final class TagService {
    static let shared = TagService()

    private init() {}

    // MARK: - Tag Fetching

    /// Fetch all existing tag names sorted by usage frequency (most used first)
    func getAllTagNames(context: NSManagedObjectContext = CoreDataStack.shared.persistentContainer.viewContext) async -> [String] {
        return await context.perform {
            let request = Tag.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \Tag.createdAt, ascending: false)]

            guard let tags = try? context.fetch(request) else {
                return []
            }

            // Sort by usage count (number of notes)
            return tags
                .sorted { $0.noteCount > $1.noteCount }
                .map { $0.name }
        }
    }

    /// Fetch top N most frequently used tags
    func getTopTags(limit: Int = 20, context: NSManagedObjectContext = CoreDataStack.shared.persistentContainer.viewContext) async -> [String] {
        let allTags = await getAllTagNames(context: context)
        return Array(allTags.prefix(limit))
    }

    /// Get tag statistics for LLM context
    func getTagStats(context: NSManagedObjectContext = CoreDataStack.shared.persistentContainer.viewContext) async -> TagStats {
        return await context.perform {
            let request = Tag.fetchRequest()
            guard let tags = try? context.fetch(request) else {
                return TagStats(totalTags: 0, totalNoteCount: 0, averageUsage: 0)
            }

            let totalTags = tags.count
            let totalNoteCount = tags.reduce(0) { $0 + $1.noteCount }
            let averageUsage = totalTags > 0 ? Double(totalNoteCount) / Double(totalTags) : 0

            return TagStats(
                totalTags: totalTags,
                totalNoteCount: totalNoteCount,
                averageUsage: averageUsage
            )
        }
    }

    // MARK: - Tag Application

    /// Apply suggested tags to a note
    func applyTags(_ tagNames: [String], to note: Note, in context: NSManagedObjectContext) {
        context.perform {
            for tagName in tagNames {
                note.addTagEntity(named: tagName, in: context)
            }
        }
    }

    /// Format existing tags for LLM prompt
    func formatTagsForPrompt(_ tagNames: [String]) -> String {
        guard !tagNames.isEmpty else {
            return "No existing tags in the system yet."
        }

        return """
        Existing tags in the system (prefer these spellings):
        \(tagNames.map { "• \($0)" }.joined(separator: "\n"))
        """
    }
}

// MARK: - Supporting Types

struct TagStats {
    let totalTags: Int
    let totalNoteCount: Int
    let averageUsage: Double
}

/// Result from tag suggestion
struct TagSuggestion: Codable {
    let primaryTag: String
    let secondaryTags: [String]
    let confidence: Double

    var allTags: [String] {
        [primaryTag] + secondaryTags
    }
}
