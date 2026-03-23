import SwiftUI
import SwiftData

struct CaptureFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var locationService = LocationService()
    var onCapture: ((Capture) -> Void)?

    var body: some View {
        DocumentScannerView { images in
            let capture = saveCapture(images: images)
            if let capture { onCapture?(capture) }
            dismiss()
        }
    }

    @discardableResult
    private func saveCapture(images: [UIImage]) -> Capture? {
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

        return capture
    }
}
