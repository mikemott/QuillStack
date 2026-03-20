import SwiftUI
import SwiftData

struct CaptureFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var locationService = LocationService()

    var body: some View {
        DocumentScannerView { images in
            saveCapture(images: images)
        }
    }

    private func saveCapture(images: [UIImage]) {
        guard !images.isEmpty else { return }

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

        let processor = CaptureProcessor()
        processor.process(capture, in: modelContext)

        let ctx = modelContext
        Task {
            if let location = await locationService.currentLocation() {
                capture.latitude = location.coordinate.latitude
                capture.longitude = location.coordinate.longitude
                capture.locationName = await locationService.reverseGeocode(location)
                try? ctx.save()
            }
        }
    }
}
