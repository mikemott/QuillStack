import SwiftData
import Foundation
import os

/// Stable, content-free identifiers for OCR failure. Safe to transmit and to
/// persist; never derived from `Error.localizedDescription`, which can embed
/// file paths or fragments of recognized text.
enum OCRFailureCode: String, Sendable {
    case noImages
    case imageUnreadable
    case noTextFound
    case extractionFailed
    case unexpected

    init(_ error: Error) {
        guard let visionError = error as? VisionOCRError else {
            self = .unexpected
            return
        }
        switch visionError {
        case .imageEncodingFailed: self = .imageUnreadable
        case .emptyResponse: self = .noTextFound
        case .extractionFailed: self = .extractionFailed
        }
    }

    /// Vision is deterministic for a given image: re-running `.noTextFound` or
    /// `.imageUnreadable` on the same bytes produces the same result. Offering a
    /// retry there would be a button that cannot work. Only transient failures —
    /// an unexpected Vision error, or FoundationModels being briefly unavailable —
    /// are worth re-running.
    var isRetryable: Bool {
        switch self {
        case .unexpected, .extractionFailed: true
        case .noImages, .imageUnreadable, .noTextFound: false
        }
    }

    /// `.noTextFound` is an outcome, not an error: a photo of something with no
    /// readable text is a perfectly valid capture.
    var isError: Bool { self != .noTextFound }

    var userMessage: String {
        switch self {
        case .noTextFound: "No text recognized in this image."
        case .imageUnreadable: "This image couldn't be read. Try capturing it again."
        case .noImages: "This capture has no image."
        case .extractionFailed: "On-device processing was unavailable."
        case .unexpected: "Text recognition didn't finish."
        }
    }
}

actor CaptureProcessor {
    private let visionService = VisionOCRService.shared
    private let enrichmentService = OnDeviceEnrichmentService.shared
    private let logger = Logger(subsystem: "com.quillstack", category: "CaptureProcessor")

    private let maxRetries = 3
    private let baseRetryDelay: TimeInterval = 2.0
    private static let enrichmentEncoder = JSONEncoder()

    struct ProcessingResult: Sendable {
        let ocrText: String
        let extractedTitle: String?
        let enrichmentJSON: Data?
        let success: Bool
        let failure: OCRFailureCode?
    }

    func process(imageData: [Data], tagNames: Set<String>) async -> ProcessingResult {
        guard !imageData.isEmpty else {
            return ProcessingResult(
                ocrText: "", extractedTitle: nil, enrichmentJSON: nil,
                success: false, failure: .noImages
            )
        }

        var lastError: Error?
        CrashReporting.ocrRequested(engine: "vision", tagCount: tagNames.count)

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
                    let result = try await visionService.recognizeText(from: data, tagNames: tagNames)
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
                let enrichmentData = try? Self.enrichmentEncoder.encode(enrichment)

                CrashReporting.ocrCompleted(charCount: description.count)

                return ProcessingResult(
                    ocrText: description,
                    extractedTitle: title,
                    enrichmentJSON: enrichmentData,
                    success: true,
                    failure: nil
                )

            } catch let error as VisionOCRError {
                lastError = error
                logger.error("OCR attempt \(attempt + 1) failed: \(error.localizedDescription)")
                break
            } catch {
                lastError = error
                logger.error("OCR attempt \(attempt + 1) failed: \(error.localizedDescription)")
            }
        }

        // localizedDescription stays in the on-device log; only a stable code leaves.
        logger.error("OCR failed after \(self.maxRetries) attempts: \(lastError?.localizedDescription ?? "unknown")")
        let code = lastError.map(OCRFailureCode.init) ?? .unexpected
        CrashReporting.ocrFailed(code: code)

        return ProcessingResult(
            ocrText: "", extractedTitle: nil, enrichmentJSON: nil,
            success: false, failure: code
        )
    }
}
