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

                // Process each page with remote OCR + tags
                var allText: [String] = []
                var allAITags: [String] = []
                var firstTitle: String?
                for image in capture.sortedImages {
                    let result = try await remoteOCRService.recognizeText(from: image.imageData)
                    image.ocrText = result.text
                    allText.append(result.text)
                    allAITags.append(contentsOf: result.aiTags)
                    if firstTitle == nil { firstTitle = result.title }
                }
                let description = allText.joined(separator: "\n\n---\n\n")
                // Deduplicate AI tags, keep max 4
                var seen = Set<String>()
                let uniqueAITags = allAITags.filter { seen.insert($0.lowercased()).inserted }.prefix(4)

                logger.info("OCR complete: \(allText.count) pages, \(description.count) chars, \(uniqueAITags.count) tags")

                // Persist OCR + Ollama-generated metadata
                capture.ocrText = description
                capture.extractedTitle = firstTitle
                capture.isProcessingOCR = false

                // Build enrichment with Ollama tags
                let enrichment = Enrichment(
                    title: firstTitle ?? "",
                    summary: String(description.prefix(200)),
                    text: description,
                    tags: [],
                    aiTags: Array(uniqueAITags),
                    actions: []
                )
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
}
