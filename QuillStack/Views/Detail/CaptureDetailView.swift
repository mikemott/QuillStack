import SwiftUI
import SwiftData

struct CaptureDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var capture: Capture
    @State private var currentPage = 0
    @State private var showTagEditor = false
    @State private var showDeleteConfirm = false
    @State private var showExportResult: ExportResult?
    @State private var selectedTags: [Tag] = []

    var body: some View {
        ZStack(alignment: .bottom) {
            QSSurface.base.ignoresSafeArea()

            imageViewer
                .ignoresSafeArea()

            metadataOverlay
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        exportToObsidian()
                    } label: {
                        Label("Export to Obsidian", systemImage: "square.and.arrow.up")
                    }

                    ShareLink(item: shareImage, preview: SharePreview(
                        capture.extractedTitle ?? "Capture",
                        image: shareImage
                    ))

                    Divider()

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(QSColor.onSurfaceVariant)
                }
            }
        }
        .alert("Delete Capture?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                modelContext.delete(capture)
                try? modelContext.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showTagEditor) {
            tagEditorSheet
        }
        .alert(
            showExportResult?.title ?? "",
            isPresented: Binding(
                get: { showExportResult != nil },
                set: { if !$0 { showExportResult = nil } }
            )
        ) {
            Button("OK") { showExportResult = nil }
        } message: {
            Text(showExportResult?.message ?? "")
        }
        .onAppear {
            selectedTags = capture.tags
        }
    }

    // MARK: - Image Viewer

    @ViewBuilder
    private var imageViewer: some View {
        let images = capture.sortedImages
        if images.count > 1 {
            TabView(selection: $currentPage) {
                ForEach(Array(images.enumerated()), id: \.offset) { index, captureImage in
                    zoomableImage(data: captureImage.imageData)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
        } else if let first = images.first {
            zoomableImage(data: first.imageData)
        }
    }

    private func zoomableImage(data: Data) -> some View {
        GeometryReader { geo in
            if let uiImage = UIImage(data: data) {
                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width)
                }
            }
        }
    }

    // MARK: - Metadata Overlay
    // Glass recipe: primary glow bleeding from bottom-left

    private var metadataOverlay: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title — onSurface, not pure white
            if let title = capture.extractedTitle {
                Text(title)
                    .font(QSFont.detailTitle)
                    .foregroundStyle(QSColor.onSurface)
            }

            // Tags row
            HStack {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(capture.tags) { tag in
                            TagChip(tag: tag, isSelected: true)
                        }
                    }
                }

                Button {
                    selectedTags = capture.tags
                    showTagEditor = true
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title3)
                        .foregroundStyle(QSColor.secondary)
                }
            }

            // Location & timestamp — use spacing, not dividers
            HStack(spacing: 12) {
                if let location = capture.locationName {
                    Label {
                        Text(location)
                            .font(QSFont.detailLocation)
                    } icon: {
                        Image(systemName: "location.fill")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(QSColor.onSurfaceMuted)
                }

                Spacer()

                Text(capture.createdAt.detailTimestamp)
                    .font(QSFont.detailTimestamp)
                    .foregroundStyle(QSColor.onSurfaceMuted)
            }

            if capture.isStack {
                Text("Page \(currentPage + 1) of \(capture.pageCount)")
                    .font(QSFont.detailPageIndicator)
                    .foregroundStyle(QSColor.onSurfaceMuted)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .qsGlass(
            glow: QSColor.tertiaryDim,
            center: .bottomLeading,
            intensity: 0.15,
            surfaceOpacity: 0.65
        )
    }

    // MARK: - Tag Editor Sheet

    private var tagEditorSheet: some View {
        NavigationStack {
            ScrollView {
                TagPickerView(selectedTags: $selectedTags)
                    .padding(.top)
            }
            .background(QSSurface.base)
            .navigationTitle("Edit Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showTagEditor = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        capture.tags = selectedTags
                        try? modelContext.save()
                        showTagEditor = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Share

    private var shareImage: Image {
        if let data = capture.sortedImages.first?.imageData,
           let uiImage = UIImage(data: data) {
            return Image(uiImage: uiImage)
        }
        return Image(systemName: "photo")
    }

    // MARK: - Export

    private func exportToObsidian() {
        let exporter = ObsidianExporter()
        do {
            try exporter.export(capture)
            showExportResult = ExportResult(
                title: "Exported",
                message: "Capture added to your Obsidian daily note."
            )
        } catch {
            showExportResult = ExportResult(
                title: "Export Failed",
                message: error.localizedDescription
            )
        }
    }
}

struct ExportResult: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
