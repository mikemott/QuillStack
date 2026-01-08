//
//  CollectionQuery.swift
//  QuillStack
//
//  Created on 2026-01-08.
//

import Foundation

// MARK: - Collection Query Models

/// A query defining which notes match a smart collection
struct CollectionQuery: Codable, Equatable {
    var conditions: [QueryCondition]
    var combineWith: LogicalOperator

    init(conditions: [QueryCondition] = [], combineWith: LogicalOperator = .and) {
        self.conditions = conditions
        self.combineWith = combineWith
    }

    /// Returns true if the query is empty (no conditions)
    var isEmpty: Bool {
        conditions.isEmpty
    }
}

/// Logical operator for combining multiple conditions
enum LogicalOperator: String, Codable, CaseIterable {
    case and
    case or

    var displayName: String {
        switch self {
        case .and: return "Match ALL"
        case .or: return "Match ANY"
        }
    }
}

/// A single query condition
struct QueryCondition: Codable, Equatable, Identifiable {
    let id: UUID
    var field: QueryField
    var `operator`: QueryOperator
    var value: String

    init(id: UUID = UUID(), field: QueryField, operator: QueryOperator, value: String) {
        self.id = id
        self.field = field
        self.operator = `operator`
        self.value = value
    }
}

/// Fields that can be queried
enum QueryField: String, Codable, CaseIterable {
    case noteType
    case tag
    case createdDate
    case updatedDate
    case content
    case hasAttachments
    case confidence
    case classificationMethod
    case completionPercentage
    case hasLinks
    case isArchived
    case hasAnnotations

    var displayName: String {
        switch self {
        case .noteType: return "Note Type"
        case .tag: return "Tag"
        case .createdDate: return "Created Date"
        case .updatedDate: return "Updated Date"
        case .content: return "Content"
        case .hasAttachments: return "Has Attachments"
        case .confidence: return "OCR Confidence"
        case .classificationMethod: return "Classification Method"
        case .completionPercentage: return "Completion %"
        case .hasLinks: return "Has Links"
        case .isArchived: return "Is Archived"
        case .hasAnnotations: return "Has Annotations"
        }
    }

    /// Available operators for this field type
    var availableOperators: [QueryOperator] {
        switch self {
        case .noteType, .tag, .classificationMethod:
            return [.equals, .notEquals, .contains]
        case .createdDate, .updatedDate:
            return [.greaterThan, .lessThan, .inRange, .inLast]
        case .content:
            return [.contains, .notContains]
        case .hasAttachments, .hasLinks, .isArchived, .hasAnnotations:
            return [.equals]
        case .confidence, .completionPercentage:
            return [.equals, .greaterThan, .lessThan, .inRange]
        }
    }

    /// The type of input expected for this field
    var inputType: QueryInputType {
        switch self {
        case .noteType:
            return .multiSelect(NoteType.allCases.map { $0.rawValue })
        case .tag:
            return .text
        case .createdDate, .updatedDate:
            return .date
        case .content, .classificationMethod:
            return .text
        case .hasAttachments, .hasLinks, .isArchived, .hasAnnotations:
            return .boolean
        case .confidence, .completionPercentage:
            return .number
        }
    }
}

/// Query operators
enum QueryOperator: String, Codable, CaseIterable {
    case equals
    case notEquals
    case contains
    case notContains
    case greaterThan
    case lessThan
    case inRange
    case inLast // "in last N days"

    var displayName: String {
        switch self {
        case .equals: return "is"
        case .notEquals: return "is not"
        case .contains: return "contains"
        case .notContains: return "does not contain"
        case .greaterThan: return "greater than"
        case .lessThan: return "less than"
        case .inRange: return "in range"
        case .inLast: return "in last"
        }
    }

    var symbol: String {
        switch self {
        case .equals: return "="
        case .notEquals: return "≠"
        case .contains: return "⊃"
        case .notContains: return "⊅"
        case .greaterThan: return ">"
        case .lessThan: return "<"
        case .inRange: return "↔"
        case .inLast: return "↻"
        }
    }
}

/// Type of input needed for a query field
enum QueryInputType {
    case text
    case number
    case date
    case boolean
    case multiSelect([String]) // Available options
}

// MARK: - Collection Sort Order

/// Sort order for collection results
enum CollectionSortOrder: String, Codable, CaseIterable {
    case dateNewest
    case dateOldest
    case updatedNewest
    case updatedOldest
    case typeAlphabetical
    case confidenceLowest
    case confidenceHighest

    var displayName: String {
        switch self {
        case .dateNewest: return "Newest First"
        case .dateOldest: return "Oldest First"
        case .updatedNewest: return "Recently Updated"
        case .updatedOldest: return "Least Recently Updated"
        case .typeAlphabetical: return "By Type"
        case .confidenceLowest: return "Lowest Confidence"
        case .confidenceHighest: return "Highest Confidence"
        }
    }

    var icon: String {
        switch self {
        case .dateNewest: return "arrow.down"
        case .dateOldest: return "arrow.up"
        case .updatedNewest: return "clock.arrow.circlepath"
        case .updatedOldest: return "clock"
        case .typeAlphabetical: return "list.bullet"
        case .confidenceLowest: return "chart.bar.fill"
        case .confidenceHighest: return "chart.bar.fill"
        }
    }

    /// Convert to NSSortDescriptor
    var descriptor: NSSortDescriptor {
        switch self {
        case .dateNewest:
            return NSSortDescriptor(key: "createdAt", ascending: false)
        case .dateOldest:
            return NSSortDescriptor(key: "createdAt", ascending: true)
        case .updatedNewest:
            return NSSortDescriptor(key: "updatedAt", ascending: false)
        case .updatedOldest:
            return NSSortDescriptor(key: "updatedAt", ascending: true)
        case .typeAlphabetical:
            return NSSortDescriptor(key: "noteType", ascending: true)
        case .confidenceLowest:
            return NSSortDescriptor(key: "ocrConfidence", ascending: true)
        case .confidenceHighest:
            return NSSortDescriptor(key: "ocrConfidence", ascending: false)
        }
    }
}

// MARK: - Note Types Enum

/// All available note types for filtering
enum NoteType: String, CaseIterable {
    case general
    case todo
    case meeting
    case email
    case recipe
    case businessCard
    case document
    case expense
    case invoice
    case form
    case sketch
    case brainstorm

    var displayName: String {
        switch self {
        case .general: return "General"
        case .todo: return "To-Do"
        case .meeting: return "Meeting"
        case .email: return "Email"
        case .recipe: return "Recipe"
        case .businessCard: return "Business Card"
        case .document: return "Document"
        case .expense: return "Expense"
        case .invoice: return "Invoice"
        case .form: return "Form"
        case .sketch: return "Sketch"
        case .brainstorm: return "Brainstorm"
        }
    }
}
