//
//  SpellCorrector.swift
//  QuillStack
//
//  On-device spell correction using UITextChecker
//

import UIKit

class SpellCorrector {
    private let checker = UITextChecker()
    private let language = "en"

    // Common OCR-specific corrections that UITextChecker might miss
    private let ocrCorrections: [String: String] = [
        // Common handwriting OCR errors
        "tD:": "To:",
        "t0:": "To:",
        "frorn": "from",
        "rnail": "mail",
        "ernail": "email",
        "emai1": "email",
        "mai1": "mail",
        "thanies": "thanks",
        "thankss": "thanks",
        "thonks": "thanks",
        "tash": "trash",
        "tush": "trash",
        "trosh": "trash",
        "belter": "better",
        "betler": "better",
        "frornatting": "formatting",
        "formatling": "formatting",
        "forrnatting": "formatting",
        "resting": "testing", // Context-dependent but common
        "teting": "testing",
        "testng": "testing",
        "rnatter": "matter",
        "nurnber": "number",
        "sorne": "some",
        "tirne": "time",
        "corne": "come",
        "horne": "home",
        "narne": "name",
        "sarne": "same",
        "garne": "game",
        "frarne": "frame",
        // Letter substitutions
        "l0ve": "love",
        "g00d": "good",
        "1ike": "like",
        "p1ease": "please",
        "he1p": "help",
        "he11o": "hello",
        "ca11": "call",
        // Common slang/informal that UITextChecker gets wrong
        "duno": "dunno",
        "Duno": "Dunno",
        "dunna": "dunno",
        "gotta": "gotta", // Prevent "correction" to something else
        "gonna": "gonna",
        "wanna": "wanna",
        // Email-specific OCR errors
        "subsect": "Subject",
        "subiect": "Subject",
        "subect": "Subject",
        "subjeet": "Subject",
        "subjecl": "Subject",
        "emailt": "email",
        "emait": "email",
        "thares": "thanks",
        "Thares": "Thanks",
        "thanhs": "thanks",
        "thankd": "thanks",
        "lhanks": "thanks",
        // More common m/rn confusion (frorn already defined above)
        "Frorn": "From",
        "fron": "from",
    ]

    // Word pairs that OCR commonly splits incorrectly
    private let splitWordCorrections: [(pattern: String, replacement: String)] = [
        ("for matting", "formatting"),
        ("for mat", "format"),
        ("some thing", "something"),
        ("any thing", "anything"),
        ("every thing", "everything"),
        ("no thing", "nothing"),
        ("to day", "today"),
        ("to morrow", "tomorrow"),
        ("yester day", "yesterday"),
        ("week end", "weekend"),
        ("birth day", "birthday"),
        ("every one", "everyone"),
        ("any one", "anyone"),
        ("some one", "someone"),
        ("no one", "no one"), // Keep as-is, it's correct
        ("in to", "into"),
        ("on to", "onto"),
        ("can not", "cannot"),
        ("with out", "without"),
        ("in side", "inside"),
        ("out side", "outside"),
        ("up date", "update"),
        ("down load", "download"),
        ("up load", "upload"),
        ("pass word", "password"),
        ("user name", "username"),
        ("e mail", "email"),
        ("web site", "website"),
    ]

    // Words to skip spell-checking (proper nouns, tech terms, etc.)
    private let skipWords: Set<String> = [
        "gmail", "yahoo", "outlook", "hotmail", "icloud",
        "http", "https", "www", "com", "org", "net", "edu",
        "todo", "asap", "fyi", "btw", "imo", "imho"
    ]

    /// Corrects spelling in the given text using on-device spell checker
    func correctSpelling(_ text: String, learnedCorrections: [String: String]? = nil) -> CorrectionResult {
        var correctedText = text
        var corrections: [SpellCorrection] = []

        // First pass: Fix split words (e.g., "for matting" → "formatting")
        for (pattern, replacement) in splitWordCorrections {
            if correctedText.lowercased().contains(pattern.lowercased()) {
                if let range = correctedText.range(of: pattern, options: .caseInsensitive) {
                    let original = String(correctedText[range])
                    correctedText.replaceSubrange(range, with: replacement)
                    corrections.append(SpellCorrection(
                        original: original,
                        corrected: replacement,
                        source: .ocrDictionary
                    ))
                }
            }
        }

        // Second pass: Apply known OCR-specific corrections (whole words only)
        for (wrong, right) in ocrCorrections {
            // Use word boundary regex to avoid matching substrings
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: wrong))\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let nsText = correctedText as NSString
                let matches = regex.matches(in: correctedText, range: NSRange(location: 0, length: nsText.length))

