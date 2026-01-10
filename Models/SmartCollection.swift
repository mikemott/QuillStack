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

        let count = (try? context.count(for: request)) ?? 0
        return count > 0
    }

    /// Fetch notes for a specific collection
    func fetchNotes(for collection: SmartCollection) -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Note")
        request.predicate = collection.predicate
        request.sortDescriptors = collection.sortDescriptors

        return (try? context.fetch(request)) ?? []
    }

    /// Count notes in a collection
    func countNotes(for collection: SmartCollection) -> Int {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Note")
        request.predicate = collection.predicate

        return (try? context.count(for: request)) ?? 0
    }

    // MARK: - Private Helpers

    /// Generate people collections from mentions
    private func generatePeopleCollections() -> [SmartCollection] {
        // Extract people mentions from notes (look for @mentions or common names)
        let request = NSFetchRequest<NSManagedObject>(entityName: "Note")
        request.predicate = NSPredicate(format: "isArchived == NO")

        guard let notes = try? context.fetch(request) else { return [] }

        var peopleSet = Set<String>()
        let mentionPattern = /@(\w+)/

        for note in notes {
            guard let content = note.value(forKey: "content") as? String else { continue }

            // Extract @mentions
            if let regex = try? NSRegularExpression(pattern: mentionPattern) {
                let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))
                for match in matches {
                    if let range = Range(match.range(at: 1), in: content) {
                        let name = String(content[range])
                        peopleSet.insert(name)
                    }
                }
            }
        }

        // Create collections for people with multiple mentions
        var collections: [SmartCollection] = []
        for person in peopleSet {
            let collection = SmartCollection.person(name: person)
            if countNotes(for: collection) > 0 {
                collections.append(collection)
            }
        }

        // Sort by note count (descending)
        return collections.sorted { collection1, collection2 in
            countNotes(for: collection1) > countNotes(for: collection2)
        }
    }

    /// Generate tag collections from tag entities
    private func generateTagCollections() -> [SmartCollection] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Tag")
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

        guard let tags = try? context.fetch(request) else { return [] }

        // Filter to tags with notes and create collections
        let collections = tags.compactMap { tag -> SmartCollection? in
            guard let id = tag.value(forKey: "id") as? UUID,
                  let name = tag.value(forKey: "name") as? String,
                  let notes = tag.value(forKey: "notes") as? Set<NSManagedObject>,
                  !notes.isEmpty else {
                return nil
            }
            return SmartCollection.tagCollection(id: id, name: name)
        }
        .filter { countNotes(for: $0) > 0 }

        // Sort by note count (descending)
        return collections.sorted { collection1, collection2 in
            countNotes(for: collection1) > countNotes(for: collection2)
        }
    }
}
