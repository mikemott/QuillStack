//
//  TextClassifier.swift
//  QuillStack
//
//  Created on 2025-12-10.
//

import Foundation

class TextClassifier {
    /// Classifies the type of note based on content
    /// Priority: explicit hashtag triggers > content analysis
    func classifyNote(content: String) -> NoteType {
        let lowercased = content.lowercased()

        // First check for explicit hashtag triggers (highest priority)
        if let explicitType = detectExplicitTrigger(lowercased) {
            return explicitType
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

    /// Exact trigger matching (original behavior)
    private func detectExactTrigger(_ prefix: String) -> NoteType? {
        // Claude prompt triggers (check first - more specific)
        let claudeTriggers = ["#claude#", "#feature#", "#prompt#", "#request#", "#issue#"]
        for trigger in claudeTriggers {
            if prefix.contains(trigger) {
                return .claudePrompt
            }
        }

        // Reminder triggers
        let reminderTriggers = ["#reminder#", "#remind#", "#remindme#"]
        for trigger in reminderTriggers {
            if prefix.contains(trigger) {
                return .reminder
            }
        }

        // Contact triggers
        let contactTriggers = ["#contact#", "#person#", "#phone#"]
        for trigger in contactTriggers {
            if prefix.contains(trigger) {
                return .contact
            }
        }

        // Todo triggers
        let todoTriggers = ["#todo#", "#to-do#", "#tasks#", "#task#"]
        for trigger in todoTriggers {
            if prefix.contains(trigger) {
                return .todo
            }
        }

        // Email triggers
        let emailTriggers = ["#email#", "#mail#"]
        for trigger in emailTriggers {
            if prefix.contains(trigger) {
                return .email
            }
        }

        // Meeting triggers
        let meetingTriggers = ["#meeting#", "#notes#", "#minutes#"]
        for trigger in meetingTriggers {
            if prefix.contains(trigger) {
                return .meeting
            }
        }

        return nil
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
        let patterns = [
            "#claude#", "#feature#", "#prompt#", "#request#", "#issue#",
            "#reminder#", "#remind#", "#remindme#",
            "#contact#", "#person#", "#phone#",
            "#todo#", "#to-do#", "#tasks#", "#task#",
            "#email#", "#mail#",
            "#meeting#", "#notes#", "#minutes#"
        ]

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
        // Get the patterns that match this note type
        let patternsToRemove: [String]

        switch noteType {
        case .claudePrompt:
            patternsToRemove = ["#claude#", "#feature#", "#prompt#", "#request#", "#issue#"]
        case .reminder:
            patternsToRemove = ["#reminder#", "#remind#", "#remindme#"]
        case .contact:
            patternsToRemove = ["#contact#", "#person#", "#phone#"]
        case .todo:
            patternsToRemove = ["#todo#", "#to-do#", "#tasks#", "#task#"]
        case .email:
            patternsToRemove = ["#email#", "#mail#"]
        case .meeting:
            patternsToRemove = ["#meeting#", "#notes#", "#minutes#"]
        case .general:
            return content  // No tags to remove for general notes
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
}

enum NoteType: String {
    case general = "general"
    case todo = "todo"
    case meeting = "meeting"
    case email = "email"
    case claudePrompt = "claudePrompt"
    case reminder = "reminder"
    case contact = "contact"

    var displayName: String {
        switch self {
        case .general: return "Note"
        case .todo: return "To-Do"
        case .meeting: return "Meeting"
        case .email: return "Email"
        case .claudePrompt: return "Feature"
        case .reminder: return "Reminder"
        case .contact: return "Contact"
        }
    }

    var icon: String {
        switch self {
        case .general: return "doc.text"
        case .todo: return "checkmark.square"
        case .meeting: return "calendar"
        case .email: return "envelope"
        case .claudePrompt: return "sparkles"
        case .reminder: return "bell"
        case .contact: return "person.crop.circle"
        }
    }

    var accentColor: String {
        switch self {
        case .general: return "badgeGeneral"
        case .todo: return "badgeTodo"
        case .meeting: return "badgeMeeting"
        case .email: return "badgeEmail"
        case .claudePrompt: return "badgePrompt"
        case .reminder: return "badgeReminder"
        case .contact: return "badgeContact"
        }
    }
}
