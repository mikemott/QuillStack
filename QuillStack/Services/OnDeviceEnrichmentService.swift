import Foundation
import FoundationModels
import os

@Generable(description: "Metadata for a captured document based on its OCR text")
struct CaptureMetadata {
    @Guide(description: "A short descriptive title summarizing the document, under 10 words")
    var title: String

    @Guide(description: "Up to 4 short topic tags describing the subject matter and content, not the physical format. Lowercase, 1-2 words each. Avoid generic tags like handwritten, notebook, notes, page, or document.")
    var aiTags: [String]
}

actor OnDeviceEnrichmentService {
    static let shared = OnDeviceEnrichmentService()

    private let logger = Logger(subsystem: "com.quillstack", category: "OnDeviceEnrichment")

    func generateMetadata(from ocrText: String) async -> CaptureMetadata? {
        let truncated = String(ocrText.prefix(2000))
        let prompt = """
        Based on the following text extracted from a captured image, generate a short title and topic tags.

        ---
        \(truncated)
        ---
        """

        do {
            let session = LanguageModelSession()
            let response = try await session.respond(
                to: prompt,
                generating: CaptureMetadata.self
            )
            logger.info("On-device enrichment: title=\(response.content.title), tags=\(response.content.aiTags)")
            return response.content
        } catch {
            logger.warning("On-device enrichment failed: \(error.localizedDescription)")
            return nil
        }
    }
}
