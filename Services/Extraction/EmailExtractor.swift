import Foundation

/// Extracts structured email data from note content using LLM with heuristic fallback.
struct EmailExtractor {

    /// Extracts email data from note content
    static func extractEmail(from content: String) async throws -> ExtractedEmail {
        // Try LLM extraction first if API key is available
        let settings = await SettingsManager.shared
        if let apiKey = await settings.claudeAPIKey, !apiKey.isEmpty {
            do {
                return try await extractWithLLM(from: content)
            } catch {
                print("[EmailExtractor] LLM extraction failed: \(error.localizedDescription), falling back to heuristic")
            }
        }

        // Fall back to heuristic extraction
        return extractWithHeuristics(from: content)
    }

    // MARK: - LLM Extraction

    private static func extractWithLLM(from content: String) async throws -> ExtractedEmail {
        let prompt = """
        Extract email information from this handwritten note. Return valid JSON with this exact structure:
        {
            "to": "recipient@example.com or null",
            "cc": "cc@example.com or null",
            "bcc": "bcc@example.com or null",
            "subject": "email subject or null",
            "body": "email body text or null"
        }

        Guidelines:
        - Extract recipient email addresses (support multiple comma-separated)
        - Extract CC and BCC if mentioned
        - Extract subject line (often after "Subject:", "Re:", "Subj:")
        - Extract body text (main content)
        - Preserve paragraph breaks in body

        Note content:
        \(content)
        """

        let response = try await LLMService.shared.performRequest(prompt: prompt, maxTokens: 500)
        let cleanedResponse = cleanJSONResponse(response)
        guard let jsonData = cleanedResponse.data(using: .utf8) else {
            throw EmailExtractionError.invalidResponse
        }

        let decoder = JSONDecoder()
        return try decoder.decode(ExtractedEmail.self, from: jsonData)
    }

    /// Clean JSON response by removing markdown code blocks
    private static func cleanJSONResponse(_ response: String) -> String {
        var cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)

        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }

        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Heuristic Extraction

    private static func extractWithHeuristics(from content: String) -> ExtractedEmail {
        let lines = content.components(separatedBy: .newlines)

        var to: String?
        var cc: String?
        var bcc: String?
        var subject: String?
        var bodyLines: [String] = []
        var inBody = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else {
                if inBody {
                    bodyLines.append("")  // Preserve blank lines in body
                }
                continue
            }

            let lowercased = trimmed.lowercased()

            // Extract To field
            if to == nil, let extracted = extractField(from: trimmed, lowercased: lowercased, prefixes: ["to:", "to ", "recipient:", "send to:"]) {
                to = extracted
                continue
            }

            // Extract CC field
            if cc == nil, let extracted = extractField(from: trimmed, lowercased: lowercased, prefixes: ["cc:", "cc ", "copy:"]) {
                cc = extracted
                continue
            }

            // Extract BCC field
            if bcc == nil, let extracted = extractField(from: trimmed, lowercased: lowercased, prefixes: ["bcc:", "bcc "]) {
                bcc = extracted
                continue
            }

            // Extract Subject field
            if subject == nil, let extracted = extractField(from: trimmed, lowercased: lowercased, prefixes: ["subject:", "subj:", "re:", "regarding:"]) {
                subject = extracted
                inBody = true
                continue
            }

            // Start body detection
            if !inBody {
                // Check for email-like indicators
                if lowercased.contains("dear") || lowercased.contains("hi ") || lowercased.contains("hello") {
                    inBody = true
                }
            }

            // Collect body
            if inBody {
                bodyLines.append(trimmed)
            }
        }

        return ExtractedEmail(
            to: to,
            cc: cc,
            bcc: bcc,
            subject: subject,
            body: bodyLines.isEmpty ? nil : bodyLines.joined(separator: "\n")
        )
    }

    // MARK: - Helpers

    private static func extractField(from line: String, lowercased: String, prefixes: [String]) -> String? {
        for prefix in prefixes {
            if lowercased.hasPrefix(prefix) {
                let value = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                return value.isEmpty ? nil : value
            }
        }
        return nil
    }
}

// MARK: - Errors

enum EmailExtractionError: LocalizedError {
    case noAPIKey
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No API key configured"
        case .invalidResponse:
            return "Invalid response from AI service"
        }
    }
}

// MARK: - Data Model

struct ExtractedEmail: Codable, Sendable, Equatable {
    let to: String?
    let cc: String?
    let bcc: String?
    let subject: String?
    let body: String?

    var hasMinimumData: Bool {
        to != nil || subject != nil || body != nil
    }

    var toRecipients: [String] {
        guard let to = to else { return [] }
        return to.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    var ccRecipients: [String] {
        guard let cc = cc else { return [] }
        return cc.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    var bccRecipients: [String] {
        guard let bcc = bcc else { return [] }
        return bcc.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }
}
