//
//  SystemCollections.swift
//  QuillStack
//
//  Created on 2026-01-08.
//

import Foundation
import CoreData

/// Pre-built system collections with common queries
struct SystemCollections {
    /// All notes collection (no filtering)
    static func allNotes(context: NSManagedObjectContext) -> SmartCollection {
        SmartCollection.create(
            in: context,
            name: "All Notes",
            query: CollectionQuery(conditions: [], combineWith: .and),
            icon: "square.grid.2x2",
            color: "#4A90E2",
            sortOrder: .updatedNewest
        )
    }

    /// Notes created in the last 7 days
    static func thisWeek(context: NSManagedObjectContext) -> SmartCollection {
        SmartCollection.create(
            in: context,
            name: "This Week",
            query: CollectionQuery(
                conditions: [
                    QueryCondition(
                        field: .createdDate,
                        operator: .inLast,
                        value: "7"
                    )
                ],
                combineWith: .and
            ),
            icon: "calendar",
            color: "#50C878",
            sortOrder: .dateNewest
        )
    }

    /// Incomplete todo items
    static func actionItems(context: NSManagedObjectContext) -> SmartCollection {
        SmartCollection.create(
            in: context,
            name: "Action Items",
            query: CollectionQuery(
                conditions: [
                    QueryCondition(
                        field: .noteType,
                        operator: .equals,
                        value: "todo"
                    ),
                    QueryCondition(
                        field: .completionPercentage,
                        operator: .lessThan,
                        value: "100"
                    )
                ],
                combineWith: .and
            ),
            icon: "checklist",
            color: "#FF6B6B",
            sortOrder: .updatedNewest
        )
    }

    /// Notes with low OCR confidence that may need review
    static func needsReview(context: NSManagedObjectContext) -> SmartCollection {
        SmartCollection.create(
            in: context,
            name: "Needs Review",
            query: CollectionQuery(
                conditions: [
                    QueryCondition(
                        field: .confidence,
                        operator: .lessThan,
                        value: "0.8"
                    )
                ],
                combineWith: .and
            ),
            icon: "exclamationmark.triangle",
            color: "#FFA500",
            sortOrder: .confidenceLowest
        )
    }

    /// Meeting notes with action items
    static func meetingFollowUps(context: NSManagedObjectContext) -> SmartCollection {
        SmartCollection.create(
            in: context,
            name: "Meeting Follow-Ups",
            query: CollectionQuery(
                conditions: [
                    QueryCondition(
                        field: .noteType,
                        operator: .equals,
                        value: "meeting"
                    ),
                    QueryCondition(
                        field: .updatedDate,
                        operator: .inLast,
                        value: "14"
                    )
                ],
                combineWith: .and
            ),
            icon: "person.2",
            color: "#9B59B6",
            sortOrder: .updatedNewest
        )
    }

    /// Notes with cross-note links
    static func linkedNotes(context: NSManagedObjectContext) -> SmartCollection {
        SmartCollection.create(
            in: context,
            name: "Linked Notes",
            query: CollectionQuery(
                conditions: [
                    QueryCondition(
                        field: .hasLinks,
                        operator: .equals,
                        value: "true"
                    )
                ],
                combineWith: .and
            ),
            icon: "link",
            color: "#3498DB",
            sortOrder: .updatedNewest
        )
    }

    /// Notes with handwritten annotations
    static func annotatedNotes(context: NSManagedObjectContext) -> SmartCollection {
        SmartCollection.create(
            in: context,
            name: "Annotated Notes",
            query: CollectionQuery(
                conditions: [
                    QueryCondition(
                        field: .hasAnnotations,
                        operator: .equals,
                        value: "true"
                    )
                ],
                combineWith: .and
            ),
            icon: "pencil.tip.crop.circle",
            color: "#E74C3C",
            sortOrder: .updatedNewest
        )
    }

    /// Recently updated notes
    static func recentlyUpdated(context: NSManagedObjectContext) -> SmartCollection {
        SmartCollection.create(
            in: context,
            name: "Recently Updated",
            query: CollectionQuery(
                conditions: [
                    QueryCondition(
                        field: .updatedDate,
                        operator: .inLast,
                        value: "3"
                    )
                ],
                combineWith: .and
            ),
            icon: "clock.arrow.circlepath",
            color: "#1ABC9C",
            sortOrder: .updatedNewest
        )
    }

    /// All system collections
    static func all(context: NSManagedObjectContext) -> [SmartCollection] {
        return [
            allNotes(context: context),
            thisWeek(context: context),
            actionItems(context: context),
            needsReview(context: context),
            meetingFollowUps(context: context),
            linkedNotes(context: context),
            annotatedNotes(context: context),
            recentlyUpdated(context: context)
        ]
    }

    /// Create all system collections in the database
    static func createSystemCollections(context: NSManagedObjectContext) throws {
        let collections = all(context: context)

        // Set order for each collection
        for (index, collection) in collections.enumerated() {
            collection.order = Int32(index)
        }

        try context.save()
    }

    /// Check if system collections exist, create them if not
    static func ensureSystemCollectionsExist(context: NSManagedObjectContext) throws {
        let request = NSFetchRequest<SmartCollection>(entityName: "SmartCollection")
        let existingCount = try context.count(for: request)

        if existingCount == 0 {
            try createSystemCollections(context: context)
        }
    }
}
