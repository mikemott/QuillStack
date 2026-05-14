import SwiftData
import Foundation
import os

actor CaptureProcessor {
    private let datalabService = DatalabOCRService.shared
    private let enrichmentService = OnDeviceEnrichmentService.shared
    private let logger = Logger(subsystem: "com.quillstack", category: "CaptureProcessor")

    private let maxRetries = 3
    private let baseRetryDelay: TimeInterval = 2.0

    struct ProcessingResult: Sendable {
        let ocrText: String
        let extractedTitle: String?
        let enrichmentJSON: Data?
        let isProcessingOCR: Bool
        let charCount: Int
        let hasContact: Bool
        let hasEvent: Bool
        let hasReceipt: Bool
        let success: Bool
        let errorDescription: String?
    }

    func process(imageData: [Data], tagNames: Set<String>) async -> ProcessingResult {
        guard !imageData.isEmpty else {
            return ProcessingResult(
                ocrText: "", extractedTitle: nil, enrichmentJSON: nil,
                isProcessingOCR: false, charCount: 0,
                hasContact: false, hasEvent: false, hasReceipt: false,
                success: false, errorDescription: "No images"
            )
        }

        var lastError: Error?
        CrashReporting.ocrRequested(engine: "datalab", tagCount: tagNames.count)

        for attempt in 0..<maxRetries {
            if attempt > 0 {
                let delay = baseRetryDelay * pow(2.0, Double(attempt - 1))
                logger.info("Retry \(attempt)/\(self.maxRetries - 1) after \(delay)s")
                try? await Task.sleep(for: .seconds(delay))
            }

            do {
                var allText: [String] = []
                var firstContact: ContactExtraction?
                var firstEvent: EventExtraction?
                var firstReceipt: ReceiptExtraction?
                var firstTodo: TodoExtraction?

                for data in imageData {
                    let result = try await datalabService.recognizeText(from: data, tagNames: tagNames)
                    allText.append(result.text)
                    if firstContact == nil { firstContact = result.contact }
                    if firstEvent == nil { firstEvent = result.event }
                    if firstReceipt == nil { firstReceipt = result.receipt }
                    if firstTodo == nil { firstTodo = result.todo }
                }

                let description = allText.joined(separator: "\n\n---\n\n")
                logger.info("OCR complete: \(allText.count) pages, \(description.count) chars")

                let metadata = await enrichmentService.generateMetadata(from: description)
                let title = metadata?.title
                let aiTags = metadata?.aiTags ?? []

                logger.info("Enrichment: title=\(title ?? "none"), \(aiTags.count) tags")

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
                let enrichmentData = try? JSONEncoder().encode(enrichment)

                CrashReporting.ocrCompleted(
                    charCount: description.count,
                    hasContact: firstContact != nil,
                    hasEvent: firstEvent != nil,
                    hasReceipt: firstReceipt != nil
                )

                return ProcessingResult(
                    ocrText: description,
                    extractedTitle: title,
                    enrichmentJSON: enrichmentData,
                    isProcessingOCR: false,
                    charCount: description.count,
                    hasContact: firstContact != nil,
                    hasEvent: firstEvent != nil,
                    hasReceipt: firstReceipt != nil,
                    success: true,
                    errorDescription: nil
                )

            } catch {
                lastError = error
                logger.error("OCR attempt \(attempt + 1) failed: \(error.localizedDescription)")
            }
        }

        logger.error("OCR failed after \(self.maxRetries) attempts: \(lastError?.localizedDescription ?? "unknown")")
        CrashReporting.ocrFailed(error: lastError?.localizedDescription ?? "unknown")

        return ProcessingResult(
            ocrText: "", extractedTitle: nil, enrichmentJSON: nil,
            isProcessingOCR: false, charCount: 0,
            hasContact: false, hasEvent: false, hasReceipt: false,
            success: false, errorDescription: lastError?.localizedDescription
        )
    }
}
