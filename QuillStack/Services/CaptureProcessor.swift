import SwiftData
import Foundation
import os

@MainActor
final class CaptureProcessor {
    private let datalabService = DatalabOCRService.shared
    private let enrichmentService = OnDeviceEnrichmentService.shared
    private let logger = Logger(subsystem: "com.quillstack", category: "CaptureProcessor")

    private let maxRetries = 3
    private let baseRetryDelay: TimeInterval = 2.0

    func process(_ capture: Capture, in context: ModelContext) {
        capture.isProcessingOCR = true
        let tagNames = Set(capture.tags.map(\.name))

        guard capture.sortedImages.first != nil else {
            capture.isProcessingOCR = false
            try? context.save()
            return
        }

        Task {
            var lastError: Error?

            for attempt in 0..<maxRetries {
                if attempt > 0 {
                    let delay = baseRetryDelay * pow(2.0, Double(attempt - 1))
                    logger.info("Retry \(attempt)/\(self.maxRetries - 1) after \(delay)s")
                    try? await Task.sleep(for: .seconds(delay))
                }

                do {
                    CrashReporting.ocrRequested(engine: "datalab", tagCount: tagNames.count)

                    var allText: [String] = []
                    var firstContact: ContactExtraction?
                    var firstEvent: EventExtraction?
                    var firstReceipt: ReceiptExtraction?
                    var firstTodo: TodoExtraction?

                    // Step 1: Datalab OCR + structured extraction
                    for image in capture.sortedImages {
                        let result = try await datalabService.recognizeText(from: image.imageData, tagNames: tagNames)
                        image.ocrText = result.text
                        allText.append(result.text)
                        if firstContact == nil { firstContact = result.contact }
                        if firstEvent == nil { firstEvent = result.event }
                        if firstReceipt == nil { firstReceipt = result.receipt }
                        if firstTodo == nil { firstTodo = result.todo }
                    }

                    let description = allText.joined(separator: "\n\n---\n\n")
                    logger.info("OCR complete: \(allText.count) pages, \(description.count) chars")

                    // Step 2: On-device enrichment for title + aiTags
                    let metadata = await enrichmentService.generateMetadata(from: description)
                    let title = metadata?.title
                    let aiTags = metadata?.aiTags ?? []

                    logger.info("Enrichment: title=\(title ?? "none"), \(aiTags.count) tags")

                    capture.ocrText = description
                    capture.extractedTitle = title
                    capture.isProcessingOCR = false

                    let enrichment = EnrichedCapture(
                        title: title ?? "",
                        summary: String(description.prefix(200)),
                        text: description,
                        tags: [],
                        aiTags: aiTags,
                        contact: firstContact,
                        event: firstEvent,
                        receipt: firstReceipt,
                        todo: firstTodo
                    )
                    capture.enrichmentJSON = try? JSONEncoder().encode(enrichment)
                    try context.save()
                    logger.info("Capture processed successfully")
                    CrashReporting.ocrCompleted(
                        charCount: description.count,
                        hasContact: firstContact != nil,
                        hasEvent: firstEvent != nil,
                        hasReceipt: firstReceipt != nil
                    )
                    return

                } catch {
                    lastError = error
                    logger.error("OCR attempt \(attempt + 1) failed: \(error.localizedDescription)")
                }
            }

            // All retries exhausted
            logger.error("OCR failed after \(self.maxRetries) attempts: \(lastError?.localizedDescription ?? "unknown")")
            CrashReporting.ocrFailed(error: lastError?.localizedDescription ?? "unknown")
            capture.isProcessingOCR = false
            try? context.save()
        }
    }
}
