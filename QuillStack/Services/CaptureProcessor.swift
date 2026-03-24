import SwiftData
import Foundation
import os

@MainActor
final class CaptureProcessor {
    private let remoteOCRService = RemoteOCRService.shared
    private let queueService = OCRQueueService.shared
    private let logger = Logger(subsystem: "com.quillstack", category: "CaptureProcessor")

    func process(_ capture: Capture, in context: ModelContext) {
        capture.isProcessingOCR = true
        let tagNames = Set(capture.tags.map(\.name))

        guard let primaryImage = capture.sortedImages.first else {
            capture.isProcessingOCR = false
            try? context.save()
            return
        }

        let imageData = primaryImage.imageData

        Task { @MainActor in
            do {
                guard await remoteOCRService.checkAvailability() else {
                    logger.info("Mac Mini unavailable, queueing OCR request")
                    capture.isProcessingOCR = false
                    try queueService.enqueue(capture: capture, imageData: imageData, in: context)
                    return
                }

                CrashReporting.ocrRequested(engine: "remote", tagCount: tagNames.count)

                var allText: [String] = []
                var allAITags: [String] = []
                var firstTitle: String?
                var firstContact: ContactExtraction?
                var firstEvent: EventExtraction?
                var firstReceipt: ReceiptExtraction?

                for image in capture.sortedImages {
                    let result = try await remoteOCRService.recognizeText(from: image.imageData, tagNames: tagNames)
                    image.ocrText = result.text
                    allText.append(result.text)
                    allAITags.append(contentsOf: result.aiTags)
                    if firstTitle == nil { firstTitle = result.title }
                    if firstContact == nil { firstContact = result.contact }
                    if firstEvent == nil { firstEvent = result.event }
                    if firstReceipt == nil { firstReceipt = result.receipt }
                }

                let description = allText.joined(separator: "\n\n---\n\n")
                var seen = Set<String>()
                let uniqueAITags = allAITags.filter { seen.insert($0.lowercased()).inserted }.prefix(4)

                logger.info("OCR complete: \(allText.count) pages, \(description.count) chars, \(uniqueAITags.count) tags")

                capture.ocrText = description
                capture.extractedTitle = firstTitle
                capture.isProcessingOCR = false

                let enrichment = EnrichedCapture(
                    title: firstTitle ?? "",
                    summary: String(description.prefix(200)),
                    text: description,
                    tags: [],
                    aiTags: Array(uniqueAITags),
                    contact: firstContact,
                    event: firstEvent,
                    receipt: firstReceipt
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

            } catch {
                logger.error("OCR failed, queueing for retry: \(error.localizedDescription)")
                CrashReporting.ocrFailed(error: error.localizedDescription)
                capture.isProcessingOCR = false
                try? queueService.enqueue(capture: capture, imageData: imageData, in: context)
            }
        }
    }
}
