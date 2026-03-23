import SwiftData
import Foundation
import os

@MainActor
final class CaptureProcessor {
    private let remoteOCRService = RemoteOCRService.shared
    private let enrichmentService = EnrichmentService.shared
    private let queueService = OCRQueueService.shared
    private let logger = Logger(subsystem: "com.quillstack", category: "CaptureProcessor")

    func process(_ capture: Capture, in context: ModelContext) {
        capture.isProcessingOCR = true

        guard let primaryImage = capture.sortedImages.first else {
            capture.isProcessingOCR = false
            try? context.save()
            return
        }

        let imageData = primaryImage.imageData

        Task { @MainActor in
            do {
                // Check if Mac Mini is available
                guard await remoteOCRService.checkAvailability() else {
                    logger.info("Mac Mini unavailable, queueing OCR request")
                    capture.isProcessingOCR = false
                    try queueService.enqueue(capture: capture, imageData: imageData, in: context)
                    return
                }

                // Process each page with remote OCR
                var allText: [String] = []
                for image in capture.sortedImages {
                    let pageText = try await remoteOCRService.recognizeText(from: image.imageData)
                    image.ocrText = pageText
                    allText.append(pageText)
                }
                let description = allText.joined(separator: "\n\n---\n\n")
                logger.info("OCR complete: \(allText.count) pages, \(description.count) chars")

                // Persist OCR text immediately
                capture.ocrText = description
                capture.isProcessingOCR = false
                try context.save()

                // Run enrichment (best-effort, OCR already saved)
                let tagNames = fetchTagNames(in: context)
                logger.info("Running enrichment with \(tagNames.count) available tags")
                let enrichment = try await enrichmentService.enrich(
                    imageDescription: description,
                    tagNames: tagNames
                )
                logger.info("Enrichment complete: title=\(enrichment.title)")

                capture.extractedTitle = enrichment.title
                capture.enrichmentJSON = try? JSONEncoder().encode(enrichment)
                try context.save()
                logger.info("Capture processed successfully")

            } catch {
                logger.error("OCR failed, queueing for retry: \(error.localizedDescription)")
                capture.isProcessingOCR = false
                try? queueService.enqueue(capture: capture, imageData: imageData, in: context)
            }
        }
    }

    // MARK: - Tag Fetching

    private func fetchTagNames(in context: ModelContext) -> [String] {
        let descriptor = FetchDescriptor<Tag>(sortBy: [SortDescriptor(\.name)])
        return ((try? context.fetch(descriptor)) ?? []).map(\.name)
    }
}
