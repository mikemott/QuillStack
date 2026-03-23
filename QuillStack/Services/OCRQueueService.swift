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
                let tagNames = Set(capture.tags.map(\.name))
                let result = try await remoteOCR.recognizeText(from: request.imageData, tagNames: tagNames)

                capture.ocrText = result.text
                capture.extractedTitle = result.title
                capture.isProcessingOCR = false

                let enrichment = EnrichedCapture(
                    title: result.title ?? "",
                    summary: String(result.text.prefix(200)),
                    text: result.text,
                    tags: [],
                    aiTags: Array(result.aiTags.prefix(4)),
                    contact: result.contact,
                    event: result.event,
                    receipt: result.receipt
                )
                capture.enrichmentJSON = try? JSONEncoder().encode(enrichment)

                context.delete(request)
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

}
