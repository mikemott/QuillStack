import Foundation
import SwiftData
import CoreLocation

@Model
final class Capture {
    var createdAt: Date = Date.now
    var extractedTitle: String?
    var ocrText: String?
    var latitude: Double?
    var longitude: Double?
    var locationName: String?
    var isProcessingOCR: Bool = false
    var enrichmentJSON: Data?

    /// Raw value of `OCRFailureCode` from the last processing attempt.
    /// nil means OCR succeeded, or has not run. Stable and content-free,
    /// so it is safe to persist and to sync.
    var ocrFailureCode: String?

    // CloudKit requires every relationship to be optional: a synced record may
    // arrive before its inverse exists. nil means "not yet materialized",
    // [] means "materialized and empty".
    @Relationship(deleteRule: .cascade, inverse: \CaptureImage.capture)
    var images: [CaptureImage]?

    @Relationship(inverse: \Tag.captures)
    var tags: [Tag]?

    init() {
        self.createdAt = .now
        self.isProcessingOCR = false
        self.images = []
        self.tags = []
    }

    var sortedImages: [CaptureImage] {
        (images ?? []).sorted { $0.pageIndex < $1.pageIndex }
    }

    var isStack: Bool { pageCount > 1 }
    var pageCount: Int { images?.count ?? 0 }

    var thumbnail: Data? {
        sortedImages.first?.thumbnailData ?? sortedImages.first?.imageData
    }

    private static let enrichmentDecoder = JSONDecoder()

    var enrichment: EnrichedCapture? {
        guard let data = enrichmentJSON else { return nil }
        return try? Capture.enrichmentDecoder.decode(EnrichedCapture.self, from: data)
    }

    var ocrFailure: OCRFailureCode? {
        ocrFailureCode.flatMap(OCRFailureCode.init(rawValue:))
    }
}
