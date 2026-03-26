import Foundation
import SwiftData
import CoreLocation

@Model
final class Capture {
    var createdAt: Date
    var extractedTitle: String?
    var ocrText: String?
    var latitude: Double?
    var longitude: Double?
    var locationName: String?
    var isProcessingOCR: Bool
    var enrichmentJSON: Data?

    @Relationship(deleteRule: .cascade, inverse: \CaptureImage.capture)
    var images: [CaptureImage]

    @Relationship(inverse: \Tag.captures)
    var tags: [Tag]

    init() {
        self.createdAt = .now
        self.isProcessingOCR = false
        self.images = []
        self.tags = []
    }

    var sortedImages: [CaptureImage] {
        images.sorted { $0.pageIndex < $1.pageIndex }
    }

    var isStack: Bool { images.count > 1 }
    var pageCount: Int { images.count }

    var thumbnail: Data? {
        sortedImages.first?.thumbnailData ?? sortedImages.first?.imageData
    }

    var enrichment: EnrichedCapture? {
        guard let data = enrichmentJSON else { return nil }
        return try? JSONDecoder().decode(EnrichedCapture.self, from: data)
    }
}
