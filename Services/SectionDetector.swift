//
//  SectionDetector.swift
//  QuillStack
//
//  Created on 2026-01-09.
//

import Foundation
import UIKit

// MARK: - Section Detection Models

/// Represents a detected section within a note
struct DetectedSection: Identifiable, Sendable {
    let id = UUID()
    let content: String
    let suggestedType: NoteType
    let suggestedTags: [String]
    let confidence: Double
    let startIndex: String.Index
    let endIndex: String.Index
}

/// Result of section detection analysis
struct SectionDetectionResult: Sendable {
    let sections: [DetectedSection]
    let shouldAutoSplit: Bool // True if confidence > 0.85
    let detectionMethod: DetectionMethod

    enum DetectionMethod: String, Sendable {
        case explicitMarkers = "explicit" // #type# tags found
        case semanticLLM = "llm"          // LLM detected sections
        case none = "none"                 // Single section detected
    }
}

// MARK: - Section Detector Service

/// Service for detecting multiple sections within a single note
/// and offering to split them into separate notes.
@MainActor
final class SectionDetector {

    static let shared = SectionDetector()

    // Minimum confidence threshold for auto-split suggestion
    private static let AUTO_SPLIT_THRESHOLD = 0.85

    private let llmService: LLMServiceProtocol
    private let textClassifier: TextClassifierProtocol

    init(llmService: LLMServiceProtocol = LLMService.shared,
         textClassifier: TextClassifierProtocol? = nil) {
        self.llmService = llmService
        self.textClassifier = textClassifier ?? MainActor.assumeIsolated { TextClassifier() }
    }

    // MARK: - Public API

    /// Detects sections in the given text
    /// - Parameters:
    ///   - text: The OCR text to analyze
    ///   - settings: User settings for LLM and classification
    /// - Returns: Section detection result with confidence
    func detectSections(in text: String, settings: SettingsManager) async -> SectionDetectionResult {
        // Fast path: Check for explicit markers first
        if let explicitResult = detectExplicitSections(in: text) {
            return explicitResult
        }

        // Check if LLM is enabled and available
        let enableLLM = await settings.enableLLMClassification
        let hasAPIKey = await settings.hasAPIKey

        guard enableLLM && hasAPIKey else {
            // No LLM available - return single section
            return createSingleSectionResult(text: text)
        }

        // Fallback: Use LLM for semantic detection
        if let llmResult = await detectSectionsWithLLM(text: text) {
            return llmResult
        }

        // No sections detected - return single section
        return createSingleSectionResult(text: text)
    }

    // MARK: - Explicit Marker Detection

