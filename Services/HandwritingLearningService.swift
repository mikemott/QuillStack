//
//  HandwritingLearningService.swift
//  QuillStack
//
//  Learns OCR corrections from user manual edits to build a personalized dictionary.
//

import Foundation
import CoreData
import os.log

@MainActor
final class HandwritingLearningService {
    static let shared = HandwritingLearningService()

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "QuillStack", category: "HandwritingLearning")

    private let context: NSManagedObjectContext

    /// Maximum Levenshtein distance to consider a change as an OCR correction
    /// (rather than a semantic rewrite)
    private let maxEditDistance = 2

    /// Minimum word length to consider for learning
    private let minWordLength = 2

    private init() {
        self.context = CoreDataStack.shared.persistentContainer.viewContext
    }

    // MARK: - Public API

    /// Detects and stores OCR corrections by comparing original and edited text.
    /// Called when user saves edits to a note.
    ///
    /// - Parameters:
    ///   - original: The original OCR text before editing
    ///   - edited: The text after user edits
    func detectCorrections(original: String, edited: String) {
        let corrections = findWordCorrections(original: original, edited: edited)

        guard !corrections.isEmpty else { return }

        for (originalWord, correctedWord) in corrections {
            storeCorrection(originalWord: originalWord, correctedWord: correctedWord)
        }

        saveContext()
    }

    /// Returns all learned corrections as a dictionary for spell checking
    func getLearnedCorrections() -> [String: String] {
        return OCRCorrection.fetchCorrectionsDictionary(in: context)
    }

    /// Gets count of learned corrections
    func correctionCount() -> Int {
        return OCRCorrection.count(in: context)
    }

    /// Gets recent corrections for display in settings
    func recentCorrections(limit: Int = 20) -> [(original: String, corrected: String, frequency: Int)] {
        let corrections = OCRCorrection.fetchAll(in: context, limit: limit)
        return corrections.map { ($0.originalWord, $0.correctedWord, Int($0.frequency)) }
    }

    /// Clears all learned corrections (for settings/reset)
    func clearAllCorrections() {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "OCRCorrection")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)

        do {
            try context.execute(deleteRequest)
            try context.save()
        } catch {
            Self.logger.error("Failed to clear OCR corrections: \(error.localizedDescription)")
        }
    }

    /// Removes a specific learned correction
    func removeCorrection(originalWord: String) {
        if let correction = OCRCorrection.find(originalWord: originalWord, in: context) {
            context.delete(correction)
            saveContext()
        }
    }

    // MARK: - Private Helpers

    /// Finds word-level corrections between original and edited text
    private func findWordCorrections(original: String, edited: String) -> [(String, String)] {
        let originalWords = tokenize(original)
        let editedWords = tokenize(edited)

        // Quick check: if word counts are very different, it's likely a major rewrite
        let countDiff = abs(originalWords.count - editedWords.count)
        if countDiff > originalWords.count / 2 {
            return []
        }

        var corrections: [(String, String)] = []

        // Use simple positional diff for similar-length texts
        // This works well for typical OCR corrections where structure is preserved
        let minLength = min(originalWords.count, editedWords.count)

        for i in 0..<minLength {
            let originalWord = originalWords[i]
            let editedWord = editedWords[i]

            // Skip if words are the same (case-insensitive)
            if originalWord.lowercased() == editedWord.lowercased() {
                continue
            }

            // Skip very short words
            if originalWord.count < minWordLength || editedWord.count < minWordLength {
                continue
            }

            // Calculate edit distance
            let distance = levenshteinDistance(originalWord.lowercased(), editedWord.lowercased())

            // Only consider as OCR correction if edit distance is small
            if distance <= maxEditDistance && distance > 0 {
                corrections.append((originalWord, editedWord))
            }
        }

        return corrections
    }

    /// Tokenizes text into words, preserving case
    private func tokenize(_ text: String) -> [String] {
        return text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .map { word in
                // Remove leading/trailing punctuation for matching
                word.trimmingCharacters(in: .punctuationCharacters)
            }
            .filter { !$0.isEmpty }
    }

    /// Stores or updates a correction in Core Data
    private func storeCorrection(originalWord: String, correctedWord: String) {
        let normalizedOriginal = originalWord.lowercased()

        // Check if we already have this correction
        if let existing = OCRCorrection.find(originalWord: normalizedOriginal, in: context) {
            // Update frequency and possibly the corrected word if it changed
            existing.recordUsage()

            // If user corrected to a different word than before, update it
            // (trust the most recent correction)
            if existing.correctedWord != correctedWord {
                existing.correctedWord = correctedWord
            }
        } else {
            // Create new correction
            _ = OCRCorrection.create(
                in: context,
                originalWord: normalizedOriginal,
                correctedWord: correctedWord
            )
        }
    }

    private func saveContext() {
        do {
            try context.save()
        } catch {
            Self.logger.error("Failed to save OCR corrections: \(error.localizedDescription)")
        }
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
