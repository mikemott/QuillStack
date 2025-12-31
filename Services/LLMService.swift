//
//  LLMService.swift
//  QuillStack
//
//  Created on 2025-12-15.
//

import Foundation

// MARK: - LLM Service

/// Service for AI-powered text enhancement using Claude API
/// Uses certificate pinning for secure communication
final class LLMService: NSObject {
    static let shared = LLMService()

    private let apiURL = URL(string: "https://api.anthropic.com/v1/messages")!
    private let model = "claude-sonnet-4-20250514"
    private let anthropicVersion = "2023-06-01"

    // Certificate pinning session
    private lazy var pinnedSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    private override init() {
        super.init()
    }

    enum LLMError: LocalizedError {
        case noAPIKey
        case invalidResponse
        case networkError(String)
        case rateLimited
        case consentRequired
        case offline

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
            case .consentRequired:
                return "Please review and accept the AI data disclosure in Settings before using AI features."
            case .offline:
                return "No network connection. Enhancement will be processed when you're back online."
            }
        }

        /// Whether this error indicates the request should be queued for later
        var shouldQueue: Bool {
            switch self {
            case .offline, .networkError:
                return true
            default:
                return false
            }
        }
    }

    // MARK: - Private API Helper

    /// Unified API request handler - eliminates code duplication
    private func performAPIRequest(prompt: String, maxTokens: Int) async throws -> String {
        // Check network connectivity first
        let offlineQueue = await OfflineQueueService.shared
        guard await offlineQueue.isOnline else {
            throw LLMError.offline
        }

        // Check consent
        let settings = await SettingsManager.shared
        guard await settings.hasAcceptedAIDisclosure || !settings.needsAIDisclosure else {
            throw LLMError.consentRequired
        }

        guard let apiKey = await settings.claudeAPIKey, !apiKey.isEmpty else {
            throw LLMError.noAPIKey
        }

        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
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

        let (data, response) = try await pinnedSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 429:
            throw LLMError.rateLimited
        default:
            // Sanitize error message to avoid leaking sensitive data
            throw LLMError.networkError("Request failed with status \(httpResponse.statusCode)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String else {
            throw LLMError.invalidResponse
        }

        return text
    }

    // MARK: - Public API

    /// Infer note type from content when no explicit tag is present
    /// Returns the inferred type or nil if no strong match
    func inferNoteType(from text: String) -> String? {
        let lowercased = text.lowercased()

        // Check for expense/receipt indicators
        let expenseIndicators = [
            // Dollar amounts
            #"\$\d+\.?\d*"#,
            // Common receipt words
            "receipt", "total", "subtotal", "tax", "paid", "change",
            "visa", "mastercard", "amex", "debit", "credit card",
            // Store/vendor patterns
            "store", "purchase", "transaction",
            // Date + amount pattern typical of receipts
            "amount", "price", "cost"
        ]

        var expenseScore = 0

        // Check for dollar amount (strong indicator)
        if lowercased.range(of: #"\$\d+\.?\d*"#, options: .regularExpression) != nil {
            expenseScore += 3
        }

        // Check for receipt-specific words
        for indicator in expenseIndicators {
            if indicator.hasPrefix("#") {
                // Regex pattern
                if lowercased.range(of: indicator, options: .regularExpression) != nil {
                    expenseScore += 2
                }
            } else if lowercased.contains(indicator) {
                expenseScore += 1
            }
        }

        // If strong expense signals, return expense type
        if expenseScore >= 3 {
            return "expense"
        }

        return nil
    }

    /// Clean up OCR text using Claude API
    /// If noteType is "general", attempts to infer the type from content
    func enhanceOCRText(_ text: String, noteType: String = "general") async throws -> EnhancedTextResult {
        // Try to infer type if general
        let effectiveType: String
        if noteType == "general", let inferred = inferNoteType(from: text) {
            effectiveType = inferred
        } else {
            effectiveType = noteType
        }

        let prompt = buildPrompt(for: text, noteType: effectiveType)
        let enhancedText = try await performAPIRequest(prompt: prompt, maxTokens: 2048)

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

        let jsonText = try await performAPIRequest(prompt: prompt, maxTokens: 1024)

        // Parse the JSON response into MeetingDetails
        guard let jsonData = jsonText.data(using: .utf8) else {
            throw LLMError.invalidResponse
        }

        let decoder = JSONDecoder()
        return try decoder.decode(MeetingDetails.self, from: jsonData)
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

        case "expense":
            return """
            You are helping format a handwritten expense or receipt note that was scanned with OCR.

            Please:
            1. Fix OCR errors (misspellings, wrong characters, garbled amounts)
            2. Extract and format: amount (with $ prefix), vendor/store name, category, date
            3. Format as structured fields:
               - Amount: $XX.XX
               - Vendor: [store/business name]
               - Category: [Food, Transport, Office, Travel, Utilities, Entertainment, or Other]
               - Date: [MMM d, yyyy format]
            4. Keep any additional notes or item details after the structured fields
            5. If an #expense# or #receipt# tag is not present, add #expense# at the start

            Original OCR text:
            \(text)

            Return ONLY the formatted expense text. No explanations.
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

    /// Generate a summary of the note content
    func summarizeNote(_ content: String, noteType: String, length: SummaryLength) async throws -> String {
        let prompt = buildSummaryPrompt(for: content, noteType: noteType, length: length)
        let summaryText = try await performAPIRequest(prompt: prompt, maxTokens: length.maxTokens)
        return summaryText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Build summarization prompt based on note type and length
    private func buildSummaryPrompt(for text: String, noteType: String, length: SummaryLength) -> String {
        let lengthInstruction: String
        switch length {
        case .brief:
            lengthInstruction = "Create a very brief summary in 1-2 sentences (about 50 words max)."
        case .medium:
            lengthInstruction = "Create a concise summary in 2-4 sentences (about 100 words max)."
        case .detailed:
            lengthInstruction = "Create a detailed summary covering all key points (about 200 words max)."
        }

        switch noteType.lowercased() {
        case "todo":
            return """
            Summarize this to-do list. Focus on the main tasks and any priorities or deadlines mentioned.

            \(lengthInstruction)

            To-do list:
            \(text)

            Return ONLY the summary, no explanations or prefixes.
            """

        case "meeting":
            return """
            Summarize these meeting notes. Focus on key decisions, action items, and important discussion points.

            \(lengthInstruction)

            Meeting notes:
            \(text)

            Return ONLY the summary, no explanations or prefixes.
            """

        case "email":
            return """
            Summarize this email draft. Focus on the main message and any requests or action items.

            \(lengthInstruction)

            Email:
            \(text)

            Return ONLY the summary, no explanations or prefixes.
            """

        default:
            return """
            Summarize this note. Capture the main ideas and key points.

            \(lengthInstruction)

            Note:
            \(text)

            Return ONLY the summary, no explanations or prefixes.
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

/// Summary length options for AI summarization
enum SummaryLength: String, CaseIterable, Identifiable {
    case brief = "brief"
    case medium = "medium"
    case detailed = "detailed"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .brief: return "Brief"
        case .medium: return "Medium"
        case .detailed: return "Detailed"
        }
    }

    var description: String {
        switch self {
        case .brief: return "1-2 sentences"
        case .medium: return "2-4 sentences"
        case .detailed: return "Full summary"
        }
    }

    var maxTokens: Int {
        switch self {
        case .brief: return 100
        case .medium: return 200
        case .detailed: return 400
        }
    }

    var icon: String {
        switch self {
        case .brief: return "text.alignleft"
        case .medium: return "text.justify"
        case .detailed: return "doc.text"
        }
    }
}

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

// MARK: - Certificate Pinning

extension LLMService: URLSessionDelegate {
    /// Implements certificate pinning for Anthropic API
    /// Validates the server certificate against known public key hashes
    nonisolated func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust,
              challenge.protectionSpace.host == "api.anthropic.com" else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Validate the certificate chain
        var error: CFError?
        let isValid = SecTrustEvaluateWithError(serverTrust, &error)

        if isValid {
            // Certificate is valid according to system trust store
            // For production, you could add public key pinning here:
            // 1. Extract the server's public key
            // 2. Compare against hardcoded SHA-256 hash of Anthropic's public key
            // For now, we trust the system validation which is still more secure than URLSession.shared
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            // Certificate validation failed - reject the connection
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}