    /// Detects sections using explicit #type# markers
    /// This is the fast path - if markers are found, we have high confidence
    private func detectExplicitSections(in text: String) -> SectionDetectionResult? {
        let pattern = #"#(\w+)#"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))

        // Need at least 2 markers to have multiple sections
        guard matches.count >= 2 else {
            return nil
        }

        var sections: [DetectedSection] = []

        // Split text by markers
        for (index, match) in matches.enumerated() {
            let markerRange = match.range
            let markerText = nsText.substring(with: match.range(at: 1))

            // Get content from after this marker to the next marker (or end)
            let contentStartOffset = markerRange.location + markerRange.length
            let contentEndOffset: Int
            if index < matches.count - 1 {
                contentEndOffset = matches[index + 1].range.location
            } else {
                contentEndOffset = nsText.length
            }

            guard contentStartOffset <= contentEndOffset else { continue }

            let startIndex = text.index(text.startIndex, offsetBy: contentStartOffset)
            let endIndex = text.index(text.startIndex, offsetBy: contentEndOffset)

            let sectionContent = String(text[startIndex..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)

            // Determine type from marker
            let noteType = NoteType.from(identifier: markerText) ?? .general

            // Extract tags from content
            let tags = extractTags(from: sectionContent)

            let section = DetectedSection(
                content: sectionContent,
                suggestedType: noteType,
                suggestedTags: tags,
                confidence: 1.0, // Explicit markers = 100% confidence
                startIndex: startIndex,
                endIndex: endIndex
            )

            sections.append(section)
        }

        guard sections.count >= 2 else {
            return nil
        }

        return SectionDetectionResult(
            sections: sections,
            shouldAutoSplit: true, // Explicit markers = always suggest split
            detectionMethod: .explicitMarkers
        )
    }

    // MARK: - LLM Semantic Detection

    /// Uses LLM to detect sections semantically
    /// TODO: Implement LLM-based section detection
    private func detectSectionsWithLLM(text: String) async -> SectionDetectionResult? {
        // Check if text is too short to have multiple sections
        guard text.count > 100 else {
            return nil
        }

        let prompt = buildSectionDetectionPrompt(text: text)

        do {
            let response = try await llmService.performRequest(prompt: prompt, maxTokens: 1000)
            return parseLLMSectionResponse(response: response, originalText: text)
        } catch {
            print("❌ LLM section detection failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func buildSectionDetectionPrompt(text: String) -> String {
        """
        Analyze the following handwritten note text and determine if it contains multiple distinct sections that should be split into separate notes.

        Look for:
        - Clear topic changes
        - Different note types (e.g., todo list followed by meeting notes)
        - Distinct information blocks separated by visual cues or context shifts

        Only suggest splitting if you are confident (>85%) that there are 2 or more distinct sections.

        TEXT:
        \(text)

        Respond in JSON format:
        {
          "hasSections": true/false,
          "confidence": 0.0-1.0,
          "sections": [
            {
              "content": "section text here",
              "type": "todo|meeting|email|general|...",
              "tags": ["tag1", "tag2"],
              "reasoning": "why this is a separate section"
            }
          ]
        }

        If there's only one coherent section, return hasSections: false with confidence 1.0.
        """
    }

    private func parseLLMSectionResponse(response: String, originalText: String) -> SectionDetectionResult? {
        // Extract JSON from response (handle markdown code blocks)
        let jsonString = extractJSON(from: response)

        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        guard let hasSections = json["hasSections"] as? Bool,
              let confidence = json["confidence"] as? Double else {
            return nil
        }

        // If no sections detected, return single section result
        guard hasSections,
              let sectionsJSON = json["sections"] as? [[String: Any]],
              sectionsJSON.count >= 2 else {
            return createSingleSectionResult(text: originalText)
        }

        // Parse sections
        var sections: [DetectedSection] = []
        var currentIndex = originalText.startIndex

        for sectionJSON in sectionsJSON {
            guard let content = sectionJSON["content"] as? String,
                  let typeString = sectionJSON["type"] as? String else {
                continue
            }

            let noteType = NoteType.from(identifier: typeString) ?? .general
            let tags = sectionJSON["tags"] as? [String] ?? []

            // Find the section in the original text
            if let range = originalText.range(of: content, range: currentIndex..<originalText.endIndex) {
                let section = DetectedSection(
                    content: content,
                    suggestedType: noteType,
                    suggestedTags: tags,
                    confidence: confidence,
                    startIndex: range.lowerBound,
                    endIndex: range.upperBound
                )
                sections.append(section)
                currentIndex = range.upperBound
            }
        }

        guard sections.count >= 2 else {
            return createSingleSectionResult(text: originalText)
        }

        return SectionDetectionResult(
            sections: sections,
            shouldAutoSplit: confidence >= Self.AUTO_SPLIT_THRESHOLD,
            detectionMethod: .semanticLLM
        )
    }

    // MARK: - Helper Methods

    /// Creates a single-section result (no splitting needed)
    private func createSingleSectionResult(text: String) -> SectionDetectionResult {
        let section = DetectedSection(
            content: text,
            suggestedType: .general,
            suggestedTags: extractTags(from: text),
            confidence: 1.0,
            startIndex: text.startIndex,
            endIndex: text.endIndex
        )

        return SectionDetectionResult(
            sections: [section],
            shouldAutoSplit: false,
            detectionMethod: .none
        )
    }

    /// Extracts hashtags from text
    private func extractTags(from text: String) -> [String] {
        let pattern = #"#(\w+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))

        var tags: [String] = []
        for match in matches {
            let tag = nsText.substring(with: match.range(at: 1))
            // Filter out note type markers (e.g., #todo#, #meeting#) by checking if they are valid type identifiers
            if NoteType.from(identifier: tag) == nil {
                tags.append(tag.lowercased())
            }
        }

        return Array(Set(tags)) // Remove duplicates
    }

    /// Extracts JSON from a response that might be wrapped in markdown code blocks
    private func extractJSON(from response: String) -> String {
        // Check if response is wrapped in ```json ... ```
        if let jsonStart = response.range(of: "```json")?.upperBound,
           let jsonEnd = response.range(of: "```", range: jsonStart..<response.endIndex)?.lowerBound {
            return String(response[jsonStart..<jsonEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Check if response is wrapped in ``` ... ```
        if let codeStart = response.range(of: "```")?.upperBound,
           let codeEnd = response.range(of: "```", range: codeStart..<response.endIndex)?.lowerBound {
            return String(response[codeStart..<codeEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Return as-is if no code blocks found
        return response.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - NoteType Extension

extension NoteType {
    /// Creates a NoteType from a string identifier
    static func from(identifier: String) -> NoteType? {
        let normalized = identifier.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "#"))

        switch normalized {
        case "todo", "task", "checklist":
            return .todo
        case "meeting", "minutes":
            return .meeting
        case "email", "mail":
            return .email
        case "contact", "business card", "businesscard":
            return .contact
        case "recipe":
            return .recipe
        case "journal", "diary":
            return .journal
        case "code", "snippet":
            return .general  // Code type removed, map to general
        case "project":
            return .general  // Project type removed, map to general
        case "general", "note":
            return .general
        default:
            return nil
        }
    }
}
