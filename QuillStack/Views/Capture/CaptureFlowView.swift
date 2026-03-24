import SwiftUI
import SwiftData

struct CaptureFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Tag.name) private var allTags: [Tag]
    @State private var locationService = LocationService()
    @State private var pendingCapture: Capture?
    @State private var selectedTags: [Tag] = []
    @State private var showTagPicker = false

    var body: some View {
        ZStack {
            if !showTagPicker {
                DocumentScannerView { images in
                    pendingCapture = createCapture(images: images)
                    showTagPicker = true
                }
            } else if let capture = pendingCapture {
                tagPickerOverlay(capture: capture)
            }
        }
    }

    // MARK: - Tag Picker Overlay

    private func tagPickerOverlay(capture: Capture) -> some View {
        ZStack(alignment: .bottom) {
            // Image preview behind the sheet
            if let data = capture.thumbnail, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(QSSurface.base)
                    .ignoresSafeArea()
            } else {
                QSSurface.base.ignoresSafeArea()
            }

            // Half-sheet tag picker
            VStack(spacing: 20) {
                Text("TAG THIS CAPTURE")
                    .font(QSFont.sectionHeader)
                    .tracking(2.5)
                    .foregroundStyle(QSColor.onSurfaceMuted)

                FlowLayout(spacing: 10) {
                    ForEach(allTags.sorted(by: { $0.captureCount > $1.captureCount })) { tag in
                        TagChip(
                            tag: tag,
                            isSelected: selectedTags.contains(where: { $0.id == tag.id }),
                            size: .large
                        ) {
                            toggleTag(tag)
                        }
                    }
                }

                Button {
                    finishCapture(capture)
                } label: {
                    Text("DONE")
                        .font(QSFont.sansMedium(size: 16))
                        .tracking(1.5)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(selectedTags.isEmpty ? QSColor.onSurfaceMuted.opacity(0.3) : QSColor.primary)
                        .foregroundStyle(selectedTags.isEmpty ? QSColor.onSurfaceMuted : QSColor.onPrimaryDark)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .disabled(selectedTags.isEmpty)
            }
            .padding(20)
            .padding(.bottom, 16)
            .background(
                QSSurface.base.opacity(0.85)
                    .background(.ultraThinMaterial)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
            .transition(.move(edge: .bottom))
        }
        .animation(.easeOut(duration: 0.3), value: showTagPicker)
    }

    // MARK: - Tag Toggle

    private func toggleTag(_ tag: Tag) {
        withAnimation(.easeInOut(duration: 0.15)) {
            if let index = selectedTags.firstIndex(where: { $0.id == tag.id }) {
                selectedTags.remove(at: index)
            } else {
                selectedTags.append(tag)
            }
        }
    }

    // MARK: - Capture Lifecycle

    private func createCapture(images: [UIImage]) -> Capture? {
        guard !images.isEmpty else { return nil }

        let capture = Capture()
        for (index, image) in images.enumerated() {
            let imageData = image.jpegData(compressionQuality: 0.85) ?? Data()
            let thumbnailData = image.thumbnail()
            let captureImage = CaptureImage(
                imageData: imageData,
                pageIndex: index,
                thumbnailData: thumbnailData
            )
            capture.images.append(captureImage)
        }

        modelContext.insert(capture)
        try? modelContext.save()
        return capture
    }

    private func finishCapture(_ capture: Capture) {
        capture.tags = selectedTags
        CrashReporting.captureStarted(pageCount: capture.images.count)
        CrashReporting.tagsSelected(selectedTags.map(\.name))
        try? modelContext.save()

        // OCR fires now with tag context
        let processor = CaptureProcessor()
        processor.process(capture, in: modelContext)

        // Location in background
        let ctx = modelContext
        Task {
            if let location = await locationService.currentLocation() {
                capture.latitude = location.coordinate.latitude
                capture.longitude = location.coordinate.longitude
                capture.locationName = await locationService.reverseGeocode(location)
                try? ctx.save()
            }
        }

        dismiss()
    }
}