                // Process matches in reverse order to preserve indices
                for match in matches.reversed() {
                    let original = nsText.substring(with: match.range)
                    correctedText = (correctedText as NSString).replacingCharacters(in: match.range, with: right)
                    corrections.append(SpellCorrection(
                        original: original,
                        corrected: right,
                        source: .ocrDictionary
                    ))
                }
            }
        }

        // Third pass: Apply learned corrections from user edits
        if let learnedCorrections = learnedCorrections {
            for (wrong, right) in learnedCorrections {
                // Use word boundary regex to avoid matching substrings
                let pattern = "\\b\(NSRegularExpression.escapedPattern(for: wrong))\\b"
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    let nsText = correctedText as NSString
                    let matches = regex.matches(in: correctedText, range: NSRange(location: 0, length: nsText.length))

                    // Process matches in reverse order to preserve indices
                    for match in matches.reversed() {
                        let original = nsText.substring(with: match.range)
                        correctedText = (correctedText as NSString).replacingCharacters(in: match.range, with: right)
                        corrections.append(SpellCorrection(
                            original: original,
                            corrected: right,
                            source: .learnedCorrection
                        ))
                    }
                }
            }
        }

        // Fourth pass: Use UITextChecker for remaining errors
        let textCheckerCorrections = correctWithTextChecker(correctedText)
        for correction in textCheckerCorrections {
            if let range = correctedText.range(of: correction.original) {
                correctedText.replaceSubrange(range, with: correction.corrected)
                corrections.append(correction)
            }
        }

        return CorrectionResult(
            originalText: text,
            correctedText: correctedText,
            corrections: corrections
        )
    }

    /// Uses UITextChecker to find and correct misspellings
    private func correctWithTextChecker(_ text: String) -> [SpellCorrection] {
        var corrections: [SpellCorrection] = []
        let nsText = text as NSString
        var offset = 0

        while offset < nsText.length {
            let misspelledRange = checker.rangeOfMisspelledWord(
                in: text,
                range: NSRange(location: offset, length: nsText.length - offset),
                startingAt: offset,
                wrap: false,
                language: language
            )

            guard misspelledRange.location != NSNotFound else { break }

            let misspelledWord = nsText.substring(with: misspelledRange)

            // Skip certain words
            if shouldSkipWord(misspelledWord) {
                offset = misspelledRange.location + misspelledRange.length
                continue
            }

            // Get suggestions
            if let guesses = checker.guesses(forWordRange: misspelledRange, in: text, language: language),
               let bestGuess = guesses.first {
                // Only apply if the guess is reasonably similar
                if isReasonableCorrection(original: misspelledWord, suggestion: bestGuess) {
                    corrections.append(SpellCorrection(
                        original: misspelledWord,
                        corrected: bestGuess,
                        source: .textChecker
                    ))
                }
            }

            offset = misspelledRange.location + misspelledRange.length
        }

        return corrections
    }

    /// Checks if a word should be skipped for spell checking
    private func shouldSkipWord(_ word: String) -> Bool {
        let lowercased = word.lowercased()

        // Skip if in skip list
        if skipWords.contains(lowercased) {
            return true
        }

        // Skip if it looks like an email
        if word.contains("@") {
            return true
        }

        // Skip if it looks like a URL
        if lowercased.hasPrefix("http") || lowercased.hasPrefix("www") {
            return true
        }

        // Skip single characters
        if word.count <= 1 {
            return true
        }

        // Skip if mostly numbers
        let letterCount = word.filter { $0.isLetter }.count
        if letterCount < word.count / 2 {
            return true
        }

        return false
    }

    /// Validates that a suggestion is reasonable (not too different from original)
    private func isReasonableCorrection(original: String, suggestion: String) -> Bool {
        // Don't accept suggestions that are vastly different in length
        let lengthDiff = abs(original.count - suggestion.count)
        if lengthDiff > 2 {
            return false
        }

        // Calculate simple edit distance ratio
        let distance = levenshteinDistance(original.lowercased(), suggestion.lowercased())
        let maxLength = max(original.count, suggestion.count)

        // Accept if edit distance is at most 40% of word length
        return distance <= max(2, maxLength * 4 / 10)
    }

    /// Calculates Levenshtein distance between two strings
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let m = s1.count
        let n = s2.count

        if m == 0 { return n }
        if n == 0 { return m }

        var matrix = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)

        for i in 0...m { matrix[i][0] = i }
        for j in 0...n { matrix[0][j] = j }

        let s1Array = Array(s1)
        let s2Array = Array(s2)

        for i in 1...m {
            for j in 1...n {
                let cost = s1Array[i-1] == s2Array[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,      // deletion
                    matrix[i][j-1] + 1,      // insertion
                    matrix[i-1][j-1] + cost  // substitution
                )
            }
        }

        return matrix[m][n]
    }
}

