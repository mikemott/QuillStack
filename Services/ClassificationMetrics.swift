//
//  ClassificationMetrics.swift
//  QuillStack
//
//  Phase 4.1: Classification Accuracy Tracking
//  Comprehensive system for tracking and measuring classification accuracy
//

import Foundation
import CoreData
import OSLog

// MARK: - Metric Data Structures

/// Represents overall classification accuracy metrics
struct ClassificationAccuracyReport: Codable {
    /// Overall correction rate (% of notes manually re-classified)
    let correctionRate: Double

    /// Total number of notes analyzed
    let totalNotes: Int

    /// Number of notes that were manually corrected
    let correctedNotes: Int

    /// Breakdown by classification method
    let methodBreakdown: [String: MethodMetrics]

    /// Most commonly misclassified patterns
    let topMisclassifications: [MisclassificationPattern]

    /// Confidence score distribution
    let confidenceDistribution: ConfidenceDistribution

    /// Timestamp when report was generated
    let generatedAt: Date
}

/// Metrics for a specific classification method
struct MethodMetrics: Codable {
    /// Classification method name
    let method: String

    /// Number of notes classified with this method
    let count: Int

    /// Percentage of total notes
    let percentage: Double

    /// Average confidence score
    let averageConfidence: Double

    /// Accuracy rate (% not corrected)
    let accuracy: Double

    /// Number of corrections needed
    let correctionsCount: Int
}

/// Represents a common misclassification pattern
struct MisclassificationPattern: Codable, Equatable {
    /// Original (incorrect) type
    let originalType: String

    /// Corrected type
    let correctedType: String

    /// Number of occurrences
    let count: Int

    /// Percentage of all corrections
    let percentage: Double
}

/// Distribution of confidence scores
struct ConfidenceDistribution: Codable {
    /// Notes with confidence >= 0.85 (high)
    let highConfidence: Int

    /// Notes with confidence 0.70-0.85 (medium)
    let mediumConfidence: Int

    /// Notes with confidence < 0.70 (low)
    let lowConfidence: Int

    /// Average confidence across all notes
    let averageConfidence: Double

    /// Breakdown by confidence range
    var percentages: [String: Double] {
        let total = Double(highConfidence + mediumConfidence + lowConfidence)
        guard total > 0 else { return [:] }

        return [
            "high": Double(highConfidence) / total * 100,
            "medium": Double(mediumConfidence) / total * 100,
            "low": Double(lowConfidence) / total * 100
        ]
    }
}

/// Data for improving LLM prompts
struct PromptImprovementData: Codable {
    /// Misclassified examples (anonymized)
    let examples: [AnonymizedExample]

    /// Common confusion patterns
    let confusionPatterns: [String: [String]]

    /// Low-confidence types that need better prompts
    let problematicTypes: [String]
}

/// Anonymized example for prompt improvement
struct AnonymizedExample: Codable {
    /// Original type (incorrect)
    let originalType: String

    /// Correct type
    let correctType: String

    /// Content length in characters
    let contentLength: Int

    /// Sanitized content preview (no PII)
    let contentPreview: String

    /// Original confidence score
    let confidence: Double

    /// Classification method used
    let method: String
}

// MARK: - Classification Metrics Service

