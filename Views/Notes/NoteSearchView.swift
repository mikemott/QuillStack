//
//  NoteSearchView.swift
//  QuillStack
//
//  Created on 2025-12-18.
//

import SwiftUI

// MARK: - Note Search View

struct NoteSearchView: View {
    @State private var viewModel = SearchViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var showingFilters = false
    @State private var selectedNote: Note?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.creamLight.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search bar
                    searchBar

                    // Filter chips
                    if viewModel.isFilterActive {
                        filterChips
                    }

                    // Content
                    if viewModel.isSearching {
                        loadingView
                    } else if viewModel.showEmptyState {
                        emptyStateView
                    } else if viewModel.hasResults {
                        resultsList
                    } else if !viewModel.hasSearched {
                        initialStateView
                    }
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.forestDark)
                }

                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingFilters = true }) {
                        Image(systemName: viewModel.isFilterActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .foregroundColor(.forestDark)
                    }
                }
            }
            .sheet(isPresented: $showingFilters) {
                SearchFilterSheet(viewModel: viewModel)
                    .presentationDetents([.medium, .large])
            }
            .navigationDestination(item: $selectedNote) { note in
                destinationView(for: note)
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.textMedium)

                TextField("Search notes...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .font(.serifBody(16, weight: .regular))
                    .foregroundStyle(Color.textDark)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                    .onSubmit {
                        if !viewModel.searchText.isEmpty {
                            viewModel.saveRecentSearch(viewModel.searchText)
                        }
                        viewModel.executeSearchImmediately()
                    }

                if !viewModel.searchText.isEmpty {
                    Button(action: { viewModel.clearSearchText() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.textLight)
                    }
                }
            }
            .padding(12)
            .background(Color.white)
            .cornerRadius(10)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .onChange(of: viewModel.searchText) { _, _ in
            viewModel.performSearch()
        }
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Note type chips
                ForEach(Array(viewModel.filters.noteTypes), id: \.self) { type in
                    FilterChip(
                        text: displayNameForType(type),
                        color: colorForType(type),
                        onRemove: { viewModel.toggleNoteType(type) }
                    )
                }

                // Date range chip
                if viewModel.filters.startDate != nil || viewModel.filters.endDate != nil {
                    FilterChip(
                        text: dateRangeText,
                        color: .forestDark,
                        onRemove: { viewModel.clearDateRange() }
                    )
                }

                // Archived chip
                if viewModel.filters.includeArchived {
                    FilterChip(
                        text: "Including Archived",
                        color: .textMedium,
                        onRemove: { viewModel.toggleIncludeArchived() }
                    )
                }

                // Clear all
                if viewModel.isFilterActive {
                    Button(action: { viewModel.clearAllFilters() }) {
                        Text("Clear All")
                            .font(.serifCaption(12, weight: .medium))
                            .foregroundColor(.forestDark)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    private var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short

        if let start = viewModel.filters.startDate, let end = viewModel.filters.endDate {
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        } else if let start = viewModel.filters.startDate {
            return "From \(formatter.string(from: start))"
        } else if let end = viewModel.filters.endDate {
            return "Until \(formatter.string(from: end))"
        }
        return "Date Range"
    }

    // MARK: - Results List

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Result count
                HStack {
                    Text("\(viewModel.resultCount) result\(viewModel.resultCount == 1 ? "" : "s")")
                        .font(.serifCaption(13, weight: .medium))
                        .foregroundColor(.textMedium)
                    Spacer()
                }
                .padding(.horizontal, 4)

                // Results
                ForEach(viewModel.results) { note in
                    SearchResultCard(
                        note: note,
                        searchQuery: viewModel.searchText,
                        onTap: { selectedNote = note }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - State Views

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Searching...")
                .font(.serifBody(15, weight: .medium))
                .foregroundColor(.textMedium)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.textLight)

            Text("No results found")
                .font(.serifHeadline(18, weight: .semibold))
                .foregroundColor(.textDark)

            Text("Try adjusting your search or filters")
                .font(.serifBody(14, weight: .regular))
                .foregroundColor(.textMedium)

            if viewModel.isFilterActive {
                Button(action: { viewModel.clearAllFilters() }) {
                    Text("Clear Filters")
                        .font(.serifBody(14, weight: .semibold))
                        .foregroundColor(.forestDark)
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var initialStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.forestLight)

            Text("Search your notes")
                .font(.serifHeadline(18, weight: .semibold))
                .foregroundColor(.textDark)

            Text("Find notes by content, type, or date")
                .font(.serifBody(14, weight: .regular))
                .foregroundColor(.textMedium)

            // Recent searches
            if !viewModel.recentSearches.isEmpty {
                recentSearchesSection
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }

    private var recentSearchesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Searches")
                    .font(.serifCaption(13, weight: .semibold))
                    .foregroundColor(.textMedium)
                Spacer()
                Button("Clear") {
                    viewModel.clearRecentSearches()
                }
                .font(.serifCaption(12, weight: .medium))
                .foregroundColor(.forestDark)
            }

            FlowLayout(spacing: 8) {
                ForEach(viewModel.recentSearches, id: \.self) { search in
                    Button(action: {
                        viewModel.searchText = search
                        viewModel.executeSearchImmediately()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 12))
                            Text(search)
                                .font(.serifCaption(13, weight: .medium))
                        }
                        .foregroundColor(.textDark)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                    }
                }
            }
        }
        .padding(.top, 24)
    }

    // MARK: - Helpers

    private func displayNameForType(_ type: String) -> String {
        switch type {
        case "todo": return "To-Do"
        case "meeting": return "Meeting"
        case "email": return "Email"
        default: return "General"
        }
    }

    private func colorForType(_ type: String) -> Color {
        switch type {
        case "todo": return .badgeTodo
        case "meeting": return .badgeMeeting
        case "email": return .badgeEmail
        default: return .badgeGeneral
        }
    }

    @ViewBuilder
    private func destinationView(for note: Note) -> some View {
        switch note.noteType.lowercased() {
        case "todo":
            TodoDetailView(note: note)
        case "email":
            EmailDetailView(note: note)
        case "meeting":
            MeetingDetailView(note: note)
        default:
            NoteDetailView(note: note)
        }
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let text: String
    let color: Color
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.serifCaption(12, weight: .medium))
                .foregroundColor(.white)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color)
        .cornerRadius(16)
    }
}

