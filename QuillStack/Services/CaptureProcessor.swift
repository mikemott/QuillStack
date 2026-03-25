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
        let captureID = capture.id

        Task { @MainActor in
            do {
                // Check if remote server is available
                guard await remoteOCRService.checkAvailability() else {
                    logger.info("Remote server unavailable, queueing OCR request")
                    try queueService.enqueue(captureID: captureID, imageData: imageData, in: context)
                    return
                }

                // Process with remote OCR
                let description = try await remoteOCRService.recognizeText(from: imageData)

                // Run enrichment
                let tagNames = fetchTagNames(in: context)
                let enrichment = try await enrichmentService.enrich(
                    imageDescription: description,
                    tagNames: tagNames
                )

                // Update capture
                capture.extractedTitle = enrichment.title
                capture.ocrText = enrichment.text
                capture.enrichmentJSON = try? JSONEncoder().encode(enrichment)
                capture.isProcessingOCR = false

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
                try? queueService.enqueue(captureID: captureID, imageData: imageData, in: context)
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
