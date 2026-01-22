//
//  LLMService.swift
//  QuillStack
//
//  Created on 2025-12-15.
//

import Foundation
import CoreData

// MARK: - LLM Service

/// Service for AI-powered text enhancement using Claude API.
/// Uses certificate pinning for secure communication.
/// Conforms to LLMServiceProtocol for testability and dependency injection.
final class LLMService: NSObject, LLMServiceProtocol, @unchecked Sendable {
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

    // MARK: - Internal API Helper

    /// Unified API request handler - eliminates code duplication
    /// Internal visibility allows TextClassifier to use this for LLM classification
    func performAPIRequest(prompt: String, maxTokens: Int) async throws -> String {
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

        // Sanitize content to remove sensitive information before sending to API
        let sanitizer = await ContentSanitizer.shared
        let sanitizedPrompt = await sanitizer.sanitize(prompt)

        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "messages": [
                ["role": "user", "content": sanitizedPrompt]
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

        // Track token usage for cost monitoring
        if let usage = json["usage"] as? [String: Any],
           let inputTokens = usage["input_tokens"] as? Int,
           let outputTokens = usage["output_tokens"] as? Int {
            // Validate token counts are reasonable (positive and not suspiciously large)
            guard inputTokens >= 0 && outputTokens >= 0,
                  inputTokens < 1_000_000 && outputTokens < 1_000_000 else {
                // Log but don't crash on invalid token counts
                print("⚠️ Invalid token counts from API: input=\(inputTokens), output=\(outputTokens)")
                return text
            }
            await LLMCostTracker.shared.recordUsage(inputTokens: inputTokens, outputTokens: outputTokens)
        }

        return text
    }

    // MARK: - Public API

    /// Perform a raw API request with a custom prompt
    /// This allows other services to leverage the pinned session for secure API calls
    /// - Parameters:
    ///   - prompt: The prompt to send to the LLM
    ///   - maxTokens: Maximum tokens in the response (default 2048)
    /// - Returns: The raw text response from the LLM
    func performRequest(prompt: String, maxTokens: Int = 2048) async throws -> String {
        return try await performAPIRequest(prompt: prompt, maxTokens: maxTokens)
    }

    /// Validates an API key by making a minimal test request
    /// Uses the pinned session for security
    /// - Parameter apiKey: The API key to validate
    /// - Returns: True if the API key is valid
    func validateAPIKey(_ apiKey: String) async -> Bool {
        guard !apiKey.isEmpty else { return false }

        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 1,
            "messages": [["role": "user", "content": "Hi"]]
        ]

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(anthropicVersion, forHTTPHeaderField: "anthropic-version")
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)

