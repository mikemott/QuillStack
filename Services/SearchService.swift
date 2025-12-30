//
//  SearchService.swift
//  QuillStack
//
//  Created on 2025-12-18.
//

import Foundation
import CoreData

// MARK: - Search Service

/// Service for searching notes with filters
class SearchService {
    static let shared = SearchService()

    private init() {}

    // MARK: - Search

    /// Search notes with the given filters
    func search(filters: SearchFilters, context: NSManagedObjectContext) -> [Note] {
        let request = NSFetchRequest<Note>(entityName: "Note")
        request.predicate = buildPredicate(from: filters)
        request.sortDescriptors = buildSortDescriptors(for: filters.sortBy)

        do {
            return try context.fetch(request)
        } catch {
            print("Search error: \(error)")
            return []
        }
    }

    /// Count notes matching the filters
    func count(filters: SearchFilters, context: NSManagedObjectContext) -> Int {
        let request = NSFetchRequest<Note>(entityName: "Note")
        request.predicate = buildPredicate(from: filters)

        do {
            return try context.count(for: request)
        } catch {
            return 0
        }
    }

    // MARK: - Predicate Building

    func buildPredicate(from filters: SearchFilters) -> NSPredicate {
        var predicates: [NSPredicate] = []

        // Text search (case and diacritic insensitive)
        if !filters.query.trimmingCharacters(in: .whitespaces).isEmpty {
            predicates.append(NSPredicate(
                format: "content CONTAINS[cd] %@",
                filters.query
            ))
        }

        // Note type filter
        if !filters.noteTypes.isEmpty {
            predicates.append(NSPredicate(
                format: "noteType IN %@",
                Array(filters.noteTypes)
            ))
        }

        // Date range filter
        if let startDate = filters.startDate {
            predicates.append(NSPredicate(
                format: "createdAt >= %@",
                startDate as NSDate
            ))
        }

        if let endDate = filters.endDate {
            // Add one day to include the entire end date
            let adjustedEndDate = Calendar.current.date(byAdding: .day, value: 1, to: endDate) ?? endDate
            predicates.append(NSPredicate(
                format: "createdAt < %@",
                adjustedEndDate as NSDate
            ))
        }

        // Archive filter
        if !filters.includeArchived {
            predicates.append(NSPredicate(format: "isArchived == NO"))
        }

        // If no predicates, return true predicate (match all)
        if predicates.isEmpty {
            return NSPredicate(value: true)
        }

        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }

    private func buildSortDescriptors(for sortOption: SearchSortOption) -> [NSSortDescriptor] {
        switch sortOption {
        case .dateNewest:
            return [NSSortDescriptor(key: "createdAt", ascending: false)]
        case .dateOldest:
            return [NSSortDescriptor(key: "createdAt", ascending: true)]
        case .updatedNewest:
            return [NSSortDescriptor(key: "updatedAt", ascending: false)]
        case .typeAlphabetical:
            return [
                NSSortDescriptor(key: "noteType", ascending: true),
                NSSortDescriptor(key: "createdAt", ascending: false)
            ]
        }
    }
}

// MARK: - Search Models

struct SearchFilters: Equatable {
    var query: String = ""
    var noteTypes: Set<String> = []
    var startDate: Date?
    var endDate: Date?
    var includeArchived: Bool = true
    var sortBy: SearchSortOption = .dateNewest

    var hasActiveFilters: Bool {
        !noteTypes.isEmpty || startDate != nil || endDate != nil || includeArchived
    }

    var activeFilterCount: Int {
        var count = 0
        if !noteTypes.isEmpty { count += 1 }
        if startDate != nil || endDate != nil { count += 1 }
        if includeArchived { count += 1 }
        return count
    }

    static let empty = SearchFilters()
}

enum SearchSortOption: String, CaseIterable, Identifiable {
    case dateNewest = "newest"
    case dateOldest = "oldest"
    case updatedNewest = "updated"
    case typeAlphabetical = "type"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dateNewest: return "Newest First"
        case .dateOldest: return "Oldest First"
        case .updatedNewest: return "Recently Updated"
        case .typeAlphabetical: return "By Type"
        }
    }

    var icon: String {
        switch self {
        case .dateNewest: return "arrow.down"
        case .dateOldest: return "arrow.up"
        case .updatedNewest: return "clock.arrow.circlepath"
        case .typeAlphabetical: return "list.bullet"
        }
    }
}

// MARK: - Search Result Highlighting

extension SearchService {
    /// Find ranges of search query in text for highlighting
    func findMatchRanges(in text: String, for query: String) -> [Range<String.Index>] {
        guard !query.isEmpty else { return [] }

        var ranges: [Range<String.Index>] = []
        var searchRange = text.startIndex..<text.endIndex

        while let range = text.range(of: query, options: [.caseInsensitive, .diacriticInsensitive], range: searchRange) {
            ranges.append(range)
            searchRange = range.upperBound..<text.endIndex
        }

        return ranges
    }

    /// Extract a snippet around the first match
    func extractSnippet(from text: String, for query: String, maxLength: Int = 150) -> String {
        guard !query.isEmpty else {
            return String(text.prefix(maxLength))
        }

        // Find first occurrence
        guard let range = text.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) else {
            return String(text.prefix(maxLength))
        }

        // Calculate snippet boundaries
        let matchStart = text.distance(from: text.startIndex, to: range.lowerBound)
        let contextBefore = 30
        let snippetStart = max(0, matchStart - contextBefore)

        // Get substring
        let startIndex = text.index(text.startIndex, offsetBy: snippetStart)
        let endIndex = text.index(startIndex, offsetBy: min(maxLength, text.distance(from: startIndex, to: text.endIndex)))

        var snippet = String(text[startIndex..<endIndex])

        // Add ellipsis if needed
        if snippetStart > 0 {
            snippet = "..." + snippet
        }
        if endIndex < text.endIndex {
            snippet = snippet + "..."
        }

        return snippet
    }
}
