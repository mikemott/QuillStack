import Foundation
import SwiftData

@Model
final class PendingOCRRequest {
    @Attribute(.unique) var id: UUID
    var imageData: Data
    var createdAt: Date
    var retryCount: Int

    @Relationship var capture: Capture?

    init(capture: Capture, imageData: Data) {
        self.id = UUID()
        self.capture = capture
        self.imageData = imageData
        self.createdAt = .now
        self.retryCount = 0
    }
}
