import SwiftUI
import SwiftData

struct CaptureDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var capture: Capture
    @State private var currentPage = 0
    @State private var showTagEditor = false
    @State private var showDeleteConfirm = false
    @State private var selectedTags: [Tag] = []

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()

            // Image viewer
            imageViewer
                .ignoresSafeArea()

            // Metadata overlay
            metadataOverlay
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }

                    ShareLink(item: shareImage, preview: SharePreview(
                        capture.extractedTitle ?? "Capture",
                        image: shareImage
                    ))
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.white)
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

    private var metadataOverlay: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            if let title = capture.extractedTitle {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
            }

            // Tags
            HStack {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(capture.tags) { tag in
                            TagChip(name: tag.name, colorHex: tag.colorHex, isSelected: true)
                        }
                    }
                }

                Button {
                    selectedTags = capture.tags
                    showTagEditor = true
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            // Location
            if let location = capture.locationName {
                Label(location, systemImage: "location.fill")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }

            // OCR text (expandable)
            if let ocrText = capture.ocrText, !ocrText.isEmpty {
                DisclosureGroup {
                    Text(ocrText)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Label("Recognized Text", systemImage: "doc.text")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .tint(.white.opacity(0.7))
            }

            // Stack indicator
            if capture.isStack {
                Text("Page \(currentPage + 1) of \(capture.pageCount)")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Tag Editor Sheet

    private var tagEditorSheet: some View {
        NavigationStack {
            ScrollView {
                TagPickerView(selectedTags: $selectedTags)
                    .padding(.top)
            }
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
}
