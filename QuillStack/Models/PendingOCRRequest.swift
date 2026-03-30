import Foundation
import SwiftData

@Model
final class PendingOCRRequest {
    var id: UUID = UUID()
    var imageData: Data = Data()
    var createdAt: Date = Date.now
    var retryCount: Int = 0

    @Relationship var capture: Capture?

    init(capture: Capture, imageData: Data) {
        self.id = UUID()
        self.capture = capture
        self.imageData = imageData
        self.createdAt = .now
        self.retryCount = 0
    }
}
