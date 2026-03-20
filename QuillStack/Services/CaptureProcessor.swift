import SwiftData
import Foundation
import os

@MainActor
final class CaptureProcessor {
    private let ocrService = OCRService()
    private let vlmService = VLMService.shared
    private let enrichmentService = EnrichmentService.shared
    private let logger = Logger(subsystem: "com.quillstack", category: "CaptureProcessor")

    func process(_ capture: Capture, in context: ModelContext) {
        capture.isProcessingOCR = true

        let imageSnapshots = capture.sortedImages.map {
            ImageSnapshot(id: $0.persistentModelID, data: $0.imageData)
        }
        let captureID = capture.persistentModelID

        Task { @MainActor in
            let vlmReady = await vlmService.isReady

            if vlmReady, let primaryImage = imageSnapshots.first {
                await runTwoStageEnrichment(imageData: primaryImage.data, captureID: captureID, context: context)

                // OCR remaining pages for multi-page documents
                if imageSnapshots.count > 1 {
                    let remainingImages = Array(imageSnapshots.dropFirst())
                    for snapshot in remainingImages {
                        let result = await ocrService.recognizeText(in: snapshot.data)
                        if let image = context.model(for: snapshot.id) as? CaptureImage {
                            image.ocrText = result.fullText
                            image.ocrConfidence = result.averageConfidence
                        }
                    }
                }
            } else {
                await runAppleVisionFallback(snapshots: imageSnapshots, captureID: captureID, context: context)
            }

            if let capture = context.model(for: captureID) as? Capture {
                capture.isProcessingOCR = false
            }
            try? context.save()
        }
    }

    // MARK: - Two-Stage: VLM describes image → Foundation Models extracts structure

    private func runTwoStageEnrichment(
        imageData: Data, captureID: PersistentIdentifier, context: ModelContext
    ) async {
        do {
            // Stage 1a: VLM describes the image (layout, context, printed text)
            // Stage 1b: Apple Vision OCR (catches text the VLM might miss, especially handwriting)
            async let vlmDescription = vlmService.describeImage(imageData)
            async let ocrResult = ocrService.recognizeText(in: imageData)

            let description = try await vlmDescription
            let ocr = await ocrResult

            // Combine both sources for Foundation Models
            var combinedInput = description
            if let ocrText = ocr.fullText, !ocrText.isEmpty {
                combinedInput += "\n\nAdditional OCR text extracted from the image:\n\(ocrText)"
            }

            // Stage 2: Foundation Models extracts structured data
            let tagNames = fetchTagNames(in: context)
            let enrichment = try await enrichmentService.enrich(
                imageDescription: combinedInput,
                tagNames: tagNames
            )

            guard let capture = context.model(for: captureID) as? Capture else { return }

            capture.extractedTitle = enrichment.title
            capture.ocrText = enrichment.text
            capture.enrichmentJSON = try? JSONEncoder().encode(enrichment)

            // Auto-apply tags (exact match only to avoid false positives)
            let allTags = fetchTags(in: context)
            for tagName in enrichment.tags {
                let normalized = tagName.lowercased()
                let match = allTags.first(where: { $0.name.lowercased() == normalized })
                if let match, !capture.tags.contains(where: { $0.id == match.id }) {
                    capture.tags.append(match)
                }
            }
        } catch {
            logger.error("Enrichment failed: \(error)")
        }
    }

    // MARK: - Apple Vision (fallback when VLM unavailable)

    private func runAppleVisionFallback(
        snapshots: [ImageSnapshot], captureID: PersistentIdentifier, context: ModelContext
    ) async {
        var pageTexts: [String] = []

        for snapshot in snapshots {
            let result = await ocrService.recognizeText(in: snapshot.data)

            if let image = context.model(for: snapshot.id) as? CaptureImage {
                image.ocrText = result.fullText
                image.ocrConfidence = result.averageConfidence
            }

            if let text = result.fullText { pageTexts.append(text) }
        }

        if let capture = context.model(for: captureID) as? Capture {
            capture.ocrText = pageTexts.isEmpty ? nil : pageTexts.joined(separator: "\n")
            capture.extractedTitle = pageTexts.first.map { String($0.prefix(80)) }
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

private struct ImageSnapshot: Sendable {
    let id: PersistentIdentifier
    let data: Data
}
