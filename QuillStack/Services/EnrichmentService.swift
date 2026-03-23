import FoundationModels
import Foundation
import os

enum EnrichmentError: Error {
    case noTagsAvailable
    case foundationModelsUnavailable
}

actor EnrichmentService {
    static let shared = EnrichmentService()

    private static let logger = Logger(subsystem: "com.quillstack", category: "EnrichmentService")

    func enrich(imageDescription: String, tagNames: [String]) async throws -> Enrichment {
        guard !tagNames.isEmpty else {
            throw EnrichmentError.noTagsAvailable
        }

        // Check if FoundationModels is available (requires iOS 26+)
        if #available(iOS 26, *) {
            guard SystemLanguageModel.default.availability == .available else {
                Self.logger.warning("FoundationModels not available, using fallback enrichment")
                return enrichFallback(imageDescription: imageDescription, tagNames: tagNames)
            }

            return try await enrichWithFoundationModels(imageDescription: imageDescription, tagNames: tagNames)
        } else {
            Self.logger.info("iOS 26+ required for FoundationModels, using fallback enrichment")
            return enrichFallback(imageDescription: imageDescription, tagNames: tagNames)
        }
    }

    @available(iOS 26, *)
    private func enrichWithFoundationModels(imageDescription: String, tagNames: [String]) async throws -> Enrichment {
        let tagList = tagNames.joined(separator: ", ")

        let session = LanguageModelSession(instructions: Instructions {
            """
            You analyze descriptions of captured images and extract structured data.
            When picking tags, you MUST choose from exactly this list: \(tagList).
            Never invent new tags. If none fit well, pick the closest match.
            For aiTags, suggest up to 4 descriptive topic tags about the subject matter.
            These should be lowercase, 1-2 words each, describing WHAT the content is about,
            not the physical format. Do not use words like "handwritten", "notebook", "notes", or "page".
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
        Self.logger.info("Enrichment complete: \(enrichment.tags.count) tags, \(enrichment.actions.count) actions")
        return enrichment
    }

    /// Fallback enrichment for iOS <26 or when FoundationModels unavailable
    private func enrichFallback(imageDescription: String, tagNames: [String]) -> Enrichment {
        let description = imageDescription.lowercased()

        // Simple rule-based title extraction (first sentence or up to 50 chars)
        let title = imageDescription
            .components(separatedBy: CharacterSet(charactersIn: ".!\n"))
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(50)
            .description ?? "Untitled"

        // Simple tag matching based on keywords
        var matchedTags: [String] = []
        for tagName in tagNames {
            if description.contains(tagName.lowercased()) {
                matchedTags.append(tagName)
            }
        }

        // If no tags matched, use first available tag as fallback
        if matchedTags.isEmpty, let firstTag = tagNames.first {
            matchedTags.append(firstTag)
        }

        // Simple action extraction based on patterns
        var actions: [Enrichment.Action] = []

        // Phone number pattern
        let phonePattern = #"\b\d{3}[-.]?\d{3}[-.]?\d{4}\b"#
        if let phoneRegex = try? NSRegularExpression(pattern: phonePattern),
           let match = phoneRegex.firstMatch(in: imageDescription, range: NSRange(imageDescription.startIndex..., in: imageDescription)),
           let range = Range(match.range, in: imageDescription) {
            let phoneNumber = String(imageDescription[range])
            actions.append(Enrichment.Action(
                type: "callPhone",
                phone: phoneNumber
            ))
        }

        // URL pattern
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue),
           let match = detector.firstMatch(in: imageDescription, range: NSRange(imageDescription.startIndex..., in: imageDescription)),
           let url = match.url {
            actions.append(Enrichment.Action(
                type: "openURL",
                url: url.absoluteString
            ))
        }

        Self.logger.info("Fallback enrichment complete: \(matchedTags.count) tags, \(actions.count) actions")

        return Enrichment(
            title: title,
            summary: imageDescription.prefix(200).description,
            text: imageDescription,
            tags: matchedTags,
            aiTags: [],
            actions: actions
        )
    }
}
