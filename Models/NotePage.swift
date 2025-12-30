//
//  NotePage.swift
//  QuillStack
//
//  Created on 2025-12-18.
//

import Foundation
import CoreData
import UIKit

@objc(NotePage)
public class NotePage: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var pageNumber: Int16
    @NSManaged public var imageData: Data? // Full resolution image (external storage)
    @NSManaged public var thumbnailData: Data? // Thumbnail for preview
    @NSManaged public var ocrResultData: Data? // Encoded OCRResult for this page
    @NSManaged public var ocrText: String? // Plain text OCR result
    @NSManaged public var ocrConfidence: Float
    @NSManaged public var createdAt: Date

    // Relationship
    @NSManaged public var note: Note?

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date()
        pageNumber = 0
        ocrConfidence = 0.0
    }
}

// MARK: - Computed Properties

extension NotePage {
    /// Get the image from imageData
    var image: UIImage? {
        guard let data = imageData else { return nil }
        return UIImage(data: data)
    }

    /// Get the thumbnail image
    var thumbnail: UIImage? {
        guard let data = thumbnailData else { return nil }
        return UIImage(data: data)
    }

    /// Decoded OCR result for confidence highlighting
    @MainActor var ocrResult: OCRResult? {
        get {
            guard let data = ocrResultData else { return nil }
            return try? JSONDecoder().decode(OCRResult.self, from: data)
        }
        set {
            ocrResultData = try? JSONEncoder().encode(newValue)
        }
    }
}

// MARK: - Convenience Initializer

extension NotePage {
    static func create(
        in context: NSManagedObjectContext,
        pageNumber: Int,
        imageData: Data?,
        thumbnailData: Data? = nil,
        note: Note? = nil
    ) -> NotePage {
        let page = NotePage(context: context)
        page.pageNumber = Int16(pageNumber)
        page.imageData = imageData
        page.thumbnailData = thumbnailData
        page.note = note
        return page
    }

    /// Generate thumbnail from image data
    func generateThumbnail(maxSize: CGFloat = 200) {
        guard let data = imageData,
              let image = UIImage(data: data) else { return }

        let scale = min(maxSize / image.size.width, maxSize / image.size.height)
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let thumbnail = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        thumbnailData = thumbnail?.jpegData(compressionQuality: 0.7)
    }
}
