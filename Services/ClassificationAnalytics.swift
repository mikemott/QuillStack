//
//  ClassificationAnalytics.swift
//  QuillStack
//
//  Phase 1.6: Classification Correction Tracking
//  Tracks and analyzes classification corrections to improve LLM prompts
//

import Foundation
import CoreData
import OSLog

/// Tracks classification accuracy and correction patterns
@MainActor
class ClassificationAnalytics {
    static let shared = ClassificationAnalytics()

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "QuillStack", category: "ClassificationAnalytics")

    private init() {}

    // MARK: - Correction Tracking

    /// Log a classification correction event
    /// - Parameters:
    ///   - note: The note that was corrected
    ///   - originalType: The type it was classified as
    ///   - correctedType: The type the user changed it to
    ///   - originalMethod: The classification method that was used
    ///   - originalConfidence: The confidence of the original classification
    func logCorrection(
        note: Note,
        originalType: NoteType,
        correctedType: NoteType,
        originalMethod: ClassificationMethod,
        originalConfidence: Double
    ) {
        logger.info("""
            Classification correction:
            - Original: \(originalType.rawValue) (\(originalMethod.rawValue), \(Int(originalConfidence * 100))%)
            - Corrected: \(correctedType.rawValue)
            - Content length: \(note.content.count) chars
            - Content hash: \(note.content.hashValue)
            """)

        // In a production app, you might send this to analytics:
        // - Track in Firebase/Mixpanel
        // - Store in a local analytics database
        // - Send anonymized data to improve ML model
    }

    // MARK: - Analytics Queries

    /// Get correction rate for all notes
    /// - Parameter context: Core Data context
    /// - Returns: Percentage of notes that were manually corrected (0.0-1.0)
    func getCorrectionRate(in context: NSManagedObjectContext) async -> Double {
        let fetchRequest = Note.fetchRequest()

        do {
            // Get total count without fetching all objects (more efficient)
            let totalCount = try context.count(for: fetchRequest)
            guard totalCount > 0 else { return 0.0 }

            // Get count of manually corrected notes
            fetchRequest.predicate = NSPredicate(format: "classificationMethod == %@", "manual")
            let correctedCount = try context.count(for: fetchRequest)

            return Double(correctedCount) / Double(totalCount)
        } catch {
            logger.error("Failed to fetch notes for correction rate: \(error.localizedDescription)")
            return 0.0
        }
    }

    /// Get most commonly misclassified types
    /// - Parameter context: Core Data context
    /// - Returns: Array of (original type, corrected type, count) tuples
    func getMisclassificationPatterns(in context: NSManagedObjectContext) async -> [(original: NoteType, corrected: NoteType, count: Int)] {
        let fetchRequest = Note.fetchRequest() as! NSFetchRequest<Note>
        fetchRequest.predicate = NSPredicate(format: "classificationMethod == %@ AND originalClassificationType != nil", "manual")

        do {
            let correctedNotes = try context.fetch(fetchRequest)

            // Group by (original, corrected) pairs
            var patterns: [String: (NoteType, NoteType, Int)] = [:]

            for note in correctedNotes {
                guard let originalTypeString = note.originalClassificationType,
                      let originalType = NoteType(rawValue: originalTypeString) else {
                    continue
                }
                let correctedType = note.type

                let key = "\(originalTypeString)->\(correctedType.rawValue)"

                if let existing = patterns[key] {
                    patterns[key] = (existing.0, existing.1, existing.2 + 1)
                } else {
                    patterns[key] = (originalType, correctedType, 1)
                }
            }

            // Sort by count descending
            return patterns.values
                .sorted { $0.2 > $1.2 }
                .map { ($0.0, $0.1, $0.2) }
        } catch {
            logger.error("Failed to fetch misclassification patterns: \(error.localizedDescription)")
            return []
        }
    }

    /// Get classification method breakdown
    /// - Parameter context: Core Data context
    /// - Returns: Dictionary of method -> count
    func getMethodBreakdown(in context: NSManagedObjectContext) async -> [String: Int] {
        let fetchRequest = Note.fetchRequest() as! NSFetchRequest<Note>

        do {
            let allNotes = try context.fetch(fetchRequest)

            var breakdown: [String: Int] = [:]
            for note in allNotes {
                let method = note.classificationMethod ?? "unknown"
                breakdown[method, default: 0] += 1
            }

            return breakdown
        } catch {
            logger.error("Failed to fetch method breakdown: \(error.localizedDescription)")
            return [:]
        }
    }

    /// Get average confidence by classification method
    /// - Parameter context: Core Data context
    /// - Returns: Dictionary of method -> average confidence
    func getAverageConfidenceByMethod(in context: NSManagedObjectContext) async -> [String: Double] {
        let fetchRequest = Note.fetchRequest() as! NSFetchRequest<Note>

        do {
            let allNotes = try context.fetch(fetchRequest)

            var methodConfidences: [String: [Double]] = [:]
            for note in allNotes {
                let method = note.classificationMethod ?? "unknown"
                methodConfidences[method, default: []].append(note.classificationConfidence)
            }

            var averages: [String: Double] = [:]
            for (method, confidences) in methodConfidences {
                let sum = confidences.reduce(0, +)
                averages[method] = sum / Double(confidences.count)
            }

            return averages
        } catch {
            logger.error("Failed to fetch confidence by method: \(error.localizedDescription)")
            return [:]
        }
    }

    /// Get classification accuracy for a specific method
    /// - Parameters:
    ///   - method: The classification method to analyze
    ///   - context: Core Data context
    /// - Returns: Accuracy rate (0.0-1.0) where 1.0 means no corrections needed
    func getAccuracyForMethod(_ method: ClassificationMethod, in context: NSManagedObjectContext) async -> Double {
        let fetchRequest = Note.fetchRequest() as! NSFetchRequest<Note>
        fetchRequest.predicate = NSPredicate(
            format: "originalClassificationType != nil OR classificationMethod == %@",
            method.rawValue
        )

        do {
            let notes = try context.fetch(fetchRequest)

            // Filter to notes originally classified with this method
            let methodNotes = notes.filter {
                // If it was corrected, check if original method matches
                if let _ = $0.originalClassificationType {
                    // Note: We don't store original method, so we can't filter precisely
                    // This is a limitation - could be improved by storing originalMethod
                    return true
                }
                // If not corrected, check current method
                return $0.classificationMethod == method.rawValue
            }

            guard !methodNotes.isEmpty else { return 1.0 }

            // Count how many were NOT corrected (i.e., were accurate)
            let accurateNotes = methodNotes.filter { $0.originalClassificationType == nil }

            return Double(accurateNotes.count) / Double(methodNotes.count)
        } catch {
            logger.error("Failed to calculate accuracy: \(error.localizedDescription)")
            return 0.0
        }
    }

    // MARK: - Export for Analysis

    /// Export correction data for external analysis (e.g., improving LLM prompts)
    /// - Parameter context: Core Data context
    /// - Returns: JSON string with anonymized correction data
    func exportCorrectionData(in context: NSManagedObjectContext) async -> String? {
        let fetchRequest = Note.fetchRequest() as! NSFetchRequest<Note>
        fetchRequest.predicate = NSPredicate(format: "classificationMethod == %@ AND originalClassificationType != nil", "manual")

        do {
            let correctedNotes = try context.fetch(fetchRequest)

            let data = correctedNotes.compactMap { note -> [String: Any]? in
                guard let originalType = note.originalClassificationType else { return nil }

                return [
                    "original_type": originalType,
                    "corrected_type": note.noteType,
                    "original_confidence": note.classificationConfidence,
                    "content_length": note.content.count,
                    // Anonymized content preview (first 100 chars, no PII)
                    "content_preview": String(note.content.prefix(100).replacingOccurrences(of: #"[\w\.-]+@[\w\.-]+"#, with: "[EMAIL]", options: .regularExpression))
                ]
            }

            let jsonData = try JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8)
        } catch {
            logger.error("Failed to export correction data: \(error.localizedDescription)")
            return nil
        }
    }
}