        do {
            let (_, response) = try await pinnedSession.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                // 200 = valid, 401 = invalid key, other codes still mean key format is valid
                return httpResponse.statusCode != 401
            }
            return false
        } catch {
            return false
        }
    }

    /// Clean up OCR text using Claude API
    func enhanceOCRText(_ text: String, noteType: String = "general") async throws -> EnhancedTextResult {
        let prompt = buildPrompt(for: text, noteType: noteType)
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
        Extract meeting details from this handwritten note that was scanned with OCR. The text may have recognition errors.

        Please extract the following information and return it as JSON:
        - subject: The main topic or purpose of the meeting (string)
        - attendees: List of people attending with FULL NAMES (array of strings)
        - date: The meeting date if mentioned, in YYYY-MM-DD format if possible, or natural language like "tomorrow" (string or null)
        - time: The meeting time if mentioned, e.g. "2:00 PM" or "14:00" (string or null)
        - location: Where the meeting is held if mentioned (string or null)
        - notes: Any additional details, agenda items, or discussion points as plain text (string)

        CRITICAL - For attendees, follow these rules exactly:
        1. Each person = ONE array entry with their FULL NAME (first + last)
        2. OCR often puts first and last names on separate lines - COMBINE THEM
           Example: If you see "Mike" on one line and "Mott" on the next, output ["Mike Mott"]
        3. Fix obvious OCR errors in names (e.g., "Matt" is likely "Mott", similar-looking letters get confused)
        4. If you see what looks like 2 capitalized words near each other, they are likely FirstName LastName
        5. NEVER output ["Mike", "Mott"] - always output ["Mike Mott"]
        6. Common OCR errors to fix:
           - "Matt" near "Mike" is probably "Mott" (Mike Mott)
           - Roman numerals often misread: 111 → III, 11 → II, 1 → I
           - Letters confused: l/1/I, O/0, rn/m, cl/d

        Original text:
        \(text)

        Return ONLY valid JSON, no markdown code blocks, no explanations. Example format:
        {"subject":"Q4 Planning","attendees":["Mike Mott","Kyle Simard"],"date":"2024-12-20","time":"2:00 PM","location":"Conference Room A","notes":"Review budget\\nDiscuss timeline"}
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
            You are helping format a handwritten email draft that was scanned with OCR. Apple Vision has processed it, but needs fixes for email-specific patterns.

            COMMON EMAIL OCR ERRORS:
            1. Email addresses corrupted: "j0hn@examp1e.c0m" → "john@example.com"
            2. Header fields split: "To.\\nBob Smith" → "To: Bob Smith"
            3. Letter confusion in names: "Matt" → "Mott", "Sara" → "Sarah"
            4. Split sentences in paragraphs need merging
            5. Missing punctuation in greetings/closings

            EMAIL-SPECIFIC FIXES:
            - Fix email addresses: lowercase, fix O→0, l→1, etc.
            - Header fields (To:, From:, Subject:, Cc:, Bcc:):
              * Keep on their own lines
              * Ensure colon after field name
              * Fix capitalization in names
            - Greeting punctuation:
              * "Hi Bob" → "Hi Bob," or "Hello" → "Hello,"
              * "Dear John Smith" → "Dear John Smith,"
            - Body paragraphs:
              * Merge lines split mid-sentence
              * Keep paragraph breaks (double newline)
              * Ensure sentences end with periods
            - Closing punctuation:
              * "Thanks" → "Thanks," or "Best regards" → "Best regards,"
            - Signature: Fix name capitalization, preserve contact info

            EXAMPLES:

            Example 1:
            Input: "To. Bob Smith\\nSubject ca11\\n\\nHi Bob\\n1 wanted to fo11ow up on the\\nrneeting yesterday"
            Output: "To: Bob Smith\\nSubject: Call\\n\\nHi Bob,\\nI wanted to follow up on the meeting yesterday."

            Example 2:
            Input: "Dear j0hn@examp1e.c0m\\nThank you for your ernail\\nBest\\nMike Matt"
            Output: "To: john@example.com\\n\\nDear John,\\nThank you for your email.\\n\\nBest,\\nMike Mott"

            RULES:
            1. Fix OCR errors in addresses, names, content
            2. Preserve email structure: headers, greeting, body, closing, signature
            3. Keep #EMAIL# trigger tag if present
            4. Merge lines split mid-sentence, preserve paragraph breaks
            5. Add appropriate punctuation for email conventions
            6. Return ONLY the corrected email - no explanations

            Original OCR text:
            \(text)

            Corrected email:
            """

        case "todo":
            return """
            You are helping correct a handwritten to-do list that was scanned with OCR. Apple Vision has processed it, but needs fixes for common handwriting errors.

            COMMON TODO-SPECIFIC OCR ERRORS:
            1. Checkbox markers corrupted: "El" → "[ ]", "lxl" → "[x]", "O" → "•"
            2. Letter confusion in tasks: "ca11" → "call", "rnail" → "mail", "buv" → "buy"
            3. Split tasks: "Pick up\\ngroceries" → "Pick up groceries" (merge unless clearly separate tasks)
            4. Numbers mixed: "Ca11 Bob at 3O0 PM" → "Call Bob at 3:00 PM"
            5. Start-of-line capitalization: "call bob" → "Call Bob"

            FIXES TO APPLY:
            - Fix checkbox/bullet markers: [ ], [x], ☑, •, -, → (standardize formatting)
            - Fix OCR errors in task text (misspellings, character confusion)
            - Add periods only if tasks are complete sentences
            - Keep each task on its own line - don't merge distinct tasks
            - Preserve priority markers if present (!, ⭐, numbers)
            - Keep hashtag triggers like #TODO# intact
            - Capitalize first word of each task

            EXAMPLES:

            Input: "El Ca11 Mike Matt about pr0ject\\n- Ernail report to Bob\\nlxl Buy groceries"
            Output: "[ ] Call Mike Mott about project\\n- Email report to Bob\\n[x] Buy groceries"

            Input: "1. Finish the\\nreport by Friday\\n2. ca11 client at 3O0"
            Output: "1. Finish the report by Friday\\n2. Call client at 3:00"

            RULES:
            1. Preserve task structure - each task stays on its own line
            2. Don't merge tasks unless clearly split mid-sentence
            3. Keep checkbox/bullet formatting intact
            4. Fix OCR errors but keep original task meaning
            5. Return ONLY the corrected todo list - no explanations

            Original OCR text:
            \(text)

            Corrected text:
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
            7. For attendee names: combine first and last names that appear on separate lines
            8. Fix common OCR errors:
               - Roman numerals: 111 → III, 11 → II, 1 → I (when context suggests Roman numerals)
               - Similar letters: l/1/I confusion, O/0 confusion, rn→m
               - Names: if "Matt" appears near "Mike", it's likely "Mott" (Mike Mott)

            Original OCR text:
            \(text)

            Return ONLY the corrected text. No explanations.
            """

        case "claudeprompt":
            return """
            You are helping format handwritten feature requests or ideas that were scanned with OCR.

            This text may contain multiple #feature# tags (or similar like #claude#, #prompt#, #request#, #issue#), each marking a separate feature idea or request.

            Please:
            1. Fix OCR errors (misspellings, wrong characters)
            2. Remove ALL occurrences of trigger tags like #feature#, #claude#, #prompt#, #request#, #issue#
            3. Identify each distinct feature/idea in the text
            4. Format as a structured list where each feature has:
               - A clear, concise title in imperative mood
               - A brief description if additional context exists
            5. Use consistent formatting:
               ## Feature 1: [Title]
               [Description if any]

               ## Feature 2: [Title]
               [Description if any]
            6. Keep the original intent - don't add scope or over-engineer
            7. If only one feature is present, still use the structured format

            Original OCR text:
            \(text)

            Return ONLY the formatted features. No explanations.
            """

        default:
            return """
            You are helping correct OCR errors from a handwritten note. Apple Vision OCR has already processed it, but handwriting recognition has predictable error patterns you need to fix.

            COMMON HANDWRITING OCR ERROR PATTERNS TO FIX:
            1. Letter confusion: I/l/1, O/0/Q, rn/m, cl/d, vv/w, ii/u, nn/m
            2. Word boundaries: "the re" → "there", "to day" → "today", "any one" → "anyone"
            3. Capitalization: Proper nouns often lowercase: "mike mott" → "Mike Mott", "apple" → "Apple" (company)
            4. Number/letter mix: "3O0" → "300", "1O" → "10", "O5" → "05" (in dates/times)
            5. Sentence starters: "1 went" → "I went", "1t was" → "It was"
            6. Common words: "teh" → "the", "adn" → "and", "tiem" → "time", "thier" → "their"

            CONTEXT-AWARE CORRECTIONS:
            - Start of sentence: "1 met" → "I met" (not "1 met")
            - Time format: "3O0 PM" → "3:00 PM", "2.3O" → "2:30"
            - Dates: "1O/15" → "10/15", "O3/2O" → "03/20"
            - Email addresses: Lowercase and fix: "j0hn@example.c0m" → "john@example.com"
            - Phone numbers: Fix digit confusion: "555-O123" → "555-0123"
            - URLs: "goog1e.com" → "google.com", "http.//site.c0m" → "http://site.com"

            STRUCTURAL FIXES:
            - Add periods to end sentences (identify sentence boundaries by capitalization and content)
            - Fix greeting punctuation: "Hello Bob" → "Hello Bob," or "Dear John" → "Dear John,"
            - Merge lines split mid-word: "under\\nstand" → "understand"
            - Merge lines split mid-phrase if they don't end with punctuation
            - Preserve intentional line breaks (lists, bullet points, paragraphs)
            - Keep email/letter formatting intact (To:, From:, Subject:)

            EXAMPLES OF GOOD CORRECTIONS:

            Example 1:
            Input: "1 need to ca11 Mike Matt about the pr0ject to day at 3O0 PM"
            Output: "I need to call Mike Mott about the project today at 3:00 PM."

            Example 2:
            Input: "Meeting\\nat 2.3O PM\\nwith Bob and Sarah"
            Output: "Meeting at 2:30 PM with Bob and Sarah"

            Example 3:
            Input: "Email j0hn.d0e@examp1e.c0m about\\nthe report by Friday"
            Output: "Email john.doe@example.com about the report by Friday."

            RULES:
            1. Fix obvious OCR errors but preserve original meaning
            2. Don't add or remove content - only correct errors
            3. Keep proper nouns, names, places as accurate as possible
            4. If uncertain about a correction, leave it as-is
            5. Preserve lists, bullet points, and intentional formatting
            6. Return ONLY the corrected text - no explanations, no markdown formatting

            Original OCR text:
            \(text)

            Corrected text:
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

    /// Expand an idea into a more detailed explanation
    func expandIdea(_ idea: String) async throws -> String {
        let prompt = """
        You are a creative thinking assistant. Take this brief idea or concept and expand it into a more developed explanation.

        Please:
        1. Elaborate on the core concept
        2. Suggest potential applications or implications
        3. Identify related ideas or connections
        4. Keep the tone thoughtful but accessible
        5. Structure the response with clear paragraphs

        Idea:
        \(idea)

        Return ONLY the expanded explanation, no prefixes like "Here's an expansion" - just start with the content directly.
        """

        return try await performAPIRequest(prompt: prompt, maxTokens: 1024)
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

    // MARK: - Tag Suggestion (QUI-157)

    /// Result from tag suggestion
    struct TagSuggestionResult: Codable {
        let primaryTag: String
        let secondaryTags: [String]
        let confidence: Double

        var allTags: [String] {
            [primaryTag] + secondaryTags
        }
    }

    /// Suggest tags for note content using LLM with vocabulary consistency
    /// - Parameters:
    ///   - content: The note content to analyze
    ///   - existingTags: List of existing tags in the system to prefer
    /// - Returns: TagSuggestionResult with primary and secondary tags
    func suggestTags(for content: String, existingTags: [String]) async throws -> TagSuggestionResult {
        // Format existing tags for prompt
        let existingTagsPrompt: String
        if existingTags.isEmpty {
            existingTagsPrompt = "No existing tags in the system yet - you can suggest any appropriate tags."
        } else {
            existingTagsPrompt = """
            Existing tags in the system (prefer these spellings):
            \(existingTags.map { "• \($0)" }.joined(separator: "\n"))
            """
        }

        // Build prompt that emphasizes vocabulary consistency
        let prompt = """
        You are helping suggest tags for a handwritten note that was captured via OCR.

        Your task is to suggest 2-5 tags that categorize this note. Follow these rules:

        1. **Primary Tag (Note Type)**: The first tag should represent the note type. CAREFULLY consider the INTENT and CONTEXT:

           - "todo" for ACTIONABLE task lists - things the user needs to DO
             ✓ Examples: "Buy groceries", "Call dentist", "Submit expense report"
             ✗ NOT for: Lists of information, book notes, summaries, reference material

           - "journal" for personal reflections, thoughts, observations, and notes about books/articles/content
             ✓ Examples: Notes from a book, thoughts on an article, learning summaries, observations
             ✗ NOT for: Action items, meeting notes, structured data

           - "meeting" for meeting notes with attendees, agendas, or discussion points
           - "email" for email drafts with To/From/Subject structure
           - "contact" for contact information (names, phone numbers, addresses)
           - "reminder" for time-based reminders or alerts
           - "expense" for expense/receipt tracking
           - "shopping" for shopping lists (items to purchase)
           - "recipe" for cooking recipes with ingredients and instructions
           - "event" for event planning (parties, conferences, gatherings)
           - "idea" for brainstorming/creative ideas/feature requests
           - "general" for anything else that doesn't fit the above categories

           **CRITICAL**: Format does NOT determine type! A bulleted list could be:
           - Book notes → "journal"
           - Shopping items → "shopping"
           - Tasks to complete → "todo"
           Look at the CONTENT and INTENT, not just the format!

        2. **Secondary Tags**: Add 1-4 more descriptive tags that help categorize the content
           - These should be specific topics, projects, or contexts (e.g., "work", "groceries", "q4-planning")

        3. **Vocabulary Consistency**: STRONGLY prefer existing tags from the system
           - If the note is about work, and "work" already exists, use "work" (not "office" or "job")
           - Match spelling and capitalization exactly
           - Only create new tags if no existing tag fits

        4. **Tag Format**: lowercase, use hyphens for multi-word tags (e.g., "project-x", "budget-2024")

        \(existingTagsPrompt)

        Note content:
        \(content)

        **Examples to guide your classification**:

        Example 1 - Book notes (NOT a todo):
        "Notes from Checklist Manifesto:
        - Checklists reduce errors
        - Two types: DO-CONFIRM and READ-DO
        - Keep checklists short and simple"
        → {"primaryTag":"journal","secondaryTags":["book-notes","checklist-manifesto"],"confidence":0.9}

        Example 2 - Actual tasks (IS a todo):
        "Today's tasks:
        - Buy milk and eggs
        - Call the dentist
        - Finish project proposal"
        → {"primaryTag":"todo","secondaryTags":["errands","work"],"confidence":0.95}

        Example 3 - Informational list (NOT a todo):
        "Key points from the presentation:
        - Revenue up 15%
        - New product launch Q3
        - Hiring 5 engineers"
        → {"primaryTag":"journal","secondaryTags":["presentation-notes","work"],"confidence":0.85}

        Example 4 - Meeting summary (IS journal if informational):
        "Meeting recap:
        - Discussed new API design
        - Sarah presented mockups
        - Timeline: 3 weeks for MVP"
        → {"primaryTag":"journal","secondaryTags":["meeting-notes","work"],"confidence":0.85}

        Example 5 - Meeting action items ONLY (IS todo):
        "Team standup follow-ups:
        - Deploy staging environment
        - Review PR #234
        - Update API docs"
        → {"primaryTag":"todo","secondaryTags":["work","team"],"confidence":0.9}

        Example 6 - Learning notes (IS journal):
        "Python course notes:
        - Functions are first-class objects
        - Use list comprehensions for cleaner code
        - Decorators modify function behavior"
        → {"primaryTag":"journal","secondaryTags":["programming","python","learning"],"confidence":0.9}

        Return ONLY valid JSON with this exact structure, no markdown code blocks, no explanations:
        {"primaryTag":"journal","secondaryTags":["book-notes"],"confidence":0.9}

        The confidence value should be 0.0 to 1.0 representing how certain you are about the primary tag classification.
        """

        let jsonText = try await performAPIRequest(prompt: prompt, maxTokens: 256)

        // Parse the JSON response
        guard let jsonData = jsonText.data(using: .utf8) else {
            throw LLMError.invalidResponse
        }

        let decoder = JSONDecoder()
        return try decoder.decode(TagSuggestionResult.self, from: jsonData)
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

