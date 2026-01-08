//
//  SmartCollectionService.swift
//  QuillStack
//
//  Created on 2026-01-08.
//

import Foundation
import CoreData
import os.log

// MARK: - Smart Collection Service Protocol

protocol SmartCollectionServiceProtocol {
    func createCollection(_ collection: SmartCollection, context: NSManagedObjectContext) throws
    func updateCollection(_ collection: SmartCollection, context: NSManagedObjectContext) throws
    func deleteCollection(_ collection: SmartCollection, context: NSManagedObjectContext) throws
    func getAllCollections(context: NSManagedObjectContext) throws -> [SmartCollection]
    func getPinnedCollections(context: NSManagedObjectContext) throws -> [SmartCollection]

    // Query evaluation
    func evaluateCollection(_ collection: SmartCollection, context: NSManagedObjectContext) throws -> [Note]
    func countMatchingNotes(for collection: SmartCollection, context: NSManagedObjectContext) throws -> Int
    func validateQuery(_ query: CollectionQuery) throws
}

// MARK: - Smart Collection Service Implementation

class SmartCollectionService: SmartCollectionServiceProtocol {
    static let shared = SmartCollectionService()

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "QuillStack", category: "SmartCollection")

    private init() {}

    // MARK: - CRUD Operations

    func createCollection(_ collection: SmartCollection, context: NSManagedObjectContext) throws {
        collection.updatedAt = Date()
        try context.save()
        Self.logger.info("Created collection: \(collection.name)")
    }

    func updateCollection(_ collection: SmartCollection, context: NSManagedObjectContext) throws {
        collection.updatedAt = Date()
        try context.save()
        Self.logger.info("Updated collection: \(collection.name)")
    }

    func deleteCollection(_ collection: SmartCollection, context: NSManagedObjectContext) throws {
        let name = collection.name
        context.delete(collection)
        try context.save()
        Self.logger.info("Deleted collection: \(name)")
    }

    func getAllCollections(context: NSManagedObjectContext) throws -> [SmartCollection] {
        let request = NSFetchRequest<SmartCollection>(entityName: "SmartCollection")
        request.sortDescriptors = [
            NSSortDescriptor(key: "isPinned", ascending: false),
            NSSortDescriptor(key: "order", ascending: true),
            NSSortDescriptor(key: "name", ascending: true)
        ]

        return try context.fetch(request)
    }

    func getPinnedCollections(context: NSManagedObjectContext) throws -> [SmartCollection] {
        let request = NSFetchRequest<SmartCollection>(entityName: "SmartCollection")
        request.predicate = NSPredicate(format: "isPinned == YES")
        request.sortDescriptors = [
            NSSortDescriptor(key: "order", ascending: true),
            NSSortDescriptor(key: "name", ascending: true)
        ]

        return try context.fetch(request)
    }

    // MARK: - Query Evaluation

    func evaluateCollection(_ collection: SmartCollection, context: NSManagedObjectContext) throws -> [Note] {
        guard let query = collection.query else {
            Self.logger.warning("Collection '\(collection.name)' has no query")
            return []
        }

        // Build predicate from query
        let predicate = try buildPredicate(from: query)

        // Create fetch request
        let request = NSFetchRequest<Note>(entityName: "Note")
        request.predicate = predicate

        // Add sort descriptor from collection
        if let sort = collection.sort {
            request.sortDescriptors = [sort.descriptor]
        }

        return try context.fetch(request)
    }

    func countMatchingNotes(for collection: SmartCollection, context: NSManagedObjectContext) throws -> Int {
        guard let query = collection.query else {
            return 0
        }

        let predicate = try buildPredicate(from: query)

        let request = NSFetchRequest<Note>(entityName: "Note")
        request.predicate = predicate

        return try context.count(for: request)
    }

    func validateQuery(_ query: CollectionQuery) throws {
        // Validate that the query is not empty
        guard !query.conditions.isEmpty else {
            throw SmartCollectionError.emptyQuery
        }

        // Validate each condition
        for condition in query.conditions {
            // Check that the value is appropriate for the field/operator combination
            try validateCondition(condition)
        }
    }

    // MARK: - Private Helpers

    private func validateCondition(_ condition: QueryCondition) throws {
        // Ensure value is not empty for most fields
        if condition.value.trimmingCharacters(in: .whitespaces).isEmpty {
            switch condition.field {
            case .hasAttachments, .hasLinks, .isArchived, .hasAnnotations:
                // Boolean fields can have empty values (will be treated as false)
                break
            default:
                throw SmartCollectionError.invalidConditionValue("Value cannot be empty for \(condition.field.displayName)")
            }
        }

        // Validate operator is available for the field
        guard condition.field.availableOperators.contains(condition.operator) else {
            throw SmartCollectionError.invalidOperator("Operator \(condition.operator.displayName) not available for \(condition.field.displayName)")
        }

        // Field-specific validation
        switch condition.field {
        case .confidence, .completionPercentage:
            // Ensure numeric values are valid
            if let value = Double(condition.value) {
                guard value >= 0 && value <= (condition.field == .completionPercentage ? 100 : 1) else {
                    throw SmartCollectionError.invalidConditionValue("Value must be between 0 and \(condition.field == .completionPercentage ? "100" : "1")")
                }
            } else if condition.operator != .inRange {
                throw SmartCollectionError.invalidConditionValue("Value must be a number")
            }

        case .createdDate, .updatedDate:
            // For date fields with inLast operator, ensure value is a number (days)
            if condition.operator == .inLast {
                guard Int(condition.value) != nil else {
                    throw SmartCollectionError.invalidConditionValue("Value must be a number of days")
                }
            }

        default:
            break
        }
    }

    /// Build NSPredicate from CollectionQuery
    private func buildPredicate(from query: CollectionQuery) throws -> NSPredicate {
        guard !query.conditions.isEmpty else {
            // No conditions = match all notes
            return NSPredicate(value: true)
        }

        var predicates: [NSPredicate] = []

        for condition in query.conditions {
            let predicate = try buildPredicate(from: condition)
            predicates.append(predicate)
        }

        // Combine predicates based on logical operator
        switch query.combineWith {
        case .and:
            return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        case .or:
            return NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        }
    }

    /// Build NSPredicate from a single QueryCondition
    private func buildPredicate(from condition: QueryCondition) throws -> NSPredicate {
        let field = condition.field
        let op = condition.operator
        let value = condition.value

        switch field {
        case .noteType:
            return buildNoteTypePredicate(operator: op, value: value)

        case .tag:
            return buildTagPredicate(operator: op, value: value)

        case .createdDate:
            return try buildDatePredicate(keyPath: "createdAt", operator: op, value: value)

        case .updatedDate:
            return try buildDatePredicate(keyPath: "updatedAt", operator: op, value: value)

        case .content:
            return buildContentPredicate(operator: op, value: value)

        case .hasAttachments:
            let hasAttachments = value.lowercased() == "true" || value == "1"
            return NSPredicate(format: "originalImageData != nil") // Has image data
                .boolean(hasAttachments)

        case .confidence:
            return try buildNumericPredicate(keyPath: "ocrConfidence", operator: op, value: value, scale: 1.0)

        case .classificationMethod:
            return buildStringPredicate(keyPath: "classificationMethod", operator: op, value: value)

        case .completionPercentage:
            // This would require calculating from todoItems
            // For now, we'll use a placeholder predicate
            return try buildCompletionPredicate(operator: op, value: value)

        case .hasLinks:
            let hasLinks = value.lowercased() == "true" || value == "1"
            return NSPredicate(format: "outgoingLinks.@count > 0 OR incomingLinks.@count > 0")
                .boolean(hasLinks)

        case .isArchived:
            let isArchived = value.lowercased() == "true" || value == "1"
            return NSPredicate(format: "isArchived == %@", NSNumber(value: isArchived))

        case .hasAnnotations:
            let hasAnnotations = value.lowercased() == "true" || value == "1"
            return NSPredicate(format: "hasAnnotations == %@", NSNumber(value: hasAnnotations))
        }
    }

    // MARK: - Field-Specific Predicate Builders

    private func buildNoteTypePredicate(operator op: QueryOperator, value: String) -> NSPredicate {
        switch op {
        case .equals:
            // Support comma-separated list for multiple types
            let types = value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            if types.count > 1 {
                return NSPredicate(format: "noteType IN %@", types)
            } else {
                return NSPredicate(format: "noteType == %@", value)
            }
        case .notEquals:
            return NSPredicate(format: "noteType != %@", value)
        case .contains:
            return NSPredicate(format: "noteType CONTAINS[cd] %@", value)
        default:
            return NSPredicate(value: false)
        }
    }

    private func buildTagPredicate(operator op: QueryOperator, value: String) -> NSPredicate {
        switch op {
        case .contains:
            return NSPredicate(format: "tags CONTAINS[cd] %@", value)
        case .notContains:
            return NSPredicate(format: "NOT tags CONTAINS[cd] %@", value)
        case .equals:
            return NSPredicate(format: "tags ==[cd] %@", value)
        default:
            return NSPredicate(value: false)
        }
    }

    private func buildDatePredicate(keyPath: String, operator op: QueryOperator, value: String) throws -> NSPredicate {
        switch op {
        case .greaterThan:
            guard let date = parseDate(value) else {
                throw SmartCollectionError.invalidConditionValue("Invalid date format")
            }
            return NSPredicate(format: "%K > %@", keyPath, date as NSDate)

        case .lessThan:
            guard let date = parseDate(value) else {
                throw SmartCollectionError.invalidConditionValue("Invalid date format")
            }
            return NSPredicate(format: "%K < %@", keyPath, date as NSDate)

        case .inLast:
            guard let days = Int(value) else {
                throw SmartCollectionError.invalidConditionValue("Invalid number of days")
            }
            let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            return NSPredicate(format: "%K >= %@", keyPath, startDate as NSDate)

        case .inRange:
            // Expect format: "2024-01-01,2024-12-31"
            let dates = value.split(separator: ",").map(String.init)
            guard dates.count == 2,
                  let startDate = parseDate(dates[0]),
                  let endDate = parseDate(dates[1]) else {
                throw SmartCollectionError.invalidConditionValue("Invalid date range format")
            }
            return NSPredicate(format: "%K >= %@ AND %K <= %@", keyPath, startDate as NSDate, keyPath, endDate as NSDate)

        default:
            return NSPredicate(value: false)
        }
    }

    private func buildContentPredicate(operator op: QueryOperator, value: String) -> NSPredicate {
        switch op {
        case .contains:
            return NSPredicate(format: "content CONTAINS[cd] %@", value)
        case .notContains:
            return NSPredicate(format: "NOT content CONTAINS[cd] %@", value)
        default:
            return NSPredicate(value: false)
        }
    }

    private func buildStringPredicate(keyPath: String, operator op: QueryOperator, value: String) -> NSPredicate {
        switch op {
        case .equals:
            return NSPredicate(format: "%K ==[cd] %@", keyPath, value)
        case .notEquals:
            return NSPredicate(format: "%K !=[cd] %@", keyPath, value)
        case .contains:
            return NSPredicate(format: "%K CONTAINS[cd] %@", keyPath, value)
        case .notContains:
            return NSPredicate(format: "NOT %K CONTAINS[cd] %@", keyPath, value)
        default:
            return NSPredicate(value: false)
        }
    }

    private func buildNumericPredicate(keyPath: String, operator op: QueryOperator, value: String, scale: Double) throws -> NSPredicate {
        switch op {
        case .equals:
            guard let numValue = Double(value) else {
                throw SmartCollectionError.invalidConditionValue("Invalid numeric value")
            }
            return NSPredicate(format: "%K == %f", keyPath, numValue / scale)

        case .greaterThan:
            guard let numValue = Double(value) else {
                throw SmartCollectionError.invalidConditionValue("Invalid numeric value")
            }
            return NSPredicate(format: "%K > %f", keyPath, numValue / scale)

        case .lessThan:
            guard let numValue = Double(value) else {
                throw SmartCollectionError.invalidConditionValue("Invalid numeric value")
            }
            return NSPredicate(format: "%K < %f", keyPath, numValue / scale)

        case .inRange:
            // Expect format: "0.5,0.9"
            let values = value.split(separator: ",").map(String.init)
            guard values.count == 2,
                  let minValue = Double(values[0]),
                  let maxValue = Double(values[1]) else {
                throw SmartCollectionError.invalidConditionValue("Invalid range format")
            }
            return NSPredicate(format: "%K >= %f AND %K <= %f", keyPath, minValue / scale, keyPath, maxValue / scale)

        default:
            return NSPredicate(value: false)
        }
    }

    private func buildCompletionPredicate(operator op: QueryOperator, value: String) throws -> NSPredicate {
        // For now, this is a simplified implementation
        // A full implementation would need to calculate completion from todoItems
        switch op {
        case .equals:
            guard let percentage = Double(value) else {
                throw SmartCollectionError.invalidConditionValue("Invalid percentage value")
            }
            if percentage == 100 {
                // All todos completed
                return NSPredicate(format: "todoItems.@count > 0 AND SUBQUERY(todoItems, $item, $item.isCompleted == NO).@count == 0")
            } else if percentage == 0 {
                // No todos completed
                return NSPredicate(format: "todoItems.@count > 0 AND SUBQUERY(todoItems, $item, $item.isCompleted == YES).@count == 0")
            } else {
                // Partial completion - this is complex, return a placeholder
                return NSPredicate(format: "todoItems.@count > 0")
            }

        case .lessThan:
            guard let percentage = Double(value) else {
                throw SmartCollectionError.invalidConditionValue("Invalid percentage value")
            }
            if percentage == 100 {
                // Has incomplete todos
                return NSPredicate(format: "SUBQUERY(todoItems, $item, $item.isCompleted == NO).@count > 0")
            } else {
                return NSPredicate(format: "todoItems.@count > 0")
            }

        default:
            return NSPredicate(format: "todoItems.@count > 0")
        }
    }

    // MARK: - Helper Methods

    private func parseDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: value) {
            return date
        }

        // Try simple date format
        let simpleDateFormatter = DateFormatter()
        simpleDateFormatter.dateFormat = "yyyy-MM-dd"
        return simpleDateFormatter.date(from: value)
    }
}

// MARK: - NSPredicate Extensions

private extension NSPredicate {
    /// Invert the predicate if the boolean is false
    func boolean(_ value: Bool) -> NSPredicate {
        value ? self : NSCompoundPredicate(notPredicateWithSubpredicate: self)
    }
}

// MARK: - Smart Collection Errors

enum SmartCollectionError: LocalizedError {
    case emptyQuery
    case invalidConditionValue(String)
    case invalidOperator(String)

    var errorDescription: String? {
        switch self {
        case .emptyQuery:
            return "Query must have at least one condition"
        case .invalidConditionValue(let message):
            return message
        case .invalidOperator(let message):
            return message
        }
    }
}
