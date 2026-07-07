import Foundation
import SwiftData

@Model
final class CaptureImage {
    @Attribute(.externalStorage) var imageData: Data = Data()
    @Attribute(.externalStorage) var thumbnailData: Data?
    var pageIndex: Int = 0
    var ocrText: String?
    var ocrConfidence: Double?
    var capture: Capture?

    init(imageData: Data, pageIndex: Int, thumbnailData: Data? = nil) {
        self.imageData = imageData
        self.pageIndex = pageIndex
        self.thumbnailData = thumbnailData
    }
}
