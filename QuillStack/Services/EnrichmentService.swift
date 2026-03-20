import FoundationModels
import Foundation
import os

actor EnrichmentService {
    static let shared = EnrichmentService()

    private static let logger = Logger(subsystem: "com.quillstack", category: "EnrichmentService")

    func enrich(imageDescription: String, tagNames: [String]) async throws -> Enrichment {
        let tagList = tagNames.joined(separator: ", ")

        let session = LanguageModelSession(instructions: Instructions {
            """
            You analyze descriptions of captured images and extract structured data.
            When picking tags, you MUST choose from exactly this list: \(tagList).
            Never invent new tags. If none fit well, pick the closest match.
            """
        })

        let response = try await session.respond(
            to: """
            Analyze this captured image description and extract structured information:

            \(imageDescription)
            """,
            generating: Enrichment.self
        )

        let enrichment = response.content
        Self.logger.info("Enrichment: title=\(enrichment.title), tags=\(enrichment.tags), actions=\(enrichment.actions.count)")
        return enrichment
    }
}
