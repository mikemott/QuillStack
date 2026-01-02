//
//  TextClassifier.swift
//  QuillStack
//
//  Created on 2025-12-10.
//

import Foundation

/// Default implementation of text classification for note type detection.
/// Uses hashtag triggers, business card detection, and content analysis.
@MainActor
final class TextClassifier: TextClassifierProtocol {
    /// Classifies the type of note based on content
    /// Priority: explicit hashtag triggers > business card detection > content analysis
    func classifyNote(content: String) -> NoteType {
        let lowercased = content.lowercased()

        // First check for explicit hashtag triggers (highest priority)
        if let explicitType = detectExplicitTrigger(lowercased) {
            return explicitType
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

    /// Exact trigger matching using NoteTypeRegistry
    private func detectExactTrigger(_ prefix: String) -> NoteType? {
        // Use the registry to detect type from exact triggers
        return NoteTypeRegistry.shared.detectType(from: prefix)
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
        // Get all triggers from the registry
        let patterns = NoteTypeRegistry.shared.allTriggers

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
        // Get the patterns that match this note type from the registry
        let patternsToRemove = NoteTypeRegistry.shared.triggers(for: noteType)

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

        // Get all triggers from registry and check for each
        let allTypes: [NoteType] = [.todo, .email, .meeting, .contact, .reminder,
                                     .expense, .shopping, .recipe, .event, .idea, .claudePrompt]

        for noteType in allTypes {
            let triggers = NoteTypeRegistry.shared.triggers(for: noteType)

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
