//
//  SearchViewModel.swift
//  QuillStack
//
//  Created on 2025-12-18.
//

import Foundation
import CoreData
import Combine

// MARK: - Search View Model

@MainActor
@Observable
final class SearchViewModel {
    // MARK: - Published Properties

    var searchText: String = ""
    var filters = SearchFilters()
    var results: [Note] = []
    var isSearching = false
    var hasSearched = false

    // MARK: - Private Properties

    private var searchTask: Task<Void, Never>?
    private let debounceDelay: UInt64 = 300_000_000 // 300ms in nanoseconds
    private let context: NSManagedObjectContext

    // MARK: - Computed Properties

    var resultCount: Int {
        results.count
    }

    var hasResults: Bool {
        !results.isEmpty
    }

    var showEmptyState: Bool {
        hasSearched && results.isEmpty
    }

    var isFilterActive: Bool {
        filters.hasActiveFilters || !filters.noteTypes.isEmpty
    }

    // MARK: - Initialization

    init(context: NSManagedObjectContext? = nil) {
        self.context = context ?? CoreDataStack.shared.persistentContainer.viewContext
    }

    // MARK: - Search Actions

    /// Perform search with debouncing
    func performSearch() {
        // Cancel previous search task
        searchTask?.cancel()

        // Create new debounced search task
        searchTask = Task {
            // Wait for debounce delay
            try? await Task.sleep(nanoseconds: debounceDelay)

            // Check if cancelled
            guard !Task.isCancelled else { return }

            await executeSearch()
        }
    }

    /// Execute search immediately without debouncing
    func executeSearchImmediately() {
        searchTask?.cancel()
        Task {
            await executeSearch()
        }
    }

    /// Clear search and results
    func clearSearch() {
        searchTask?.cancel()
        searchText = ""
        filters = SearchFilters()
        results = []
        hasSearched = false
    }

    /// Clear only the text, keep filters
    func clearSearchText() {
        searchText = ""
        performSearch()
    }

    // MARK: - Filter Actions

    func toggleNoteType(_ type: String) {
        if filters.noteTypes.contains(type) {
            filters.noteTypes.remove(type)
        } else {
            filters.noteTypes.insert(type)
        }
        executeSearchImmediately()
    }

    func setDateRange(start: Date?, end: Date?) {
        filters.startDate = start
        filters.endDate = end
        executeSearchImmediately()
    }

    func clearDateRange() {
        filters.startDate = nil
        filters.endDate = nil
        executeSearchImmediately()
    }

    func toggleIncludeArchived() {
        filters.includeArchived.toggle()
        executeSearchImmediately()
    }

    func setSortOption(_ option: SearchSortOption) {
        filters.sortBy = option
        executeSearchImmediately()
    }

    func clearAllFilters() {
        filters = SearchFilters()
        executeSearchImmediately()
    }

    // MARK: - Private Methods

    private func executeSearch() async {
        isSearching = true

        // Update filters with current search text
        var searchFilters = filters
        searchFilters.query = searchText

        // Perform search
        let searchResults = SearchService.shared.search(filters: searchFilters, context: context)

        // Update results on main actor
        results = searchResults
        hasSearched = true
        isSearching = false
    }
}

// MARK: - Recent Searches

extension SearchViewModel {
    private static let recentSearchesKey = "recentSearches"
    private static let maxRecentSearches = 10

    var recentSearches: [String] {
        UserDefaults.standard.stringArray(forKey: Self.recentSearchesKey) ?? []
    }

    func saveRecentSearch(_ query: String) {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        var recent = recentSearches
        // Remove if already exists
        recent.removeAll { $0.lowercased() == query.lowercased() }
        // Add at beginning
        recent.insert(query, at: 0)
        // Limit count
        if recent.count > Self.maxRecentSearches {
            recent = Array(recent.prefix(Self.maxRecentSearches))
        }
        UserDefaults.standard.set(recent, forKey: Self.recentSearchesKey)
    }

    func removeRecentSearch(_ query: String) {
        var recent = recentSearches
        recent.removeAll { $0 == query }
        UserDefaults.standard.set(recent, forKey: Self.recentSearchesKey)
    }

    func clearRecentSearches() {
        UserDefaults.standard.removeObject(forKey: Self.recentSearchesKey)
    }
}
