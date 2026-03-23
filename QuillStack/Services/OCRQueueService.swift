import SwiftData
import Foundation
import UIKit
import os

@MainActor
final class OCRQueueService {
    static let shared = OCRQueueService()

    private let logger = Logger(subsystem: "com.quillstack", category: "OCRQueue")
    private var isProcessing = false

    private init() {}

    func enqueue(capture: Capture, imageData: Data, in context: ModelContext) throws {
        let request = PendingOCRRequest(capture: capture, imageData: imageData)
        context.insert(request)
        try context.save()
        logger.info("Enqueued OCR request for capture")
    }

    func getPendingCount(in context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<PendingOCRRequest>()
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    func processQueue(in context: ModelContext) async {
        guard !isProcessing else {
            logger.debug("Queue processing already in progress")
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        let remoteOCR = RemoteOCRService.shared
        let enrichmentService = EnrichmentService.shared

        guard await remoteOCR.checkAvailability() else {
            logger.debug("Mac Mini not available, skipping queue processing")
            return
        }

        let descriptor = FetchDescriptor<PendingOCRRequest>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        guard let requests = try? context.fetch(descriptor) else { return }

        logger.info("Processing \(requests.count) pending OCR requests")

        for request in requests {
            // Check for orphaned requests before doing network work
            guard let capture = request.capture else {
                logger.warning("Capture not found for pending request, removing from queue")
                context.delete(request)
                try? context.save()
                continue
            }

            do {
                let description = try await remoteOCR.recognizeText(from: request.imageData)

                // Persist OCR text immediately
                capture.ocrText = description
                capture.isProcessingOCR = false
                context.delete(request)
                try context.save()

                // Run enrichment (best-effort, OCR already saved)
                let tagNames = fetchTagNames(in: context)
                let enrichment = try await enrichmentService.enrich(
                    imageDescription: description,
                    tagNames: tagNames
                )

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
                logger.info("Processed OCR for capture")

            } catch {
                logger.error("Failed to process OCR request: \(error.localizedDescription)")
                request.retryCount += 1

                if request.retryCount > 5 {
                    logger.warning("Max retries exceeded, removing request")
                    capture.isProcessingOCR = false
                    context.delete(request)
                }

                try? context.save()
            }
        }

        logger.info("Queue processing complete")
    }

    private func fetchTagNames(in context: ModelContext) -> [String] {
        fetchTags(in: context).map(\.name)
    }

    private func fetchTags(in context: ModelContext) -> [Tag] {
        let descriptor = FetchDescriptor<Tag>(sortBy: [SortDescriptor(\.name)])
        return (try? context.fetch(descriptor)) ?? []
    }
}
