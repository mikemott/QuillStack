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
        let allPending = (try? context.fetch(FetchDescriptor<PendingOCRRequest>())) ?? []
        if allPending.contains(where: { $0.capture?.persistentModelID == capture.persistentModelID }) {
            logger.debug("OCR request already queued for this capture, skipping")
            return
        }

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
        guard let requests = try? context.fetch(descriptor), !requests.isEmpty else { return }

        logger.info("Processing \(requests.count) pending OCR requests")

        for request in requests {
            guard let capture = request.capture else {
                logger.warning("Capture not found for pending request, removing from queue")
                context.delete(request)
                try? context.save()
                continue
            }

            do {
                let tagNames = Set(capture.tags.map(\.name))
                let imageData = request.imageData

                let result = try await remoteOCR.recognizeText(from: imageData, tagNames: tagNames)

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
                    receipt: result.receipt,
                    todo: result.todo
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
