//
//  SearchFilterSheet.swift
//  QuillStack
//
//  Created on 2025-12-18.
//

import SwiftUI

// MARK: - Search Filter Sheet

struct SearchFilterSheet: View {
    @ObservedObject var viewModel: SearchViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var endDate: Date = Date()
    @State private var useDateRange = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.creamLight.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Note Type Filters
                        noteTypeSection

                        // Date Range Filter
                        dateRangeSection

                        // Archive Filter
                        archiveSection

                        // Sort Options
                        sortSection
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") {
                        viewModel.clearAllFilters()
                        useDateRange = false
                    }
                    .foregroundColor(.forestDark)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        applyFilters()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.forestDark)
                }
            }
            .onAppear {
                // Initialize state from viewModel
                useDateRange = viewModel.filters.startDate != nil || viewModel.filters.endDate != nil
                if let start = viewModel.filters.startDate {
                    startDate = start
                }
                if let end = viewModel.filters.endDate {
                    endDate = end
                }
            }
        }
    }

    // MARK: - Note Type Section

    private var noteTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Note Type", icon: "doc.text")

            VStack(spacing: 0) {
                ForEach(noteTypes, id: \.self) { type in
                    Button(action: {
                        viewModel.toggleNoteType(type)
                    }) {
                        HStack {
                            // Type icon
                            Image(systemName: iconForType(type))
                                .foregroundColor(colorForType(type))
                                .frame(width: 24)

                            Text(displayNameForType(type))
                                .font(.serifBody(15, weight: .medium))
                                .foregroundColor(.textDark)

                            Spacer()

                            // Checkmark
                            if viewModel.filters.noteTypes.contains(type) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.forestDark)
                                    .fontWeight(.semibold)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }

                    if type != noteTypes.last {
                        Divider().padding(.leading, 56)
                    }
                }
            }
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)

            if viewModel.filters.noteTypes.isEmpty {
                Text("All types shown")
                    .font(.serifCaption(12, weight: .regular))
                    .foregroundColor(.textMedium)
            } else {
                Text("\(viewModel.filters.noteTypes.count) type(s) selected")
                    .font(.serifCaption(12, weight: .regular))
                    .foregroundColor(.forestDark)
            }
        }
    }

    // MARK: - Date Range Section

    private var dateRangeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Date Range", icon: "calendar")

            VStack(spacing: 0) {
                // Toggle
                Toggle(isOn: $useDateRange) {
                    Text("Filter by date")
                        .font(.serifBody(15, weight: .medium))
                        .foregroundColor(.textDark)
                }
                .tint(.forestDark)
                .padding(16)

                if useDateRange {
                    Divider()

                    // Start Date
                    DatePicker(
                        "From",
                        selection: $startDate,
                        in: ...endDate,
                        displayedComponents: .date
                    )
                    .font(.serifBody(15, weight: .medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    Divider()

                    // End Date
                    DatePicker(
                        "To",
                        selection: $endDate,
                        in: startDate...,
                        displayedComponents: .date
                    )
                    .font(.serifBody(15, weight: .medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    Divider()

                    // Quick presets
                    HStack(spacing: 8) {
                        ForEach(datePresets, id: \.name) { preset in
                            Button(action: {
                                startDate = preset.start
                                endDate = preset.end
                            }) {
                                Text(preset.name)
                                    .font(.serifCaption(12, weight: .medium))
                                    .foregroundColor(.forestDark)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.forestLight.opacity(0.2))
                                    .cornerRadius(16)
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
    }

    // MARK: - Archive Section

    private var archiveSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Archive", icon: "archivebox")

            VStack(spacing: 0) {
                Toggle(isOn: Binding(
                    get: { viewModel.filters.includeArchived },
                    set: { _ in viewModel.toggleIncludeArchived() }
                )) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Include archived notes")
                            .font(.serifBody(15, weight: .medium))
                            .foregroundColor(.textDark)
                        Text("Show notes that have been archived")
                            .font(.serifCaption(12, weight: .regular))
                            .foregroundColor(.textMedium)
                    }
                }
                .tint(.forestDark)
                .padding(16)
            }
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
    }

    // MARK: - Sort Section

    private var sortSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Sort By", icon: "arrow.up.arrow.down")

            VStack(spacing: 0) {
                ForEach(SearchSortOption.allCases) { option in
                    Button(action: {
                        viewModel.setSortOption(option)
                    }) {
                        HStack {
                            Image(systemName: option.icon)
                                .foregroundColor(.forestDark)
                                .frame(width: 24)

                            Text(option.displayName)
                                .font(.serifBody(15, weight: .medium))
                                .foregroundColor(.textDark)

                            Spacer()

                            if viewModel.filters.sortBy == option {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.forestDark)
                                    .fontWeight(.semibold)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }

                    if option != SearchSortOption.allCases.last {
                        Divider().padding(.leading, 56)
                    }
                }
            }
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
    }

    // MARK: - Helper Views

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.forestDark)
            Text(title)
                .font(.serifHeadline(16, weight: .semibold))
                .foregroundColor(.textDark)
        }
    }

    // MARK: - Data

    private let noteTypes = ["general", "todo", "meeting", "email"]

    private func displayNameForType(_ type: String) -> String {
        switch type {
        case "todo": return "To-Do"
        case "meeting": return "Meeting"
        case "email": return "Email"
        default: return "General"
        }
    }

    private func iconForType(_ type: String) -> String {
        switch type {
        case "todo": return "checklist"
        case "meeting": return "person.3"
        case "email": return "envelope"
        default: return "doc.text"
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

    private var datePresets: [(name: String, start: Date, end: Date)] {
        let calendar = Calendar.current
        let now = Date()
        return [
            ("Today", calendar.startOfDay(for: now), now),
            ("This Week", calendar.date(byAdding: .day, value: -7, to: now)!, now),
            ("This Month", calendar.date(byAdding: .month, value: -1, to: now)!, now),
            ("This Year", calendar.date(byAdding: .year, value: -1, to: now)!, now)
        ]
    }

    // MARK: - Actions

    private func applyFilters() {
        if useDateRange {
            viewModel.setDateRange(start: startDate, end: endDate)
        } else {
            viewModel.clearDateRange()
        }
    }
}

// MARK: - Preview

#Preview {
    SearchFilterSheet(viewModel: SearchViewModel())
}
