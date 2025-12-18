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
    func enhanceOCRText(_ text: String, noteType: String = "general") async throws -> EnhancedTextResult {
        guard let apiKey = SettingsManager.shared.claudeAPIKey, !apiKey.isEmpty else {
            throw LLMError.noAPIKey
        }

        let prompt = buildPrompt(for: text, noteType: noteType)

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

    /// Extract structured meeting details from text using LLM
    func extractMeetingDetails(from text: String) async throws -> MeetingDetails {
        guard let apiKey = SettingsManager.shared.claudeAPIKey, !apiKey.isEmpty else {
            throw LLMError.noAPIKey
        }

        let prompt = """
        Extract meeting details from this handwritten note that was scanned with OCR. The text may have some recognition errors.

        Please extract the following information and return it as JSON:
        - subject: The main topic or purpose of the meeting (string)
        - attendees: List of people attending, use first names only when possible (array of strings)
        - date: The meeting date if mentioned, in YYYY-MM-DD format if possible, or natural language like "tomorrow" (string or null)
        - time: The meeting time if mentioned, e.g. "2:00 PM" or "14:00" (string or null)
        - location: Where the meeting is held if mentioned (string or null)
        - notes: Any additional details, agenda items, or discussion points as plain text (string)

        For attendees:
        - Extract just first names when you see full names (e.g., "John Smith" → "John")
        - If you see email addresses, extract the name part (e.g., "john.smith@company.com" → "John")
        - Clean up any OCR errors in names

        Original text:
        \(text)

        Return ONLY valid JSON, no markdown code blocks, no explanations. Example format:
        {"subject":"Q4 Planning","attendees":["Mike","Sarah"],"date":"2024-12-20","time":"2:00 PM","location":"Conference Room A","notes":"Review budget\\nDiscuss timeline"}
        """

        let requestBody: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 1024,
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
              let jsonText = firstContent["text"] as? String else {
            throw LLMError.invalidResponse
        }

        // Parse the JSON response into MeetingDetails
        guard let jsonData = jsonText.data(using: .utf8) else {
            throw LLMError.invalidResponse
        }

        let decoder = JSONDecoder()
        let meetingDetails = try decoder.decode(MeetingDetails.self, from: jsonData)

        return meetingDetails
    }

    /// Build enhancement prompt based on note type
    private func buildPrompt(for text: String, noteType: String) -> String {
        switch noteType.lowercased() {
        case "email":
            return """
            You are helping format a handwritten email that was scanned with OCR. The text may have recognition errors and formatting issues.

            Please:
            1. Fix OCR errors (misspellings, wrong characters)
            2. Merge lines that were incorrectly split by OCR (e.g., "Return\\nto sender" → "Return to sender")
            3. Add appropriate punctuation:
               - Greetings should have commas (e.g., "Hello" → "Hello,")
               - Sentences should end with periods
               - Closings should have punctuation (e.g., "Thanks" → "Thanks!")
            4. Preserve the email structure: greeting, body paragraphs, closing, signature
            5. Keep the #EMAIL# tag, To:, and Subject: lines intact
            6. Preserve bullet points and lists
            7. Keep email addresses exactly as written

            Original OCR text:
            \(text)

            Return ONLY the corrected and formatted email text. No explanations.
            """

        case "todo":
            return """
            You are helping correct a handwritten to-do list that was scanned with OCR.

            Please:
            1. Fix OCR errors (misspellings, wrong characters)
            2. Preserve checkbox markers like [ ], [x], •, -, etc.
            3. Keep each task item on its own line
            4. Fix punctuation within tasks if needed
            5. Keep the #TODO# or similar tag if present
            6. Don't merge lines - each task should stay separate

            Original OCR text:
            \(text)

            Return ONLY the corrected text. No explanations.
            """

        case "meeting":
            return """
            You are helping correct handwritten meeting notes that were scanned with OCR.

            Please:
            1. Fix OCR errors (misspellings, wrong characters)
            2. Preserve section headers (Attendees, Agenda, Action Items, etc.)
            3. Fix punctuation and add periods where sentences end
            4. Merge lines that were incorrectly split mid-sentence
            5. Keep bullet points and numbered lists intact
            6. Preserve names and proper nouns carefully

            Original OCR text:
            \(text)

            Return ONLY the corrected text. No explanations.
            """

        default:
            return """
            You are helping correct OCR errors from a handwritten note. The text was scanned from handwriting and may contain recognition errors.

            Please:
            1. Fix obvious OCR errors (misspellings, wrong characters)
            2. Preserve the original meaning and structure
            3. Keep proper nouns, email addresses, phone numbers as accurate as possible
            4. Fix punctuation where clearly missing
            5. Merge lines that were incorrectly split mid-sentence
            6. Don't add or remove content, only correct errors

            Original OCR text:
            \(text)

            Return ONLY the corrected text, nothing else. No explanations.
            """
        }
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

/// Structured meeting details extracted by LLM
struct MeetingDetails: Codable {
    let subject: String
    let attendees: [String]
    let date: String?
    let time: String?
    let location: String?
    let notes: String

    /// Attempts to parse the date string into a Date object
    /// If the parsed date is in the past, assumes next year
    var parsedDate: Date? {
        guard let dateStr = date else { return nil }

        let formatter = DateFormatter()
        let calendar = Calendar.current

        // Try relative dates first
        let lowercased = dateStr.lowercased()
        if lowercased.contains("today") {
            return Date()
        } else if lowercased.contains("tomorrow") {
            return calendar.date(byAdding: .day, value: 1, to: Date())
        }

        // Formats that include explicit year
        let formatsWithYear = [
            "yyyy-MM-dd",
            "MM/dd/yyyy",
            "MM/dd/yy",
            "MMMM d, yyyy",
            "MMM d, yyyy"
        ]

        // Formats without year (assume current/next year)
        let formatsWithoutYear = [
            "MMMM d",
            "MMM d",
            "MM/dd",
            "M/d"
        ]

        // Try formats with explicit year first
        for format in formatsWithYear {
            formatter.dateFormat = format
            if let parsedDate = formatter.date(from: dateStr) {
                return adjustToFutureIfNeeded(parsedDate)
            }
        }

        // Try formats without year - set to current year first
        let currentYear = calendar.component(.year, from: Date())
        for format in formatsWithoutYear {
            formatter.dateFormat = format
            if let parsedDate = formatter.date(from: dateStr) {
                // The parsed date will have year 2000 or similar, so we need to set the correct year
                var components = calendar.dateComponents([.month, .day], from: parsedDate)
                components.year = currentYear
                if let dateThisYear = calendar.date(from: components) {
                    return adjustToFutureIfNeeded(dateThisYear)
                }
            }
        }

        return nil
    }

    /// If the date is in the past (more than 1 day ago), assume next year
    private func adjustToFutureIfNeeded(_ date: Date) -> Date {
        let calendar = Calendar.current
        let oneDayAgo = calendar.date(byAdding: .day, value: -1, to: Date())!

        if date < oneDayAgo {
            // Date is in the past, add a year
            return calendar.date(byAdding: .year, value: 1, to: date) ?? date
        }
        return date
    }
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

    private init() {
        // Load settings from UserDefaults on init
        loadSettings()
    }

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
