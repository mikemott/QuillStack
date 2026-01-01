//
//  BusinessCardDetector.swift
//  QuillStack
//
//  Created on 2025-12-31.
//

import Foundation

/// Service for detecting if scanned text is likely from a business card
struct BusinessCardDetector {

    /// Threshold score to classify as business card
    private static let threshold: Int = 40

    /// Check if text content appears to be from a business card
    static func isBusinessCard(_ text: String) -> Bool {
        return confidenceScore(text) >= threshold
    }

    /// Calculate confidence score for business card detection
    /// Higher scores indicate higher likelihood of being a business card
    static func confidenceScore(_ text: String) -> Int {
        var score = 0

        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let fullText = text.lowercased()

        // ===== DISQUALIFIERS (check first) =====

        // Contains explicit type triggers for other note types
        let otherTriggers = [
            "#todo#", "#task#", "#to-do#", "#tasks#",
            "#meeting#", "#notes#", "#minutes#",
            "#email#", "#mail#",
            "#reminder#", "#remind#", "#remindme#",
            "#event#", "#appointment#", "#schedule#",
            "#idea#", "#thought#",
            "#claude#", "#feature#", "#prompt#",
            "#expense#", "#receipt#", "#spent#",
            "#shopping#", "#grocery#", "#list#",
            "#recipe#", "#cook#", "#bake#"
        ]

        for trigger in otherTriggers {
            if fullText.contains(trigger) {
                return -100 // Immediately disqualify
            }
        }

        // Too many lines (business cards are compact)
        if lines.count > 15 {
            score -= 20
        }

        // Contains long paragraph text (>50 words without breaks)
        let words = text.split(separator: " ")
        if words.count > 50 {
            // Check if it's dense text without line breaks
            let avgWordsPerLine = Double(words.count) / Double(max(lines.count, 1))
            if avgWordsPerLine > 10 {
                score -= 50 // Likely a document, not a card
            }
        }

        // ===== POSITIVE INDICATORS =====

        // Contains phone number
        let phonePattern = #"\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}"#
        if let regex = try? NSRegularExpression(pattern: phonePattern),
           regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil {
            score += 20
        }

        // Contains email
        let emailPattern = #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#
        if let regex = try? NSRegularExpression(pattern: emailPattern),
           regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil {
            score += 20
        }

        // Contains website/URL
        let urlPatterns = [
            #"https?://[^\s]+"#,
            #"www\.[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#,
            #"[A-Za-z0-9-]+\.(com|org|net|io|co)\b"#
        ]
        for pattern in urlPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil {
                // Make sure it's not an email domain
                if !text.contains("@") || text.contains("www.") || text.contains("http") {
                    score += 15
                    break
                }
            }
        }

        // Contains address pattern (city, state, zip)
        let addressPattern = #"[A-Za-z\s]+,\s*[A-Z]{2}\s*\d{5}"#
        if let regex = try? NSRegularExpression(pattern: addressPattern),
           regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil {
            score += 15
        }

        // Low line count (2-10 lines is typical for business cards)
        if lines.count >= 2 && lines.count <= 10 {
            score += 10
        }

        // Contains company indicators
        let companyIndicators = [
            "inc", "llc", "ltd", "corp", "corporation",
            "company", "co.", "group", "holdings",
            "solutions", "services", "consulting", "partners",
            "technologies", "tech", "systems", "enterprises"
        ]
        for indicator in companyIndicators {
            if fullText.contains(indicator) {
                score += 10
                break
            }
        }

        // Short average line length (business cards have compact text)
        let totalChars = lines.reduce(0) { $0 + $1.count }
        let avgLineLength = totalChars / max(lines.count, 1)
        if avgLineLength < 40 {
            score += 5
        }

        // Contains job title indicators
        let titleIndicators = [
            "ceo", "cto", "cfo", "president", "director",
            "manager", "engineer", "designer", "developer",
            "consultant", "analyst", "specialist", "coordinator",
            "founder", "partner", "owner", "vp", "vice president"
        ]
        for indicator in titleIndicators {
            if fullText.contains(indicator) {
                score += 5
                break
            }
        }

        // Has a name-like first line (2-3 capitalized words)
        if let firstLine = lines.first {
            let firstWords = firstLine.split(separator: " ")
            if firstWords.count >= 2 && firstWords.count <= 4 {
                let allCapitalized = firstWords.allSatisfy { $0.first?.isUppercase == true }
                if allCapitalized {
                    score += 5
                }
            }
        }

        return score
    }

    /// Returns a human-readable breakdown of the detection reasoning
    static func debugBreakdown(_ text: String) -> String {
        var breakdown: [String] = []
        let score = confidenceScore(text)

        breakdown.append("Total Score: \(score) (threshold: \(threshold))")
        breakdown.append("Result: \(score >= threshold ? "BUSINESS CARD" : "NOT A BUSINESS CARD")")
        breakdown.append("")

        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        breakdown.append("Line count: \(lines.count)")

        // Check what was detected
        if let _ = ContactParser.extractPhone(from: text) {
            breakdown.append("+ Phone detected (+20)")
        }
        if let _ = ContactParser.extractEmail(from: text) {
            breakdown.append("+ Email detected (+20)")
        }
        if let _ = ContactParser.extractWebsite(from: text) {
            breakdown.append("+ Website detected (+15)")
        }

        return breakdown.joined(separator: "\n")
    }
}
