import Foundation
import SwiftData

@Model
final class CaptureImage {
    @Attribute(.externalStorage) var imageData: Data
    @Attribute(.externalStorage) var thumbnailData: Data?
    var pageIndex: Int
    var ocrText: String?
    var ocrConfidence: Double?
    var capture: Capture?

    init(imageData: Data, pageIndex: Int, thumbnailData: Data? = nil) {
        self.imageData = imageData
        self.pageIndex = pageIndex
        self.thumbnailData = thumbnailData
    }
}
