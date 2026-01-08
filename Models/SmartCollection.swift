//
//  SmartCollection.swift
//  QuillStack
//
//  Created on 2026-01-08.
//

import Foundation
import CoreData

@objc(SmartCollection)
public class SmartCollection: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var icon: String? // SF Symbol name
    @NSManaged public var color: String? // Hex color
    @NSManaged public var queryData: Data // Encoded CollectionQuery
    @NSManaged public var sortOrder: String // Encoded SortOrder
    @NSManaged public var isPinned: Bool
    @NSManaged public var order: Int32 // Display order
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date

    /// Decoded query for evaluation
    var query: CollectionQuery? {
        get {
            guard !queryData.isEmpty else { return nil }
            return try? JSONDecoder().decode(CollectionQuery.self, from: queryData)
        }
        set {
            queryData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    /// Decoded sort order
    var sort: CollectionSortOrder? {
        get {
            return CollectionSortOrder(rawValue: sortOrder)
        }
        set {
            sortOrder = newValue?.rawValue ?? CollectionSortOrder.updatedNewest.rawValue
        }
    }

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date()
        updatedAt = Date()
        isPinned = false
        order = 0
        sortOrder = CollectionSortOrder.updatedNewest.rawValue
        queryData = Data()
    }
}

// MARK: - Convenience Initializer
extension SmartCollection {
    static func create(
        in context: NSManagedObjectContext,
        name: String,
        query: CollectionQuery,
        icon: String? = nil,
        color: String? = nil,
        sortOrder: CollectionSortOrder = .updatedNewest
    ) -> SmartCollection {
        let collection = SmartCollection(context: context)
        collection.name = name
        collection.query = query
        collection.icon = icon
        collection.color = color
        collection.sort = sortOrder
        return collection
    }
}
