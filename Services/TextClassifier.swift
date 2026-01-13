//
//  TextClassifier.swift
//  QuillStack
//
//  Created on 2025-12-10.
//

import Foundation
import UIKit

/// Default implementation of text classification for note type detection.
/// Uses hashtag triggers, business card detection, and content analysis.
@MainActor
final class TextClassifier: TextClassifierProtocol {

    // MARK: - Prompt Versioning

    /// Current LLM prompt version for classification
    /// Increment this when making significant prompt changes to track accuracy improvements
    /// Format: "v{major}.{minor}" where major = breaking changes, minor = improvements
    private static let PROMPT_VERSION = "v2.1"

    // MARK: - LLM Classification Cache

    /// In-memory cache for LLM classification results to avoid redundant API calls
    /// Note: This is a session cache. For persistent caching, use Note.llmClassificationCache field.
    /// The Core Data field is used when saving notes, while this in-memory cache is for the current session.
    private var classificationCache: [String: NoteClassification] = [:]
    private let cacheMaxSize = 100

    /// Clear old cache entries when limit reached
    private func maintainCache() {
        if classificationCache.count > cacheMaxSize {
            // Remove oldest entries (simple FIFO)
            let keysToRemove = Array(classificationCache.keys.prefix(classificationCache.count - cacheMaxSize))
            for key in keysToRemove {
                classificationCache.removeValue(forKey: key)
            }
        }
    }

    /// Determines if manual type selection should be shown based on classification and user settings
    /// - Parameters:
    ///   - classification: The classification result to evaluate
    ///   - settings: User settings for classification behavior
    /// - Returns: True if user should be prompted to manually select type
    func shouldShowManualTypePicker(for classification: NoteClassification, settings: SettingsManager) -> Bool {
        // Always show picker if user enabled "always ask" mode
        if settings.alwaysAskForClassification {
            return true
        }

        // For explicit hashtag classifications, never show picker (user was explicit)
        if classification.method == .explicit {
            return false
        }

        // For manual classifications, never show picker (already manual)
        if classification.method == .manual {
            return false
        }

        // Check if confidence is below threshold
        return classification.confidence < settings.classificationConfidenceThreshold
    }

    /// Classifies the type of note based on content
    /// Priority: explicit hashtag triggers > spoken command triggers > business card detection > content analysis
    func classifyNote(content: String) -> NoteType {
        let lowercased = content.lowercased()

        // First check for explicit hashtag triggers (highest priority)
        if let explicitType = detectExplicitTrigger(lowercased) {
            return explicitType
        }

        // Next check for natural-language voice/command triggers
        if let commandType = detectCommandTrigger(lowercased) {
            return commandType
        }

        // Check for business card (auto-detect contact without hashtag)
        if BusinessCardDetector.isBusinessCard(content) {
            return .contact
        }

        // Fall back to content analysis
        if isMeetingNote(lowercased) {
            return .meeting
        }

        if isTodoNote(lowercased) {
            return .todo
        }

        return .general
    }
    
    // MARK: - Async Classification with Full Details
    
    /// Classifies the type of note with full classification details including confidence and method.
    /// Priority: explicit hashtag triggers > LLM classification > heuristic detection > content analysis
    /// Respects user classification settings (threshold, always ask, LLM enabled)
    func classifyNoteAsync(content: String, image: UIImage?) async -> NoteClassification {
        let lowercased = content.lowercased()
        let settings = await SettingsManager.shared

        // 1. Hashtag triggers (explicit - highest priority, 100% confidence)
        if let explicitType = detectExplicitTrigger(lowercased) {
            return .explicit(explicitType)
        }

        // 2. LLM classification (NEW - intelligent detection)
        // Only use LLM if enabled in settings and API key is configured
        let enableLLM = await settings.enableLLMClassification
        let hasAPIKey = await settings.hasAPIKey

        if enableLLM && hasAPIKey {
            // Check cache first
            let cacheKey = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if let cached = classificationCache[cacheKey] {
                return cached
            }

            // Try LLM classification (with error handling and fallback)
            if let llmClassification = await classifyWithLLM(content) {
                // Cache the result
                maintainCache()
                classificationCache[cacheKey] = llmClassification
                return llmClassification
            }
        }
        
        // 3. Voice command triggers (existing)
        if let commandType = detectCommandTrigger(lowercased) {
            return NoteClassification(
                type: commandType,
                confidence: 0.80,
                method: .voiceCommand,
                reasoning: "Voice command pattern detected"
            )
        }
        
        // 4. Business card detection (heuristic - existing)
        if BusinessCardDetector.isBusinessCard(content) {
            let score = BusinessCardDetector.confidenceScore(content)
            let confidence = min(Double(score) / 100.0, 0.95) // Normalize to 0-0.95
            return .heuristic(
                .contact,
                confidence: max(confidence, 0.70),
                reasoning: "Business card pattern detected (phone + email)"
            )
        }
        
        // 5. Content analysis (existing heuristics)
        if isMeetingNote(lowercased) {
            return NoteClassification(
                type: .meeting,
                confidence: 0.65,
                method: .contentAnalysis,
                reasoning: "Meeting keywords detected"
            )
        }
        
        if isTodoNote(lowercased) {
            return NoteClassification(
                type: .todo,
                confidence: 0.65,
                method: .contentAnalysis,
                reasoning: "Todo keywords detected"
            )
        }
        
        // 6. Default fallback
        return .default(.general)
    }
    
