//
//  SmartCollection.swift
//  QuillStack
//
//  Created on 2026-01-09.
//

import Foundation
import CoreData

/// Represents a smart collection for auto-organizing notes
struct SmartCollection: Identifiable, Hashable {
    let id: String
    let title: String
    let icon: String
    let predicate: NSPredicate
    let sortDescriptors: [NSSortDescriptor]
    let defaultExpanded: Bool

    init(
        id: String,
        title: String,
        icon: String,
        predicate: NSPredicate,
        sortDescriptors: [NSSortDescriptor],
        defaultExpanded: Bool = false
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.predicate = predicate
        self.sortDescriptors = sortDescriptors
        self.defaultExpanded = defaultExpanded
    }

    // Hashable conformance for use in Set
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: SmartCollection, rhs: SmartCollection) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Predefined Collections

extension SmartCollection {
    /// Recent notes (last 7 days)
    static var recent: SmartCollection {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return SmartCollection(
            id: "recent",
            title: "Recent (Last 7 Days)",
            icon: "clock",
            predicate: NSPredicate(format: "createdAt >= %@ AND isArchived == NO", sevenDaysAgo as NSDate),
            sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: false)],
            defaultExpanded: true
        )
    }

    /// Archive collection (completed/old notes)
    static var archive: SmartCollection {
        SmartCollection(
            id: "archive",
            title: "Archive",
            icon: "archivebox",
            predicate: NSPredicate(format: "isArchived == YES"),
            sortDescriptors: [NSSortDescriptor(key: "updatedAt", ascending: false)],
            defaultExpanded: false
        )
    }

    /// Notes with links (related notes)
    static var related: SmartCollection {
        SmartCollection(
            id: "related",
            title: "Related",
            icon: "link",
            predicate: NSPredicate(format: "(outgoingLinks.@count > 0 OR incomingLinks.@count > 0) AND isArchived == NO"),
            sortDescriptors: [NSSortDescriptor(key: "updatedAt", ascending: false)],
            defaultExpanded: false
        )
    }

    /// Create a collection for a specific tag
    static func tagCollection(id: UUID, name: String) -> SmartCollection {
        SmartCollection(
            id: "tag-\(id.uuidString)",
            title: name,
            icon: "tag",
            predicate: NSPredicate(format: "ANY tagEntities.id == %@ AND isArchived == NO", id as CVarArg),
            sortDescriptors: [NSSortDescriptor(key: "updatedAt", ascending: false)],
            defaultExpanded: false
        )
    }

    /// Create a collection for notes mentioning a person
    static func person(name: String) -> SmartCollection {
        SmartCollection(
            id: "person-\(name)",
            title: name,
            icon: "person",
            predicate: NSPredicate(format: "content CONTAINS[cd] %@ AND isArchived == NO", name),
            sortDescriptors: [NSSortDescriptor(key: "updatedAt", ascending: false)],
            defaultExpanded: false
        )
    }
}

// MARK: - Collection Generator

/// Generates smart collections from notes
@MainActor
class SmartCollectionGenerator {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    /// Generate all collections, hiding empty ones
    func generateCollections() -> [SmartCollection] {
        var collections: [SmartCollection] = []

        // Always show Recent (even if empty)
        collections.append(.recent)

        // Add People collections (auto-detected from mentions)
        let peopleCollections = generatePeopleCollections()
        collections.append(contentsOf: peopleCollections)

        // Add Tag collections (grouped by tag)
        let tagCollections = generateTagCollections()
        collections.append(contentsOf: tagCollections)

        // Add Related collection (only if has notes)
        if hasNotesForCollection(.related) {
            collections.append(.related)
        }

        // Always show Archive at the end
        collections.append(.archive)

        return collections
    }

    /// Check if a collection has notes
    func hasNotesForCollection(_ collection: SmartCollection) -> Bool {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Note")
        request.predicate = collection.predicate
        request.fetchLimit = 1

        do {
            let count = try context.count(for: request)
            return count > 0
        } catch {
            print("⚠️ SmartCollection: Failed to count notes for collection '\(collection.id)': \(error)")
            return false
        }
    }

    /// Fetch notes for a specific collection
    func fetchNotes(for collection: SmartCollection) -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Note")
        request.predicate = collection.predicate
        request.sortDescriptors = collection.sortDescriptors

        do {
            return try context.fetch(request)
        } catch {
            print("⚠️ SmartCollection: Failed to fetch notes for collection '\(collection.id)': \(error)")
            return []
        }
    }

    /// Count notes in a collection
    func countNotes(for collection: SmartCollection) -> Int {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Note")
        request.predicate = collection.predicate

        do {
            return try context.count(for: request)
        } catch {
            print("⚠️ SmartCollection: Failed to count notes for collection '\(collection.id)': \(error)")
            return 0
        }
    }

    // MARK: - Private Helpers

    /// Generate people collections from mentions
    private func generatePeopleCollections() -> [SmartCollection] {
        // Extract people mentions from notes (look for @mentions or common names)
        let request = NSFetchRequest<NSManagedObject>(entityName: "Note")
        request.predicate = NSPredicate(format: "isArchived == NO")

        guard let notes = try? context.fetch(request) else {
            print("⚠️ SmartCollection: Failed to fetch notes for people collection generation")
            return []
        }

        var peopleSet = Set<String>()
        let mentionPattern = /@(\w+)/

        for note in notes {
            guard let content = note.value(forKey: "content") as? String else { continue }

            // Extract @mentions using modern Swift regex API
            for match in content.matches(of: mentionPattern) {
                let (_, nameSubstring) = match.output
                peopleSet.insert(String(nameSubstring))
            }
        }

        // Create collections for people with multiple mentions and pre-calculate counts
        let collectionsWithCounts = peopleSet.compactMap { person -> (collection: SmartCollection, count: Int)? in
            let collection = SmartCollection.person(name: person)
            let count = countNotes(for: collection)
            return count > 0 ? (collection, count) : nil
        }

        // Sort by note count (descending)
        return collectionsWithCounts
            .sorted { $0.count > $1.count }
            .map { $0.collection }
    }

    /// Generate tag collections from tag entities
    private func generateTagCollections() -> [SmartCollection] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Tag")
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

        guard let tags = try? context.fetch(request) else {
            print("⚠️ SmartCollection: Failed to fetch tags for collection generation")
            return []
        }

        // Filter to tags with notes and create collections with pre-calculated counts
        let collectionsWithCounts = tags.compactMap { tag -> (collection: SmartCollection, count: Int)? in
            guard let id = tag.value(forKey: "id") as? UUID,
                  let name = tag.value(forKey: "name") as? String,
                  let notes = tag.value(forKey: "notes") as? Set<NSManagedObject>,
                  !notes.isEmpty else {
                return nil
            }
            let collection = SmartCollection.tagCollection(id: id, name: name)
            let count = countNotes(for: collection)
            return count > 0 ? (collection, count) : nil
        }

        // Sort by note count (descending)
        return collectionsWithCounts
            .sorted { $0.count > $1.count }
            .map { $0.collection }
    }
}
