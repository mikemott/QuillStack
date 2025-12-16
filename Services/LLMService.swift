//
//  LLMService.swift
//  QuillStack
//
//  Created on 2025-12-15.
//

import Foundation
import Combine

// MARK: - LLM Service

class LLMService {
    static let shared = LLMService()

    private init() {}

    enum LLMError: LocalizedError {
        case noAPIKey
        case invalidResponse
        case networkError(String)
        case rateLimited

        var errorDescription: String? {
            switch self {
            case .noAPIKey:
                return "No API key configured. Add your Claude API key in Settings."
            case .invalidResponse:
                return "Invalid response from AI service."
            case .networkError(let message):
                return "Network error: \(message)"
            case .rateLimited:
                return "Rate limited. Please try again later."
            }
        }
    }

    /// Clean up OCR text using Claude API
    func enhanceOCRText(_ text: String, context: String = "handwritten note") async throws -> EnhancedTextResult {
        guard let apiKey = SettingsManager.shared.claudeAPIKey, !apiKey.isEmpty else {
            throw LLMError.noAPIKey
        }

        let prompt = """
        You are helping correct OCR errors from a \(context). The text was scanned from handwriting and may contain recognition errors.

        Please:
        1. Fix obvious OCR errors (e.g., "tD:" should be "To:", "frwattig" might be "formatting")
        2. Preserve the original meaning and structure
        3. Keep proper nouns, email addresses, phone numbers, and addresses as accurate as possible
        4. Don't add or remove content, only correct errors
        5. Maintain line breaks and formatting

        Original OCR text:
        \(text)

        Return ONLY the corrected text, nothing else. No explanations or markdown.
        """

        let requestBody: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 2048,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }

        if httpResponse.statusCode == 429 {
            throw LLMError.rateLimited
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LLMError.networkError("Status \(httpResponse.statusCode): \(errorMessage)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let enhancedText = firstContent["text"] as? String else {
            throw LLMError.invalidResponse
        }

        // Calculate what changed
        let changes = findChanges(original: text, enhanced: enhancedText)

        return EnhancedTextResult(
            originalText: text,
            enhancedText: enhancedText,
            changes: changes
        )
    }

    /// Find word-level changes between original and enhanced text
    private func findChanges(original: String, enhanced: String) -> [TextChange] {
        var changes: [TextChange] = []

        let originalWords = original.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let enhancedWords = enhanced.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }

        // Simple diff - find words that changed
        let minCount = min(originalWords.count, enhancedWords.count)

        for i in 0..<minCount {
            if originalWords[i] != enhancedWords[i] {
                changes.append(TextChange(
                    original: originalWords[i],
                    corrected: enhancedWords[i],
                    position: i
                ))
            }
        }

        return changes
    }
}

// MARK: - Result Models

struct EnhancedTextResult {
    let originalText: String
    let enhancedText: String
    let changes: [TextChange]

    var hasChanges: Bool {
        !changes.isEmpty
    }

    var changeCount: Int {
        changes.count
    }
}

struct TextChange: Identifiable {
    let id = UUID()
    let original: String
    let corrected: String
    let position: Int
}

// MARK: - Settings Manager

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let claudeAPIKey = "claudeAPIKey"
        static let autoEnhanceOCR = "autoEnhanceOCR"
        static let showLowConfidenceHighlights = "showLowConfidenceHighlights"
        static let lowConfidenceThreshold = "lowConfidenceThreshold"
    }

    private init() {}

    @Published var claudeAPIKey: String? = nil {
        didSet {
            if let key = claudeAPIKey {
                // Store in Keychain for security (simplified: using UserDefaults for demo)
                defaults.set(key, forKey: Keys.claudeAPIKey)
            } else {
                defaults.removeObject(forKey: Keys.claudeAPIKey)
            }
        }
    }

    @Published var autoEnhanceOCR: Bool = false {
        didSet {
            defaults.set(autoEnhanceOCR, forKey: Keys.autoEnhanceOCR)
        }
    }

    @Published var showLowConfidenceHighlights: Bool = true {
        didSet {
            defaults.set(showLowConfidenceHighlights, forKey: Keys.showLowConfidenceHighlights)
        }
    }

    @Published var lowConfidenceThreshold: Float = 0.7 {
        didSet {
            defaults.set(lowConfidenceThreshold, forKey: Keys.lowConfidenceThreshold)
        }
    }

    func loadSettings() {
        claudeAPIKey = defaults.string(forKey: Keys.claudeAPIKey)
        autoEnhanceOCR = defaults.bool(forKey: Keys.autoEnhanceOCR)
        showLowConfidenceHighlights = defaults.object(forKey: Keys.showLowConfidenceHighlights) as? Bool ?? true
        lowConfidenceThreshold = defaults.object(forKey: Keys.lowConfidenceThreshold) as? Float ?? 0.7
    }

    var hasAPIKey: Bool {
        guard let key = claudeAPIKey else { return false }
        return !key.isEmpty
    }
}