    // MARK: - LLM Classification

    /// Classifies note content using LLM
    /// Returns nil if LLM classification fails (network error, invalid response, rate limited, etc.)
    private func classifyWithLLM(_ text: String) async -> NoteClassification? {
        // 1. Check network availability first (offline fallback)
        guard NetworkAvailability.shared.isNetworkAvailable else {
            return nil // Fall back to heuristics when offline
        }

        // 2. Check rate limits to prevent excessive API costs
        guard LLMRateLimiter.shared.canMakeCall() else {
            return nil // Fall back to heuristics when rate limited
        }

        // 3. Check if LLM service is available (has API key)
        let settings = await SettingsManager.shared
        guard let apiKey = await settings.claudeAPIKey, !apiKey.isEmpty else {
            return nil // Fall back to heuristics
        }

        // 4. Skip LLM for very short text (likely noise)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count < 10 {
            return nil
        }

        // 5. Build classification prompt
        let prompt = buildClassificationPrompt(text: trimmed)

        do {
            // Call LLM with short response (just type name)
            let response = try await LLMService.shared.performAPIRequest(
                prompt: prompt,
                maxTokens: 20
            )

            // Record successful call for rate limiting
            LLMRateLimiter.shared.recordCall()

            // Parse response - should be just a type name
            let typeName = response
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
                .replacingOccurrences(of: ".", with: "") // Remove trailing periods
                .replacingOccurrences(of: "\"", with: "") // Remove quotes
                .replacingOccurrences(of: "'", with: "") // Remove single quotes

            // Map to NoteType
            guard let noteType = NoteType(rawValue: typeName) else {
                // Invalid response - try to extract type from response
                if let extracted = extractTypeFromLLMResponse(response) {
                    return extracted
                }
                // If extraction fails, return nil to fall back to heuristics
                return nil
            }

            // Return LLM classification with high confidence and prompt version
            return .llm(
                noteType,
                confidence: 0.85,
                reasoning: "LLM classification",
                promptVersion: Self.PROMPT_VERSION
            )

        } catch {
            // LLM call failed - fall back to heuristics
            // Don't record call since it failed
            return nil
        }
    }
    
    /// Builds the classification prompt for LLM with few-shot examples
    private func buildClassificationPrompt(text: String) -> String {
        return """
        Classify this handwritten note into one of these types:

        **Note Types:**
        - **todo**: ACTIONABLE tasks - things the user must DO
          ✓ Examples: "Buy milk", "Call dentist", "Submit report by Friday"
          ✗ NOT for: Lists of information, book notes, reference material, meeting summaries

        - **journal**: Personal thoughts, notes ABOUT content, reflections, learning summaries
          ✓ Examples: Book chapter notes, article summaries, observations, thoughts
          ✗ NOT for: Action items, structured data, meeting action items

        - **meeting**: Meeting notes with attendees, agendas, or discussion points
          Note: If meeting notes contain ONLY action items, classify as "todo" instead

        - **email**: Draft emails with To/From/Subject structure
        - **contact**: Contact information with name + contact details (phone/email/address)
        - **reminder**: Time-based reminders or alerts with dates/times
        - **expense**: Receipts, purchases, financial tracking
        - **shopping**: Shopping lists - items to purchase at a store
        - **recipe**: Cooking recipes with ingredients and instructions
        - **event**: Calendar events, appointments, celebrations (with date/time/location)
        - **idea**: Creative ideas, brainstorming, concepts, feature requests
        - **claudePrompt**: Requests or prompts for AI assistants like Claude
        - **general**: General notes that don't fit other categories

        **CRITICAL CLASSIFICATION RULES:**
        1. **Format does NOT determine type!** A bulleted list could be:
           - Book notes (informational) → journal
           - Shopping items (purchases) → shopping
           - Tasks to complete (actionable) → todo
           **Classify by CONTENT and INTENT, not format!**

        2. Return ONLY the type name (lowercase), nothing else
        3. Choose the MOST SPECIFIC type that matches
        4. Contact requires name + at least one contact detail (phone/email/address)
        5. Temporal markers (dates/times) suggest reminder or event
        6. Structured email format (To/From/Subject) indicates email type
        7. If unsure or doesn't fit a category, return "general"

        **Examples with Edge Cases:**

        Example 1 - Book notes (NOT a todo, IS journal):
        Text: "Notes from Chapter 3:
        - Protagonist faces moral dilemma
        - Theme of redemption emerges
        - Foreshadowing of final conflict"
        Type: journal
        Reasoning: Informational notes ABOUT content, not actionable tasks

        Example 2 - Actual tasks (IS a todo):
        Text: "Today:
        - Buy milk and eggs
        - Call the dentist
        - Finish project proposal"
        Type: todo
        Reasoning: Clear actionable items the user must complete

        Example 3 - Information list (NOT a todo, IS journal):
        Text: "Key takeaways from presentation:
        - Revenue up 15% YoY
        - New product launch Q3
        - Hiring 5 engineers"
        Type: journal
        Reasoning: Summary of information, not action items

        Example 4 - Time-based reminder:
        Text: "Call mom tomorrow at 3pm about birthday party"
        Type: reminder
        Reasoning: Contains specific date/time for future action

        Example 5 - Contact info:
        Text: "John Smith
        555-123-4567
        john@example.com
        Sales Manager at Acme Corp"
        Type: contact
        Reasoning: Name + contact details present

        Example 6 - Meeting with action items:
        Text: "Discussed Q4 roadmap
        Action items: Update docs, schedule follow-up
        Attendees: Sarah, Mike"
        Type: meeting
        Reasoning: Meeting context with attendees, despite having action items

        Example 7 - Pure action list from meeting (IS todo):
        Text: "Meeting follow-ups:
        □ Update documentation
        □ Schedule Q2 review
        □ Send proposal to client"
        Type: todo
        Reasoning: Only contains actionable tasks, no meeting context

        Example 8 - Shopping list:
        Text: "Grocery store: Milk, bread, eggs, cheese, bananas"
        Type: shopping
        Reasoning: Items to purchase

        Example 9 - Expense tracking:
        Text: "Spent $45.99 at Target for office supplies
        Receipt #12345"
        Type: expense
        Reasoning: Financial transaction with amount

        Example 10 - Creative idea:
        Text: "What if we built a feature that automatically summarizes meeting notes?"
        Type: idea
        Reasoning: Brainstorming/feature concept

        Example 11 - AI prompt:
        Text: "Write a poem about autumn leaves"
        Type: claudePrompt
        Reasoning: Direct instruction or request for an AI assistant

        **Text to classify:**
        \(text)

        Type:
        """
    }
    
    /// Attempts to extract note type from LLM response that may contain extra text
    private func extractTypeFromLLMResponse(_ response: String) -> NoteClassification? {
        let lowercased = response.lowercased()

        // Try to find a type name in the response
        for noteType in NoteType.allCases {
            if lowercased.contains(noteType.rawValue) {
                return .llm(
                    noteType,
                    confidence: 0.80,
                    reasoning: "Extracted from LLM response",
                    promptVersion: Self.PROMPT_VERSION
                )
            }
        }

        return nil
    }

    /// Detects explicit #type# triggers at the start of content
    /// Now with OCR-error tolerance for common misreads
    private func detectExplicitTrigger(_ text: String) -> NoteType? {
        // Normalize: remove extra whitespace, check first ~100 chars
        let prefix = String(text.prefix(100)).trimmingCharacters(in: .whitespacesAndNewlines)

        // First try exact matches
        if let exactMatch = detectExactTrigger(prefix) {
            return exactMatch
        }

        // Then try fuzzy matching for OCR errors
        return detectFuzzyTrigger(prefix)
    }

    /// Exact trigger matching using NoteTypeConfigRegistry
    private func detectExactTrigger(_ prefix: String) -> NoteType? {
        // Use the config registry to detect type from exact triggers
        return NoteTypeConfigRegistry.shared.detectType(from: prefix)
    }

    /// Fuzzy trigger matching to handle common OCR errors
    /// Handles: extra spaces, doubled letters, # misread as H or tt, period instead of #
    private func detectFuzzyTrigger(_ prefix: String) -> NoteType? {
        // Normalize for fuzzy matching: collapse spaces, remove punctuation variations
        let normalized = prefix
            .replacingOccurrences(of: " ", with: "")  // Remove spaces
            .replacingOccurrences(of: ".", with: "#") // Period often misread for #
            .replacingOccurrences(of: ",", with: "")  // Remove stray commas

        // Claude prompt patterns - check first (more specific)
        let claudePatterns = [
            "#claude#", "#c1aude#", "#ciaude#", "#claudee#", "#claube#",
            "#feature#", "#featur#", "#featuer#", "#featuree#", "#f3ature#",
            "#prompt#", "#prompl#", "#prornpt#", "#promptt#",
            "#request#", "#requesl#", "#requesi#", "#requestt#",
            "#issue#", "#issu3#", "#issuse#", "#issuee#",
            "#claude", "claude#", "#feature", "feature#", "#prompt", "prompt#"
        ]
        for pattern in claudePatterns {
            if normalized.contains(pattern.replacingOccurrences(of: " ", with: "")) {
                return .claudePrompt
            }
        }

        // Reminder patterns
        let reminderPatterns = [
            "#reminder#", "#reminde#", "#rerinder#", "#rerninder#",
            "#remind#", "#rernind#", "#rernlnd#",
            "#remindme#", "#remindm3#",
            "#reminder", "reminder#", "#remind", "remind#"
        ]
        for pattern in reminderPatterns {
            if normalized.contains(pattern.replacingOccurrences(of: " ", with: "")) {
                return .reminder
            }
        }

        // Contact patterns
        let contactPatterns = [
            "#contact#", "#contacl#", "#contaci#", "#coniact#",
            "#person#", "#pers0n#", "#persun#",
            "#phone#", "#phon3#", "#fone#",
            "#contact", "contact#", "#person", "person#"
        ]
        for pattern in contactPatterns {
            if normalized.contains(pattern.replacingOccurrences(of: " ", with: "")) {
                return .contact
            }
        }

        // Expense patterns
        let expensePatterns = [
            "#expense#", "#expens3#", "#expanse#", "#expensee#",
            "#receipt#", "#recipt#", "#reciept#", "#recelpt#",
            "#spent#", "#spentt#", "#sp3nt#",
            "#paid#", "#pald#", "#pa1d#",
            "#expense", "expense#", "#receipt", "receipt#"
        ]
        for pattern in expensePatterns {
            if normalized.contains(pattern.replacingOccurrences(of: " ", with: "")) {
                return .expense
            }
        }

        // Shopping patterns
        let shoppingPatterns = [
            "#shopping#", "#shoppinq#", "#shopplng#", "#shoppingg#",
            "#shop#", "#shopp#",
            "#grocery#", "#groceries#", "#grocer1es#", "#qrocery#",
            "#list#", "#listt#",
            "#shopping", "shopping#", "#grocery", "grocery#"
        ]
        for pattern in shoppingPatterns {
            if normalized.contains(pattern.replacingOccurrences(of: " ", with: "")) {
                return .shopping
            }
        }

        // Recipe patterns
        let recipePatterns = [
            "#recipe#", "#recipee#", "#recip3#", "#reclpe#",
            "#cook#", "#cookk#", "#c00k#",
            "#bake#", "#bakee#", "#bak3#",
            "#recipe", "recipe#", "#cook", "cook#"
        ]
        for pattern in recipePatterns {
            if normalized.contains(pattern.replacingOccurrences(of: " ", with: "")) {
                return .recipe
            }
        }

        // Event patterns
        let eventPatterns = [
            "#event#", "#eventt#", "#evnt#", "#3vent#",
            "#appointment#", "#appointrnent#", "#apointment#", "#appointmentt#",
            "#schedule#", "#schedu1e#", "#schedulle#",
            "#appt#", "#apptt#",
            "#event", "event#", "#appointment", "appointment#"
        ]
        for pattern in eventPatterns {
            if normalized.contains(pattern.replacingOccurrences(of: " ", with: "")) {
                return .event
            }
        }

        // Idea patterns
        let ideaPatterns = [
            "#idea#", "#ideaa#", "#1dea#", "#ldea#",
            "#thought#", "#thoughtt#", "#thouqht#", "#thoughl#",
            "#note-to-self#", "#notetoself#", "#note2self#",
            "#idea", "idea#", "#thought", "thought#"
        ]
        for pattern in ideaPatterns {
            if normalized.contains(pattern.replacingOccurrences(of: " ", with: "")) {
                return .idea
            }
        }

        // Todo patterns - handle common OCR errors
        let todoPatterns = [
            "#todo#", "#tod0#", "#todoo#", "#toDo#",
            "#task#", "#tasks#", "#taskk#", "#tash#", "#tashs#",
            "#to-do#", "#todo", "todo#", "#todolt", "#todott"
        ]
        for pattern in todoPatterns {
            if normalized.contains(pattern.replacingOccurrences(of: " ", with: "")) {
                return .todo
            }
        }

        // Email patterns - handle OCR errors like "emailtt", "ernail", "emai1"
        let emailPatterns = [
            "#email#", "#emaill#", "#emailtt", "#ernail#", "#emai1#",
            "#mail#", "#maill#", "#mai1#",
            "#email", "email#", "#emailtt.", "#emailt."
        ]
        for pattern in emailPatterns {
            if normalized.contains(pattern.replacingOccurrences(of: " ", with: "")) {
                return .email
            }
        }

        // Meeting patterns
        let meetingPatterns = [
            "#meeting#", "#meetinq#", "#meetimg#", "#rneetinq#",
            "#notes#", "#notess#", "#note5#",
            "#minutes#", "#rninutes#", "#minutess#",
            "#meeting", "meeting#"
        ]
        for pattern in meetingPatterns {
            if normalized.contains(pattern.replacingOccurrences(of: " ", with: "")) {
                return .meeting
            }
        }

        // Last resort: check for hashtag followed by keyword within a few characters
        // This catches "# email" or "#email tt" type errors
        if matchesLoosePattern(normalized, keywords: ["claude", "feature", "prompt", "request", "issue"]) {
            return .claudePrompt
        }
        if matchesLoosePattern(normalized, keywords: ["reminder", "remind", "remindme"]) {
            return .reminder
        }
        if matchesLoosePattern(normalized, keywords: ["contact", "person", "phone"]) {
            return .contact
        }
        if matchesLoosePattern(normalized, keywords: ["expense", "receipt", "spent", "paid"]) {
            return .expense
        }
        if matchesLoosePattern(normalized, keywords: ["shopping", "shop", "grocery", "groceries"]) {
            return .shopping
        }
        if matchesLoosePattern(normalized, keywords: ["recipe", "cook", "bake"]) {
            return .recipe
        }
        if matchesLoosePattern(normalized, keywords: ["event", "appointment", "schedule", "appt"]) {
            return .event
        }
        if matchesLoosePattern(normalized, keywords: ["idea", "thought", "notetoself"]) {
            return .idea
        }
        if matchesLoosePattern(normalized, keywords: ["email", "mail", "emai", "ernail"]) {
            return .email
        }
        if matchesLoosePattern(normalized, keywords: ["todo", "task", "tasks", "toDo"]) {
            return .todo
        }
        if matchesLoosePattern(normalized, keywords: ["meeting", "notes", "minutes"]) {
            return .meeting
        }

        return nil
    }

    /// Detects spoken/voice-friendly phrases like "create a reminder" to infer note type without hashtags.
    private func detectCommandTrigger(_ text: String) -> NoteType? {
        let sanitized = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        let phraseChecks: [(NoteType, [String])] = [
            (.reminder, [
                "create a reminder",
                "set a reminder",
                "reminder for",
                "reminder to",
                "remind me to",
                "remind me about",
                "remind us to"
            ]),
            (.todo, [
                "create a todo",
                "create a to-do",
                "make a to-do",
                "todo list",
                "to-do list",
                "task list",
                "add this task",
                "add to my list",
                "create a checklist",
                "checklist for"
            ]),
            (.meeting, [
                "schedule a meeting",
                "schedule meeting",
                "meeting with",
                "meeting at",
                "set up a meeting",
                "plan a meeting",
                "agenda for"
            ]),
            (.event, [
                "schedule an event",
                "plan an event",
                "schedule the event",
                "appointment at",
                "book an appointment",
                "set an appointment"
            ]),
            (.shopping, [
                "add to my shopping list",
                "add this to groceries",
                "shopping run",
                "restock list"
            ]),
            (.recipe, [
                "recipe for",
                "ingredients for",
                "how to cook",
                "how do i cook"
            ]),
            (.idea, [
                "idea for",
                "brainstorm",
                "what if we",
                "concept for",
                "thinking about"
            ]),
            (.expense, [
                "log an expense",
                "add an expense",
                "expense report",
                "track this expense",
                "paid for",
                "i spent"
            ]),
            (.email, [
                "draft an email",
                "write an email",
                "compose an email",
                "email draft",
                "send an email to"
            ]),
            (.contact, [
                "save this contact",
                "contact info",
                "phone number is",
                "email address is",
                "add them to contacts"
            ])
        ]

        for (noteType, phrases) in phraseChecks {
            if phrases.contains(where: { sanitized.contains($0) }) {
                return noteType
            }
        }

        if sanitized.contains("shopping list") || sanitized.contains("grocery list") {
            return .shopping
        }

        if sanitized.contains("receipt for") || sanitized.contains("i paid") {
            return .expense
        }

        if sanitized.contains("schedule a call") || sanitized.contains("plan a call") {
            return .meeting
        }

        if sanitized.contains("reminder") && sanitized.contains("tomorrow") {
            return .reminder
        }

        return nil
    }

    /// Checks if text starts with # followed by a keyword (with some tolerance)
    private func matchesLoosePattern(_ text: String, keywords: [String]) -> Bool {
        // Look for # near the start followed by keyword
        guard let hashIndex = text.firstIndex(of: "#") else { return false }
        let afterHash = String(text[hashIndex...].dropFirst())

        for keyword in keywords {
            // Check if keyword appears within first 10 chars after #
            let searchArea = String(afterHash.prefix(10))
            if searchArea.contains(keyword) {
                return true
            }

            // Also check for common character substitutions
            let variations = generateOCRVariations(keyword)
            for variation in variations {
                if searchArea.contains(variation) {
                    return true
                }
            }
        }

        return false
    }

    /// Generates common OCR misread variations of a keyword
    private func generateOCRVariations(_ word: String) -> [String] {
        var variations: [String] = []

        // Common OCR substitutions
        let substitutions: [(String, String)] = [
            ("m", "rn"), ("m", "nn"),  // m often read as rn or nn
            ("l", "1"), ("l", "i"),    // l often read as 1 or i
            ("o", "0"),                 // o often read as 0
            ("g", "q"),                 // g often read as q
            ("a", "o"),                 // a sometimes read as o
            ("i", "l"), ("i", "1"),    // i often read as l or 1
        ]

        for (original, replacement) in substitutions {
            if word.contains(original) {
                variations.append(word.replacingOccurrences(of: original, with: replacement))
            }
        }

        return variations
    }

    private func isMeetingNote(_ text: String) -> Bool {
        let meetingIndicators = [
            "meeting",
            "call with",
            "agenda",
            "attendees:",
            "discussion:",
            "action items",
            "minutes",
            "conference"
        ]

        return meetingIndicators.contains { text.contains($0) }
    }

    private func isTodoNote(_ text: String) -> Bool {
        let todoIndicators = [
            "[ ]",
            "[x]",
            "checklist"
        ]

        return todoIndicators.contains { text.contains($0) }
    }

    /// Extracts the trigger tag from content (for display/removal purposes)
    func extractTriggerTag(from content: String) -> (tag: String, cleanedContent: String)? {
        // Get all triggers from the config registry
        let patterns = NoteTypeConfigRegistry.shared.allTriggers

        let lowercased = content.lowercased()

        for pattern in patterns {
            if let range = lowercased.range(of: pattern) {
                // Find the same range in original content (preserving case)
                let startIndex = content.index(content.startIndex, offsetBy: lowercased.distance(from: lowercased.startIndex, to: range.lowerBound))
                let endIndex = content.index(content.startIndex, offsetBy: lowercased.distance(from: lowercased.startIndex, to: range.upperBound))

                let tag = String(content[startIndex..<endIndex])
                var cleaned = content
                cleaned.removeSubrange(startIndex..<endIndex)
                cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

                return (tag, cleaned)
            }
        }

        return nil
    }

    /// Removes ALL occurrences of matched trigger tags from content
    /// Returns the cleaned content with all tags stripped
    func extractAllTriggerTags(from content: String, for noteType: NoteType) -> String {
        // Get the patterns that match this note type from the config registry
        let patternsToRemove = NoteTypeConfigRegistry.shared.triggers(for: noteType)

        // No tags to remove if empty (e.g., general notes)
        if patternsToRemove.isEmpty {
            return content
        }

        var cleaned = content

        // Remove all occurrences of each pattern (case-insensitive)
        for pattern in patternsToRemove {
            if let regex = try? NSRegularExpression(
                pattern: NSRegularExpression.escapedPattern(for: pattern),
                options: .caseInsensitive
            ) {
                cleaned = regex.stringByReplacingMatches(
                    in: cleaned,
                    options: [],
                    range: NSRange(cleaned.startIndex..., in: cleaned),
                    withTemplate: ""
                )
            }
        }

        // Clean up extra whitespace and newlines created by removal
        cleaned = cleaned
            .replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned
    }

    /// Detects all tags in content and splits into multiple sections
    /// Returns array of (noteType, content) for each detected section
    /// If no tags found, returns single section with classified type
    func splitIntoSections(content: String) -> [NoteSection] {
        let lowercased = content.lowercased()
        var sections: [NoteSection] = []

        // Find all tag positions
        var tagPositions: [(range: Range<String.Index>, type: NoteType)] = []

        // Get all triggers from config registry and check for each
        let allTypes: [NoteType] = [.todo, .email, .meeting, .contact, .reminder,
                                     .expense, .shopping, .recipe, .event, .idea, .claudePrompt]

        for noteType in allTypes {
            let triggers = NoteTypeConfigRegistry.shared.triggers(for: noteType)

            for trigger in triggers {
                var searchStart = lowercased.startIndex

                while searchStart < lowercased.endIndex,
                      let range = lowercased.range(of: trigger, range: searchStart..<lowercased.endIndex) {
                    tagPositions.append((range, noteType))
                    searchStart = range.upperBound
                }
            }
        }

        // Sort by position
        tagPositions.sort { content.distance(from: content.startIndex, to: $0.range.lowerBound) < content.distance(from: content.startIndex, to: $1.range.lowerBound) }

        // If no tags found, classify entire content
        if tagPositions.isEmpty {
            let noteType = classifyNote(content: content)
            return [NoteSection(noteType: noteType, content: content, tagRange: content.startIndex..<content.startIndex)]
        }

        // Handle content before first tag (if any)
        if !tagPositions.isEmpty {
            let firstTagIndex = tagPositions[0].range.lowerBound
            let contentBeforeFirstTag = String(content[content.startIndex..<firstTagIndex])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !contentBeforeFirstTag.isEmpty {
                // Classify content before first tag
                let preTagType = classifyNote(content: contentBeforeFirstTag)
                sections.append(NoteSection(
                    noteType: preTagType,
                    content: contentBeforeFirstTag,
                    tagRange: content.startIndex..<content.startIndex
                ))
            }
        }

        // Split content based on tag positions
        for (index, tagPosition) in tagPositions.enumerated() {
            let endIndex: String.Index

            if index < tagPositions.count - 1 {
                // Not the last section: end at next tag
                endIndex = tagPositions[index + 1].range.lowerBound
            } else {
                // Last section: include all remaining content
                endIndex = content.endIndex
            }

            // Extract section content (excluding the tag itself)
            let sectionContent = String(content[tagPosition.range.upperBound..<endIndex])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Only create section if there's content after the tag
            if !sectionContent.isEmpty {
                sections.append(NoteSection(
                    noteType: tagPosition.type,
                    content: sectionContent,
                    tagRange: tagPosition.range
                ))
            }
        }

        // If we found tags but no valid sections (e.g., all tags at end with no content),
        // treat as single note
        if sections.isEmpty {
            let noteType = classifyNote(content: content)
            return [NoteSection(noteType: noteType, content: content, tagRange: content.startIndex..<content.startIndex)]
        }

        return sections
    }
}

// NoteType enum is now defined in Models/NoteType.swift