// MARK: - Result Types

struct CorrectionResult {
    let originalText: String
    let correctedText: String
    let corrections: [SpellCorrection]

    var hasCorrections: Bool {
        !corrections.isEmpty
    }

    var correctionCount: Int {
        corrections.count
    }
}

struct SpellCorrection {
    let original: String
    let corrected: String
    let source: CorrectionSource
}

enum CorrectionSource {
    case ocrDictionary      // From our known OCR error dictionary
    case textChecker        // From UITextChecker
    case learnedCorrection  // From user's learned corrections
}

// MARK: - Email-Specific Post-Processing

extension SpellCorrector {
    /// Structure-aware correction for email content
    func correctEmailContent(_ text: String, learnedCorrections: [String: String]? = nil) -> CorrectionResult {
        var lines = text.components(separatedBy: "\n")
        var allCorrections: [SpellCorrection] = []

        for i in 0..<lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Fix "To:" line variations
            if let toMatch = matchToLine(trimmed) {
                let correctedLine = "To: \(toMatch)"
                if correctedLine != line {
                    allCorrections.append(SpellCorrection(
                        original: line,
                        corrected: correctedLine,
                        source: .ocrDictionary
                    ))
                    lines[i] = correctedLine
                }
                continue
            }

            // Fix "Subject:" line variations
            if let subjectMatch = matchSubjectLine(trimmed) {
                let correctedLine = "Subject: \(subjectMatch)"
                if correctedLine != line {
                    allCorrections.append(SpellCorrection(
                        original: line,
                        corrected: correctedLine,
                        source: .ocrDictionary
                    ))
                    lines[i] = correctedLine
                }
                continue
            }

            // General spell correction for body lines (with learned corrections)
            let lineResult = correctSpelling(line, learnedCorrections: learnedCorrections)
            if lineResult.hasCorrections {
                lines[i] = lineResult.correctedText
                allCorrections.append(contentsOf: lineResult.corrections)
            }
        }

        let correctedText = lines.joined(separator: "\n")

        return CorrectionResult(
            originalText: text,
            correctedText: correctedText,
            corrections: allCorrections
        )
    }

    /// Matches variations of "To:" line and extracts the email address
    private func matchToLine(_ line: String) -> String? {
        let lowercased = line.lowercased()
        let toPatterns = ["to:", "t0:", "to :", "td:", "tD:", "ta:"]

        for pattern in toPatterns {
            if lowercased.hasPrefix(pattern) {
                let rest = String(line.dropFirst(pattern.count)).trimmingCharacters(in: .whitespaces)
                return rest
            }
        }

        // Also check for "To" followed by email-like content
        if lowercased.hasPrefix("to") && line.contains("@") {
            let components = line.components(separatedBy: .whitespaces)
            for component in components where component.contains("@") {
                return component
            }
        }

        return nil
    }

    /// Matches variations of "Subject:" line and extracts the subject
    private func matchSubjectLine(_ line: String) -> String? {
        let lowercased = line.lowercased()
        let subjectPatterns = [
            "subject:", "subject :", "subj:", "subj :",
            "subject.", "subiect:", "sub:", "sub :"
        ]

        for pattern in subjectPatterns {
            if lowercased.hasPrefix(pattern) {
                let rest = String(line.dropFirst(pattern.count)).trimmingCharacters(in: .whitespaces)
                return rest
            }
        }

        return nil
    }
}
