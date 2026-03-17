import SwiftUI
import SwiftData

struct CaptureFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var cameraService = CameraService()
    @State private var locationService = LocationService()
    @State private var capturedImages: [UIImage] = []
    @State private var selectedTags: [Tag] = []
    @State private var phase: CapturePhase = .camera

    enum CapturePhase {
        case camera
        case tagging
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch phase {
            case .camera:
                cameraView
            case .tagging:
                taggingView
            }
        }
        .onAppear {
            cameraService.configure()
            cameraService.start()
        }
        .onDisappear {
            cameraService.stop()
        }
    }

    // MARK: - Camera

    private var cameraView: some View {
        ZStack {
            CameraPreviewView(session: cameraService.previewSession)
                .ignoresSafeArea()

            VStack {
                // Top bar
                HStack {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white)
                    Spacer()
                    if !capturedImages.isEmpty {
                        Text("Page \(capturedImages.count)")
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    }
                }
                .padding()

                Spacer()

                // Bottom controls
                HStack(spacing: 40) {
                    if !capturedImages.isEmpty {
                        Button {
                            phase = .tagging
                        } label: {
                            Text("Done (\(capturedImages.count))")
                                .font(.callout)
                                .fontWeight(.medium)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                        }
                    }

                    Button {
                        Task { await capturePhoto() }
                    } label: {
                        Circle()
                            .fill(.white)
                            .frame(width: 72, height: 72)
                            .overlay(
                                Circle()
                                    .stroke(.white.opacity(0.3), lineWidth: 4)
                                    .frame(width: 82, height: 82)
                            )
                    }

                    if capturedImages.isEmpty {
                        Spacer().frame(width: 72)
                    }
                }
                .padding(.bottom, 30)
            }
        }
    }

    // MARK: - Tagging

    private var taggingView: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Preview of captured images
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(capturedImages.enumerated()), id: \.offset) { index, image in
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(alignment: .topTrailing) {
                                        if capturedImages.count > 1 {
                                            Text("\(index + 1)")
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                                .padding(4)
                                                .background(.ultraThinMaterial)
                                                .clipShape(Circle())
                                                .padding(4)
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(height: 108)

                    TagPickerView(selectedTags: $selectedTags)
                }
                .padding(.top)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Tag Capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back") { phase = .camera }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { saveCapture() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Actions

    private func capturePhoto() async {
        guard let image = await cameraService.capture() else { return }
        let corrected = await CameraService.detectAndCorrectDocument(in: image)
        capturedImages.append(corrected)

        if capturedImages.count == 1 {
            phase = .tagging
        }
    }

    private func saveCapture() {
        let capture = Capture()
        capture.tags = selectedTags

        for (index, image) in capturedImages.enumerated() {
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

        // Run OCR in background after save
        let processor = CaptureProcessor()
        processor.process(capture, in: modelContext)

        // Attach location if enabled
        Task {
            if let location = await locationService.currentLocation() {
                capture.latitude = location.coordinate.latitude
                capture.longitude = location.coordinate.longitude
                capture.locationName = await locationService.reverseGeocode(location)
                try? modelContext.save()
            }
        }

        dismiss()
    }
}