/// Comprehensive service for tracking and analyzing classification accuracy
@MainActor
class ClassificationMetrics {
    static let shared = ClassificationMetrics()

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "QuillStack", category: "ClassificationMetrics")

    private init() {}

    // MARK: - Core Metrics

    /// Generate comprehensive accuracy report
    /// - Parameter context: Core Data context
    /// - Returns: Complete accuracy report with all metrics
    func generateAccuracyReport(in context: NSManagedObjectContext) async -> ClassificationAccuracyReport {
        logger.info("Generating classification accuracy report...")

        let correctionRate = await getCorrectionRate(in: context)
        let totalNotes = await getTotalNotesCount(in: context)
        let correctedNotes = await getCorrectedNotesCount(in: context)
        let methodBreakdown = await getMethodBreakdown(in: context)
        let topMisclassifications = await getTopMisclassifications(in: context, limit: 10)
        let confidenceDistribution = await getConfidenceDistribution(in: context)

        let report = ClassificationAccuracyReport(
            correctionRate: correctionRate,
            totalNotes: totalNotes,
            correctedNotes: correctedNotes,
            methodBreakdown: methodBreakdown,
            topMisclassifications: topMisclassifications,
            confidenceDistribution: confidenceDistribution,
            generatedAt: Date()
        )

        logger.info("Report generated: \(totalNotes) total notes, \(Int(correctionRate * 100))% correction rate")

        return report
    }

    /// Get overall correction rate
    /// - Parameter context: Core Data context
    /// - Returns: Percentage of notes that were manually corrected (0.0-1.0)
    func getCorrectionRate(in context: NSManagedObjectContext) async -> Double {
        let totalCount = await getTotalNotesCount(in: context)
        guard totalCount > 0 else { return 0.0 }

        let correctedCount = await getCorrectedNotesCount(in: context)
        return Double(correctedCount) / Double(totalCount)
    }

    /// Get total number of notes
    private func getTotalNotesCount(in context: NSManagedObjectContext) async -> Int {
        let fetchRequest = Note.fetchRequest()

        do {
            return try context.count(for: fetchRequest)
        } catch {
            logger.error("Failed to count total notes: \(error.localizedDescription)")
            return 0
        }
    }

    /// Get number of manually corrected notes
    private func getCorrectedNotesCount(in context: NSManagedObjectContext) async -> Int {
        let fetchRequest = Note.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "originalClassificationType != nil")

        do {
            return try context.count(for: fetchRequest)
        } catch {
            logger.error("Failed to count corrected notes: \(error.localizedDescription)")
            return 0
        }
    }

    // MARK: - Method Analysis

    /// Get detailed breakdown by classification method
    /// - Parameter context: Core Data context
    /// - Returns: Dictionary of method name to detailed metrics
    func getMethodBreakdown(in context: NSManagedObjectContext) async -> [String: MethodMetrics] {
        let fetchRequest = Note.fetchRequest() as! NSFetchRequest<Note>

        do {
            let allNotes = try context.fetch(fetchRequest)
            let totalCount = allNotes.count
            guard totalCount > 0 else { return [:] }

            // Group by method
            var methodGroups: [String: [Note]] = [:]
            for note in allNotes {
                let method = note.classificationMethod ?? "unknown"
                methodGroups[method, default: []].append(note)
            }

            // Calculate metrics for each method
            var breakdown: [String: MethodMetrics] = [:]
            for (method, notes) in methodGroups {
                let count = notes.count
                let percentage = Double(count) / Double(totalCount)

                // Calculate average confidence
                let totalConfidence = notes.reduce(0.0) { $0 + $1.classificationConfidence }
                let averageConfidence = totalConfidence / Double(count)

                // Calculate accuracy (notes not corrected)
                let notCorrected = notes.filter { $0.originalClassificationType == nil }
                let accuracy = Double(notCorrected.count) / Double(count)
                let correctionsCount = count - notCorrected.count

                breakdown[method] = MethodMetrics(
                    method: method,
                    count: count,
                    percentage: percentage,
                    averageConfidence: averageConfidence,
                    accuracy: accuracy,
                    correctionsCount: correctionsCount
                )
            }

            return breakdown
        } catch {
            logger.error("Failed to generate method breakdown: \(error.localizedDescription)")
            return [:]
        }
    }

    /// Get accuracy rate for a specific method
    /// - Parameters:
    ///   - method: Classification method to analyze
    ///   - context: Core Data context
    /// - Returns: Accuracy rate (0.0-1.0) where 1.0 means no corrections needed
    func getAccuracyForMethod(_ method: ClassificationMethod, in context: NSManagedObjectContext) async -> Double {
        let fetchRequest = Note.fetchRequest() as! NSFetchRequest<Note>
        fetchRequest.predicate = NSPredicate(format: "classificationMethod == %@", method.rawValue)

        do {
            let notes = try context.fetch(fetchRequest)
            guard !notes.isEmpty else { return 1.0 }

            let accurateNotes = notes.filter { $0.originalClassificationType == nil }
            return Double(accurateNotes.count) / Double(notes.count)
        } catch {
            logger.error("Failed to calculate accuracy for method \(method.rawValue): \(error.localizedDescription)")
            return 0.0
        }
    }

    // MARK: - Misclassification Analysis

    /// Get top misclassification patterns
    /// - Parameters:
    ///   - context: Core Data context
    ///   - limit: Maximum number of patterns to return
    /// - Returns: Array of most common misclassifications
    func getTopMisclassifications(in context: NSManagedObjectContext, limit: Int = 10) async -> [MisclassificationPattern] {
        let fetchRequest = Note.fetchRequest() as! NSFetchRequest<Note>
        fetchRequest.predicate = NSPredicate(format: "originalClassificationType != nil")

        do {
            let correctedNotes = try context.fetch(fetchRequest)
            let totalCorrections = correctedNotes.count
            guard totalCorrections > 0 else { return [] }

            // Group by (original, corrected) pairs
            var patterns: [String: (String, String, Int)] = [:]

            for note in correctedNotes {
                guard let originalType = note.originalClassificationType else { continue }
                let correctedType = note.noteType

                let key = "\(originalType)->\(correctedType)"

                if let existing = patterns[key] {
                    patterns[key] = (existing.0, existing.1, existing.2 + 1)
                } else {
                    patterns[key] = (originalType, correctedType, 1)
                }
            }

            // Convert to MisclassificationPattern and sort
            return patterns.values
                .map { (original, corrected, count) in
                    MisclassificationPattern(
                        originalType: original,
                        correctedType: corrected,
                        count: count,
                        percentage: Double(count) / Double(totalCorrections)
                    )
                }
                .sorted { $0.count > $1.count }
                .prefix(limit)
                .map { $0 }
        } catch {
            logger.error("Failed to get misclassification patterns: \(error.localizedDescription)")
            return []
        }
    }

    /// Identify note types that are frequently misclassified
    /// - Parameter context: Core Data context
    /// - Returns: Array of problematic note types with error rates
    func getProblematicTypes(in context: NSManagedObjectContext) async -> [(type: String, errorRate: Double)] {
        let misclassifications = await getTopMisclassifications(in: context, limit: 100)

        // Count errors by original type
        var errorCounts: [String: Int] = [:]
        for pattern in misclassifications {
            errorCounts[pattern.originalType, default: 0] += pattern.count
        }

        // Get total counts for each type
        let fetchRequest = Note.fetchRequest() as! NSFetchRequest<Note>

        do {
            let allNotes = try context.fetch(fetchRequest)
            var typeCounts: [String: Int] = [:]
            for note in allNotes {
                let type = note.originalClassificationType ?? note.noteType
                typeCounts[type, default: 0] += 1
            }

            // Calculate error rates
            var results: [(String, Double)] = []
            for (type, errorCount) in errorCounts {
                if let totalCount = typeCounts[type], totalCount > 0 {
                    let errorRate = Double(errorCount) / Double(totalCount)
                    results.append((type, errorRate))
                }
            }

            return results.sorted { $0.1 > $1.1 }
        } catch {
            logger.error("Failed to identify problematic types: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Confidence Analysis

    /// Get confidence score distribution
    /// - Parameter context: Core Data context
    /// - Returns: Distribution of notes by confidence level
    func getConfidenceDistribution(in context: NSManagedObjectContext) async -> ConfidenceDistribution {
        let fetchRequest = Note.fetchRequest() as! NSFetchRequest<Note>

        do {
            let allNotes = try context.fetch(fetchRequest)

            var highCount = 0
            var mediumCount = 0
            var lowCount = 0
            var totalConfidence = 0.0

            for note in allNotes {
                let confidence = note.classificationConfidence
                totalConfidence += confidence

                if confidence >= 0.85 {
                    highCount += 1
                } else if confidence >= 0.70 {
                    mediumCount += 1
                } else {
                    lowCount += 1
                }
            }

            let averageConfidence = allNotes.isEmpty ? 0.0 : totalConfidence / Double(allNotes.count)

            return ConfidenceDistribution(
                highConfidence: highCount,
                mediumConfidence: mediumCount,
                lowConfidence: lowCount,
                averageConfidence: averageConfidence
            )
        } catch {
            logger.error("Failed to calculate confidence distribution: \(error.localizedDescription)")
            return ConfidenceDistribution(
                highConfidence: 0,
                mediumConfidence: 0,
                lowConfidence: 0,
                averageConfidence: 0.0
            )
        }
    }

    /// Get average confidence by note type
    /// - Parameter context: Core Data context
    /// - Returns: Dictionary of note type to average confidence
    func getAverageConfidenceByType(in context: NSManagedObjectContext) async -> [String: Double] {
        let fetchRequest = Note.fetchRequest() as! NSFetchRequest<Note>

        do {
            let allNotes = try context.fetch(fetchRequest)

            var typeConfidences: [String: [Double]] = [:]
            for note in allNotes {
                typeConfidences[note.noteType, default: []].append(note.classificationConfidence)
            }

            var averages: [String: Double] = [:]
            for (type, confidences) in typeConfidences {
                let sum = confidences.reduce(0, +)
                averages[type] = sum / Double(confidences.count)
            }

            return averages
        } catch {
            logger.error("Failed to calculate confidence by type: \(error.localizedDescription)")
            return [:]
        }
    }

    // MARK: - Prompt Improvement Data

    /// Generate data for improving LLM classification prompts
    /// - Parameter context: Core Data context
    /// - Returns: Anonymized data suitable for prompt engineering
    /// - Warning: Content previews are aggressively anonymized but should still be treated as
    ///   potentially sensitive. Use only with user consent for external sharing.
    func generatePromptImprovementData(in context: NSManagedObjectContext) async -> PromptImprovementData {
        let fetchRequest = Note.fetchRequest() as! NSFetchRequest<Note>
        fetchRequest.predicate = NSPredicate(format: "originalClassificationType != nil")

        do {
            let correctedNotes = try context.fetch(fetchRequest)

            // Create anonymized examples
            let examples = correctedNotes.prefix(50).compactMap { note -> AnonymizedExample? in
                guard let originalType = note.originalClassificationType else { return nil }

                return AnonymizedExample(
                    originalType: originalType,
                    correctType: note.noteType,
                    contentLength: note.content.count,
                    contentPreview: anonymizeContent(note.content),
                    confidence: note.classificationConfidence,
                    method: note.classificationMethod ?? "unknown"
                )
            }

            // Identify confusion patterns (which types get confused with each other)
            var confusionPatterns: [String: [String]] = [:]
            for note in correctedNotes {
                guard let originalType = note.originalClassificationType else { continue }
                let correctedType = note.noteType
                confusionPatterns[originalType, default: []].append(correctedType)
            }

            // Get types with low accuracy
            let problematicTypes = await getProblematicTypes(in: context)
                .filter { $0.errorRate > 0.2 } // More than 20% error rate
                .map { $0.type }

            return PromptImprovementData(
                examples: examples,
                confusionPatterns: confusionPatterns,
                problematicTypes: problematicTypes
            )
        } catch {
            logger.error("Failed to generate prompt improvement data: \(error.localizedDescription)")
            return PromptImprovementData(
                examples: [],
                confusionPatterns: [:],
                problematicTypes: []
            )
        }
    }

    /// Anonymize content for safe export
    /// WARNING: This is aggressive anonymization to prevent any PII leakage.
    /// Only structural information is preserved for prompt engineering.
    private func anonymizeContent(_ content: String) -> String {
        let preview = String(content.prefix(100))

        // Remove emails
        var sanitized = preview.replacingOccurrences(
            of: #"[\w\.-]+@[\w\.-]+"#,
            with: "[EMAIL]",
            options: .regularExpression
        )

        // Remove phone numbers (various formats)
        sanitized = sanitized.replacingOccurrences(
            of: #"\b\d{3}[-.\s]?\d{3}[-.\s]?\d{4}\b"#,
            with: "[PHONE]",
            options: .regularExpression
        )

        // Remove URLs
        sanitized = sanitized.replacingOccurrences(
            of: #"https?://[^\s]+"#,
            with: "[URL]",
            options: .regularExpression
        )

        // Remove any remaining numbers (could be IDs, account numbers, SSNs, etc.)
        sanitized = sanitized.replacingOccurrences(
            of: #"\b\d{4,}\b"#,
            with: "[NUMBER]",
            options: .regularExpression
        )

        // Remove capitalized words that could be names or places
        // Keep common words like "I", "The", "A" but remove likely proper nouns
        sanitized = sanitized.replacingOccurrences(
            of: #"\b[A-Z][a-z]{2,}\b"#,
            with: "[NAME]",
            options: .regularExpression
        )

        // Remove street addresses (number + street indicators)
        sanitized = sanitized.replacingOccurrences(
            of: #"\b\d+\s+(st|street|ave|avenue|rd|road|blvd|boulevard|dr|drive|ln|lane|ct|court)\b"#,
            with: "[ADDRESS]",
            options: [.regularExpression, .caseInsensitive]
        )

        // Remove any @ symbols that might have been missed
        sanitized = sanitized.replacingOccurrences(of: "@", with: "[AT]")

        // Remove dollar amounts that could be sensitive financial info
        sanitized = sanitized.replacingOccurrences(
            of: #"\$\d+"#,
            with: "[AMOUNT]",
            options: .regularExpression
        )

        return sanitized
    }

    // MARK: - Export

    /// Export full accuracy report as JSON
    /// - Parameter context: Core Data context
    /// - Returns: JSON string of the complete report
    func exportAccuracyReport(in context: NSManagedObjectContext) async -> String? {
        let report = await generateAccuracyReport(in: context)

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601

            let jsonData = try encoder.encode(report)
            return String(data: jsonData, encoding: .utf8)
        } catch {
            logger.error("Failed to export accuracy report: \(error.localizedDescription)")
            return nil
        }
    }

    /// Export prompt improvement data as JSON
    /// - Parameter context: Core Data context
    /// - Returns: JSON string of anonymized examples and patterns
    /// - Warning: This export contains anonymized note content. Even with aggressive anonymization,
    ///   users should be informed and consent before this data is exported or shared.
    ///   Only use for internal analysis or with explicit user permission.
    func exportPromptImprovementData(in context: NSManagedObjectContext) async -> String? {
        let data = await generatePromptImprovementData(in: context)

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted

            let jsonData = try encoder.encode(data)
            return String(data: jsonData, encoding: .utf8)
        } catch {
            logger.error("Failed to export prompt improvement data: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Real-time Tracking

    /// Track a classification event (called when note is first classified)
    /// - Parameters:
    ///   - note: The note that was classified
    ///   - classification: The classification result
    func trackClassification(note: Note, classification: NoteClassification) {
        logger.debug("""
            Classification tracked:
            - Note ID: \(note.id.uuidString)
            - Type: \(classification.type.rawValue)
            - Method: \(classification.method.rawValue)
            - Confidence: \(Int(classification.confidence * 100))%
            """)
    }

    /// Track a correction event (called when user manually changes type)
    /// - Parameters:
    ///   - note: The note that was corrected
    ///   - originalType: The type it was classified as
    ///   - correctedType: The type the user changed it to
    ///   - originalMethod: The classification method that was used
    ///   - originalConfidence: The confidence of the original classification
    func trackCorrection(
        note: Note,
        originalType: NoteType,
        correctedType: NoteType,
        originalMethod: ClassificationMethod,
        originalConfidence: Double
    ) {
        logger.info("""
            Classification correction:
            - Note ID: \(note.id.uuidString)
            - Original: \(originalType.rawValue) (\(originalMethod.rawValue), \(Int(originalConfidence * 100))%)
            - Corrected: \(correctedType.rawValue)
            - Content length: \(note.content.count) chars
            """)

        // Also log to the existing ClassificationAnalytics for backward compatibility
        ClassificationAnalytics.shared.logCorrection(
            note: note,
            originalType: originalType,
            correctedType: correctedType,
            originalMethod: originalMethod,
            originalConfidence: originalConfidence
        )
    }
}
