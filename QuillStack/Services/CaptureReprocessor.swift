import Foundation
import SwiftData
import os

/// Single place where a `ProcessingResult` is written back to a `Capture`.
/// Both the initial capture flow and the detail view's Retry go through here,
/// so a success can never leave a stale failure code behind — and a failure can
/// never be silently dropped.
@MainActor
enum CaptureReprocessor {

    private static let logger = Logger(subsystem: "com.quillstack", category: "CaptureReprocessor")

    static func apply(_ result: CaptureProcessor.ProcessingResult, to capture: Capture) {
        capture.isProcessingOCR = false
        if result.success {
            capture.ocrText = result.ocrText
            capture.extractedTitle = result.extractedTitle
            capture.enrichmentJSON = result.enrichmentJSON
            capture.ocrFailureCode = nil
        } else {
            capture.ocrFailureCode = result.failure?.rawValue
        }
    }

    /// Re-runs OCR for an existing capture. Only meaningful for retryable codes —
    /// Vision is deterministic for a given image.
    static func rerun(for capture: Capture, in context: ModelContext) async {
        let imageData = capture.sortedImages.map(\.imageData)
        let tagNames = Set((capture.tags ?? []).map(\.name))

        capture.isProcessingOCR = true
        save(context)

        let result = await CaptureProcessor().process(imageData: imageData, tagNames: tagNames)
        apply(result, to: capture)
        save(context)
    }

    /// `try?` on save() discards the reason. Log it — a failed save means the
    /// user's work is not on disk.
    static func save(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            logger.error("ModelContext save failed: \(error.localizedDescription)")
            CrashReporting.storeLoadFailed(stage: "save")
        }
    }
}
