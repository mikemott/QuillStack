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
                logger.info("OCR text received: \(description.prefix(100))...")

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
                logger.info("Enrichment complete: title=\(enrichment.title ?? "none")")

                capture.extractedTitle = enrichment.title
                capture.enrichmentJSON = try? JSONEncoder().encode(enrichment)

                // Auto-apply tags
                let allTags = fetchTags(in: context)
                for tagName in enrichment.tags {
                    let normalized = tagName.lowercased()
                    let match = allTags.first(where: { $0.name.lowercased() == normalized })
                    if let match, !capture.tags.contains(where: { $0.id == match.id }) {
                        capture.tags.append(match)
                    }
                }

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
        fetchTags(in: context).map(\.name)
    }

    private func fetchTags(in context: ModelContext) -> [Tag] {
        let descriptor = FetchDescriptor<Tag>(sortBy: [SortDescriptor(\.name)])
        return (try? context.fetch(descriptor)) ?? []
    }
}
