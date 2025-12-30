//
//  PromptRefinerService.swift
//  QuillStack
//
//  Created on 2025-12-30.
//

import Foundation

// MARK: - Refined Prompt Model

/// Structured output from LLM refinement of handwritten notes
struct RefinedPrompt: Codable {
    let title: String
    let body: String
    let suggestedLabels: [String]
    let originalText: String

    /// Returns the full markdown body for GitHub issue
    var fullIssueBody: String {
        """
        \(body)

        ---
        *Created from handwritten notes via QuillStack*
        """
    }
}

// MARK: - Prompt Refiner Service

/// Transforms rough handwritten notes into structured GitHub issue format
@MainActor
final class PromptRefinerService {
    static let shared = PromptRefinerService()

    private let llmService = LLMService.shared

    private init() {}

    // MARK: - Public API

    /// Transforms handwritten notes into a structured GitHub issue
    /// - Parameters:
    ///   - rawText: The OCR-processed text from handwritten notes
    ///   - projectContext: Optional context about the project (e.g., tech stack, conventions)
    /// - Returns: A structured RefinedPrompt suitable for GitHub issue creation
    func refineToGitHubIssue(rawText: String, projectContext: String? = nil) async throws -> RefinedPrompt {
        let prompt = buildRefinementPrompt(rawText: rawText, projectContext: projectContext)

        // Use the LLM service's API infrastructure
        let response = try await performRefinement(prompt: prompt)

        // Parse the response into structured format
        return try parseRefinedPrompt(from: response, originalText: rawText)
    }

    // MARK: - Private Methods

    private func buildRefinementPrompt(rawText: String, projectContext: String?) -> String {
        let contextSection = projectContext.map { """

        Project context:
        \($0)
        """ } ?? ""

        return """
        You are helping transform handwritten feature requests or bug reports into well-structured GitHub issues.

        Given rough handwritten notes (which may contain OCR errors), produce a structured GitHub issue with:

        1. **Title**: A clear, concise title in imperative mood (e.g., "Add dark mode toggle", "Fix login timeout issue")
        2. **Description**: A clear explanation of the feature or bug
        3. **Acceptance Criteria**: A bulleted checklist of requirements (if applicable)
        4. **Technical Notes**: Any implementation hints from the notes (if present)
        5. **Labels**: Suggest 1-3 appropriate labels from: enhancement, bug, documentation, ui, performance, refactor, security, testing

        Guidelines:
        - Keep the original intent - don't over-engineer or add scope
        - Fix obvious OCR errors in the text
        - Use Markdown formatting suitable for GitHub
        - If the note is vague, create reasonable acceptance criteria based on common patterns
        - For bugs, include "Steps to Reproduce" if mentioned
        \(contextSection)

        Original handwritten notes:
        ---
        \(rawText)
        ---

        Respond in JSON format with this exact structure:
        {
            "title": "Issue title here",
            "body": "Full markdown body for the issue",
            "suggestedLabels": ["label1", "label2"]
        }

        Return ONLY valid JSON, no markdown code blocks or explanations.
        """
    }

    private func performRefinement(prompt: String) async throws -> String {
        // Check network connectivity first
        let offlineQueue = OfflineQueueService.shared
        guard offlineQueue.isOnline else {
            throw LLMService.LLMError.offline
        }

        // Check for API key
        let settings = SettingsManager.shared
        guard settings.hasAcceptedAIDisclosure || !settings.needsAIDisclosure else {
            throw LLMService.LLMError.consentRequired
        }

        guard let apiKey = settings.claudeAPIKey, !apiKey.isEmpty else {
            throw LLMService.LLMError.noAPIKey
        }

        // Build request
        let apiURL = URL(string: "https://api.anthropic.com/v1/messages")!
        let model = "claude-sonnet-4-20250514"
        let anthropicVersion = "2023-06-01"

        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 2048,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(anthropicVersion, forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMService.LLMError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 429:
            throw LLMService.LLMError.rateLimited
        default:
            throw LLMService.LLMError.networkError("Request failed with status \(httpResponse.statusCode)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String else {
            throw LLMService.LLMError.invalidResponse
        }

        return text
    }

    private func parseRefinedPrompt(from response: String, originalText: String) throws -> RefinedPrompt {
        // Try to parse as JSON
        guard let jsonData = response.data(using: .utf8) else {
            throw LLMService.LLMError.invalidResponse
        }

        struct LLMResponse: Codable {
            let title: String
            let body: String
            let suggestedLabels: [String]
        }

        do {
            let decoded = try JSONDecoder().decode(LLMResponse.self, from: jsonData)
            return RefinedPrompt(
                title: decoded.title,
                body: decoded.body,
                suggestedLabels: decoded.suggestedLabels,
                originalText: originalText
            )
        } catch {
            // Fallback: Try to extract manually if JSON parsing fails
            return try extractFallbackPrompt(from: response, originalText: originalText)
        }
    }

    /// Fallback extraction when JSON parsing fails
    private func extractFallbackPrompt(from response: String, originalText: String) throws -> RefinedPrompt {
        // Extract title from first line or heading
        let lines = response.components(separatedBy: .newlines).filter { !$0.isEmpty }

        guard let firstLine = lines.first else {
            throw LLMService.LLMError.invalidResponse
        }

        // Remove markdown heading syntax if present
        let title = firstLine
            .replacingOccurrences(of: "^#+\\s*", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Body is everything after the title
        let body = lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

        // Try to detect labels from content
        let suggestedLabels = detectLabels(from: response)

        return RefinedPrompt(
            title: title.isEmpty ? "Feature Request" : title,
            body: body.isEmpty ? response : body,
            suggestedLabels: suggestedLabels,
            originalText: originalText
        )
    }

    /// Detect appropriate labels based on content keywords
    private func detectLabels(from text: String) -> [String] {
        let lowercased = text.lowercased()
        var labels: [String] = []

        // Enhancement indicators
        if lowercased.contains("add") || lowercased.contains("new") || lowercased.contains("feature") || lowercased.contains("implement") {
            labels.append("enhancement")
        }

        // Bug indicators
        if lowercased.contains("fix") || lowercased.contains("bug") || lowercased.contains("error") || lowercased.contains("broken") {
            labels.append("bug")
        }

        // UI indicators
        if lowercased.contains("button") || lowercased.contains("ui") || lowercased.contains("design") || lowercased.contains("screen") || lowercased.contains("view") {
            labels.append("ui")
        }

        // Documentation indicators
        if lowercased.contains("doc") || lowercased.contains("readme") || lowercased.contains("comment") {
            labels.append("documentation")
        }

        // Performance indicators
        if lowercased.contains("perf") || lowercased.contains("slow") || lowercased.contains("fast") || lowercased.contains("optimize") {
            labels.append("performance")
        }

        // Default to enhancement if no labels detected
        if labels.isEmpty {
            labels.append("enhancement")
        }

        return Array(labels.prefix(3))
    }
}
