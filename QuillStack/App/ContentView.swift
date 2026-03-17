import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Capture.createdAt, order: .reverse) private var captures: [Capture]
    @Query(sort: \Tag.name) private var tags: [Tag]
    @State private var selectedTag: Tag?
    @State private var showCamera = false
    @State private var searchText = ""

    private var filteredCaptures: [Capture] {
        var result = captures
        if let tag = selectedTag {
            result = result.filter { $0.tags.contains(where: { $0.id == tag.id }) }
        }
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { capture in
                (capture.extractedTitle?.lowercased().contains(query) ?? false)
                || (capture.ocrText?.lowercased().contains(query) ?? false)
                || (capture.locationName?.lowercased().contains(query) ?? false)
                || capture.tags.contains(where: { $0.name.lowercased().contains(query) })
            }
        }
        return result
    }

    private var groupedByDate: [(date: Date, captures: [Capture])] {
        let grouped = Dictionary(grouping: filteredCaptures) { $0.createdAt.startOfDay }
        return grouped
            .sorted { $0.key > $1.key }
            .map { (date: $0.key, captures: $0.value) }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24, pinnedViews: [.sectionHeaders]) {
                        tagFilterBar

                        ForEach(groupedByDate, id: \.date) { group in
                            dateSection(group.date, captures: group.captures)
                        }
                    }
                    .padding(.bottom, 80)
                }
                .searchable(text: $searchText, prompt: "Search captures")

                captureButton
            }
            .navigationTitle("Captures")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: SettingsPlaceholder()) {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPlaceholder()
            }
        }
    }

    // MARK: - Tag Filter Bar

    private var tagFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tags) { tag in
                    TagChip(
                        name: tag.name,
                        colorHex: tag.colorHex,
                        isSelected: selectedTag?.id == tag.id
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTag = selectedTag?.id == tag.id ? nil : tag
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Date Section

    private func dateSection(_ date: Date, captures: [Capture]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(date.timelineHeader)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(captures.count)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal)

            let columns = [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
            ]

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(captures) { capture in
                    NavigationLink(destination: DetailPlaceholder(capture: capture)) {
                        CaptureCard(capture: capture)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Capture Button

    private var captureButton: some View {
        Button {
            showCamera = true
        } label: {
            Image(systemName: "camera.fill")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(Color.primary)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        }
        .padding(.bottom, 16)
    }
}

// MARK: - Placeholder Views

struct SettingsPlaceholder: View {
    var body: some View {
        Text("Settings")
            .navigationTitle("Settings")
    }
}

struct CameraPlaceholder: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            Text("Camera")
            Button("Dismiss") { dismiss() }
        }
    }
}

struct DetailPlaceholder: View {
    let capture: Capture

    var body: some View {
        Text("Detail for \(capture.extractedTitle ?? "Capture")")
            .navigationTitle("Detail")
    }
}