// MARK: - Search Result Card

struct SearchResultCard: View {
    let note: Note
    let searchQuery: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack {
                    // Type badge
                    Text(displayName)
                        .font(.serifCaption(10, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(badgeColor)
                        .cornerRadius(4)

                    Spacer()

                    // Date
                    Text(formattedDate)
                        .font(.serifCaption(11, weight: .regular))
                        .foregroundColor(.textLight)

                    // Archived indicator
                    if note.isArchived {
                        Image(systemName: "archivebox.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.textLight)
                    }
                }

                // Content snippet with highlighted query
                Text(snippet)
                    .font(.serifBody(14, weight: .regular))
                    .foregroundColor(.textDark)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            .padding(14)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    private var displayName: String {
        switch note.noteType.lowercased() {
        case "todo": return "To-Do"
        case "meeting": return "Meeting"
        case "email": return "Email"
        default: return "Note"
        }
    }

    private var badgeColor: Color {
        switch note.noteType.lowercased() {
        case "todo": return .badgeTodo
        case "meeting": return .badgeMeeting
        case "email": return .badgeEmail
        default: return .badgeGeneral
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: note.createdAt)
    }

    private var snippet: String {
        SearchService.shared.extractSnippet(from: note.content, for: searchQuery)
    }
}

// MARK: - Preview

#Preview {
    NoteSearchView()
}
