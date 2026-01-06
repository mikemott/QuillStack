//
//  ClassificationAnalyticsService.swift
//  QuillStack
//
//  Created on 2026-01-06.
//

import Foundation
import CoreData
import os.log

/// Analytics service for tracking hashtag usage and classification methods.
/// Used to inform hashtag deprecation decisions (QUI-125).
@MainActor
class ClassificationAnalyticsService {

    static let shared = ClassificationAnalyticsService()

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "QuillStack", category: "ClassificationAnalytics")

    private init() {}

    // MARK: - Data Models

    struct ClassificationStats {
        let totalNotes: Int
        let explicitCount: Int // Hashtag-based classification
        let llmCount: Int // AI-based classification
        let heuristicCount: Int // Pattern-based classification
        let unknownCount: Int // No classification method recorded

        var explicitPercentage: Double {
            guard totalNotes > 0 else { return 0.0 }
            return (Double(explicitCount) / Double(totalNotes)) * 100.0
        }

        var llmPercentage: Double {
            guard totalNotes > 0 else { return 0.0 }
            return (Double(llmCount) / Double(totalNotes)) * 100.0
        }

        var heuristicPercentage: Double {
            guard totalNotes > 0 else { return 0.0 }
            return (Double(heuristicCount) / Double(totalNotes)) * 100.0
        }
    }

    struct TrendDataPoint {
        let date: Date
        let explicitCount: Int
        let totalCount: Int

        var explicitPercentage: Double {
            guard totalCount > 0 else { return 0.0 }
            return (Double(explicitCount) / Double(totalCount)) * 100.0
        }
    }

    struct TypeBreakdown {
        let noteType: String
        let explicitCount: Int
        let totalCount: Int

        var explicitPercentage: Double {
            guard totalCount > 0 else { return 0.0 }
            return (Double(explicitCount) / Double(totalCount)) * 100.0
        }
    }

    // MARK: - Private Helpers

    /// Validate days parameter to prevent invalid ranges
    private func validateDays(_ days: Int) -> Bool {
        guard days > 0 && days <= 365 else {
            logger.warning("Invalid days parameter: \(days). Must be between 1 and 365.")
            return false
        }
        return true
    }

    /// Count notes matching a classification method
    private func countForMethod(_ method: String?, in context: NSManagedObjectContext) -> Int {
        let request = NSFetchRequest<Note>(entityName: "Note")
        if let method = method {
            request.predicate = NSPredicate(format: "classificationMethod == %@", method)
        } else {
            request.predicate = NSPredicate(format: "classificationMethod == nil")
        }
        return (try? context.count(for: request)) ?? 0
    }

    // MARK: - Overall Statistics

    /// Get overall classification statistics for all notes
    func getOverallStats(context: NSManagedObjectContext) -> ClassificationStats? {
        do {
            let totalRequest = NSFetchRequest<Note>(entityName: "Note")
            let totalNotes = try context.count(for: totalRequest)

            let explicitCount = countForMethod("explicit", in: context)
            let llmCount = countForMethod("llm", in: context)
            let heuristicCount = countForMethod("heuristic", in: context)
            let unknownCount = countForMethod(nil, in: context)

            return ClassificationStats(
                totalNotes: totalNotes,
                explicitCount: explicitCount,
                llmCount: llmCount,
                heuristicCount: heuristicCount,
                unknownCount: unknownCount
            )
        } catch {
            logger.error("Failed to fetch classification stats: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Time-based Trend Analysis

    /// Get trend data for the last N days (1-365)
    func getTrendData(days: Int, context: NSManagedObjectContext) -> [TrendDataPoint] {
        guard validateDays(days) else {
            return []
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var trendData: [TrendDataPoint] = []

        for dayOffset in (0..<days).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else {
                continue
            }

            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: date) else {
                continue
            }

            let datePredicate = NSPredicate(
                format: "createdAt >= %@ AND createdAt < %@",
                date as NSDate,
                nextDate as NSDate
            )

            do {
                // Count total notes for this day
                let totalRequest = NSFetchRequest<Note>(entityName: "Note")
                totalRequest.predicate = datePredicate
                let totalCount = try context.count(for: totalRequest)

                // Count explicit (hashtag) notes for this day
                let explicitRequest = NSFetchRequest<Note>(entityName: "Note")
                let explicitPredicate = NSPredicate(format: "classificationMethod == %@", "explicit")
                explicitRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, explicitPredicate])
                let explicitCount = try context.count(for: explicitRequest)

                trendData.append(TrendDataPoint(
                    date: date,
                    explicitCount: explicitCount,
                    totalCount: totalCount
                ))
            } catch {
                logger.error("Failed to fetch trend data for date \(date.ISO8601Format()): \(error.localizedDescription)")
            }
        }

        return trendData
    }

    // MARK: - Type-based Breakdown

    /// Get hashtag usage breakdown by note type
    func getTypeBreakdown(context: NSManagedObjectContext) -> [TypeBreakdown] {
        let fetchRequest = NSFetchRequest<Note>(entityName: "Note")

        do {
            let notes = try context.fetch(fetchRequest)

            // Group by note type
            let notesByType = Dictionary(grouping: notes) { $0.noteType ?? "unknown" }

            return notesByType.map { noteType, notesOfType in
                let explicitCount = notesOfType.filter { $0.classificationMethod == "explicit" }.count
                return TypeBreakdown(
                    noteType: noteType,
                    explicitCount: explicitCount,
                    totalCount: notesOfType.count
                )
            }
            .sorted { $0.totalCount > $1.totalCount } // Sort by total count descending
        } catch {
            logger.error("Failed to fetch type breakdown: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Recent Usage Analysis

    /// Get statistics for notes created in the last N days (1-365)
    func getRecentStats(days: Int, context: NSManagedObjectContext) -> ClassificationStats? {
        guard validateDays(days) else {
            return nil
        }

        let calendar = Calendar.current
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: Date()) else {
            return nil
        }

        let datePredicate = NSPredicate(format: "createdAt >= %@", startDate as NSDate)

        do {
            // Count total notes
            let totalRequest = NSFetchRequest<Note>(entityName: "Note")
            totalRequest.predicate = datePredicate
            let totalNotes = try context.count(for: totalRequest)

            // Count by classification method
            let explicitRequest = NSFetchRequest<Note>(entityName: "Note")
            explicitRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                datePredicate,
                NSPredicate(format: "classificationMethod == %@", "explicit")
            ])
            let explicitCount = try context.count(for: explicitRequest)

            let llmRequest = NSFetchRequest<Note>(entityName: "Note")
            llmRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                datePredicate,
                NSPredicate(format: "classificationMethod == %@", "llm")
            ])
            let llmCount = try context.count(for: llmRequest)

            let heuristicRequest = NSFetchRequest<Note>(entityName: "Note")
            heuristicRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                datePredicate,
                NSPredicate(format: "classificationMethod == %@", "heuristic")
            ])
            let heuristicCount = try context.count(for: heuristicRequest)

            let unknownRequest = NSFetchRequest<Note>(entityName: "Note")
            unknownRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                datePredicate,
                NSPredicate(format: "classificationMethod == nil")
            ])
            let unknownCount = try context.count(for: unknownRequest)

            return ClassificationStats(
                totalNotes: totalNotes,
                explicitCount: explicitCount,
                llmCount: llmCount,
                heuristicCount: heuristicCount,
                unknownCount: unknownCount
            )
        } catch {
            logger.error("Failed to fetch recent stats: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Decision Support

    /// Generate a recommendation for hashtag deprecation based on usage data
    func getDeprecationRecommendation(context: NSManagedObjectContext) -> String {
        guard let recentStats = getRecentStats(days: 90, context: context) else {
            return "Insufficient data to make a recommendation."
        }

        let explicitPercentage = recentStats.explicitPercentage

        if explicitPercentage < 5.0 {
            return "Hashtag usage is very low (<5%). Consider removing UI hints and moving towards deprecation."
        } else if explicitPercentage > 20.0 {
            return "Hashtag usage is significant (>20%). Keep as a documented power-user feature."
        } else {
            return "Hashtag usage is moderate (5-20%). Continue monitoring trends before making deprecation decisions."
        }
    }
}
