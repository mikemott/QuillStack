//
//  MultiPageService.swift
//  QuillStack
//
//  Created on 2025-12-18.
//

import Foundation
import CoreData
import UIKit
import Combine

// MARK: - Multi-Page Service

class MultiPageService {
    static let shared = MultiPageService()

    private init() {}

    // MARK: - Page Processing

    /// Process multiple images in parallel with OCR
    func processPages(
        images: [UIImage],
        for note: Note,
        context: NSManagedObjectContext
    ) async throws -> [NotePage] {
        var pages: [NotePage] = []

        // Process all images in parallel using task group
        try await withThrowingTaskGroup(of: (Int, OCRResult, Data?, Data?).self) { group in
            for (index, image) in images.enumerated() {
                group.addTask {
                    // Perform OCR
                    let ocrResult = try await OCRService.shared.recognizeTextWithConfidence(from: image)

                    // Compress image data
                    let imageData = image.jpegData(compressionQuality: 0.8)

                    // Generate thumbnail
                    let thumbnailData = self.generateThumbnail(from: image, maxSize: 200)

                    return (index, ocrResult, imageData, thumbnailData)
                }
            }

            // Collect results in order
            var results: [(Int, OCRResult, Data?, Data?)] = []
            for try await result in group {
                results.append(result)
            }

            // Sort by original index
            results.sort { $0.0 < $1.0 }

            // Create NotePage objects on main context
            await MainActor.run {
                for (index, ocrResult, imageData, thumbnailData) in results {
                    let page = NotePage(context: context)
                    page.pageNumber = Int16(index)
                    page.imageData = imageData
                    page.thumbnailData = thumbnailData
                    page.ocrText = ocrResult.fullText
                    page.ocrConfidence = Float(ocrResult.averageConfidence)
                    page.ocrResultData = try? JSONEncoder().encode(ocrResult)
                    page.note = note

                    note.addToPages(page)
                    pages.append(page)
                }

                // Update note content with combined text
                note.content = results
                    .map { $0.1.fullText }
                    .joined(separator: "\n\n--- Page Break ---\n\n")

                // Calculate average confidence
                let totalConfidence = results.reduce(Float(0)) { $0 + $1.1.averageConfidence }
                note.ocrConfidence = totalConfidence / Float(results.count)
            }
        }

        return pages
    }

    /// Add a single page to an existing note
    func addPage(
        image: UIImage,
        to note: Note,
        context: NSManagedObjectContext
    ) async throws -> NotePage {
        // Perform OCR
        let ocrResult = try await OCRService.shared.recognizeTextWithConfidence(from: image)

        // Prepare data
        let imageData = image.jpegData(compressionQuality: 0.8)
        let thumbnailData = generateThumbnail(from: image, maxSize: 200)

        // Get next page number
        let currentPageCount = note.pageCount

        // Create page on main context
        return await MainActor.run {
            let page = NotePage(context: context)
            page.pageNumber = Int16(currentPageCount)
            page.imageData = imageData
            page.thumbnailData = thumbnailData
            page.ocrText = ocrResult.fullText
            page.ocrConfidence = Float(ocrResult.averageConfidence)
            page.ocrResultData = try? JSONEncoder().encode(ocrResult)
            page.note = note

            note.addToPages(page)

            // Update note content
            if !note.content.isEmpty {
                note.content += "\n\n--- Page Break ---\n\n"
            }
            note.content += ocrResult.fullText

            // Recalculate average confidence
            let allPages = note.sortedPages
            let totalConfidence = allPages.reduce(0.0) { $0 + Double($1.ocrConfidence) }
            note.ocrConfidence = Float(totalConfidence / Double(allPages.count))

            return page
        }
    }

    /// Remove a page from a note
    func removePage(_ page: NotePage, from note: Note, context: NSManagedObjectContext) {
        note.removeFromPages(page)
        context.delete(page)

        // Renumber remaining pages
        let remainingPages = note.sortedPages
        for (index, remainingPage) in remainingPages.enumerated() {
            remainingPage.pageNumber = Int16(index)
        }

        // Rebuild content
        note.content = remainingPages
            .compactMap { $0.ocrText }
            .joined(separator: "\n\n--- Page Break ---\n\n")

        // Recalculate confidence
        if !remainingPages.isEmpty {
            let totalConfidence = remainingPages.reduce(0.0) { $0 + Double($1.ocrConfidence) }
            note.ocrConfidence = Float(totalConfidence / Double(remainingPages.count))
        }
    }

    /// Reorder pages
    func reorderPages(_ pages: [NotePage], for note: Note) {
        for (index, page) in pages.enumerated() {
            page.pageNumber = Int16(index)
        }

        // Rebuild content in new order
        note.content = pages
            .compactMap { $0.ocrText }
            .joined(separator: "\n\n--- Page Break ---\n\n")
    }

    // MARK: - Helpers

    private func generateThumbnail(from image: UIImage, maxSize: CGFloat) -> Data? {
        let scale = min(maxSize / image.size.width, maxSize / image.size.height)
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let thumbnail = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return thumbnail?.jpegData(compressionQuality: 0.7)
    }
}

// MARK: - Batch Capture State

class BatchCaptureState: ObservableObject {
    @Published var capturedImages: [UIImage] = []
    @Published var isProcessing = false
    @Published var processingProgress: Float = 0
    @Published var error: String?

    var imageCount: Int { capturedImages.count }

    func addImage(_ image: UIImage) {
        capturedImages.append(image)
    }

    func removeImage(at index: Int) {
        guard index >= 0, index < capturedImages.count else { return }
        capturedImages.remove(at: index)
    }

    func clear() {
        capturedImages.removeAll()
        isProcessing = false
        processingProgress = 0
        error = nil
    }
}
