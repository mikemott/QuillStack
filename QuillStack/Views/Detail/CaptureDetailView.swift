import SwiftUI
import SwiftData
import EventKit

struct CaptureDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var capture: Capture
    @State private var currentPage = 0
    @State private var showTagEditor = false
    @State private var showOCRText = false
    @State private var showDeleteConfirm = false
    @State private var showExportResult: ExportResult?
    @State private var selectedTags: [Tag] = []
    @State private var eventStore = EKEventStore()
    @State private var contactForAction: IdentifiableWrapper<ContactExtraction>?
    @State private var eventForAction: IdentifiableWrapper<EventExtraction>?
    @State private var receiptForAction: IdentifiableWrapper<ReceiptExtraction>?

    var body: some View {
        ZStack(alignment: .bottom) {
            QSSurface.base.ignoresSafeArea()

            ZStack(alignment: .bottomTrailing) {
                imageViewer
                    .ignoresSafeArea()

                ActionIconStack(capture: capture) { tag in
                    handleAction(tag)
                }
                .padding(20)
                .padding(.bottom, 200)
            }

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
        .sheet(item: $contactForAction) { wrapper in
            ContactActionView(extraction: wrapper.value) {
                contactForAction = nil
            }
        }
        .sheet(item: $eventForAction) { wrapper in
            EventActionView(extraction: wrapper.value, eventStore: eventStore) {
                eventForAction = nil
            }
        }
        .sheet(item: $receiptForAction) { wrapper in
            ReceiptPreviewSheet(receipt: wrapper.value, capture: capture, onExport: {
                exportToObsidian()
                receiptForAction = nil
            }, onDismiss: {
                receiptForAction = nil
            })
        }
        .onAppear {
            selectedTags = capture.tags ?? []
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

    /// Before this, a failed OCR was completely silent: the capture saved with no
    /// text, no title, no action icons, and no way to re-run. Retry appears only
    /// for codes where re-running can actually change the outcome — Vision is
    /// deterministic for a given image.
    @ViewBuilder
    private var ocrStatusSection: some View {
        if capture.isProcessingOCR {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Recognizing text…")
                    .font(QSFont.detailBody)
                    .foregroundStyle(QSColor.onSurfaceMuted)
                    .accessibilityIdentifier("ocr-processing")
                Spacer()
            }
        } else if let failure = capture.ocrFailure {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: failure.isError ? "exclamationmark.triangle.fill" : "text.viewfinder")
                        .font(.system(size: 12))
                        .accessibilityHidden(true)

                    Text(failure.userMessage)
                        .font(QSFont.detailBody)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("ocr-status-message")

                    Spacer()
                }
                .foregroundStyle(failure.isError ? QSColor.onSurface : QSColor.onSurfaceMuted)

                if failure.isRetryable {
                    Button(action: retryOCR) {
                        Text("RETRY")
                            .font(QSFont.mono(size: 10))
                            .fontWeight(.bold)
                            .tracking(1.5)
                            .foregroundStyle(QSColor.onPrimaryDark)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(QSColor.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("ocr-retry")
                    .accessibilityLabel("Retry text recognition")
                }
            }
            .padding(12)
            .background(QSSurface.container)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private func retryOCR() {
        Task { @MainActor in
            await CaptureReprocessor.rerun(for: capture, in: modelContext)
        }
    }

    /// Recognized text is otherwise invisible in the app — it only reaches
    /// search and Obsidian export. Surfacing it here makes an unenriched
    /// capture (OCR ran, titling failed) distinguishable from a failed one.
    @ViewBuilder
    private var ocrTextSection: some View {
        if let text = capture.ocrText, !text.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { showOCRText.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Text("RECOGNIZED TEXT")
                            .font(QSFont.mono(size: 9))
                            .fontWeight(.bold)
                            .tracking(1.5)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                            .rotationEffect(.degrees(showOCRText ? 0 : -90))

                        Spacer()

                        Text("\(text.count) CHARS")
                            .font(QSFont.monoLight(size: 10))
                    }
                    .foregroundStyle(QSColor.onSurfaceMuted)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("ocr-text-toggle")
                .accessibilityLabel(showOCRText ? "Hide recognized text" : "Show recognized text")
                .accessibilityHint("\(text.count) characters were recognized in this capture")

                if showOCRText {
                    ScrollView {
                        Text(text)
                            .font(QSFont.detailBody)
                            .foregroundStyle(QSColor.onSurfaceVariant)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 180)
                    .padding(12)
                    .background(QSSurface.container)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .accessibilityIdentifier("ocr-text-body")
                }
            }
        }
    }

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
                        ForEach(capture.tags ?? []) { tag in
                            TagChip(tag: tag, isSelected: true)
                        }
                    }
                }

                Button {
                    selectedTags = capture.tags ?? []
                    showTagEditor = true
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title3)
                        .foregroundStyle(QSColor.secondary)
                }
            }

            // AI topic tags
            if let aiTags = capture.enrichment?.aiTags, !aiTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(aiTags, id: \.self) { tag in
                            AITagChip(label: tag)
                        }
                    }
                }
            }

            ocrStatusSection

            ocrTextSection

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

    // MARK: - Quick Actions

    private func handleAction(_ tag: String) {
        CrashReporting.actionTapped(tag)
        switch tag {
        case "Contact":
            if let contact = capture.enrichment?.contact {
                contactForAction = IdentifiableWrapper(contact)
            }
        case "Event":
            if let event = capture.enrichment?.event {
                eventForAction = IdentifiableWrapper(event)
            }
        case "Receipt":
            if let receipt = capture.enrichment?.receipt {
                receiptForAction = IdentifiableWrapper(receipt)
            }
        default: break
        }
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
